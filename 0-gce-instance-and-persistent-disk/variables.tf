# variables.tf — parameterise project, location, machine shape and disk inputs.
variable "project" {
  description = "GCP project ID the provider operates in. A project is GCP's isolation boundary (billing, quota, IAM all scoped here)."
  type        = string
}

variable "region" {
  description = "GCP region the provider defaults to (e.g. us-central1, asia-southeast1)."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCE zone to start the instance and zonal disks in. A zonal PD attaches only to instances in the SAME zone."
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "GCE machine type. e2-micro is the always-free shape in us-central1/us-east1/us-west1 (1 instance/month)."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_size" {
  description = "Boot disk size in GB. 30 GB pd-standard stays inside the always-free 30 GB-month allowance."
  type        = number
  default     = 30
}

variable "data_disk_size" {
  description = "Extra (non-boot) persistent disk size in GB. Kept small to stay near zero cost."
  type        = number
  default     = 10
}

variable "lesson" {
  description = "Lesson slug written into the lesson label so a cleanup script can filter exactly these resources."
  type        = string
  default     = "0-gce-instance-and-persistent-disk"
}
