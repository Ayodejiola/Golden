/**
 * hub-network — ALZ connectivity hub: VNet, Azure Firewall Premium (+policy, DNS proxy, IDPS),
 * optional Bastion, and the central private DNS zones every spoke resolves through the firewall DNS proxy.
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

resource "azurerm_virtual_network" "hub" {
  name                = var.names.virtual_network
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space, 4, 0)] # /26 of a /22
}

resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space, 4, 1)]
}

# Private endpoints for shared services (ACR, Grafana) consumed by every spoke.
resource "azurerm_subnet" "shared_pe" {
  name                              = "snet-shared-pe"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.hub.name
  address_prefixes                  = [cidrsubnet(var.address_space, 4, 2)]
  private_endpoint_network_policies = "Enabled"
  default_outbound_access_enabled   = false
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space, 3, 2)] # 10.0.1.0/25 reserved for ExpressRoute/VPN
}

resource "azurerm_public_ip" "firewall" {
  name                = "${var.names.public_ip}-afw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  name                     = var.names.firewall_policy
  location                 = var.location
  resource_group_name      = var.resource_group_name
  sku                      = "Premium"
  threat_intelligence_mode = "Deny"
  tags                     = var.tags

  dns {
    proxy_enabled = true
  }

  intrusion_detection {
    mode = "Deny"
  }

  insights {
    enabled                            = true
    default_log_analytics_workspace_id = var.log_analytics_workspace_id
    retention_in_days                  = 30
  }
}

# Egress allow-list for AKS and platform services. Everything else is denied by default.
resource "azurerm_firewall_policy_rule_collection_group" "platform" {
  name               = "rcg-platform-egress"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 200

  network_rule_collection {
    name     = "aks-core-network"
    priority = 210
    action   = "Allow"

    rule {
      name                  = "ntp"
      protocols             = ["UDP"]
      source_addresses      = var.spoke_address_spaces
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }

    rule {
      name                  = "azure-monitor-servicetag"
      protocols             = ["TCP"]
      source_addresses      = var.spoke_address_spaces
      destination_addresses = ["AzureMonitor"]
      destination_ports     = ["443"]
    }
  }

  application_rule_collection {
    name     = "aks-core-fqdn"
    priority = 220
    action   = "Allow"

    rule {
      name                  = "aks-fqdn-tag"
      source_addresses      = var.spoke_address_spaces
      destination_fqdn_tags = ["AzureKubernetesService"]
      protocols {
        type = "Https"
        port = 443
      }
    }

    rule {
      name              = "azure-platform"
      source_addresses  = var.spoke_address_spaces
      destination_fqdns = [
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "mcr-0001.mcr-msedge.net",
        "management.azure.com",
        "login.microsoftonline.com",
        "packages.microsoft.com",
        "acs-mirror.azureedge.net",
        "packages.aks.azure.com",
        "*.ods.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "*.monitoring.azure.com",
        "*.ingest.monitor.azure.com",
        "*.handler.control.monitor.azure.com",
        "global.handler.control.monitor.azure.com",
        "dc.services.visualstudio.com",
        "*.in.applicationinsights.azure.com",
        "*.cloud.defender.microsoft.com",
        "data.policy.core.windows.net",
        "store.policy.core.windows.net",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  application_rule_collection {
    name     = "gitops-and-supply-chain"
    priority = 230
    action   = "Allow"

    # Argo CD pulls Git over HTTPS; Kyverno checks Sigstore transparency log for keyless signatures.
    # All container images and Helm charts are mirrored into ACR (ADR-0012), so no public registries are allowed.
    rule {
      name              = "github-git"
      source_addresses  = var.spoke_address_spaces
      destination_fqdns = [
        "github.com",
        "api.github.com",
        "codeload.github.com",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }

    rule {
      name              = "sigstore"
      source_addresses  = var.spoke_address_spaces
      destination_fqdns = [
        "rekor.sigstore.dev",
        "fulcio.sigstore.dev",
        "tuf-repo-cdn.sigstore.dev",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  # Explicit east-west exceptions between spokes (default: denied). Each entry must cite an ADR or EXC record.
  dynamic "network_rule_collection" {
    for_each = length(var.east_west_rules) > 0 ? [1] : []
    content {
      name     = "east-west"
      priority = 250
      action   = "Allow"
      dynamic "rule" {
        for_each = var.east_west_rules
        content {
          name                  = rule.value.name
          protocols             = ["TCP"]
          source_addresses      = rule.value.source_addresses
          destination_addresses = rule.value.destination_addresses
          destination_ports     = rule.value.destination_ports
        }
      }
    }
  }

  # GitHub-hosted runners injected into spoke subnets (ADR-0013) need the Actions service and package registries.
  dynamic "application_rule_collection" {
    for_each = length(var.runner_address_spaces) > 0 ? [1] : []
    content {
      name     = "ci-runners"
      priority = 240
      action   = "Allow"
      rule {
        name              = "github-actions"
        source_addresses  = var.runner_address_spaces
        destination_fqdns = [
          "github.com",
          "api.github.com",
          "*.actions.githubusercontent.com",
          "codeload.github.com",
          "objects.githubusercontent.com",
          "results-receiver.actions.githubusercontent.com",
          "*.blob.core.windows.net",
          "ghcr.io",
          "*.pkg.github.com",
          "pkg-containers.githubusercontent.com",
          "token.actions.githubusercontent.com",
          "rekor.sigstore.dev",
          "fulcio.sigstore.dev",
          "tuf-repo-cdn.sigstore.dev",
          "pypi.org",
          "files.pythonhosted.org",
          "registry.npmjs.org",
          "registry.terraform.io",
          "releases.hashicorp.com",
          "management.azure.com",
          "login.microsoftonline.com",
        ]
        protocols {
          type = "Https"
          port = 443
        }
      }
    }
  }

  dynamic "application_rule_collection" {
    for_each = length(var.extra_allowed_fqdns) > 0 ? [1] : []
    content {
      name     = "approved-exceptions"
      priority = 300
      action   = "Allow"
      rule {
        name              = "exceptions"
        source_addresses  = var.spoke_address_spaces
        destination_fqdns = var.extra_allowed_fqdns
        protocols {
          type = "Https"
          port = 443
        }
      }
    }
  }
}

resource "azurerm_firewall" "this" {
  name                = var.names.firewall
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  zones               = var.zones
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.platform]
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                           = "diag-to-law"
  target_resource_id             = azurerm_firewall.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "${var.names.public_ip}-bas"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  count                  = var.enable_bastion ? 1 : 0
  name                   = var.names.bastion
  location               = var.location
  resource_group_name    = var.resource_group_name
  sku                    = "Standard"
  tunneling_enabled      = true
  copy_paste_enabled     = false
  file_copy_enabled      = false
  shareable_link_enabled = false
  tags                   = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# Central private DNS zones (ALZ pattern): spokes do not create their own zones.
resource "azurerm_private_dns_zone" "this" {
  for_each            = toset(var.private_dns_zones)
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each              = azurerm_private_dns_zone.this
  name                  = "link-${azurerm_virtual_network.hub.name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}
