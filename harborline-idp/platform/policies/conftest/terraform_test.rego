package main

import rego.v1

mk_change(type, after) := {"address": sprintf("%s.test", [type]), "type": type, "change": {"actions": ["create"], "after": after}}

good_tags := {
	"environment": "dev", "owner": "x", "cost-center": "CC-1001",
	"data-classification": "internal", "managed-by": "terraform",
}

test_public_storage_denied if {
	count(deny) > 0 with input as {"resource_changes": [mk_change("azurerm_key_vault", {"public_network_access_enabled": true, "purge_protection_enabled": true})]}
}

test_grafana_public_allowed if {
	count(deny) == 0 with input as {"resource_changes": [mk_change("azurerm_dashboard_grafana", {"public_network_access_enabled": true})]}
}

test_aks_public_denied if {
	some msg in deny with input as {"resource_changes": [mk_change("azurerm_kubernetes_cluster", {"local_account_disabled": true, "private_cluster_enabled": false})]}
	contains(msg, "must be private")
}

test_aks_compliant if {
	count(deny) == 0 with input as {"resource_changes": [mk_change("azurerm_kubernetes_cluster", {"local_account_disabled": true, "private_cluster_enabled": true})]}
}

test_pg_password_denied if {
	count(deny) == 1 with input as {"resource_changes": [mk_change("azurerm_postgresql_flexible_server", {"authentication": [{"password_auth_enabled": true}]})]}
}

test_pg_password_allowed_with_exception if {
	count(deny) == 0 with input as {"resource_changes": [mk_change("azurerm_postgresql_flexible_server", {"authentication": [{"password_auth_enabled": true}], "tags": {"exception": "EXC-0001"}})]}
}

test_rg_missing_tags_denied if {
	count(deny) == 1 with input as {"resource_changes": [mk_change("azurerm_resource_group", {"tags": {"owner": "x"}})]}
}

test_rg_tags_ok if {
	count(deny) == 0 with input as {"resource_changes": [mk_change("azurerm_resource_group", {"tags": good_tags})]}
}

test_waf_detection_denied if {
	count(deny) == 1 with input as {"resource_changes": [mk_change("azurerm_web_application_firewall_policy", {"policy_settings": [{"mode": "Detection"}]})]}
}

test_destroy_warns if {
	count(warn) == 1 with input as {"resource_changes": [{"address": "x", "type": "azurerm_resource_group", "change": {"actions": ["delete"], "after": null}}]}
}
