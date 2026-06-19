# Core Setup
location     = "eastus"
project_name = "aks-kv"
environment  = "dev"

# AKS Configuration
node_count      = 1
vm_size         = "Standard_B2s"
os_disk_size_gb = 30

# Security & Identity
sa_namespace = "default"
sa_name      = "workload-identity-sa"

# Secrets Injection Engine
key_vault_secrets = {
  "db-password" = "SuperSecret123"
}

# Unified Tagging Engine (Merged from variables.tf)
tags = {
  Project     = "KeyVault-AKS-Bridge"
  Environment = "Dev"
  Owner       = "Nikhil Mhatre"
  CostCenter  = "CC-4042"
}

