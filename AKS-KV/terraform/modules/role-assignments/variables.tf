variable "keyvault_id" {
  description = "The fully qualified Azure Resource ID of the target Key Vault where secrets or access policies are managed."
  type        = string
}

variable "uami_principal_id" {
  description = "The Principal (Object) ID of the User-Assigned Managed Identity. Crucial for establishing RBAC role assignments."
  type        = string
}

variable "tags" {
  description = "A mapping of corporate or project-specific operational metadata tags to apply to all provisioned resources."
  type        = map(string)
  default     = {}
}