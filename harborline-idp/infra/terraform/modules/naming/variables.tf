variable "org" {
  description = "Organisation short code used in globally unique names."
  type        = string
  default     = "hbl"
  validation {
    condition     = can(regex("^[a-z]{2,4}$", var.org))
    error_message = "org must be 2-4 lowercase letters."
  }
}

variable "workload" {
  description = "Workload or stack short name, e.g. plat, ins, hub, mgmt."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.workload))
    error_message = "workload must be 2-8 lowercase alphanumerics starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prod", "shared"], var.environment)
    error_message = "environment must be one of dev, stg, prod, shared."
  }
}

variable "location" {
  description = "Azure region (programmatic name)."
  type        = string
  validation {
    condition     = contains(["canadacentral", "canadaeast", "eastus2", "centralus"], var.location)
    error_message = "location must be an approved Harborline region (data residency standard)."
  }
}

variable "instance" {
  description = "Instance number for side-by-side deployments."
  type        = number
  default     = 1
  validation {
    condition     = var.instance >= 1 && var.instance <= 99
    error_message = "instance must be between 1 and 99."
  }
}

variable "owner" {
  description = "Owning team (Backstage group name)."
  type        = string
}

variable "cost_center" {
  description = "Finance cost centre code for chargeback."
  type        = string
  validation {
    condition     = can(regex("^CC-[0-9]{4}$", var.cost_center))
    error_message = "cost_center must look like CC-1234."
  }
}

variable "data_classification" {
  description = "Highest data classification stored or processed (see docs/governance/data-classification.md)."
  type        = string
  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be public, internal, confidential or restricted."
  }
}

variable "criticality" {
  description = "Business criticality tier driving SLOs and DR (tier-0 .. tier-3)."
  type        = string
  default     = "tier-2"
  validation {
    condition     = contains(["tier-0", "tier-1", "tier-2", "tier-3"], var.criticality)
    error_message = "criticality must be tier-0..tier-3."
  }
}

variable "extra_tags" {
  description = "Additional tags merged over the standard set."
  type        = map(string)
  default     = {}
}
