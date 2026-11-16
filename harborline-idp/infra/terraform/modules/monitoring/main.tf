/**
 * monitoring — central observability backends (ALZ management subscription):
 * Log Analytics, Azure Monitor workspace (managed Prometheus), Azure Managed Grafana and the platform action group.
 * Per-environment Application Insights and Prometheus DCRs live with each AKS cluster (modules/aks).
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.names.log_analytics
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags
}

# Long-term, low-cost retention for audit-relevant tables (regulatory: 7 years for kube-audit is NOT required;
# 2 years total retention meets the Harborline logging standard — see docs/governance/standards.md).
resource "azurerm_log_analytics_workspace_table" "audit" {
  for_each                = toset(["AKSAudit", "AKSAuditAdmin", "AzureActivity", "AZFWApplicationRule", "AZFWNetworkRule"])
  workspace_id            = azurerm_log_analytics_workspace.this.id
  name                    = each.value
  retention_in_days       = var.retention_days
  total_retention_in_days = 730
}

resource "azurerm_monitor_workspace" "prometheus" {
  name                = var.names.monitor_workspace
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_dashboard_grafana" "this" {
  name                              = var.names.grafana
  location                          = var.location
  resource_group_name               = var.resource_group_name
  sku                               = "Standard"
  grafana_major_version             = var.grafana_major_version
  api_key_enabled                   = false
  deterministic_outbound_ip_enabled = true
  public_network_access_enabled     = var.grafana_public_network_access
  zone_redundancy_enabled           = true
  tags                              = var.tags

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.prometheus.id
  }
}

resource "azurerm_role_assignment" "grafana_amw_reader" {
  scope                = azurerm_monitor_workspace.prometheus.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  for_each             = toset(var.monitored_scopes)
  scope                = each.value
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "grafana_admins" {
  scope                = azurerm_dashboard_grafana.this.id
  role_definition_name = "Grafana Admin"
  principal_id         = var.grafana_admin_group_object_id
}

resource "azurerm_role_assignment" "grafana_viewers" {
  scope                = azurerm_dashboard_grafana.this.id
  role_definition_name = "Grafana Viewer"
  principal_id         = var.grafana_viewer_group_object_id
}

resource "azurerm_monitor_action_group" "platform" {
  name                = var.names.action_group
  resource_group_name = var.resource_group_name
  short_name          = "hbl-plat"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_emails
    content {
      name                    = "email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.oncall_webhook_url == null ? [] : [var.oncall_webhook_url]
    content {
      name                    = "oncall"
      service_uri             = webhook_receiver.value
      use_common_alert_schema = true
    }
  }
}

# Activity log of this subscription to the central workspace (other subscriptions are covered by ALZ policy).
resource "azurerm_monitor_diagnostic_setting" "activity" {
  name                       = "activity-to-law"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = ["Administrative", "Security", "Policy", "Alert", "ServiceHealth", "ResourceHealth"]
    content {
      category = enabled_log.value
    }
  }
}
