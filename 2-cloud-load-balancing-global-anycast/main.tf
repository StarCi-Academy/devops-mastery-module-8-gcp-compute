# main.tf — global external HTTP(S) Load Balancer, terraform-first.
#
# Mental model: a GLOBAL external HTTP(S) LB owns ONE anycast IP advertised from
# every Google edge POP, so a user in Singapore and a user in the US resolve the
# SAME IP and Google's network routes each to the nearest healthy backend region.
# This is the big difference from an AWS ALB, which is REGIONAL (one ALB per
# region + Route 53 / Global Accelerator to go global). The LB is assembled from
# five resources that chain front-to-back:
#
#   global_forwarding_rule (anycast IP :80)
#        -> target_http_proxy
#             -> url_map (path-based routing + default_service)
#                  -> backend_service (enable_cdn, health_checks, balancing RATE)
#                       -> regional MIG (the actual VMs)
#   health_check  feeds the backend_service AND the MIG autohealer
#
# `terraform fmt/validate/init` run offline; `plan/apply` need real GCP
# credentials (see .e2e/agnostic/*-require-creds.md).

locals {
  # Every resource carries these labels so a label-filtered cleanup sweeps
  # exactly this lesson's resources in a shared project. GCP labels are
  # lowercase key/value (max 63 chars) — NOT the capitalised Tag of AWS.
  common_labels = {
    course     = "devops-mastery"
    lesson     = var.lesson
    managed-by = "terraform"
  }
}

# Resolve the latest non-deprecated Debian 12 image from its image FAMILY
# instead of pinning an image name that goes stale as Google ships CVE patches.
data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

# ---------------------------------------------------------------------------
# Backend fleet — an instance template + regional MIG (built in lesson 1). The
# named_port "http" is what the backend service targets by name. nginx serves a
# page naming its zone so we can SEE which region answered an anycast request.
# ---------------------------------------------------------------------------
resource "google_compute_instance_template" "lab" {
  name_prefix  = "starci-lb-tpl-"
  machine_type = var.machine_type

  disk {
    source_image = data.google_compute_image.debian.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = 30
    disk_type    = "pd-standard"
  }

  network_interface {
    network = "default"
    access_config {
      # ephemeral public IP (no static address reserved)
    }
  }

  # Serve the zone name at / and a 200 at /healthz so an anycast curl shows which
  # region answered and the health check has a target.
  metadata_startup_script = <<-EOF
    #!/usr/bin/env bash
    set -euo pipefail
    apt-get update -y
    apt-get install -y nginx
    ZONE=$(curl -s -H "Metadata-Flavor: Google" \
      "http://metadata.google.internal/computeMetadata/v1/instance/zone" | awk -F/ '{print $NF}')
    echo "Hello from $(hostname) ($ZONE)" > /var/www/html/index.html
    echo "ok" > /var/www/html/healthz
    systemctl enable --now nginx
  EOF

  # Network tag the firewall rule targets so Google's health-check probers can
  # reach port 80.
  tags = ["http-server"]

  labels = local.common_labels

  service_account {
    email  = "default"
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# health_check — the signal the backend service uses to decide a backend is
# serving. Exactly ONE protocol block is allowed. The backend service drops a
# backend out of rotation the moment it fails this probe.
resource "google_compute_health_check" "lab" {
  name = "starci-lb-hc"

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/healthz"
  }
}

resource "google_compute_region_instance_group_manager" "lab" {
  name               = "starci-lb-${var.lesson}"
  region             = var.region
  base_instance_name = "starci-lb"

  version {
    instance_template = google_compute_instance_template.lab.self_link
  }

  target_size = var.backend_size

  # named_port — the backend service references this port BY NAME ("http"), so
  # the LB layer never hardcodes the number 80.
  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.lab.id
    initial_delay_sec = 120
  }
}

