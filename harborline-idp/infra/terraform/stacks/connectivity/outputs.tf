output "hub_vnet_id" {
  description = "Hub VNet ID."
  value       = module.hub.vnet_id
}

output "firewall_private_ip" {
  description = "Firewall private IP."
  value       = module.hub.firewall_private_ip
}

output "private_dns_zone_ids" {
  description = "Central private DNS zone IDs."
  value       = module.hub.private_dns_zone_ids
}
