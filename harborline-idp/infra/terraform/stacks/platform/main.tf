/**
 * platform — one application landing zone per environment: spoke network, AKS, Key Vault, WAF ingress,
 * Application Insights, Azure Policy guardrails, VNet-injected CI runners and platform add-on identities.
 */

module "naming" {
  source              = "../../modules/naming"
  workload            = "plat"
  environment         = var.environment
  location            = var.location
  owner               = "platform-engineering"
  cost_center         = var.cost_center
  data_classification = "confidential"
  criticality         = var.environment == "prod" ? "tier-0" : "tier-2"
}

resource "azurerm_resource_group" "this" {
  name     = module.naming.names.resource_group
  location = var.location
  tags     = module.naming.tags
}

# ---------- Network ----------
module "spoke" {
  source    = "../../modules/spoke-network"
  providers = {
    azurerm     = azurerm
    azurerm.hub = azurerm.hub
  }
  names                   = module.naming.names
  tags                    = module.naming.tags
  location                = var.location
  resource_group_name     = azurerm_resource_group.this.name
  address_space           = var.spoke_address_space
  hub_vnet_id             = data.azurerm_virtual_network.hub.id
  hub_vnet_name           = data.azurerm_virtual_network.hub.name
  hub_resource_group_name = data.azurerm_virtual_network.hub.resource_group_name
  hub_firewall_private_ip = data.azurerm_firewall.hub.ip_configuration[0].private_ip_address
  use_remote_gateways     = var.use_remote_gateways
}

# ---------- Secrets ----------
module "key_vault" {
  source                     = "../../modules/key-vault"
  name                       = module.naming.names.key_vault
  location                   = var.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id = module.spoke.subnet_ids["pe"]
  private_dns_zone_id        = data.azurerm_private_dns_zone.hub["privatelink.vaultcore.azure.net"].id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.central.id
  role_assignments           = {
    platform-admins = { role = "Key Vault Administrator", principal_id = var.groups.platform_admins }
    ci-apply        = { role = "Key Vault Secrets Officer", principal_id = data.azurerm_client_config.current.object_id }
    otel-collector  = { role = "Key Vault Secrets User", principal_id = module.addon_identity["otel-collector"].principal_id }
  }
  tags = module.naming.tags
}

# ---------- Kubernetes ----------
module "aks" {
  source                     = "../../modules/aks"
  name                       = module.naming.names.aks
  environment                = var.environment
  location                   = var.location
  resource_group_name        = azurerm_resource_group.this.name
  node_resource_group_name   = module.naming.names.aks_node_rg
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  kubernetes_version         = var.kubernetes_version
  sku_tier                   = var.aks_sku_tier
  vnet_id                    = module.spoke.vnet_id
  system_subnet_id           = module.spoke.subnet_ids["aks-system"]
  user_subnet_id             = module.spoke.subnet_ids["aks-user"]
  private_dns_zone_id        = data.azurerm_private_dns_zone.hub["privatelink.${var.location}.azmk8s.io"].id
  acr_id                     = data.azurerm_container_registry.shared.id
  admin_group_object_id      = var.groups.platform_admins
  reader_group_object_ids    = [var.groups.all_engineers]
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.central.id
  monitor_workspace_id       = data.azurerm_monitor_workspace.central.id
  action_group_id            = data.azurerm_monitor_action_group.platform.id
  system_pool                = var.system_pool
  user_pools                 = var.user_pools
  tags                       = module.naming.tags

  depends_on = [module.spoke]
}

# Identities for platform add-ons that call Azure (federated to their Kubernetes service accounts).
module "addon_identity" {
  source   = "../../modules/workload-identity"
  for_each = {
    otel-collector = { namespace = "observability", sa = "otel-collector", roles = {} }
    kyverno        = {
      namespace = "kyverno"
      sa        = "kyverno-admission-controller"
      roles     = { acr = { scope = data.azurerm_container_registry.shared.id, role = "AcrPull" } }
    }
  }
  name                = "id-plat-${each.key}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  namespace           = each.value.namespace
  service_account     = each.value.sa
  oidc_issuers        = { primary = module.aks.oidc_issuer_url }
  role_assignments    = each.value.roles
  tags                = module.naming.tags
}

# ---------- Telemetry ----------
resource "azurerm_application_insights" "this" {
  name                = module.naming.names.app_insights
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = data.azurerm_log_analytics_workspace.central.id
  application_type    = "web"
  retention_in_days   = 90
  sampling_percentage = 100 # tail sampling happens in the OTel collector
  tags                = module.naming.tags
}

resource "azurerm_key_vault_secret" "appinsights" {
  name         = "appinsights-connection-string"
  key_vault_id = module.key_vault.id
  value        = azurerm_application_insights.this.connection_string
  content_type = "text/plain"
  tags         = { rotation = "on-recreate" }
}

# ---------- Public ingress ----------
module "app_gateway" {
  source                     = "../../modules/app-gateway-waf"
  name                       = module.naming.names.app_gateway
  waf_policy_name            = module.naming.names.waf_policy
  location                   = var.location
  resource_group_name        = azurerm_resource_group.this.name
  subnet_id                  = module.spoke.subnet_ids["agw"]
  backend_ip                 = module.spoke.ingress_internal_ip
  key_vault_id               = module.key_vault.id
  min_capacity               = var.environment == "prod" ? 2 : 1
  max_capacity               = var.environment == "prod" ? 10 : 3
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.central.id
  tags                       = module.naming.tags
  sites                      = {
    for k, s in var.public_sites : k => {
      host_name             = s.host_name
      certificate_secret_id = "${module.key_vault.uri}secrets/${s.certificate_name}"
      health_path           = s.health_path
    }
  }
}

# ---------- Governance ----------
module "policy" {
  source               = "../../modules/policy-assignments"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  deny_effect          = var.environment == "dev" ? "Audit" : "Deny"
  k8s_effect           = var.environment == "dev" ? "audit" : "deny"
  allowed_images_regex = "^(${replace(data.azurerm_container_registry.shared.login_server, ".", "\\.")}|mcr\\.microsoft\\.com)/.+$"
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

# ---------- CI runners in the spoke (ADR-0013) ----------
module "runner_network" {
  count              = var.github_business_id == null ? 0 : 1
  source             = "../../modules/github-runner-network"
  name               = "ghns-plat-${var.environment}-${module.naming.region_short}"
  location           = var.location
  resource_group_id  = azurerm_resource_group.this.id
  subnet_id          = module.spoke.subnet_ids["runners"]
  github_business_id = var.github_business_id
  tags               = module.naming.tags
}
