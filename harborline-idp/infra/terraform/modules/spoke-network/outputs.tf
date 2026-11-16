output "vnet_id" {
  description = "Spoke VNet ID."
  value       = azurerm_virtual_network.spoke.id
}

output "vnet_name" {
  description = "Spoke VNet name."
  value       = azurerm_virtual_network.spoke.name
}

output "subnet_ids" {
  description = "Map of subnet key => subnet ID (aks-system, aks-user, agw, pe, ilb, runners)."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "subnet_cidrs" {
  description = "Map of subnet key => CIDR."
  value       = { for k, v in local.subnets : k => v.cidr }
}

output "ingress_internal_ip" {
  description = "Static private IP reserved for the internal NGINX ingress load balancer."
  value       = cidrhost(local.subnets["ilb"].cidr, 10)
}

output "route_table_id" {
  description = "Egress route table ID (AKS uses userDefinedRouting outbound type)."
  value       = azurerm_route_table.egress.id
}
