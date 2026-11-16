output "workload_identity_client_ids" {
  description = "Client IDs → gitops/workloads/<env>/insurance/<app>/values.yaml (workloadIdentity.clientId)."
  value       = { for k, v in module.identity : k => v.client_id }
}

output "postgresql_fqdn" {
  description = "PostgreSQL FQDN (private)."
  value       = module.postgresql.fqdn
}

output "postgresql_role_names" {
  description = "Entra principal names to create as PostgreSQL roles (equal to identity names)."
  value       = { for k, v in module.identity : k => v.name }
}

output "service_bus_fqdn" {
  description = "Service Bus fully qualified namespace."
  value       = module.service_bus.fqdn
}
