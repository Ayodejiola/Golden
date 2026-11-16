data "azurerm_client_config" "current" {}

data "azurerm_subnet" "pe" {
  name                 = "snet-pe"
  virtual_network_name = "vnet-plat-${var.environment}-cac-01"
  resource_group_name  = "rg-plat-${var.environment}-cac-01"
}

data "azurerm_kubernetes_cluster" "this" {
  name                = "aks-plat-${var.environment}-cac-01"
  resource_group_name = "rg-plat-${var.environment}-cac-01"
}

data "azurerm_private_dns_zone" "hub" {
  provider            = azurerm.hub
  for_each            = toset(["privatelink.postgres.database.azure.com", "privatelink.servicebus.windows.net"])
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

data "azurerm_monitor_action_group" "platform" {
  provider            = azurerm.management
  name                = "ag-mgmt-shared-cac-01"
  resource_group_name = "rg-mgmt-shared-cac-01"
}
