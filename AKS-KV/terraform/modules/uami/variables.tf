variable "identity_name" {
  description = "Name of the Managed Indentity"
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
