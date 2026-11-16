variable "location" {
  description = "Primary region."
  type        = string
  default     = "canadacentral"
}

variable "cost_center" {
  description = "Cost centre."
  type        = string
}

variable "connectivity_subscription_id" {
  description = "Connectivity subscription ID."
  type        = string
}

variable "management_subscription_id" {
  description = "Management subscription ID."
  type        = string
}

variable "hub_address_space" {
  description = "Hub VNet CIDR (/22)."
  type        = string
  default     = "10.0.0.0/22"
}

variable "spoke_address_spaces" {
  description = "Map of environment => spoke /16 (IPAM-allocated)."
  type        = map(string)
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion for break-glass."
  type        = bool
  default     = true
}

variable "extra_allowed_fqdns" {
  description = "Approved egress exceptions (each must reference an EXC-#### record in the PR)."
  type        = list(string)
  default     = []
}

variable "east_west_rules" {
  description = "Spoke-to-spoke exceptions (each references an ADR/EXC)."
  type        = list(object({
    name                  = string
    source_addresses      = list(string)
    destination_addresses = list(string)
    destination_ports     = list(string)
  }))
  default = []
}
