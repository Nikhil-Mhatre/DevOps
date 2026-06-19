# ==============================================================================
# Root Environment Outputs
# ==============================================================================

output "resource_group_name" {
  description = "The name of the core resource group containing all assets."
  value       = azurerm_resource_group.rg.name
}

output "aks_cluster_name" {
  description = "The name of the provisioned AKS cluster."
  value       = module.aks.name
}

output "key_vault_name" {
  description = "The name of the Key Vault. Plug this into the 'keyvaultName' field of your SecretProviderClass YAML."
  value       = module.key_vault.name
}

output "uami_client_id" {
  description = "The Client ID of the Workload Identity. Plug this into the 'clientID' field of your SecretProviderClass YAML."
  value       = module.uami.client_id
}

output "service_acc_name" {
  description = "Service Account Name."
  value       = var.sa_name
}
output "service_acc_namespace" {
  description = "Service Account Namespace."
  value       = var.sa_namespace
}

# ------------------------------------------------------------------------------
# Quality of Life Helper Commands
# ------------------------------------------------------------------------------

output "aks_connection_command" {
  description = "Run this command in your terminal to connect Git Bash/kubectl to your new cluster."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${module.aks.name} --overwrite-existing"
}
