output "resource_group_name" {
  description = "Name of the project resource group"
  value       = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  description = "ACR login server URL (use as ACR_LOGIN_SERVER secret in GitHub)"
  value       = azurerm_container_registry.acr.login_server
}

output "aks_cluster_name" {
  description = "AKS cluster name (use as AKS_CLUSTER_NAME secret in GitHub)"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_get_credentials_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}

output "kube_config" {
  description = "Raw kubeconfig (sensitive)"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}
