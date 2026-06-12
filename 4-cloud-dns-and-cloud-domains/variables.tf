# variables.tf — parameterise project, location, the zone DNS name and the two
# IPs the split-horizon zones resolve to.
variable "project" {
  description = "GCP project ID the provider operates in. A project is GCP's isolation boundary (billing, quota, IAM all scoped here)."
  type        = string
}

variable "region" {
  description = "GCP region the provider defaults to. Cloud DNS is global anycast, but the VPC subnet for the private zone is regional."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCE zone the provider defaults to. Cloud DNS itself is not zonal; this only matters if the lab also touches zonal resources."
  type        = string
  default     = "us-central1-a"
}

variable "dns_name" {
  description = "Fully-qualified DNS name of the managed zone, WITH the trailing dot (e.g. lab.example.com.). Use a subdomain you control or a test-only name."
  type        = string
  default     = "lab.starci-academy.dev."
}

variable "anycast_ip" {
  description = "The global anycast IPv4 the public A record points to — the IP of the global forwarding rule built in the Cloud LB lesson. Override with a real reserved IP."
  type        = string
  default     = "34.120.0.10"
}

variable "internal_ip" {
  description = "The internal LB IPv4 the PRIVATE split-horizon A record resolves to for clients inside the VPC."
  type        = string
  default     = "10.0.0.100"
}

variable "lesson" {
  description = "Lesson slug written into the lesson label so a cleanup script can filter exactly these resources."
  type        = string
  default     = "4-cloud-dns-and-cloud-domains"
}
