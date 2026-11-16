variable "environment" {
  description = "Environment name."
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment must be dev, stg or prod."
  }
}

variable "location" {
  description = "Primary region."
  type        = string
  default     = "canadacentral"
}

variable "cost_center" {
  description = "Cost centre."
  type        = string
}

variable "subscription_id" {
  description = "Landing zone subscription for this environment."
  type        = string
}

variable "connectivity_subscription_id" {
  description = "Connectivity (hub) subscription."
  type        = string
}

variable "management_subscription_id" {
  description = "Management subscription."
  type        = string
}

variable "spoke_address_space" {
  description = "Spoke /16 allocated by IPAM."
  type        = string
}

variable "use_remote_gateways" {
  description = "Use hub ExpressRoute/VPN gateway."
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  description = "AKS Kubernetes minor version."
  type        = string
}

variable "aks_sku_tier" {
  description = "AKS tier (Free only in dev)."
  type        = string
  default     = "Standard"
}

variable "system_pool" {
  description = "System pool sizing."
  type        = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
}

variable "user_pools" {
  description = "User node pools."
  type        = map(object({
    vm_size   = string
    min_count = number
    max_count = number
    labels    = optional(map(string), {})
    taints    = optional(list(string), [])
  }))
}

variable "groups" {
  description = "Entra group object IDs."
  type        = object({
    platform_admins      = string
    platform_admins_name = string
    all_engineers        = string
  })
}

variable "public_sites" {
  description = "Public sites served through the WAF (certificate imported in the platform Key Vault)."
  type        = map(object({
    host_name        = string
    certificate_name = string
    health_path      = optional(string, "/healthz")
  }))
}

variable "github_business_id" {
  description = "GitHub enterprise/org databaseId for hosted-runner private networking (null to skip)."
  type        = string
  default     = null
}

variable "backstage_db_password_rotation" {
  description = "RFC3339 timestamp of the last Backstage DB password rotation; change it to rotate (EXC-0001)."
  type        = string
  default     = "2026-11-01T00:00:00Z"
}
