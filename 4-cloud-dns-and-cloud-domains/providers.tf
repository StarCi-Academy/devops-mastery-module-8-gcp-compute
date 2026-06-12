# providers.tf — terraform block + Google provider for the Cloud DNS lab. This
# lesson provisions REAL Cloud DNS resources (a public google_dns_managed_zone
# with DNSSEC, several google_dns_record_set, and a private split-horizon zone
# bound to a VPC). `terraform fmt/validate/init` run offline; `plan/apply` need
# GCP credentials (see .e2e/agnostic/*-require-creds.md).

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
