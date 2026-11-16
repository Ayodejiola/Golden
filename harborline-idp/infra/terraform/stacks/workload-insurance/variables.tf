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
  description = "Cost centre of the Insurance Digital team."
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

variable "postgres" {
  description = "PostgreSQL sizing per environment."
  type        = object({
    sku_name             = string
    storage_mb           = number
    high_availability    = bool
    geo_redundant_backup = bool
  })
}

variable "service_bus_capacity" {
  description = "Service Bus Premium messaging units."
  type        = number
  default     = 1
}

variable "dba_group" {
  description = "Entra group administering the database."
  type        = object({
    object_id      = string
    principal_name = string
  })
}
