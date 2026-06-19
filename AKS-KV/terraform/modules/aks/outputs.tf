# ==============================================================================
# AKS Module Outputs
# ==============================================================================

output "id" {
  description = "The Azure Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "name" {
  description = "The name of the provisioned AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

# ------------------------------------------------------------------------------
# Crucial for Workload Identity Federation
# ------------------------------------------------------------------------------
output "oidc_issuer_url" {
  description = "The OIDC issuer URL required to establish the trust bridge between Kubernetes and Microsoft Entra ID."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

# ------------------------------------------------------------------------------
# Infrastructure Management
# ------------------------------------------------------------------------------
output "node_resource_group" {
  description = "The auto-generated Azure Resource Group containing the actual underlying worker node VMs."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}
