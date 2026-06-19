# ==============================================================================
# Role Assignment Outputs
# ==============================================================================

output "uami_role_assignment_id" {
  description = "The generated ID of the Role Assignment to UAMI."
  value       = azurerm_role_assignment.uami_kv_user.id
}

output "uami_role_assignment_principal_id" {
  description = "The Principal ID that was granted the role to UAMI."
  value       = azurerm_role_assignment.uami_kv_user.principal_id
}

output "uami_role_definition_name" {
  description = "The name of the role that was assigned to UAMI(e.g., 'Key Vault Secrets User')."
  value       = azurerm_role_assignment.uami_kv_user.role_definition_id
}
