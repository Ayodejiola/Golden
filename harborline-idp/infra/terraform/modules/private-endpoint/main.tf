/**
 * private-endpoint — one Private Endpoint with its DNS zone group registered in the central hub zone.
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

variable "name" {
  description = "Private endpoint name (pep-<resource>-<subresource>)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the endpoint."
  type        = string
}

variable "subnet_id" {
  description = "Private endpoint subnet ID."
  type        = string
}

variable "target_resource_id" {
  description = "Resource the endpoint connects to."
  type        = string
}

variable "subresource_names" {
  description = "Group IDs, e.g. [\"vault\"], [\"registry\"], [\"postgresqlServer\"], [\"namespace\"]."
  type        = list(string)
}

variable "private_dns_zone_ids" {
  description = "Central private DNS zone IDs for registration."
  type        = list(string)
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

resource "azurerm_private_endpoint" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.subnet_id
  custom_network_interface_name = "nic-${var.name}"
  tags                          = var.tags

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = var.target_resource_id
    subresource_names              = var.subresource_names
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}

output "id" {
  description = "Private endpoint ID."
  value       = azurerm_private_endpoint.this.id
}

output "private_ip" {
  description = "Private IP address of the endpoint."
  value       = azurerm_private_endpoint.this.private_service_connection[0].private_ip_address
}
