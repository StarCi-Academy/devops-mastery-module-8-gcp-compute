# outputs.tf — values printed after apply (read with `terraform output`).
output "instance_template_self_link" {
  description = "Self link of the instance template the MIG launches instances from."
  value       = google_compute_instance_template.lab.self_link
}

output "instance_template_name" {
  description = "Generated name of the instance template (name_prefix + random suffix)."
  value       = google_compute_instance_template.lab.name
}

output "mig_name" {
  description = "Name of the regional MIG (used by gcloud list-instances / resize commands)."
  value       = google_compute_region_instance_group_manager.lab.name
}

output "mig_instance_group" {
  description = "Self link of the instance group the MIG manages (the backend a load balancer would target)."
  value       = google_compute_region_instance_group_manager.lab.instance_group
}

output "health_check_self_link" {
  description = "Self link of the health check used by the autohealer."
  value       = google_compute_health_check.lab.self_link
}

output "autoscaler_name" {
  description = "Name of the region autoscaler driving the MIG on CPU."
  value       = google_compute_region_autoscaler.lab.name
}
