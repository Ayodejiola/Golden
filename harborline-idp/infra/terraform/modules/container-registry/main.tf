/**
 * container-registry — ACR Premium, private only, Entra auth only, zone-redundant, geo-replicated.
 * Images and Helm charts from public sources are imported here (ADR-0012); clusters never pull from the internet.
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

resource "azurerm_container_registry" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Premium"
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = false
  network_rule_bypass_option    = "AzureServices"
  data_endpoint_enabled         = true
  export_policy_enabled         = false
  zone_redundancy_enabled       = true
  retention_policy_in_days      = var.untagged_retention_days
  tags                          = var.tags

  dynamic "georeplications" {
    for_each = var.geo_replication_locations
    content {
      location                  = georeplications.value
      zone_redundancy_enabled   = true
      regional_endpoint_enabled = true
      tags                      = var.tags
    }
  }
}

module "pe" {
  count                = var.private_endpoint_subnet_id == null ? 0 : 1
  source               = "../private-endpoint"
  name                 = "pep-${var.name}-registry"
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.private_endpoint_subnet_id
  target_resource_id   = azurerm_container_registry.this.id
  subresource_names    = ["registry"]
  private_dns_zone_ids = [var.private_dns_zone_id]
  tags                 = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "diag-to-law"
  target_resource_id             = azurerm_container_registry.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "audit"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# CI identities push; nothing else may push. Clusters get AcrPull via the aks module.
resource "azurerm_role_assignment" "push" {
  for_each             = var.push_principal_ids
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = each.value
}

variable "name" {
  description = "Registry name (alphanumeric)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group."
  type        = string
}

variable "geo_replication_locations" {
  description = "Additional regions to replicate to (DR region)."
  type        = list(string)
  default     = ["canadaeast"]
}

variable "untagged_retention_days" {
  description = "Days to keep untagged manifests."
  type        = number
  default     = 30
}

variable "private_endpoint_subnet_id" {
  description = "Subnet for the registry private endpoint. Null when the endpoint is created by the connectivity stack."
  type        = string
  default     = null
}

variable "private_dns_zone_id" {
  description = "privatelink.azurecr.io zone ID in the hub (required when private_endpoint_subnet_id is set)."
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Workspace for diagnostic logs."
  type        = string
}

variable "push_principal_ids" {
  description = "Map of name => principal ID allowed to push (CI identities)."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

output "id" {
  description = "Registry ID."
  value       = azurerm_container_registry.this.id
}

output "login_server" {
  description = "Registry login server."
  value       = azurerm_container_registry.this.login_server
}
