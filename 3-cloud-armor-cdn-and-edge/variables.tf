# variables.tf — parameterise project, region, the MIG backend reference and the
# DNS zone name. The instance group that serves traffic is created in the
# previous lesson (1-instance-template-and-mig-autoscale); pass its self_link in
# via var.backend_instance_group so this lesson focuses on the edge stack.
variable "project" {
  description = "GCP project ID the provider operates in. A project is GCP's isolation boundary (billing, quota, IAM all scoped here)."
  type        = string
}

variable "region" {
  description = "GCP region the provider defaults to (e.g. us-central1). The LB itself is GLOBAL — only the backend MIG is regional."
  type        = string
  default     = "us-central1"
}

variable "backend_instance_group" {
  description = "Self link of the regional MIG (instanceGroup) that serves traffic, e.g. from lesson 1. Leave empty to validate the config offline without a real backend."
  type        = string
  default     = ""
}

variable "dns_name" {
  description = "Fully-qualified DNS name of the managed zone, MUST end with a trailing dot, e.g. 'lab.example.com.'. Use a domain you own for a real apply."
  type        = string
  default     = "lab.example.com."
}

variable "signed_url_key" {
  description = "128-bit base64url-encoded HMAC key for Cloud CDN signed URLs. Generate with `head -c 16 /dev/urandom | base64 | tr +/ -_`. NEVER commit a real key — pass via TF_VAR_signed_url_key."
  type        = string
  default     = "aGVsbG8td29ybGQtMTIzNA" # placeholder for offline validate only
  sensitive   = true
}

variable "lesson" {
  description = "Lesson slug written into every resource's lesson label so a cleanup script can filter exactly these resources."
  type        = string
  default     = "3-cloud-armor-cdn-and-edge"
}
