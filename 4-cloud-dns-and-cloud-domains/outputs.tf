# outputs.tf — values printed after apply (read with `terraform output`).
output "public_zone_name_servers" {
  description = "The Google anycast nameservers (ns-cloud-*.googledomains.com) to delegate to at the registrar/parent zone."
  value       = google_dns_managed_zone.public.name_servers
}

output "public_zone_id" {
  description = "ID of the public managed zone."
  value       = google_dns_managed_zone.public.id
}

output "private_zone_id" {
  description = "ID of the private split-horizon managed zone bound to the VPC."
  value       = google_dns_managed_zone.private.id
}

output "apex_public_ip" {
  description = "The anycast IP the public apex A record resolves to (the Cloud LB global forwarding rule)."
  value       = var.anycast_ip
}

output "apex_private_ip" {
  description = "The internal IP the private apex A record resolves to from inside the VPC."
  value       = var.internal_ip
}
