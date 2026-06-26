variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "Central India"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "terraform-demo-rg"
}
