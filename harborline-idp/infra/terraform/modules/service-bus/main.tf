/**
 * service-bus — Premium namespace (zone-redundant by default), Entra auth only, private endpoint,
 * topics/subscriptions with duplicate detection and dead-lettering (ADR-0008).
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

resource "azurerm_servicebus_namespace" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Premium"
  capacity                      = var.capacity
  premium_messaging_partitions  = 1
  local_auth_enabled            = false
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_servicebus_topic" "this" {
  for_each                                = var.topics
  name                                    = each.key
  namespace_id                            = azurerm_servicebus_namespace.this.id
  requires_duplicate_detection            = true
  duplicate_detection_history_time_window = "PT10M"
  default_message_ttl                     = each.value.default_message_ttl
  max_size_in_megabytes                   = each.value.max_size_in_megabytes
  support_ordering                        = each.value.support_ordering
}

locals {
  subscriptions = merge([
    for topic, t in var.topics : {
      for sub, s in t.subscriptions : "${topic}/${sub}" => merge(s, { topic = topic, name = sub })
    }
  ]...)
}

resource "azurerm_servicebus_subscription" "this" {
  for_each                                  = local.subscriptions
  name                                      = each.value.name
  topic_id                                  = azurerm_servicebus_topic.this[each.value.topic].id
  max_delivery_count                        = each.value.max_delivery_count
  lock_duration                             = each.value.lock_duration
  dead_lettering_on_message_expiration      = true
  dead_lettering_on_filter_evaluation_error = true
  requires_session                          = each.value.requires_session
}

resource "azurerm_servicebus_subscription_rule" "this" {
  for_each        = { for k, v in local.subscriptions : k => v if v.sql_filter != null }
  name            = "filter"
  subscription_id = azurerm_servicebus_subscription.this[each.key].id
  filter_type     = "SqlFilter"
  sql_filter      = each.value.sql_filter
}

module "pe" {
  source               = "../private-endpoint"
  name                 = "pep-${var.name}-sb"
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.private_endpoint_subnet_id
  target_resource_id   = azurerm_servicebus_namespace.this.id
  subresource_names    = ["namespace"]
  private_dns_zone_ids = [var.private_dns_zone_id]
  tags                 = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "diag-to-law"
  target_resource_id             = azurerm_servicebus_namespace.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_metric_alert" "dead_letters" {
  name                = "alert-${var.name}-deadletters"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_servicebus_namespace.this.id]
  description         = "Messages are being dead-lettered. Runbook: servicebus-dead-letter."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ServiceBus/namespaces"
    metric_name      = "DeadletteredMessages"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = 0

    dimension {
      name     = "EntityName"
      operator = "Include"
      values   = ["*"]
    }
  }

  action {
    action_group_id = var.action_group_id
  }
}

resource "azurerm_monitor_metric_alert" "throttled" {
  name                = "alert-${var.name}-throttled"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_servicebus_namespace.this.id]
  description         = "Service Bus is throttling requests; consider scaling messaging units."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ServiceBus/namespaces"
    metric_name      = "ThrottledRequests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = var.action_group_id
  }
}

variable "name" {
  description = "Namespace name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group."
  type        = string
}

variable "capacity" {
  description = "Messaging units (1, 2, 4, 8, 16)."
  type        = number
  default     = 1
}

variable "topics" {
  description = "Topics and their subscriptions."
  type        = map(object({
    default_message_ttl   = optional(string, "P14D")
    max_size_in_megabytes = optional(number, 5120)
    support_ordering      = optional(bool, false)
    subscriptions         = map(object({
      max_delivery_count = optional(number, 10)
      lock_duration      = optional(string, "PT1M")
      requires_session   = optional(bool, false)
      sql_filter         = optional(string)
    }))
  }))
}

variable "private_endpoint_subnet_id" {
  description = "Private endpoint subnet."
  type        = string
}

variable "private_dns_zone_id" {
  description = "privatelink.servicebus.windows.net zone ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace for diagnostics."
  type        = string
}

variable "action_group_id" {
  description = "Action group for alerts."
  type        = string
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

output "id" {
  description = "Namespace ID."
  value       = azurerm_servicebus_namespace.this.id
}

output "fqdn" {
  description = "Fully qualified namespace for SDK clients."
  value       = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
}

output "topic_ids" {
  description = "Map of topic name => ID."
  value       = { for k, t in azurerm_servicebus_topic.this : k => t.id }
}

output "subscription_ids" {
  description = "Map of topic/subscription => ID."
  value       = { for k, s in azurerm_servicebus_subscription.this : k => s.id }
}
