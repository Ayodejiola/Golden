/**
 * workload-identity — one user-assigned managed identity per Kubernetes service account,
 * federated with each cluster's OIDC issuer, with least-privilege role assignments (ADR-0005).
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "this" {
  for_each            = var.oidc_issuers
  name                = "fic-${each.key}-${var.namespace}-${var.service_account}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account}"
}

resource "azurerm_role_assignment" "this" {
  for_each             = var.role_assignments
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

variable "name" {
  description = "Identity name (id-<workload>-<service>-<env>)."
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

variable "namespace" {
  description = "Kubernetes namespace of the service account."
  type        = string
}

variable "service_account" {
  description = "Kubernetes service account name."
  type        = string
}

variable "oidc_issuers" {
  description = "Map of cluster key => OIDC issuer URL (primary and DR clusters)."
  type        = map(string)
}

variable "role_assignments" {
  description = "Map of key => { scope, role }. Scope as narrowly as possible (topic, subscription, vault)."
  type        = map(object({
    scope = string
    role  = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

output "client_id" {
  description = "Client ID to annotate the service account with (azure.workload.identity/client-id)."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "principal_id" {
  description = "Object ID."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "name" {
  description = "Identity name (also the PostgreSQL role name)."
  value       = azurerm_user_assigned_identity.this.name
}
