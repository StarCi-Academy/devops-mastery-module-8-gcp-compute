locals {
  common_labels = {
    lesson  = var.lesson
    managed = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Cloud Armor security policy — WAF (OWASP CRS) + rate limit + adaptive L7 DDoS.
# A security policy is NOT a standalone appliance like AWS WAF: it is ATTACHED to
# a backend service (see security_policy below) and evaluated at the Google edge
# POP, before traffic reaches the backend region.
# -----------------------------------------------------------------------------
resource "google_compute_security_policy" "web" {
  name = "starci-web-armor"
  # type — CLOUD_ARMOR is the edge WAF policy (vs CLOUD_ARMOR_EDGE / network).
  type        = "CLOUD_ARMOR"
  description = "Lab Cloud Armor: OWASP SQLi rule + per-IP rate limit"

  # Rule 1000 — block OWASP CRS SQL-injection patterns. The preconfigured WAF
  # expression is auto-updated by Google's security team when a new CVE lands.
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
    description = "Block OWASP CRS SQL injection"
  }

  # Rule 2000 — per-IP rate limit: 100 requests / 60s, then ban the IP for 60s.
  # enforce_on_key = IP gives each source IP its OWN cell/counter (cell-based),
  # so one abuser does not throttle every other user.
  rule {
    action   = "rate_based_ban"
    priority = 2000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 60
    }
    description = "Rate limit 100/min per IP, ban 60s"
  }

  # Default rule — required: priority 2147483647 matching "*". Allow everything
  # that the rules above did not deny.
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow"
  }

  # Adaptive Protection — ML-based L7 DDoS detection. FREE; surfaces rule
  # suggestions for volumetric / low-and-slow attacks.
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
}

# -----------------------------------------------------------------------------
# Global external HTTP load balancer stack. Order of data flow:
#   global_forwarding_rule -> target_http_proxy -> url_map -> backend_service
# The single anycast IP on the forwarding rule serves the WHOLE planet — unlike
# an AWS ALB, which is regional and needs Route 53 latency routing across regions.
# -----------------------------------------------------------------------------

# Health check — the LB only sends traffic to backends that pass this probe.
resource "google_compute_health_check" "web" {
  name                = "starci-web-hc"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# Backend service — the L7 backend the LB routes to. Cloud CDN is enabled INLINE
# here (one flag, enable_cdn) and the Cloud Armor policy is attached INLINE here
# (security_policy). No separate CloudFront distribution / WAF Web ACL needed.
resource "google_compute_backend_service" "web" {
  name = "starci-web-backend"
  # protocol — talk HTTP to the backends.
  protocol = "HTTP"
  # load_balancing_scheme — EXTERNAL_MANAGED is the modern global external HTTP LB.
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.web.id]

  # backend — the regional MIG that serves traffic (passed in from lesson 1).
  # Guarded by a count-style for_each so the config still VALIDATES offline when
  # no real instance group is supplied.
  dynamic "backend" {
    for_each = var.backend_instance_group == "" ? [] : [var.backend_instance_group]
    content {
      group          = backend.value
      balancing_mode = "UTILIZATION"
    }
  }

  # enable_cdn — turn on Cloud CDN edge caching for this backend service.
  enable_cdn = true

  cdn_policy {
    # cache_mode — USE_ORIGIN_HEADERS is the production default: the backend's
    # Cache-Control header decides what is cacheable (predictable, versioned).
    # Note: default_ttl/max_ttl/client_ttl cannot be set with USE_ORIGIN_HEADERS.
    cache_mode = "USE_ORIGIN_HEADERS"
    # negative_caching — cache 404/410 briefly to avoid a thundering herd on dead URLs.
    negative_caching = true
    # serve_while_stale — serve stale cache for up to 24h if the origin is down.
    serve_while_stale            = 86400
    signed_url_cache_max_age_sec = 7200

    cache_key_policy {
      # include_query_string=false collapses ?ts=123 noise so random query params
      # do not blow up the cache key into per-request unique misses.
      # Note: query_string_blacklist/whitelist cannot be set when include_query_string=false.
      include_query_string = false
    }
  }

  # security_policy — attach the Cloud Armor policy. Without this the policy
  # exists but enforces nothing.
  security_policy = google_compute_security_policy.web.id
}

# Signed-URL key — HMAC key on the backend service so the EDGE can validate
# signed URLs for private content WITHOUT calling the origin.
resource "google_compute_backend_service_signed_url_key" "video" {
  name            = "video-key"
  key_value       = var.signed_url_key
  backend_service = google_compute_backend_service.web.name
}

# URL map — host/path routing. Default sends everything to the web backend.
resource "google_compute_url_map" "web" {
  name            = "starci-web-urlmap"
  default_service = google_compute_backend_service.web.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.web.id

    # /static/* and /private/* both ride the same CDN-enabled backend here; in
    # production these often point at a backend BUCKET vs a backend SERVICE.
    path_rule {
      paths   = ["/static/*"]
      service = google_compute_backend_service.web.id
    }
  }
}

# Target HTTP proxy — binds the forwarding rule to the URL map.
resource "google_compute_target_http_proxy" "web" {
  name    = "starci-web-proxy"
  url_map = google_compute_url_map.web.id
}

# Global forwarding rule — the single GLOBAL anycast entry point. port_range 80,
# scheme matches the backend service.
resource "google_compute_global_forwarding_rule" "web" {
  name                  = "starci-web-fwd"
  target                = google_compute_target_http_proxy.web.id
  port_range            = "80"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  labels                = local.common_labels
}

# -----------------------------------------------------------------------------
# Cloud DNS — a managed zone + an A record pointing the friendly hostname at the
# LB's single anycast IP. One IP, resolved the same everywhere on Earth.
# -----------------------------------------------------------------------------
resource "google_dns_managed_zone" "web" {
  name        = "starci-web-zone"
  dns_name    = var.dns_name
  description = "Lab public zone for the Cloud Armor + CDN edge stack"
  visibility  = "public"
  labels      = local.common_labels
}

resource "google_dns_record_set" "web" {
  name         = "www.${google_dns_managed_zone.web.dns_name}"
  managed_zone = google_dns_managed_zone.web.name
  type         = "A"
  ttl          = 300
  # rrdatas — the anycast IPv4 the global forwarding rule was assigned.
  rrdatas = [google_compute_global_forwarding_rule.web.ip_address]
}
