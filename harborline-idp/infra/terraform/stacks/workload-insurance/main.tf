/**
 * workload-insurance — data and messaging for the Harborline Policy Portal (reference app), owned by the
 * Insurance Digital team with platform review. Separate state from the platform stack (blast-radius isolation).
 */

module "naming" {
  source              = "../../modules/naming"
  workload            = "ins"
  environment         = var.environment
  location            = var.location
  owner               = "insurance-digital"
  cost_center         = var.cost_center
  data_classification = "restricted"
  criticality         = var.environment == "prod" ? "tier-1" : "tier-3"
}

resource "azurerm_resource_group" "this" {
  name     = module.naming.names.resource_group
  location = var.location
  tags     = module.naming.tags
}

locals {
  namespace = "insurance"
  is_prod   = var.environment == "prod"
}

# ---------- Data tier ----------
module "postgresql" {
  source                       = "../../modules/postgresql"
  name                         = module.naming.names.postgresql
  location                     = var.location
  resource_group_name          = azurerm_resource_group.this.name
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  sku_name                     = var.postgres.sku_name
  storage_mb                   = var.postgres.storage_mb
  high_availability            = var.postgres.high_availability
  geo_redundant_backup_enabled = var.postgres.geo_redundant_backup
  backup_retention_days        = local.is_prod ? 35 : 7
  entra_admin                  = var.dba_group
  databases                    = ["insurance"]
  private_endpoint_subnet_id   = data.azurerm_subnet.pe.id
  private_dns_zone_id          = data.azurerm_private_dns_zone.hub["privatelink.postgres.database.azure.com"].id
  log_analytics_workspace_id   = data.azurerm_log_analytics_workspace.central.id
  action_group_id              = data.azurerm_monitor_action_group.platform.id
  tags                         = module.naming.tags
}

# The migration job identity is an Entra admin on THIS server only; it creates the app roles with
# pgaadauth_create_principal and grants least privilege (apps/insurance/policy-api/migrations).
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "migrator" {
  server_name         = module.postgresql.name
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = module.identity["db-migrator"].principal_id
  principal_name      = module.identity["db-migrator"].name
  principal_type      = "ServicePrincipal"
}

# ---------- Messaging tier ----------
module "service_bus" {
  source              = "../../modules/service-bus"
  name                = module.naming.names.service_bus
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  capacity            = var.service_bus_capacity
  topics              = {
    claims = {
      subscriptions = {
        triage = { max_delivery_count = 5, sql_filter = "eventType = 'claim.submitted'" }
        audit  = {}
      }
    }
    policies = {
      subscriptions = {
        analytics = {}
      }
    }
  }
  private_endpoint_subnet_id = data.azurerm_subnet.pe.id
  private_dns_zone_id        = data.azurerm_private_dns_zone.hub["privatelink.servicebus.windows.net"].id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.central.id
  action_group_id            = data.azurerm_monitor_action_group.platform.id
  tags                       = module.naming.tags
}

# ---------- Workload identities (no secrets: ADR-0005) ----------
locals {
  identities = {
    policy-api = {
      sa    = "policy-api"
      ns    = local.namespace
      roles = {
        send-claims   = { scope = module.service_bus.topic_ids["claims"], role = "Azure Service Bus Data Sender" }
        send-policies = { scope = module.service_bus.topic_ids["policies"], role = "Azure Service Bus Data Sender" }
      }
    }
    claims-worker = {
      sa    = "claims-worker"
      ns    = local.namespace
      roles = {
        receive-triage = { scope = module.service_bus.subscription_ids["claims/triage"], role = "Azure Service Bus Data Receiver" }
        send-claims    = { scope = module.service_bus.topic_ids["claims"], role = "Azure Service Bus Data Sender" }
      }
    }
    db-migrator = {
      sa    = "db-migrator"
      ns    = local.namespace
      roles = {}
    }
    # AKS-managed KEDA reads queue depth to scale the worker; federated to kube-system/keda-operator.
    keda-scaler = {
      sa    = "keda-operator"
      ns    = "kube-system"
      roles = {
        manage-claims = { scope = module.service_bus.topic_ids["claims"], role = "Azure Service Bus Data Owner" }
      }
    }
  }
}

module "identity" {
  source              = "../../modules/workload-identity"
  for_each            = local.identities
  name                = "id-ins-${each.key}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  namespace           = each.value.ns
  service_account     = each.value.sa
  oidc_issuers        = { primary = data.azurerm_kubernetes_cluster.this.oidc_issuer_url }
  role_assignments    = each.value.roles
  tags                = module.naming.tags
}
