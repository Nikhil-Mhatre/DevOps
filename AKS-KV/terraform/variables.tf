# ==============================================================================
# Core
# ==============================================================================
variable "project_name" {
  type        = string
  description = "The short code or name of the project (e.g., 'kv-demo')."
}

variable "environment" {
  type        = string
  description = "The deployment stage (e.g., 'dev', 'staging', 'prod')."
  default     = "dev"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

# ==============================================================================
# AKS
# ==============================================================================

variable "node_count" {
  description = "The initial number of worker nodes for the cluster."
  type        = number
  default     = 1

  # Optimization: Prevents deploying a broken cluster with 0 nodes
  validation {
    condition     = var.node_count >= 1
    error_message = "The node_count must be at least 1."
  }
}

variable "vm_size" {
  description = "The virtual machine SKU size to use for the worker nodes."
  type        = string
  default     = "Standard_B2s"
}

variable "os_disk_size_gb" {
  description = "The size of the OS disk for the AKS worker nodes in GB."
  type        = number

  # Optimization: Prevents disks that are too small to hold the Kubernetes OS
  validation {
    condition     = var.os_disk_size_gb >= 30
    error_message = "The OS disk size must be at least 30 GB to support the AKS node image."
  }
}

# ==============================================================================
# Key Vault & Workload Identity
# ==============================================================================

variable "sa_namespace" {
  description = "The Kubernetes namespace where the Service Account will live."
  type        = string
}

variable "sa_name" {
  description = "The name of the Kubernetes Service Account used for Workload Identity."
  type        = string
}

# Removed the obsolete db_password variable here!

variable "key_vault_secrets" {
  description = "A map of secret names and values to inject dynamically into Key Vault."
  type        = map(string)
  sensitive   = true
  default     = {}
}

# ==============================================================================
# Operational
# ==============================================================================
variable "tags" {
  description = "Standard corporate resource tags applied to all assets."
  type        = map(string)
  default     = {} # Cleared defaults to avoid overwrite confusion
}


