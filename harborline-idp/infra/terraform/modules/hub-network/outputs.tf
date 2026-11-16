output "vnet_id" {
  description = "Hub VNet resource ID."
  value       = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  description = "Hub VNet name."
  value       = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Firewall private IP — next hop for spoke UDRs and DNS server for spokes (DNS proxy)."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "shared_pe_subnet_id" {
  description = "Subnet for shared-service private endpoints (ACR)."
  value       = azurerm_subnet.shared_pe.id
}

output "firewall_policy_id" {
  description = "Firewall policy ID (spoke stacks may add rule collection groups)."
  value       = azurerm_firewall_policy.this.id
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone name => resource ID."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}
