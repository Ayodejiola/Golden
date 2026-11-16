output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace ID."
  value       = module.monitoring.log_analytics_workspace_id
}

output "monitor_workspace_id" {
  description = "Azure Monitor workspace ID."
  value       = module.monitoring.monitor_workspace_id
}

output "grafana_endpoint" {
  description = "Grafana URL."
  value       = module.monitoring.grafana_endpoint
}

output "acr_login_server" {
  description = "Shared registry login server."
  value       = module.acr.login_server
}

output "action_group_id" {
  description = "Platform action group."
  value       = module.monitoring.action_group_id
}
