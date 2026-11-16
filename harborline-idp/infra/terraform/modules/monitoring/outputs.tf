output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_guid" {
  description = "Log Analytics workspace (customer) ID."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "monitor_workspace_id" {
  description = "Azure Monitor workspace (managed Prometheus) resource ID."
  value       = azurerm_monitor_workspace.prometheus.id
}

output "grafana_endpoint" {
  description = "Managed Grafana URL."
  value       = azurerm_dashboard_grafana.this.endpoint
}

output "action_group_id" {
  description = "Platform action group ID used by all alert rules."
  value       = azurerm_monitor_action_group.platform.id
}
