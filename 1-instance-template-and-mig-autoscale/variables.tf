# variables.tf — parameterise project, region, machine shape, capacity bounds
# and the CPU target the autoscaler holds.
variable "project" {
  description = "GCP project ID the provider operates in. A project is GCP's isolation boundary (billing, quota, IAM all scoped here)."
  type        = string
}

variable "region" {
  description = "GCP region the regional MIG spreads instances across (e.g. us-central1 has zones -a/-b/-c). A REGIONAL MIG is multi-zone by default."
  type        = string
  default     = "us-central1"
}

variable "machine_type" {
  description = "GCE machine type the template launches. e2-micro is the always-free shape in us-central1/us-east1/us-west1 (1 instance/month)."
  type        = string
  default     = "e2-micro"
}

variable "min_replicas" {
  description = "Minimum MIG size. The autoscaler never scales below this even under zero load."
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum MIG size. The autoscaler can never launch more than this — the hard cost ceiling for the lab."
  type        = number
  default     = 3
}

variable "target_size" {
  description = "Initial MIG size before the autoscaler takes over. NOTE: once the autoscaler is attached it owns the size, so the MIG ignores changes to this (see lifecycle.ignore_changes in main.tf)."
  type        = number
  default     = 2
}

variable "cpu_target" {
  description = "Average CPU utilization (0.0-1.0) the autoscaler holds the MIG at. 0.6 = scale out when the fleet averages above 60%."
  type        = number
  default     = 0.6
}

variable "lesson" {
  description = "Lesson slug written into the lesson label so a cleanup script can filter exactly these resources in a shared project."
  type        = string
  default     = "1-instance-template-and-mig-autoscale"
}
