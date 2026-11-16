/**
 * connectivity — ALZ hub: firewall, central private DNS, shared private endpoints.
 * Owned by Network Engineering (see CODEOWNERS). Spokes peer themselves via the platform stack.
 */

module "naming" {
  source              = "../../modules/naming"
  workload            = "hub"
  environment         = "shared"
  location            = var.location
  owner               = "network-engineering"
  cost_center         = var.cost_center
  data_classification = "internal"
  criticality         = "tier-0"
}

resource "azurerm_resource_group" "this" {
  name     = module.naming.names.resource_group
  location = var.location
  tags     = module.naming.tags
}

data "azurerm_log_analytics_workspace" "central" {
  provider            = azurerm.management
  name                = "log-mgmt-shared-cac-01"
  resource_group_name = "rg-mgmt-shared-cac-01"
}

data "azurerm_container_registry" "shared" {
  provider            = azurerm.management
  name                = "acrhblmgmtsharedcac01"
  resource_group_name = "rg-mgmt-shared-cac-01"
}

module "hub" {
  source                     = "../../modules/hub-network"
  names                      = module.naming.names
  tags                       = module.naming.tags
  location                   = var.location
  resource_group_name        = azurerm_resource_group.this.name
  address_space              = var.hub_address_space
  spoke_address_spaces       = values(var.spoke_address_spaces)
  runner_address_spaces      = [for cidr in values(var.spoke_address_spaces) : cidrsubnet(cidr, 8, 11)]
  enable_bastion             = var.enable_bastion
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.central.id
  extra_allowed_fqdns        = var.extra_allowed_fqdns
  east_west_rules            = var.east_west_rules
}

module "acr_pe" {
  source               = "../../modules/private-endpoint"
  name                 = "pep-${data.azurerm_container_registry.shared.name}-registry"
  location             = var.location
  resource_group_name  = azurerm_resource_group.this.name
  subnet_id            = module.hub.shared_pe_subnet_id
  target_resource_id   = data.azurerm_container_registry.shared.id
  subresource_names    = ["registry"]
  private_dns_zone_ids = [module.hub.private_dns_zone_ids["privatelink.azurecr.io"]]
  tags                 = module.naming.tags
}

resource "azurerm_management_lock" "hub" {
  name       = "cannot-delete"
  scope      = azurerm_resource_group.this.id
  lock_level = "CanNotDelete"
  notes      = "Hub networking: deletion isolates every spoke."
}
