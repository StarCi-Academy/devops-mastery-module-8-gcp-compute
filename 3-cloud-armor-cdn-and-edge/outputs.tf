# outputs.tf — values printed after apply (read with `terraform output`).
output "anycast_ip" {
  description = "The single GLOBAL anycast IPv4 of the forwarding rule — resolves the same everywhere."
  value       = google_compute_global_forwarding_rule.web.ip_address
}

output "security_policy_id" {
  description = "Self link / ID of the attached Cloud Armor security policy."
  value       = google_compute_security_policy.web.id
}

output "backend_service_id" {
  description = "ID of the CDN-enabled backend service the Armor policy is attached to."
  value       = google_compute_backend_service.web.id
}

output "dns_record_name" {
  description = "The A record FQDN pointing at the anycast IP."
  value       = google_dns_record_set.web.name
}
