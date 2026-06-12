# providers.tf — terraform block + Google provider for the global external
# HTTP(S) Load Balancer lab. This lesson wires a GLOBAL load balancer that owns
# ONE anycast IP serving the whole planet: a google_compute_health_check, a
# google_compute_backend_service (enable_cdn) fed by a regional MIG, a
# google_compute_url_map (path-based routing), a google_compute_target_http_proxy,
# and a google_compute_global_forwarding_rule.
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
