output "github_client_ids" {
  description = "Set each as AZURE_CLIENT_ID in the matching GitHub environment (tf-apply-<env>) or repo variable."
  value       = module.github_oidc.client_ids
}

output "github_principal_ids" {
  description = "Principal IDs of CI identities."
  value       = module.github_oidc.principal_ids
}
