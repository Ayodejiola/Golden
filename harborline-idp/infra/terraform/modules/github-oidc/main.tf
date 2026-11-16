/**
 * github-oidc — managed identities federated with GitHub Actions OIDC. No client secrets exist anywhere.
 * Separate identities per purpose keep blast radius small:
 *   plan   : Reader + state blob read, trusted for pull_request events
 *   apply  : Contributor (+ RBAC Admin with ABAC condition) on the env subscription, trusted only for the GitHub environment
 *   push   : AcrPush on the shared registry, trusted for main-branch builds of service repos
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

locals {
  issuer = "https://token.actions.githubusercontent.com"
}

resource "azurerm_user_assigned_identity" "this" {
  for_each            = var.identities
  name                = "id-gh-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

locals {
  credentials = merge([
    for id_key, id in var.identities : {
      for idx, subject in id.subjects : "${id_key}-${idx}" => { identity = id_key, subject = subject }
    }
  ]...)

  roles = merge([
    for id_key, id in var.identities : {
      for r_key, r in id.roles : "${id_key}-${r_key}" => merge(r, { identity = id_key })
    }
  ]...)
}

resource "azurerm_federated_identity_credential" "this" {
  for_each            = local.credentials
  name                = "gh-${each.key}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this[each.value.identity].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = local.issuer
  subject             = each.value.subject
}

resource "azurerm_role_assignment" "this" {
  for_each             = local.roles
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this[each.value.identity].principal_id
  condition            = each.value.condition
  condition_version    = each.value.condition == null ? null : "2.0"
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for CI identities."
  type        = string
}

variable "identities" {
  description = <<-EOT
    Map of identity key => { subjects, roles }. Subjects use GitHub OIDC claims, e.g.
    repo:harborline/harborline-idp:environment:prod or repo:harborline/harborline-idp:pull_request.
  EOT
  type = map(object({
    subjects = list(string)
    roles    = map(object({
      scope     = string
      role      = string
      condition = optional(string)
    }))
  }))
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

output "client_ids" {
  description = "Map of identity key => client ID (store as GitHub environment variable AZURE_CLIENT_ID)."
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.client_id }
}

output "principal_ids" {
  description = "Map of identity key => principal ID."
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.principal_id }
}
