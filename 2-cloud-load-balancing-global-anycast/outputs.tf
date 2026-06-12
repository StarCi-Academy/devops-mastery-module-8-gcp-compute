# outputs.tf — values printed after apply (read with `terraform output`).
output "anycast_ip" {
  description = "The single global anycast IP the forwarding rule serves on. The same IP answers from every region via Google's edge POPs."
  value       = google_compute_global_forwarding_rule.web.ip_address
}

output "forwarding_rule_name" {
  description = "Name of the global forwarding rule (the main hourly cost driver — delete first on cleanup)."
  value       = google_compute_global_forwarding_rule.web.name
}

output "backend_service_name" {
  description = "Name of the global backend service (Cloud CDN enabled) fed by the regional MIG."
  value       = google_compute_backend_service.web.name
}

output "url_map_name" {
  description = "Name of the URL map holding the path-based routing rules."
  value       = google_compute_url_map.web.name
}

output "mig_name" {
  description = "Name of the regional MIG that is the LB's backend (used by gcloud list-instances)."
  value       = google_compute_region_instance_group_manager.lab.name
}
