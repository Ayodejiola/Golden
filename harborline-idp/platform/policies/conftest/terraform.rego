# Conftest policy for Terraform plans (terraform show -json tfplan > plan.json; conftest test plan.json).
# Second line of defence after module defaults and Azure Policy: catches risky changes before apply.
package main

import rego.v1

mandatory_tags := {"environment", "owner", "cost-center", "data-classification", "managed-by"}

# Resources allowed to keep public network access, each backed by an ADR.
public_access_exceptions := {
	"azurerm_dashboard_grafana", # ADR-0009: Entra ID + Conditional Access
	"azurerm_monitor_data_collection_endpoint", # Entra-authenticated ingestion; AMPLS on roadmap
}

changes contains rc if {
	some rc in input.resource_changes
	some action in rc.change.actions
	action in {"create", "update"}
}

deny contains msg if {
	some rc in changes
	rc.change.after.public_network_access_enabled == true
	not rc.type in public_access_exceptions
	msg := sprintf("%s: public network access must be disabled (Corp landing zone, ADR-0003)", [rc.address])
}

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_servicebus_namespace"
	rc.change.after.local_auth_enabled == true
	msg := sprintf("%s: Service Bus SAS/local auth must be disabled (ADR-0005)", [rc.address])
}

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_container_registry"
	rc.change.after.admin_enabled == true
	msg := sprintf("%s: ACR admin user must be disabled", [rc.address])
}

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_postgresql_flexible_server"
	some auth in rc.change.after.authentication
	auth.password_auth_enabled == true
	not startswith(object.get(object.get(rc.change.after, "tags", {}), "exception", ""), "EXC-")
	msg := sprintf("%s: PostgreSQL password authentication must be disabled (Entra only, ADR-0007)", [rc.address])
}

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_kubernetes_cluster"
	rc.change.after.local_account_disabled != true
	msg := sprintf("%s: AKS local accounts must be disabled (CIS 5.5.x)", [rc.address])
}

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_kubernetes_cluster"
	rc.change.after.private_cluster_enabled != true
	msg := sprintf("%s: AKS API server must be private (CIS 5.4.2)", [rc.address])
}

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_key_vault"
	rc.change.after.purge_protection_enabled != true
	msg := sprintf("%s: Key Vault purge protection is mandatory", [rc.address])
}

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_storage_account"
	rc.change.after.shared_access_key_enabled == true
	msg := sprintf("%s: storage shared keys must be disabled", [rc.address])
}

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_resource_group"
	tags := object.get(rc.change.after, "tags", {})
	missing := mandatory_tags - {k | some k, _ in tags}
	count(missing) > 0
	msg := sprintf("%s: missing mandatory tags %v", [rc.address, missing])
}

deny contains msg if {
	some rc in changes
	rc.type == "azurerm_web_application_firewall_policy"
	some ps in rc.change.after.policy_settings
	ps.mode != "Prevention"
	msg := sprintf("%s: WAF must run in Prevention mode", [rc.address])
}

# Destroys are allowed but must be visible: the pipeline turns warnings into a required PR acknowledgement.
warn contains msg if {
	some rc in input.resource_changes
	"delete" in rc.change.actions
	msg := sprintf("%s will be DESTROYED (%v)", [rc.address, rc.change.actions])
}
