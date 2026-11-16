# Shared resources are looked up by their convention names instead of remote state:
# loose coupling, no cross-stack state read permissions needed.

data "azurerm_client_config" "current" {}

data "azurerm_virtual_network" "hub" {
  provider            = azurerm.hub
  name                = "vnet-hub-shared-cac-01"
  resource_group_name = "rg-hub-shared-cac-01"
}

data "azurerm_firewall" "hub" {
  provider            = azurerm.hub
  name                = "afw-hub-shared-cac-01"
  resource_group_name = "rg-hub-shared-cac-01"
}

data "azurerm_private_dns_zone" "hub" {
  provider            = azurerm.hub
  for_each            = toset(["privatelink.${var.location}.azmk8s.io", "privatelink.vaultcore.azure.net"])
  name                = each.value
  resource_group_name = "rg-hub-shared-cac-01"
}

data "azurerm_log_analytics_workspace" "central" {
  provider            = azurerm.management
  name                = "log-mgmt-shared-cac-01"
  resource_group_name = "rg-mgmt-shared-cac-01"
}

data "azurerm_monitor_workspace" "central" {
  provider            = azurerm.management
  name                = "amw-mgmt-shared-cac-01"
  resource_group_name = "rg-mgmt-shared-cac-01"
}

data "azurerm_container_registry" "shared" {
  provider            = azurerm.management
  name                = "acrhblmgmtsharedcac01"
  resource_group_name = "rg-mgmt-shared-cac-01"
}

data "azurerm_monitor_action_group" "platform" {
  provider            = azurerm.management
  name                = "ag-mgmt-shared-cac-01"
  resource_group_name = "rg-mgmt-shared-cac-01"
}
