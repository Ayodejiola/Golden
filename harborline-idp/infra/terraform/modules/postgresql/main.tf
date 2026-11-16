/**
 * postgresql — Azure Database for PostgreSQL Flexible Server, private endpoint mode (ADR-0007).
 *  - Entra ID authentication only (password auth disabled): apps connect with workload identity tokens.
 *  - Zone-redundant HA in stg/prod, geo-redundant backups (35 days) for regional DR.
 *  - TLS 1.2+, pgaudit, connection throttling, diagnostic logs, baseline metric alerts.
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  version                       = var.postgres_version
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  storage_tier                  = var.storage_tier
  auto_grow_enabled             = true
  backup_retention_days         = var.backup_retention_days
  geo_redundant_backup_enabled  = var.geo_redundant_backup_enabled
  zone                          = "1"
  public_network_access_enabled = false
  administrator_login           = try(var.password_auth.administrator_login, null)
  administrator_password        = try(var.password_auth.administrator_password, null)
  tags                          = var.tags

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = var.password_auth != null # only with an approved exception (EXC-####)
    tenant_id                     = var.tenant_id
  }

  dynamic "high_availability" {
    for_each = var.high_availability ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }
  }

  maintenance_window {
    day_of_week  = 0 # Sunday
    start_hour   = 3
    start_minute = 0
  }

  lifecycle {
    # Zones swap after a failover; do not fight Azure about it.
    ignore_changes = [zone, high_availability[0].standby_availability_zone]
  }
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "this" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  object_id           = var.entra_admin.object_id
  principal_name      = var.entra_admin.principal_name
  principal_type      = "Group"
}

locals {
  server_parameters = merge({
    "require_secure_transport"            = "on"
    "ssl_min_protocol_version"            = "TLSv1.2"
    "log_connections"                     = "on"
    "log_disconnections"                  = "on"
    "log_checkpoints"                     = "on"
    "log_min_duration_statement"          = "500"
    "connection_throttle.enable"          = "on"
    "azure.extensions"                    = "PGCRYPTO,UUID-OSSP,PG_STAT_STATEMENTS"
    "shared_preload_libraries"            = "pg_cron,pg_stat_statements,pgaudit"
    "pgaudit.log"                         = "ddl,role"
    "idle_in_transaction_session_timeout" = "60000"
  }, var.extra_parameters)
}

resource "azurerm_postgresql_flexible_server_configuration" "this" {
  for_each  = local.server_parameters
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = each.value
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  for_each  = toset(var.databases)
  name      = each.value
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  lifecycle {
    prevent_destroy = true
  }
}

module "pe" {
  source               = "../private-endpoint"
  name                 = "pep-${var.name}-pg"
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.private_endpoint_subnet_id
  target_resource_id   = azurerm_postgresql_flexible_server.this.id
  subresource_names    = ["postgresqlServer"]
  private_dns_zone_ids = [var.private_dns_zone_id]
  tags                 = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "diag-to-law"
  target_resource_id             = azurerm_postgresql_flexible_server.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

locals {
  metric_alerts = {
    cpu                = { metric = "cpu_percent", op = "GreaterThan", threshold = 80, sev = 2, agg = "Average" }
    memory             = { metric = "memory_percent", op = "GreaterThan", threshold = 85, sev = 2, agg = "Average" }
    storage            = { metric = "storage_percent", op = "GreaterThan", threshold = 80, sev = 1, agg = "Maximum" }
    connections_failed = { metric = "connections_failed", op = "GreaterThan", threshold = 10, sev = 2, agg = "Total" }
  }
}

resource "azurerm_monitor_metric_alert" "this" {
  for_each            = local.metric_alerts
  name                = "alert-${var.name}-${each.key}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_postgresql_flexible_server.this.id]
  description         = "PostgreSQL ${each.key} threshold breached. Runbook: postgres-connection-saturation / postgres-failover."
  severity            = each.value.sev
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = each.value.metric
    aggregation      = each.value.agg
    operator         = each.value.op
    threshold        = each.value.threshold
  }

  action {
    action_group_id = var.action_group_id
  }
}

variable "name" {
  description = "Server name."
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

variable "tenant_id" {
  description = "Entra tenant ID."
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "sku_name" {
  description = "Compute SKU, e.g. B_Standard_B2ms (dev), GP_Standard_D4ds_v5 (prod)."
  type        = string
}

variable "storage_mb" {
  description = "Initial storage size in MB (auto-grow is on)."
  type        = number
  default     = 65536
}

variable "storage_tier" {
  description = "Premium SSD performance tier."
  type        = string
  default     = "P10"
}

variable "backup_retention_days" {
  description = "PITR retention in days (7-35)."
  type        = number
  default     = 35
}

variable "geo_redundant_backup_enabled" {
  description = "Geo-redundant backups for regional DR (immutable after creation)."
  type        = bool
  default     = true
}

variable "high_availability" {
  description = "Zone-redundant HA (not available on Burstable SKUs)."
  type        = bool
  default     = true
}

variable "entra_admin" {
  description = "Entra group that administers the server (DBA group, PIM-eligible)."
  type        = object({
    object_id      = string
    principal_name = string
  })
}

variable "databases" {
  description = "Databases to create."
  type        = list(string)
}

variable "password_auth" {
  description = "Password authentication — prohibited by default (ADR-0007). Only set with an approved exception tag on the server."
  type        = object({
    administrator_login    = string
    administrator_password = string
  })
  default   = null
  sensitive = true
}

variable "extra_parameters" {
  description = "Additional server parameters."
  type        = map(string)
  default     = {}
}

variable "private_endpoint_subnet_id" {
  description = "Private endpoint subnet."
  type        = string
}

variable "private_dns_zone_id" {
  description = "privatelink.postgres.database.azure.com zone ID."
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
  description = "Server ID."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "name" {
  description = "Server name."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "fqdn" {
  description = "Server FQDN (resolves privately via the hub zone)."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}
