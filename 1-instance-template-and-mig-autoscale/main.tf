# main.tf — instance template + regional MIG + autoscaler + health check,
# terraform-first.
#
# Mental model: an INSTANCE TEMPLATE is an immutable, versioned blueprint (image,
# machine_type, disk, network, startup script). A REGIONAL MANAGED INSTANCE GROUP
# (MIG) stamps out N copies of that blueprint and — because it is REGIONAL —
# spreads them evenly across the zones of the region, self-healing failed VMs
# against a HEALTH CHECK. A REGION AUTOSCALER moves the MIG size toward a CPU
# target. This differs from AWS: the MIG is multi-zone by DEFAULT (no per-zone
# wiring), and the autoscaler is a SEPARATE resource that points at the MIG's
# self_link rather than a policy attached to the group.
# `terraform fmt/validate/init` run offline; `plan/apply` need real GCP
# credentials (see .e2e/agnostic/*-require-creds.md).

locals {
  # Every resource carries these labels so a label-filtered cleanup sweeps
  # exactly this lesson's resources in a shared project (no accidental cost
  # leak). GCP labels are lowercase key/value (max 63 chars) — NOT the
  # capitalised Tag of AWS.
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
# Instance template — the immutable, versioned blueprint the MIG launches from.
# Changing any field forces a NEW template (name_prefix + create_before_destroy)
# because a template is immutable once created.
# ---------------------------------------------------------------------------
resource "google_compute_instance_template" "lab" {
  # name_prefix (not name) lets Terraform create a NEW template before destroying
  # the old one on replace, so there is never a name collision and the MIG can
  # roll onto the new version (create-before-destroy).
  name_prefix  = "starci-mig-tpl-"
  machine_type = var.machine_type

  # disk — the boot disk spec. source_image from the resolved family; auto_delete
  # so the disk is not orphaned (left billing) when an instance is replaced; boot
  # marks it the boot volume.
  disk {
    source_image = data.google_compute_image.debian.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = 30
    disk_type    = "pd-standard"
  }

  # network_interface — empty access_config attaches an ephemeral external IP so
  # the bootstrapped nginx is reachable for the lab.
  network_interface {
    network = "default"
    access_config {
      # ephemeral public IP (no static address reserved)
    }
  }

  # metadata_startup_script — runs once at first boot. Plain text here; the
  # provider stores it on the startup-script metadata key (no base64 needed,
  # unlike AWS user_data which must be base64-encoded).
  metadata_startup_script = <<-EOF
    #!/usr/bin/env bash
    set -euo pipefail
    apt-get update -y
    apt-get install -y nginx stress-ng
    echo "ok" > /var/www/html/healthz
    systemctl enable --now nginx
  EOF

  # tags — network tags (NOT billing labels). Firewall rules and the health
  # check source ranges target these.
  tags = ["http-server"]

  # labels — key/value pairs for billing/cleanup filtering.
  labels = local.common_labels

  # scheduling — STANDARD = on-demand. SPOT would cut cost ~60-91% but lets
  # Google reclaim the VM with a 30s notice (fine for stateless MIG workers).
  scheduling {
    provisioning_model = "STANDARD"
    preemptible        = false
    automatic_restart  = true
  }

  # service_account — key-free identity for code on the box. cloud-platform
  # scope + IAM roles is the modern path (no long-lived key file).
  service_account {
    email  = "default"
    scopes = ["cloud-platform"]
  }

  # A template is immutable; create the replacement before deleting the old one
  # so the MIG always has a valid version to reference.
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Health check — the signal the MIG's autohealer (and any load balancer) uses
# to decide a VM is alive. Exactly ONE protocol block is allowed.
# ---------------------------------------------------------------------------
resource "google_compute_health_check" "lab" {
  name = "starci-mig-hc"

  # check_interval_sec / timeout_sec — probe every 10s, fail a probe after 5s.
  check_interval_sec = 10
  timeout_sec        = 5
  # thresholds — 2 consecutive successes mark healthy, 3 failures mark unhealthy.
  healthy_threshold   = 2
  unhealthy_threshold = 3

  # http_health_check — probe HTTP GET /healthz on port 80. request_path served
  # by the nginx static file the startup script writes.
  http_health_check {
    port         = 80
    request_path = "/healthz"
  }
}

# ---------------------------------------------------------------------------
# Regional MIG — stamps the template across the region's zones, self-heals.
# ---------------------------------------------------------------------------
resource "google_compute_region_instance_group_manager" "lab" {
  name = "starci-mig-${var.lesson}"
  # region (not zone) is what makes this a REGIONAL MIG: instances are spread
  # evenly across the zones of the region automatically.
  region = var.region
  # base_instance_name — prefix for the generated VM names (a random suffix is
  # appended per instance).
  base_instance_name = "starci-mig"

  # version — which template to launch. A MIG can carry two versions for canary;
  # here a single version points at the template by self_link.
  version {
    instance_template = google_compute_instance_template.lab.self_link
  }

  # target_size — initial instance count. The autoscaler overwrites this at
  # runtime, so ignore_changes below keeps `apply` from fighting it.
  target_size = var.target_size

  # named_port — names a port so a backend service / load balancer can target
  # it by name later (the LB lesson builds on this).
  named_port {
    name = "http"
    port = 80
  }

  # auto_healing_policies — recreate a VM that fails the health check.
  # initial_delay_sec gives a fresh VM 120s to run its startup script before the
  # autohealer starts probing (too short -> it kills VMs still installing nginx).
  auto_healing_policies {
    health_check      = google_compute_health_check.lab.id
    initial_delay_sec = 120
  }

  # update_policy — how a template change rolls out. PROACTIVE + a max_surge of 4
  # (one per zone in us-central1: a/b/c/f) adds new VMs before removing old ones,
  # so the fleet never drops capacity during a rolling update (the GCP analogue of
  # AWS instance refresh). For a REGIONAL MIG, max_surge_fixed must be 0 OR >= the
  # number of zones in the region (4 for us-central1).
  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 4
    max_unavailable_fixed = 0
  }

  # The autoscaler OWNS target_size at runtime; without this ignore every
  # `terraform apply` would reset the count and fight the autoscaler.
  lifecycle {
    ignore_changes = [target_size]
  }
}

# ---------------------------------------------------------------------------
# Region autoscaler — a SEPARATE resource (unlike AWS) that points at the MIG
# and holds average CPU at the target, scaling between min/max replicas.
# ---------------------------------------------------------------------------
resource "google_compute_region_autoscaler" "lab" {
  name   = "starci-mig-autoscaler"
  region = var.region
  # target — the self_link of the MIG this autoscaler drives. One autoscaler per
  # MIG; this is the wiring that makes the group elastic.
  target = google_compute_region_instance_group_manager.lab.self_link

  autoscaling_policy {
    # min/max_replicas — the hard bounds the autoscaler moves between.
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
    # cooldown_period — seconds to wait after a new VM boots before its metrics
    # count, so warm-up CPU does not cause false scale-out thrashing.
    cooldown_period = 60

    # cpu_utilization — target-tracking on average CPU. A single target (0.6)
    # is enough; GCP derives the scale-out/scale-in steps from it.
    cpu_utilization {
      target = var.cpu_target
    }
  }
}
