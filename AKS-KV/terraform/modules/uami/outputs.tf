# ==============================================================================
# Managed Identity Outputs
# ==============================================================================

output "id" {
  description = "The Azure Resource ID of the User Assigned Managed Identity."
  value       = azurerm_user_assigned_identity.this.id
}

output "principal_id" {
  description = "The Object/Principal ID of the Managed Identity. Used by the Role Assignment module to grant Key Vault access."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "client_id" {
  description = "The Client ID of the Managed Identity. Crucial for the 'clientID' field in the AKS SecretProviderClass YAML."
  value       = azurerm_user_assigned_identity.this.client_id
}