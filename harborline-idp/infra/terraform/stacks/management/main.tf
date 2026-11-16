/**
 * management — shared observability backends and the shared container registry (ALZ management subscription).
 * Apply order: bootstrap → management → connectivity → platform (dev, stg, prod) → workload stacks.
 */

module "naming" {
  source              = "../../modules/naming"
  workload            = "mgmt"
  environment         = "shared"
  location            = var.location
  owner               = "platform-engineering"
  cost_center         = var.cost_center
  data_classification = "confidential"
  criticality         = "tier-0"
}

resource "azurerm_resource_group" "this" {
  name     = module.naming.names.resource_group
  location = var.location
  tags     = module.naming.tags
}

module "monitoring" {
  source                         = "../../modules/monitoring"
  names                          = module.naming.names
  tags                           = module.naming.tags
  location                       = var.location
  resource_group_name            = azurerm_resource_group.this.name
  subscription_id                = var.management_subscription_id
  retention_days                 = 90
  monitored_scopes               = [for s in var.monitored_subscription_ids : "/subscriptions/${s}"]
  grafana_admin_group_object_id  = var.groups.platform_admins
  grafana_viewer_group_object_id = var.groups.all_engineers
  alert_emails                   = var.alert_emails
  oncall_webhook_url             = var.oncall_webhook_url
}

module "acr" {
  source                     = "../../modules/container-registry"
  name                       = module.naming.names.container_registry
  location                   = var.location
  resource_group_name        = azurerm_resource_group.this.name
  geo_replication_locations  = ["canadaeast"]
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = module.naming.tags
  # Private endpoint is created in the hub by the connectivity stack (central PE subnet + DNS).
  push_principal_ids = {
    ci = data.azurerm_user_assigned_identity.acr_push.principal_id
  }
}

data "azurerm_user_assigned_identity" "acr_push" {
  name                = "id-gh-acr-push"
  resource_group_name = "rg-cicd-shared-cac-01"
}

resource "azurerm_management_lock" "acr" {
  name       = "cannot-delete"
  scope      = module.acr.id
  lock_level = "CanNotDelete"
  notes      = "Shared registry for all environments."
}
