resource "azurerm_federated_identity_credential" "this" {
  name                      = var.fed_cred_name
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  user_assigned_identity_id = var.uami_id
  subject                   = var.service_account_subject
}
