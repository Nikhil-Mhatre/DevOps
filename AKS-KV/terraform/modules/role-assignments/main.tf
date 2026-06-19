data "azurerm_client_config" "current" {}

// UAMI Role Assignment
resource "azurerm_role_assignment" "uami_kv_user" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.uami_principal_id
}


// Giving Terraform SP this role in order to add secrets
resource "azurerm_role_assignment" "admin_kv_officer" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
