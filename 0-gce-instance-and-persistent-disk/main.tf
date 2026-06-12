# main.tf — GCE instance + persistent disk lab, terraform-first.
#
# Mental model: a GCE instance is a virtual machine carved out of a host in one
# ZONE. Two identity inputs decide WHAT it is (the boot image = the OS disk
# contents, machine_type = the CPU/RAM shape) and WHERE it lives (zone). A
# persistent disk (PD) is a network block device, decoupled from any one
# instance: it lives in the same zone, can be detached from one VM and attached
# to another, and can be snapshotted independently. This lab declares the
# instance, an extra data disk attached to it, and a snapshot of that disk.
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
# `family` returns the newest image in the family automatically.
data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

# The lab GCE instance. Each argument below maps 1:1 to a Registry argument and
# is explained line-by-line in the lesson body (codeExplaining ## 1).
resource "google_compute_instance" "lab" {
  # name — a unique name for the resource, required by GCE.
  name = "starci-gce-lab"
  # machine_type — the CPU/RAM shape. e2-micro is the always-free shape.
  machine_type = var.machine_type
  # zone — the zone the machine is created in. A zonal PD must match this zone.
  zone = var.zone

  # boot_disk — the boot disk for the instance. initialize_params creates a
  # fresh disk from the resolved image; auto_delete=true so the boot disk is
  # NOT orphaned (left billing as an unattached PD) when the instance is gone.
  boot_disk {
    auto_delete = true
    initialize_params {
      image  = data.google_compute_image.debian.self_link
      size   = var.boot_disk_size
      type   = "pd-standard" # standard HDD-backed PD; the 30 GB free tier shape
      labels = local.common_labels
    }
  }

  # network_interface — networks to attach to the instance. Empty access_config
  # block assigns an ephemeral external IP so the bootstrap is reachable.
  network_interface {
    network = "default"
    access_config {
      # ephemeral public IP (no static address reserved)
    }
  }

  # metadata_startup_script — runs once at first boot. Unlike the raw
  # `startup-script` metadata key, changing THIS argument forces the instance
  # to be recreated, so the bootstrap is tracked as part of the desired state.
  metadata_startup_script = <<-EOF
    #!/usr/bin/env bash
    set -euo pipefail
    apt-get update -y
    apt-get install -y nginx
    systemctl enable --now nginx
  EOF

  # tags — network tags (NOT billing labels). Firewall rules target these.
  tags = ["http-server"]

  # labels — key/value pairs for billing/cleanup filtering (the GCP analogue of
  # AWS cost-allocation tags).
  labels = local.common_labels

  # scheduling — controls Spot/preemptible behaviour and host maintenance.
  # provisioning_model = STANDARD is on-demand (NOT preempted). SPOT would cut
  # cost ~60-91% but lets Google reclaim the VM with a 30s notice.
  scheduling {
    provisioning_model  = "STANDARD"
    preemptible         = false
    automatic_restart   = true
    on_host_maintenance = "MIGRATE" # live-migrate during host maintenance
  }

  # service_account — the identity code on the box assumes to call Google APIs,
  # so it gets short-lived tokens with NO long-lived key file. `cloud-platform`
  # scope + IAM roles is the modern, key-free path (Google's answer to IMDSv2).
  service_account {
    email  = "default"
    scopes = ["cloud-platform"]
  }

  # shielded_instance_config — verifiable boot integrity (Secure Boot, vTPM,
  # integrity monitoring) to defend against boot-level malware/rootkits.
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # allow_stopping_for_update — let Terraform stop the VM to apply changes that
  # require a stopped instance (e.g. resizing the machine_type) instead of
  # erroring out on the next apply.
  allow_stopping_for_update = true

  # deletion_protection — FALSE for a lab so `terraform destroy` is not blocked.
  # TRUE for stateful production instances.
  deletion_protection = false
}

# A standalone, zonal persistent disk — NOT a boot disk. This is the key
# decoupling lesson: the disk is an independent resource with its own lifecycle,
# created empty here and attached to the instance below. Same zone as the VM.
resource "google_compute_disk" "data" {
  name   = "starci-data-disk"
  type   = "pd-balanced" # SSD-backed balanced PD: better IOPS than pd-standard
  zone   = var.zone
  size   = var.data_disk_size
  labels = local.common_labels
}

# Attach the data disk to the instance as a SEPARATE resource (rather than an
# inline attached_disk block). google_compute_attached_disk decouples the disk
# lifecycle from the instance lifecycle: you can detach/re-attach without
# recreating the VM, and attach a dynamic number of disks. mode READ_WRITE
# means only ONE instance can attach it at a time.
resource "google_compute_attached_disk" "data" {
  disk        = google_compute_disk.data.id
  instance    = google_compute_instance.lab.id
  device_name = "data-disk"
  mode        = "READ_WRITE"
}

# A snapshot of the data disk. A snapshot is an independent, incremental,
# point-in-time copy stored in Cloud Storage — it survives the disk and can
# restore into a NEW disk (even in another zone/region). source_disk references
# the data disk so Terraform orders creation correctly.
resource "google_compute_snapshot" "data" {
  name        = "starci-data-snapshot"
  source_disk = google_compute_disk.data.id
  zone        = var.zone
  labels      = local.common_labels
}
