/**
 * policy-assignments — Azure Policy guardrails for an application landing zone subscription.
 * Complements the ALZ management-group assignments (MCSB, Deny-Public-Endpoints, diagnostics) with
 * AKS-specific controls. Definitions are looked up by display name so the plan fails loudly if Microsoft renames one.
 * Effects are "Audit" in dev and "Deny" in stg/prod (see docs/security/cis-aks-benchmark.md).
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

locals {
  excluded_namespaces = ["kube-system", "gatekeeper-system", "azure-arc", "kube-public", "kyverno", "app-routing-system"]

  policies = {
    aks-private-cluster = {
      display_name = "Azure Kubernetes Service Private Clusters should be enabled"
      parameters   = { effect = var.deny_effect }
    }
    aks-local-auth-disabled = {
      display_name = "Azure Kubernetes Service Clusters should have local authentication methods disabled"
      parameters   = { effect = var.deny_effect }
    }
    aks-defender-profile = {
      display_name = "Azure Kubernetes Service clusters should have Defender profile enabled"
      parameters   = { effect = "Audit" }
    }
    aks-azure-policy-addon = {
      display_name = "Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters"
      parameters   = { effect = "Audit" }
    }
    k8s-https-only = {
      display_name = "Kubernetes clusters should be accessible only over HTTPS"
      parameters   = { effect = var.k8s_effect, excludedNamespaces = local.excluded_namespaces }
    }
    k8s-allowed-images = {
      display_name = "Kubernetes cluster containers should only use allowed images"
      parameters   = {
        effect                      = var.k8s_effect
        excludedNamespaces          = local.excluded_namespaces
        allowedContainerImagesRegex = var.allowed_images_regex
      }
    }
    k8s-no-external-lb = {
      display_name = "Kubernetes clusters should use internal load balancers"
      parameters   = { effect = var.k8s_effect, excludedNamespaces = local.excluded_namespaces }
    }
  }

  initiatives = {
    pod-security-restricted = {
      display_name = "Kubernetes cluster pod security restricted standards for Linux-based workloads"
      parameters   = { effect = var.k8s_effect, excludedNamespaces = local.excluded_namespaces }
    }
  }
}

data "azurerm_policy_definition" "this" {
  for_each     = local.policies
  display_name = each.value.display_name
}

data "azurerm_policy_set_definition" "this" {
  for_each     = local.initiatives
  display_name = each.value.display_name
}

data "azurerm_policy_definition" "require_tag" {
  display_name = "Require a tag on resource groups"
}

resource "azurerm_subscription_policy_assignment" "policies" {
  for_each             = local.policies
  name                 = substr("hbl-${each.key}", 0, 64)
  display_name         = "[Harborline] ${each.value.display_name}"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_definition.this[each.key].id
  enforce              = true
  parameters           = jsonencode({ for k, v in each.value.parameters : k => { value = v } })
  non_compliance_message {
    content = "Blocked by Harborline platform guardrail ${each.key}. See https://backstage.harborline.example/docs/default/component/harborline-idp/security/cis-aks-benchmark/"
  }
}

resource "azurerm_subscription_policy_assignment" "initiatives" {
  for_each             = local.initiatives
  name                 = substr("hbl-${each.key}", 0, 64)
  display_name         = "[Harborline] ${each.value.display_name}"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_set_definition.this[each.key].id
  enforce              = true
  parameters           = jsonencode({ for k, v in each.value.parameters : k => { value = v } })
}

resource "azurerm_subscription_policy_assignment" "require_tags" {
  for_each             = toset(var.mandatory_tags)
  name                 = substr("hbl-require-rg-tag-${each.value}", 0, 64)
  display_name         = "[Harborline] Require tag '${each.value}' on resource groups"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_definition.require_tag.id
  enforce              = true
  parameters           = jsonencode({ tagName = { value = each.value } })
}

variable "subscription_id" {
  description = "Target subscription resource ID (/subscriptions/<guid>)."
  type        = string
}

variable "deny_effect" {
  description = "Effect for Azure resource policies: Audit (dev) or Deny (stg/prod)."
  type        = string
  default     = "Deny"
  validation {
    condition     = contains(["Audit", "Deny"], var.deny_effect)
    error_message = "deny_effect must be Audit or Deny."
  }
}

variable "k8s_effect" {
  description = "Effect for in-cluster (Gatekeeper) policies: audit (dev) or deny (stg/prod)."
  type        = string
  default     = "deny"
  validation {
    condition     = contains(["audit", "deny"], var.k8s_effect)
    error_message = "k8s_effect must be audit or deny."
  }
}

variable "allowed_images_regex" {
  description = "Regex of allowed images (Harborline ACR and Microsoft-managed add-on images)."
  type        = string
}

variable "mandatory_tags" {
  description = "Tags required on every resource group."
  type        = list(string)
  default     = ["environment", "owner", "cost-center", "data-classification"]
}
