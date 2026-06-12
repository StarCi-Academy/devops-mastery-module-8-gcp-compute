# providers.tf — terraform block + Google provider for the Cloud Armor + Cloud
# CDN + edge lab. This lesson builds a full GLOBAL external HTTP load balancer
# (health check -> backend service -> url map -> target http proxy -> global
# forwarding rule), enables Cloud CDN on the backend service, attaches a Cloud
# Armor security policy (WAF + rate limit), adds a signed-URL key, and points a
# Cloud DNS record at the single anycast IP.
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
