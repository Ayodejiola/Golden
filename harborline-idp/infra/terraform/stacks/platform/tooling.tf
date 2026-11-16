# Platform tooling identities and the Backstage database.
# Backstage runs only in the prod platform cluster (it catalogues every environment).

locals {
  tooling_identities = merge(
    {
      argocd-repo-server = {
        namespace = "argocd"
        sa        = "argocd-repo-server"
        roles     = { acr = { scope = data.azurerm_container_registry.shared.id, role = "AcrPull" } }
      }
    },
    var.environment == "prod" ? {
      backstage = {
        namespace = "backstage"
        sa        = "backstage"
        roles     = {
          kv-secrets = { scope = module.key_vault.id, role = "Key Vault Secrets User" }
          # Backstage Kubernetes plugin reads all clusters; reader role is granted per cluster in each env.
        }
      }
    } : {},
  )
}

module "tooling_identity" {
  source              = "../../modules/workload-identity"
  for_each            = local.tooling_identities
  name                = "id-plat-${each.key}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  namespace           = each.value.namespace
  service_account     = each.value.sa
  oidc_issuers        = { primary = module.aks.oidc_issuer_url }
  role_assignments    = each.value.roles
  tags                = module.naming.tags
}

# App routing (managed NGINX) reads TLS certificates for internal ingress from the platform Key Vault.
resource "azurerm_role_assignment" "app_routing_kv" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = module.aks.app_routing_identity_object_id
}

# ---------- Backstage database (prod only) ----------
# EXC-0001 (docs/governance/exceptions-process.md): Backstage's database client uses password auth until
# Entra token auth for the Backstage backend is validated. Compensating controls: private endpoint only,
# dedicated server with no customer data, password in Key Vault (rotated 90 days), pgaudit on.
data "azurerm_private_dns_zone" "postgres" {
  count               = var.environment == "prod" ? 1 : 0
  provider            = azurerm.hub
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = "rg-hub-shared-cac-01"
}

resource "random_password" "backstage_db" {
  count            = var.environment == "prod" ? 1 : 0
  length           = 40
  special          = true
  override_special = "-_.~"
  keepers          = {
    rotation = var.backstage_db_password_rotation
  }
}

module "backstage_db" {
  count                        = var.environment == "prod" ? 1 : 0
  source                       = "../../modules/postgresql"
  name                         = module.naming.names.postgresql
  location                     = var.location
  resource_group_name          = azurerm_resource_group.this.name
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  sku_name                     = "GP_Standard_D2ds_v5"
  storage_mb                   = 32768
  high_availability            = true
  geo_redundant_backup_enabled = true
  entra_admin                  = { object_id = var.groups.platform_admins, principal_name = var.groups.platform_admins_name }
  databases                    = ["backstage"]
  private_endpoint_subnet_id   = module.spoke.subnet_ids["pe"]
  private_dns_zone_id          = data.azurerm_private_dns_zone.postgres[0].id
  log_analytics_workspace_id   = data.azurerm_log_analytics_workspace.central.id
  action_group_id              = data.azurerm_monitor_action_group.platform.id
  password_auth                = {
    administrator_login    = "backstage_admin"
    administrator_password = random_password.backstage_db[0].result
  }
  tags = merge(module.naming.tags, { "exception" = "EXC-0001" })
}

resource "azurerm_key_vault_secret" "backstage_db" {
  count           = var.environment == "prod" ? 1 : 0
  name            = "backstage-db-password"
  key_vault_id    = module.key_vault.id
  value           = random_password.backstage_db[0].result
  content_type    = "text/plain"
  expiration_date = timeadd(var.backstage_db_password_rotation, "2160h") # 90 days
}
