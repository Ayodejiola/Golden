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
  description = "Resource group for hub resources."
  type        = string
}

variable "address_space" {
  description = "Hub VNet CIDR (expects a /22)."
  type        = string
  default     = "10.0.0.0/22"
}

variable "spoke_address_spaces" {
  description = "Spoke CIDRs allowed to egress through the firewall."
  type        = list(string)
}

variable "runner_address_spaces" {
  description = "CIDRs of GitHub runner subnets in spokes (CI egress rule collection)."
  type        = list(string)
  default     = []
}

variable "east_west_rules" {
  description = "Allowed spoke-to-spoke flows (default deny). Reference the ADR/EXC in the name."
  type        = list(object({
    name                  = string
    source_addresses      = list(string)
    destination_addresses = list(string)
    destination_ports     = list(string)
  }))
  default = []
}

variable "zones" {
  description = "Availability zones for firewall and public IPs."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion (Standard) for break-glass access to private resources."
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace for firewall logs and policy analytics."
  type        = string
}

variable "extra_allowed_fqdns" {
  description = "Additional egress FQDNs approved through the exceptions process (EXC-#### in commit)."
  type        = list(string)
  default     = []
}

variable "private_dns_zones" {
  description = "Private Link DNS zones hosted centrally in the hub."
  type        = list(string)
  default     = [
    "privatelink.canadacentral.azmk8s.io",
    "privatelink.canadaeast.azmk8s.io",
    "privatelink.vaultcore.azure.net",
    "privatelink.azurecr.io",
    "privatelink.postgres.database.azure.com",
    "privatelink.servicebus.windows.net",
    "privatelink.blob.core.windows.net",
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.grafana.azure.com",
    "privatelink.canadacentral.prometheus.monitor.azure.com",
  ]
}
