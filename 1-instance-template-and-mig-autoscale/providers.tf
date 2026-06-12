# providers.tf — terraform block + Google provider for the instance template +
# regional MIG + autoscaler lab. This lesson provisions REAL GCP compute (one
# google_compute_instance_template, one regional google_compute_health_check,
# one google_compute_region_instance_group_manager spread across the region's
# zones, and one google_compute_region_autoscaler driving it on CPU).
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
}
