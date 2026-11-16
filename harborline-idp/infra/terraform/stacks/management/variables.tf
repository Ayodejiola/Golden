variable "location" {
  description = "Primary region."
  type        = string
  default     = "canadacentral"
}

variable "cost_center" {
  description = "Cost centre."
  type        = string
}

variable "management_subscription_id" {
  description = "Management subscription ID."
  type        = string
}

variable "monitored_subscription_ids" {
  description = "Subscriptions Grafana may read Azure Monitor metrics from."
  type        = list(string)
}

variable "groups" {
  description = "Entra group object IDs."
  type        = object({
    platform_admins = string
    all_engineers   = string
  })
}

variable "alert_emails" {
  description = "Platform alert email receivers."
  type        = map(string)
  default     = {}
}

variable "oncall_webhook_url" {
  description = "On-call webhook (inject via TF_VAR_oncall_webhook_url from a GitHub environment secret)."
  type        = string
  default     = null
  sensitive   = true
}
