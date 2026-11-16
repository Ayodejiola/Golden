output "aks_name" {
  description = "AKS cluster name."
  value       = module.aks.name
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer for workload identity federation (consumed by workload stacks by lookup)."
  value       = module.aks.oidc_issuer_url
}

output "key_vault_uri" {
  description = "Platform Key Vault URI."
  value       = module.key_vault.uri
}

output "ingress_internal_ip" {
  description = "Static IP for the internal NGINX ingress (gitops/addons/ingress-internal)."
  value       = module.spoke.ingress_internal_ip
}

output "app_gateway_public_ip" {
  description = "Public IP for DNS A records of public sites."
  value       = module.app_gateway.public_ip
}

output "addon_identity_client_ids" {
  description = "Client IDs for platform add-on service accounts (gitops/addons values)."
  value       = merge({ for k, v in module.addon_identity : k => v.client_id }, { for k, v in module.tooling_identity : k => v.client_id })
}

output "github_network_settings_id" {
  description = "Register in GitHub hosted compute networking for this environment's runner group."
  value       = try(module.runner_network[0].github_network_settings_id, null)
}