# ---------------------------------------------------------------------------
# Firewall — Google's health-check probers come from 130.211.0.0/22 and
# 35.191.0.0/16. Without an ingress rule allowing them to the backend port,
# EVERY backend reports unhealthy and the LB returns 502. This is the #1
# beginner pitfall on GCP load balancing.
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "allow_health_check" {
  name    = "starci-lb-allow-hc"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # The two Google-owned ranges every GCP LB / health check probes from.
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["http-server"]
}

# ---------------------------------------------------------------------------
# Backend service — the GLOBAL pool of backends. load_balancing_scheme
# EXTERNAL_MANAGED selects the modern global external HTTP(S) LB data plane
# (Envoy-based) that supports advanced features (Cloud Armor, advanced traffic
# management); the legacy EXTERNAL scheme is being phased out. enable_cdn turns
# on Cloud CDN edge caching in front of this backend.
# ---------------------------------------------------------------------------
resource "google_compute_backend_service" "web" {
  name                  = "starci-lb-web-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  # port_name resolves against the MIG's named_port, so traffic lands on port 80
  # without the LB knowing the number.
  port_name = "http"
  # health_checks (Required for a backend service with instance-group backends) —
  # a backend only receives traffic while it passes this probe.
  health_checks = [google_compute_health_check.lab.id]
  timeout_sec   = 30

  # enable_cdn — "If true, enable Cloud CDN for this BackendService." Cacheable
  # responses are served from Google's edge POPs, cutting latency and backend
  # load. The cache_mode below caches based on the origin's Cache-Control headers.
  enable_cdn = true
  cdn_policy {
    cache_mode  = "USE_ORIGIN_HEADERS"
    default_ttl = 3600
    client_ttl  = 3600
    max_ttl     = 86400
    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = true
    }
  }

  # backend — the group that serves traffic. balancing_mode RATE caps requests
  # per second per instance (the natural fit for HTTP); UTILIZATION balances on
  # CPU and CONNECTION balances open connections (used for L4 / TCP). capacity_scaler
  # 1.0 makes the full max_rate available.
  backend {
    group                 = google_compute_region_instance_group_manager.lab.instance_group
    balancing_mode        = "RATE"
    max_rate_per_instance = 100
    capacity_scaler       = 1.0
  }
}

# ---------------------------------------------------------------------------
# URL map — the routing brain. default_service catches everything; a path_matcher
# sends /api/* to a different backend. Here both paths point at the same backend
# for the lab, but the WIRING shows how one anycast IP fans out by path without a
# second forwarding rule (each extra forwarding rule is the main hourly cost).
# Matches are longest-path-first; a path must start with / and may only end in /*.
# ---------------------------------------------------------------------------
resource "google_compute_url_map" "web" {
  name            = "starci-lb-url-map"
  default_service = google_compute_backend_service.web.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "main"
  }

  path_matcher {
    name            = "main"
    default_service = google_compute_backend_service.web.id

    path_rule {
      paths   = ["/api", "/api/*"]
      service = google_compute_backend_service.web.id
    }
  }
}

# ---------------------------------------------------------------------------
# Target HTTP proxy — "used by one or more global forwarding rule to route
# incoming HTTP requests to a URL map." It is the glue between the IP-level
# forwarding rule and the URL-level routing map.
# ---------------------------------------------------------------------------
resource "google_compute_target_http_proxy" "web" {
  name    = "starci-lb-http-proxy"
  url_map = google_compute_url_map.web.id
}

# ---------------------------------------------------------------------------
# Global forwarding rule — binds the anycast IP + port to the proxy. Because it
# is GLOBAL and load_balancing_scheme is EXTERNAL_MANAGED, the ip_address Google
# assigns is an ANYCAST address advertised from every edge POP. This single
# resource is what makes one IP serve the whole planet — and it is the main
# hourly cost driver of the LB (billed per hour even at zero traffic).
# ---------------------------------------------------------------------------
resource "google_compute_global_forwarding_rule" "web" {
  name                  = "starci-lb-fwd-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  ip_protocol           = "TCP"
  target                = google_compute_target_http_proxy.web.id
  labels                = local.common_labels
}
