# ==============================================================================
# Key Vault Module Outputs
# ==============================================================================

output "id" {
  description = "The Azure Resource ID of the Key Vault. Required for assigning RBAC roles and creating secrets."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "The exact name of the Key Vault. Required by the AKS SecretProviderClass YAML."
  value       = azurerm_key_vault.this.name
}

output "vault_uri" {
  description = "The URI of the Key Vault (e.g., https://myvault.vault.azure.net/)."
  value       = azurerm_key_vault.this.vault_uri
}