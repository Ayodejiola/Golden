variable "names" {
  description = "Name map from the naming module."
  type        = map(string)
}

variable "tags" {
  description = "Tags from the naming module."
  type        = map(string)
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the spoke network."
  type        = string
}

variable "address_space" {
  description = "Spoke VNet CIDR (expects a /16)."
  type        = string
  validation {
    condition     = can(cidrhost(var.address_space, 0)) && endswith(var.address_space, "/16")
    error_message = "address_space must be a valid /16 CIDR (subnet plan assumes /16)."
  }
}

variable "hub_vnet_id" {
  description = "Hub VNet resource ID."
  type        = string
}

variable "hub_vnet_name" {
  description = "Hub VNet name."
  type        = string
}

variable "hub_resource_group_name" {
  description = "Hub VNet resource group."
  type        = string
}

variable "hub_firewall_private_ip" {
  description = "Hub firewall private IP (UDR next hop and DNS proxy)."
  type        = string
}

variable "use_remote_gateways" {
  description = "Use the hub ExpressRoute/VPN gateway for on-premises connectivity."
  type        = bool
  default     = false
}

variable "flow_logs" {
  description = "VNet flow logs + Traffic Analytics configuration."
  type        = object({
    enabled               = bool
    network_watcher_name  = optional(string)
    network_watcher_rg    = optional(string)
    storage_account_id    = optional(string)
    workspace_guid        = optional(string)
    workspace_resource_id = optional(string)
  })
  default = { enabled = false }
}
