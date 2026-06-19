variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group where AKS will be deployed."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Tags applied to AKS resources."
  type        = map(string)
  default     = {}
}

variable "node_count" {
  description = "The initial number of worker nodes for the cluster."
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "The virtual machine SKU size to use for the worker nodes."
  type        = string
  default     = "Standard_B2s"
}
