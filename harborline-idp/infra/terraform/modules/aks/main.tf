/**
 * aks — Harborline baseline AKS cluster (aligned to the AKS baseline reference architecture and CIS AKS Benchmark).
 *
 *  - Private API server with custom private DNS zone in the hub; local accounts disabled; Entra ID + Azure RBAC.
 *  - Azure CNI Overlay with Cilium dataplane and network policy (ADR-0006); egress via hub firewall (UDR).
 *  - Workload identity + OIDC issuer; Key Vault Secrets Store CSI driver with rotation.
 *  - Azure Policy add-on, Defender for Containers, image cleaner, KEDA + VPA, managed NGINX (app routing).
 *  - AzureLinux nodes, ephemeral OS disks, encryption at host, zone-spread pools, planned maintenance windows.
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

# ---------- Identities ----------
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.name}-cp"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "id-${var.name}-kubelet"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "cp_network" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_role_assignment" "cp_private_dns" {
  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_role_assignment" "cp_kubelet_operator" {
  scope                = azurerm_user_assigned_identity.kubelet.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.kubelet.principal_id
}

# ---------- Cluster ----------
resource "azurerm_kubernetes_cluster" "this" {
  name                                = var.name
  location                            = var.location
  resource_group_name                 = var.resource_group_name
  node_resource_group                 = var.node_resource_group_name
  dns_prefix_private_cluster          = var.name
  kubernetes_version                  = var.kubernetes_version
  sku_tier                            = var.sku_tier
  support_plan                        = "KubernetesOfficial"
  private_cluster_enabled             = true
  private_dns_zone_id                 = var.private_dns_zone_id
  private_cluster_public_fqdn_enabled = false
  local_account_disabled              = true
  role_based_access_control_enabled   = true
  run_command_enabled                 = false
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true
  azure_policy_enabled                = true
  image_cleaner_enabled               = true
  image_cleaner_interval_hours        = 48
  cost_analysis_enabled               = var.sku_tier != "Free"
  automatic_upgrade_channel           = "patch"
  node_os_upgrade_channel             = "NodeImage"
  tags                                = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    tenant_id              = var.tenant_id
    admin_group_object_ids = [var.admin_group_object_id]
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_pool.vm_size
    zones                        = var.zones
    auto_scaling_enabled         = true
    min_count                    = var.system_pool.min_count
    max_count                    = var.system_pool.max_count
    max_pods                     = 110
    os_sku                       = "AzureLinux"
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = var.system_pool.os_disk_size_gb
    host_encryption_enabled      = var.host_encryption_enabled
    only_critical_addons_enabled = true
    vnet_subnet_id               = var.system_subnet_id
    orchestrator_version         = var.kubernetes_version
    temporary_name_for_rotation  = "systemtmp"
    node_labels                  = { "harborline.io/pool" = "system" }
    tags                         = var.tags

    upgrade_settings {
      max_surge                     = "33%"
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 0
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    outbound_type       = "userDefinedRouting"
    load_balancer_sku   = "standard"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = cidrhost(var.service_cidr, 10)
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = "pods=[app.kubernetes.io/name,app.kubernetes.io/part-of,harborline.io/team]"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  workload_autoscaler_profile {
    keda_enabled                    = true
    vertical_pod_autoscaler_enabled = true
  }

  # Managed NGINX: no default (public) controller; the internal one is declared in gitops/addons/platform-config.
  web_app_routing {
    dns_zone_ids             = var.app_routing_dns_zone_ids
    default_nginx_controller = "None"
  }

  storage_profile {
    blob_driver_enabled         = false
    disk_driver_enabled         = true
    file_driver_enabled         = false
    snapshot_controller_enabled = true
  }

  dynamic "key_management_service" {
    for_each = var.kms == null ? [] : [var.kms]
    content {
      key_vault_key_id         = key_management_service.value.key_id
      key_vault_network_access = key_management_service.value.network_access
    }
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = var.maintenance.day_of_week
    start_time  = var.maintenance.start_time
    utc_offset  = var.maintenance.utc_offset
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = var.maintenance.day_of_week
    start_time  = var.maintenance.start_time
    utc_offset  = var.maintenance.utc_offset
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count, # owned by the cluster autoscaler
    ]
    precondition {
      condition     = var.sku_tier != "Free" || var.environment == "dev"
      error_message = "Only dev may use the Free tier: stg/prod need the uptime SLA (Standard or Premium)."
    }
  }

  depends_on = [
    azurerm_role_assignment.cp_network,
    azurerm_role_assignment.cp_private_dns,
    azurerm_role_assignment.cp_kubelet_operator,
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each                = var.user_pools
  name                    = each.key
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  mode                    = "User"
  vm_size                 = each.value.vm_size
  zones                   = var.zones
  auto_scaling_enabled    = true
  min_count               = each.value.min_count
  max_count               = each.value.max_count
  max_pods                = 110
  os_sku                  = "AzureLinux"
  os_disk_type            = "Ephemeral"
  os_disk_size_gb         = each.value.os_disk_size_gb
  host_encryption_enabled = var.host_encryption_enabled
  vnet_subnet_id          = var.user_subnet_id
  orchestrator_version    = var.kubernetes_version
  node_labels             = merge({ "harborline.io/pool" = each.key }, each.value.labels)
  node_taints             = each.value.taints
  tags                    = var.tags

  upgrade_settings {
    max_surge                     = "33%"
    drain_timeout_in_minutes      = 30
    node_soak_duration_in_minutes = 5
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

# ---------- Access: Entra groups, least privilege ----------
resource "azurerm_role_assignment" "cluster_admins" {
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.admin_group_object_id
}

resource "azurerm_role_assignment" "cluster_user_role" {
  for_each             = toset(concat([var.admin_group_object_id], var.reader_group_object_ids))
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "cluster_readers" {
  for_each             = toset(var.reader_group_object_ids)
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  principal_id         = each.value
}

# ---------- Control-plane diagnostics ----------
resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "diag-to-law"
  target_resource_id             = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = var.diagnostic_categories
    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
