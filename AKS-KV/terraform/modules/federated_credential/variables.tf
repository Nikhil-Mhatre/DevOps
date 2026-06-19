variable "resource_group_name" {
  description = "The name of the Azure Resource Group where the federated identity credential will be registered."
  type        = string
}

variable "tags" {
  description = "A mapping of standard corporate resource tags applied to all assets."
  type        = map(string)
  default     = {}
}

variable "fed_cred_name" {
  description = "The descriptive name for the Federated Identity Credential trust link."
  type        = string
}

variable "oidc_issuer_url" {
  description = "The OpenID Connect (OIDC) Issuer URL exported directly from the provisioned AKS cluster."
  type        = string
}

variable "uami_id" {
  description = "The fully qualified Azure Resource ID of the User-Assigned Managed Identity acting as the parent for this credential."
  type        = string
}

variable "service_account_subject" {
  description = "The fully formatted Kubernetes system subject string linking the namespace and service account name (e.g., 'system:serviceaccount:default:my-app-sa')."
  type        = string
}
