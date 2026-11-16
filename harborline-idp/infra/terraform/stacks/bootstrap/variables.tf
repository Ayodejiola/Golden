variable "location" {
  description = "Primary region."
  type        = string
  default     = "canadacentral"
}

variable "cost_center" {
  description = "Cost centre for platform shared costs."
  type        = string
}

variable "management_subscription_id" {
  description = "ALZ management subscription (state, CI identities, monitoring, ACR)."
  type        = string
}

variable "connectivity_subscription_id" {
  description = "ALZ connectivity subscription (hub)."
  type        = string
}

variable "landing_zone_subscription_ids" {
  description = "Map of environment => application landing zone subscription ID."
  type        = map(string)
}

variable "environments" {
  description = "Environments with their own state container."
  type        = list(string)
  default     = ["dev", "stg", "prod"]
}

variable "state_storage_account_id" {
  description = "Resource ID of the Terraform state storage account created by scripts/bootstrap-state.sh."
  type        = string
}

variable "github_org" {
  description = "GitHub organisation."
  type        = string
}

variable "github_repo" {
  description = "Platform repository name."
  type        = string
  default     = "harborline-idp"
}

variable "service_repositories" {
  description = "Service repositories (created from Backstage templates) allowed to push images."
  type        = list(string)
  default     = []
}

variable "assignable_roles" {
  description = "Roles the apply identities may assign (ABAC-constrained delegation)."
  type        = list(string)
  default     = [
    "AcrPull",
    "AcrPush",
    "Key Vault Administrator",
    "Key Vault Secrets Officer",
    "Key Vault Secrets User",
    "Key Vault Certificate User",
    "Key Vault Crypto User",
    "Network Contributor",
    "Private DNS Zone Contributor",
    "Managed Identity Operator",
    "Azure Service Bus Data Sender",
    "Azure Service Bus Data Receiver",
    "Azure Service Bus Data Owner",
    "Monitoring Reader",
    "Monitoring Data Reader",
    "Monitoring Metrics Publisher",
    "Azure Kubernetes Service RBAC Cluster Admin",
    "Azure Kubernetes Service RBAC Reader",
    "Azure Kubernetes Service RBAC Writer",
    "Azure Kubernetes Service Cluster User Role",
    "Grafana Admin",
    "Grafana Viewer",
  ]
}
