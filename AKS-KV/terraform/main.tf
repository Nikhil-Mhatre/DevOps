resource "random_id" "unique_suffix" {
  byte_length = 3 # Generates a 6-character random hex suffix (e.g., '4a9b2c')
}

locals {
  universal_name = "${var.project_name}-${var.environment}"
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.universal_name}-rg"
  location = var.location
}

// uami means User Access Managed Identity
module "uami" {
  source              = "./modules/uami"
  identity_name       = "${local.universal_name}-mi"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = var.tags
}

module "aks" {
  source              = "./modules/aks"
  cluster_name        = "${local.universal_name}-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  node_count          = var.node_count
  vm_size             = var.vm_size
  tags                = var.tags
}

module "key_vault" {
  source              = "./modules/key-vault"
  keyvault_name       = "${local.universal_name}-vault-${random_id.unique_suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

module "role_assignments" {
  source            = "./modules/role-assignments"
  keyvault_id       = module.key_vault.id
  uami_principal_id = module.uami.principal_id
  tags              = var.tags
}

# Forces Terraform to freeze for 30 seconds after role assignments finish. 
# This guarantees Entra ID replication completes before any secret ingestion occurs.
resource "time_sleep" "wait_for_rbac_propagation" {
  depends_on = [module.role_assignments]

  create_duration = "30s"
}

# Securely Inject the Test Secret (Execution-Locked behind the time delay)
resource "azurerm_key_vault_secret" "secrets" {
  for_each = toset(nonsensitive(keys(var.key_vault_secrets)))

  name         = each.key                        # Takes the map key (e.g., "db-password")
  value        = var.key_vault_secrets[each.key] # Takes the map value (e.g., "SuperSecret123")
  key_vault_id = module.key_vault.id

  # Will not execute until the 30-second replication window successfully clears
  depends_on = [time_sleep.wait_for_rbac_propagation]
}

module "federated_credential" {
  source                  = "./modules/federated_credential"
  resource_group_name     = azurerm_resource_group.rg.name
  fed_cred_name           = "${local.universal_name}-fed-cred"
  oidc_issuer_url         = module.aks.oidc_issuer_url
  uami_id                 = module.uami.id
  service_account_subject = "system:serviceaccount:${var.sa_namespace}:${var.sa_name}"
  tags                    = var.tags
}
