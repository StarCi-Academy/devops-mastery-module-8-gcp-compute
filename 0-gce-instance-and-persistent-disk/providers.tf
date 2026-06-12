# providers.tf — terraform block + Google provider for the GCE instance +
# persistent disk lab. This lesson provisions REAL GCP compute (one
# google_compute_instance with a boot disk, one extra google_compute_disk
# attached to it, and one google_compute_snapshot of that disk).
# `terraform fmt/validate/init` run offline; `plan/apply` need GCP credentials
# (see .e2e/agnostic/*-require-creds.md).

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# GCP differs from AWS here: a PROJECT is the hard isolation boundary (every
# resource lives in exactly one project, billing/quota/IAM are per-project).
# Credentials are read in order: GOOGLE_APPLICATION_CREDENTIALS (a service
# account key file) -> `gcloud auth application-default login` ADC. NEVER
# hardcode a key path or secret here.
provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}
