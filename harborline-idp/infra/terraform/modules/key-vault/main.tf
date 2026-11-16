/**
 * key-vault — Premium (HSM-backed keys), RBAC-only, purge-protected, private endpoint, deny-by-default firewall.
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

resource "azurerm_key_vault" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "premium"
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

module "pe" {
  source               = "../private-endpoint"
  name                 = "pep-${var.name}-vault"
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.private_endpoint_subnet_id
  target_resource_id   = azurerm_key_vault.this.id
  subresource_names    = ["vault"]
  private_dns_zone_ids = [var.private_dns_zone_id]
  tags                 = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "diag-to-law"
  target_resource_id             = azurerm_key_vault.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs" # includes AuditEvent
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_role_assignment" "this" {
  for_each             = var.role_assignments
  scope                = azurerm_key_vault.this.id
  role_definition_name = each.value.role
  principal_id         = each.value.principal_id
}

variable "name" {
  description = "Key Vault name (<= 24 chars)."
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

variable "tenant_id" {
  description = "Entra tenant ID."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet for the private endpoint."
  type        = string
}

variable "private_dns_zone_id" {
  description = "privatelink.vaultcore.azure.net zone ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace for audit logs."
  type        = string
}

variable "role_assignments" {
  description = "Map of key => { role, principal_id } (e.g. Key Vault Secrets User for a workload identity)."
  type        = map(object({
    role         = string
    principal_id = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

output "id" {
  description = "Key Vault ID."
  value       = azurerm_key_vault.this.id
}

output "uri" {
  description = "Key Vault URI."
  value       = azurerm_key_vault.this.vault_uri
}

output "name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.this.name
}
