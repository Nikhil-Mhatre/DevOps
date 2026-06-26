terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-backend-rg"
    storage_account_name = "storage4757"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}
