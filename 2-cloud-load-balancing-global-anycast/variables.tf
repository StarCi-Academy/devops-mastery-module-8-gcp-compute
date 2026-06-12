# variables.tf — parameterise project, region, machine shape and the lesson
# label used by a cleanup sweep.
variable "project" {
  description = "GCP project ID the provider operates in. A project is GCP's isolation boundary (billing, quota, IAM all scoped here)."
  type        = string
}

variable "region" {
  description = "GCP region the backend MIG spreads instances across. The LB itself is GLOBAL (anycast) and is not pinned to a region."
  type        = string
  default     = "us-central1"
}

variable "machine_type" {
  description = "GCE machine type the backend template launches. e2-micro is the always-free shape in us-central1/us-east1/us-west1 (1 instance/month)."
  type        = string
  default     = "e2-micro"
}

variable "backend_size" {
  description = "Number of backend VMs the regional MIG runs behind the load balancer."
  type        = number
  default     = 2
}

variable "lesson" {
  description = "Lesson slug written into the lesson label so a cleanup script can filter exactly these resources in a shared project."
  type        = string
  default     = "2-cloud-load-balancing-global-anycast"
}
