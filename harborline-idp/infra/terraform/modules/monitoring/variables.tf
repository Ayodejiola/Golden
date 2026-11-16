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
  description = "Resource group for monitoring resources."
  type        = string
}

variable "subscription_id" {
  description = "Subscription ID hosting these resources (activity log export)."
  type        = string
}

variable "retention_days" {
  description = "Interactive retention for Log Analytics (days)."
  type        = number
  default     = 90
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB (-1 = unlimited). Protects against runaway cost."
  type        = number
  default     = -1
}

variable "grafana_major_version" {
  description = "Azure Managed Grafana major version."
  type        = number
  default     = 11
}

variable "grafana_public_network_access" {
  description = "Allow Grafana over the internet (Entra ID + Conditional Access enforced). See ADR-0009."
  type        = bool
  default     = true
}

variable "monitored_scopes" {
  description = "Subscription/resource-group scopes Grafana may read metrics from."
  type        = list(string)
  default     = []
}

variable "grafana_admin_group_object_id" {
  description = "Entra group granted Grafana Admin."
  type        = string
}

variable "grafana_viewer_group_object_id" {
  description = "Entra group granted Grafana Viewer (all engineers)."
  type        = string
}

variable "alert_emails" {
  description = "Map of receiver name => email for the platform action group."
  type        = map(string)
  default     = {}
}

variable "oncall_webhook_url" {
  description = "On-call paging webhook (e.g. PagerDuty/Opsgenie). Stored as sensitive tfvar in the pipeline."
  type        = string
  default     = null
  sensitive   = true
}
