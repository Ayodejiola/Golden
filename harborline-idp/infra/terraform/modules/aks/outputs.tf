output "id" {
  description = "Cluster resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "name" {
  description = "Cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_object_id" {
  description = "Kubelet identity object ID."
  value       = azurerm_user_assigned_identity.kubelet.principal_id
}

output "node_resource_group" {
  description = "Managed node resource group."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "private_fqdn" {
  description = "Private API server FQDN."
  value       = azurerm_kubernetes_cluster.this.private_fqdn
}

output "key_vault_secrets_provider_identity" {
  description = "Object ID of the CSI driver add-on identity."
  value       = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].object_id
}

output "app_routing_identity_object_id" {
  description = "Object ID of the app routing (managed NGINX) add-on identity."
  value       = azurerm_kubernetes_cluster.this.web_app_routing[0].web_app_routing_identity[0].object_id
}
