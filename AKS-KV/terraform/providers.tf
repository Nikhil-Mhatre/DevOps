terraform {
  required_version = ">= 1.15.4"

  backend "azurerm" {
    resource_group_name  = "terraform-backend-rg"
    storage_account_name = "tfstate475703"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.78.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      # Wipes the Key Vault completely from Azure when running 'terraform destroy'
      purge_soft_delete_on_destroy = true
      # Cleanly purges any individual secrets deleted during the process
      purge_soft_deleted_secrets_on_destroy = true
    }
  }
}
