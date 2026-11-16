/**
 * spoke-network — application landing zone VNet peered to the hub.
 * All egress is forced through the hub firewall (UDR) and DNS resolves through the firewall DNS proxy.
 *
 * Subnet plan for a /16 (index → CIDR for 10.10.0.0/16):
 *   aks-system  10.10.0.0/24   aks-user  10.10.4.0/22   agw  10.10.8.0/24
 *   pe          10.10.9.0/24   ilb       10.10.10.0/24  runners 10.10.11.0/24
 * Pods use the Cilium overlay CIDR and consume no VNet addresses (ADR-0006).
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">= 4.40, < 5.0"
      configuration_aliases = [azurerm.hub]
    }
  }
}

locals {
  subnets = {
    aks-system = { cidr = cidrsubnet(var.address_space, 8, 0), udr = true, delegation = null }
    aks-user   = { cidr = cidrsubnet(var.address_space, 6, 1), udr = true, delegation = null }
    agw        = { cidr = cidrsubnet(var.address_space, 8, 8), udr = false, delegation = null }
    pe         = { cidr = cidrsubnet(var.address_space, 8, 9), udr = false, delegation = null }
    ilb        = { cidr = cidrsubnet(var.address_space, 8, 10), udr = true, delegation = null }
    runners    = { cidr = cidrsubnet(var.address_space, 8, 11), udr = true, delegation = "GitHub.Network/networkSettings" }
  }
}

resource "azurerm_virtual_network" "spoke" {
  name                = var.names.virtual_network
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  dns_servers         = [var.hub_firewall_private_ip]
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each                          = local.subnets
  name                              = "snet-${each.key}"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = [each.value.cidr]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = each.key == "pe" ? "Enabled" : "Disabled"

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]
    content {
      name = "delegation"
      service_delegation {
        name    = delegation.value
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

# ---------- NSGs: deny-by-default, explicit allows only ----------
resource "azurerm_network_security_group" "this" {
  for_each            = local.subnets
  name                = "${var.names.network_security_grp}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "agw_inbound" {
  for_each = {
    gateway-manager = { priority = 100, source = "GatewayManager", ports = ["65200-65535"] }
    azure-lb        = { priority = 110, source = "AzureLoadBalancer", ports = ["*"] }
    https-internet  = { priority = 120, source = "Internet", ports = ["443"] }
  }
  name                        = "allow-${each.key}"
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = each.value.source
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = each.value.ports
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this["agw"].name
}

resource "azurerm_network_security_rule" "ilb_from_agw" {
  name                        = "allow-https-from-agw"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = local.subnets["agw"].cidr
  source_port_range           = "*"
  destination_address_prefix  = local.subnets["ilb"].cidr
  destination_port_ranges     = ["443", "80"]
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this["ilb"].name
}

resource "azurerm_network_security_rule" "deny_internet_inbound" {
  for_each                    = { for k, v in local.subnets : k => v if k != "agw" }
  name                        = "deny-internet-inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = "Internet"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[each.key].name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = local.subnets
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_network_watcher_flow_log" "this" {
  count                = var.flow_logs.enabled ? 1 : 0
  name                 = "fl-${azurerm_virtual_network.spoke.name}"
  network_watcher_name = var.flow_logs.network_watcher_name
  resource_group_name  = var.flow_logs.network_watcher_rg
  target_resource_id   = azurerm_virtual_network.spoke.id
  storage_account_id   = var.flow_logs.storage_account_id
  enabled              = true
  version              = 2
  tags                 = var.tags

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = var.flow_logs.workspace_guid
    workspace_region      = var.location
    workspace_resource_id = var.flow_logs.workspace_resource_id
    interval_in_minutes   = 10
  }
}

# ---------- Forced tunnelling to the hub firewall ----------
resource "azurerm_route_table" "egress" {
  name                          = var.names.route_table
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.hub_firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each       = { for k, v in local.subnets : k => v if v.udr }
  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.egress.id
}

# ---------- Peering (spoke side in this subscription, hub side via aliased provider) ----------
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  use_remote_gateways          = var.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                     = azurerm.hub
  name                         = "peer-to-${azurerm_virtual_network.spoke.name}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  allow_gateway_transit        = var.use_remote_gateways
}
