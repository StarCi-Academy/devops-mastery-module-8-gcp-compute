# outputs.tf — values printed after apply (read with `terraform output`).
output "instance_id" {
  description = "Self link / ID of the lab GCE instance."
  value       = google_compute_instance.lab.id
}

output "instance_external_ip" {
  description = "Ephemeral external IPv4 of the lab instance (reach the nginx bootstrap here)."
  value       = google_compute_instance.lab.network_interface[0].access_config[0].nat_ip
}

output "boot_image" {
  description = "Self link of the Debian 12 image the boot disk was initialized from."
  value       = data.google_compute_image.debian.self_link
}

output "data_disk_id" {
  description = "ID of the standalone pd-balanced data disk attached to the instance."
  value       = google_compute_disk.data.id
}

output "snapshot_id" {
  description = "ID of the snapshot taken of the data disk."
  value       = google_compute_snapshot.data.id
}
