/**
 * github-runner-network — Azure private networking for GitHub-hosted runners (ADR-0013).
 * Creates the GitHub.Network/networkSettings resource bound to a delegated spoke subnet. Paste the
 * `github_network_settings_id` output into GitHub → Enterprise/Org settings → Hosted compute networking,
 * then attach the network configuration to the runner group for this environment.
 * Prerequisite: `az provider register --namespace GitHub.Network` on the subscription.
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azapi = { source = "Azure/azapi", version = ">= 2.0, < 3.0" }
  }
}

resource "azapi_resource" "network_settings" {
  type      = "GitHub.Network/networkSettings@2024-04-02"
  name      = var.name
  location  = var.location
  parent_id = var.resource_group_id
  tags      = var.tags

  body = {
    properties = {
      businessId = var.github_business_id
      subnetId   = var.subnet_id
    }
  }

  response_export_values = ["tags.GitHubId"]
}

variable "name" {
  description = "Network settings resource name."
  type        = string
}

variable "location" {
  description = "Azure region (must match the subnet's VNet region)."
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID."
  type        = string
}

variable "subnet_id" {
  description = "Subnet delegated to GitHub.Network/networkSettings."
  type        = string
}

variable "github_business_id" {
  description = "GitHub enterprise or organisation database ID (GraphQL databaseId)."
  type        = string
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

output "github_network_settings_id" {
  description = "Value to register in GitHub hosted compute networking."
  value       = azapi_resource.network_settings.output.tags.GitHubId
}
