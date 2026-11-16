/**
 * bootstrap — CI/CD identities for GitHub Actions (OIDC, no secrets) and their least-privilege RBAC.
 * Applied once (and on change) by a Cloud Admin with PIM-elevated Owner; every other stack runs in pipelines.
 */

module "naming" {
  source              = "../../modules/naming"
  workload            = "cicd"
  environment         = "shared"
  location            = var.location
  owner               = "platform-engineering"
  cost_center         = var.cost_center
  data_classification = "internal"
  criticality         = "tier-1"
}

resource "azurerm_resource_group" "this" {
  name     = module.naming.names.resource_group
  location = var.location
  tags     = module.naming.tags
}

# Role definition IDs for the ABAC condition that limits what the apply identities may assign.
data "azurerm_role_definition" "assignable" {
  for_each = toset(var.assignable_roles)
  name     = each.value
}

locals {
  repo         = "repo:${var.github_org}/${var.github_repo}"
  role_guids   = join(", ", [for r in data.azurerm_role_definition.assignable : basename(r.role_definition_id)])
  state_scopes = { for env in concat(var.environments, ["shared"]) : env => "${var.state_storage_account_id}/blobServices/default/containers/tfstate-${env}" }

  # Constrained delegation: the apply identity may only create/delete assignments for the allow-listed roles.
  rbac_condition = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.role_guids}}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.role_guids}}
     )
    )
  EOT

  env_identities = merge(
    { for env, sub in var.landing_zone_subscription_ids : "tf-plan-${env}" => {
      subjects = ["${local.repo}:pull_request", "${local.repo}:ref:refs/heads/main"]
      roles    = {
        reader-lz   = { scope = "/subscriptions/${sub}", role = "Reader" }
        reader-hub  = { scope = "/subscriptions/${var.connectivity_subscription_id}", role = "Reader" }
        reader-mgmt = { scope = "/subscriptions/${var.management_subscription_id}", role = "Reader" }
        state       = { scope = local.state_scopes[env], role = "Storage Blob Data Contributor" }
      }
    } },
    { for env, sub in var.landing_zone_subscription_ids : "tf-apply-${env}" => {
      subjects = ["${local.repo}:environment:${env}"]
      roles    = {
        contributor = { scope = "/subscriptions/${sub}", role = "Contributor" }
        rbac-admin  = { scope = "/subscriptions/${sub}", role = "Role Based Access Control Administrator", condition = local.rbac_condition }
        hub-peering = { scope = "/subscriptions/${var.connectivity_subscription_id}", role = "Network Contributor" }
        hub-dns     = { scope = "/subscriptions/${var.connectivity_subscription_id}", role = "Private DNS Zone Contributor" }
        hub-rbac    = { scope = "/subscriptions/${var.connectivity_subscription_id}", role = "Role Based Access Control Administrator", condition = local.rbac_condition }
        reader-mgmt = { scope = "/subscriptions/${var.management_subscription_id}", role = "Reader" }
        mgmt-rbac   = { scope = "/subscriptions/${var.management_subscription_id}", role = "Role Based Access Control Administrator", condition = local.rbac_condition }
        state       = { scope = local.state_scopes[env], role = "Storage Blob Data Contributor" }
      }
    } },
  )

  shared_identities = {
    "tf-plan-shared" = {
      subjects = ["${local.repo}:pull_request", "${local.repo}:ref:refs/heads/main"]
      roles    = {
        reader-hub  = { scope = "/subscriptions/${var.connectivity_subscription_id}", role = "Reader" }
        reader-mgmt = { scope = "/subscriptions/${var.management_subscription_id}", role = "Reader" }
        state       = { scope = local.state_scopes["shared"], role = "Storage Blob Data Contributor" }
      }
    }
    "tf-apply-shared" = {
      subjects = ["${local.repo}:environment:shared"]
      roles    = {
        hub       = { scope = "/subscriptions/${var.connectivity_subscription_id}", role = "Contributor" }
        mgmt      = { scope = "/subscriptions/${var.management_subscription_id}", role = "Contributor" }
        hub-rbac  = { scope = "/subscriptions/${var.connectivity_subscription_id}", role = "Role Based Access Control Administrator", condition = local.rbac_condition }
        mgmt-rbac = { scope = "/subscriptions/${var.management_subscription_id}", role = "Role Based Access Control Administrator", condition = local.rbac_condition }
        state     = { scope = local.state_scopes["shared"], role = "Storage Blob Data Contributor" }
      }
    }
    # Image builds: AcrPush is granted on the registry by the management stack.
    "acr-push" = {
      subjects = concat(
        ["${local.repo}:ref:refs/heads/main"],
        [for r in var.service_repositories : "repo:${var.github_org}/${r}:ref:refs/heads/main"],
      )
      roles = {}
    }
  }
}

module "github_oidc" {
  source              = "../../modules/github-oidc"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  identities          = merge(local.env_identities, local.shared_identities)
  tags                = module.naming.tags
}

resource "azurerm_management_lock" "rg" {
  name       = "cannot-delete"
  scope      = azurerm_resource_group.this.id
  lock_level = "CanNotDelete"
  notes      = "CI identities: deleting breaks every pipeline. Remove only via change request."
}
