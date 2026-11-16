/**
 * naming — Harborline Cloud Adoption Framework naming & tagging convention.
 *
 * Pattern: <type>-<workload>-<env>-<region>-<instance>
 * Constrained resources (Key Vault, Storage, ACR, Grafana) use compact variants that respect Azure limits.
 * This module has no providers and no resources; it is covered by `terraform test` (tests/naming.tftest.hcl).
 */
terraform {
  required_version = ">= 1.9.0"
}

locals {
  region_short = {
    canadacentral = "cac"
    canadaeast    = "cae"
    eastus2       = "eus2"
    centralus     = "cus"
  }

  loc  = local.region_short[var.location]
  inst = format("%02d", var.instance)
  base = "${var.workload}-${var.environment}-${local.loc}-${local.inst}"
  # Compact, alphanumeric-only base for resources that forbid hyphens.
  compact = lower(replace("${var.org}${var.workload}${var.environment}${local.loc}${local.inst}", "-", ""))

  names = {
    resource_group       = "rg-${local.base}"
    virtual_network      = "vnet-${local.base}"
    network_security_grp = "nsg-${local.base}"
    route_table          = "rt-${local.base}"
    firewall             = "afw-${local.base}"
    firewall_policy      = "afwp-${local.base}"
    public_ip            = "pip-${local.base}"
    bastion              = "bas-${local.base}"
    aks                  = "aks-${local.base}"
    aks_node_rg          = "rg-${local.base}-aksnodes"
    app_gateway          = "agw-${local.base}"
    waf_policy           = "wafp-${local.base}"
    log_analytics        = "log-${local.base}"
    app_insights         = "appi-${local.base}"
    monitor_workspace    = "amw-${local.base}"
    action_group         = "ag-${local.base}"
    dce                  = "dce-${local.base}"
    dcr                  = "dcr-${local.base}"
    postgresql           = "psql-${local.base}"
    service_bus          = "sbns-${local.base}"
    managed_identity     = "id-${local.base}"
    private_endpoint     = "pep-${local.base}"
    # Length-constrained names
    key_vault          = substr("kv-${var.org}-${var.workload}-${var.environment}-${local.loc}${local.inst}", 0, 24)
    storage_account    = substr(local.compact, 0, 24)
    container_registry = substr("acr${local.compact}", 0, 50)
    grafana            = substr("amg-${var.org}-${var.workload}-${var.environment}-${local.loc}", 0, 23)
  }

  tags = merge({
    "environment"         = var.environment
    "workload"            = var.workload
    "owner"               = var.owner
    "cost-center"         = var.cost_center
    "data-classification" = var.data_classification
    "criticality"         = var.criticality
    "managed-by"          = "terraform"
    "repository"          = "harborline/harborline-idp"
  }, var.extra_tags)
}
