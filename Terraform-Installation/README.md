# Terraform on Windows 11 with Azure — Complete Setup Guide

A step-by-step guide to provisioning Azure infrastructure using Terraform, with Service Principal authentication and remote state stored in Azure Blob Storage.

**Environment:** Windows 11 · VS Code · Git Bash · Microsoft Azure

---

## Table of Contents

1. [Install Required Tools](#1-install-required-tools)
2. [Login to Azure](#2-login-to-azure)
3. [Create a Service Principal](#3-create-a-service-principal)
4. [Configure Environment Variables](#4-configure-environment-variables)
5. [Assign RBAC to the Terraform Service Principal](#5-assign-rbac-to-the-terraform-service-principal)
6. [Grant Role Assignment Permissions to the Terraform SP](#6-grant-role-assignment-permissions-to-the-terraform-sp)
7. [Create a Terraform Project](#7-create-a-terraform-project)
8. [Configure Remote State in Azure Storage](#8-configure-remote-state-in-azure-storage)
9. [Write Terraform Configuration Files](#9-write-terraform-configuration-files)
10. [Initialize Terraform](#10-initialize-terraform)
11. [Validate Configuration](#11-validate-configuration)
12. [Plan and Deploy](#12-plan-and-deploy)
13. [Verify Remote State](#13-verify-remote-state)
14. [Destroy Resources](#14-destroy-resources)
15. [Recommended Project Structure](#15-recommended-project-structure)
16. [Security Best Practices](#16-security-best-practices)
17. [Common Commands Reference](#17-common-commands-reference)
18. [Future Learning Path](#18-future-learning-path)
19. [Official Documentation](#official-documentation)

---

## 1. Install Required Tools

### Git

Download from [git-scm.com/download/win](https://git-scm.com/download/win) and install using the default options.

```bash
git --version
```

### VS Code

Download from [code.visualstudio.com](https://code.visualstudio.com/) and install the following recommended extensions:

| Extension           | Purpose                               |
| ------------------- | ------------------------------------- |
| HashiCorp Terraform | Syntax highlighting and auto-complete |
| Error Lens          | Inline error display                  |
| Prettier            | Consistent code formatting            |

### Terraform

1. Download the binary from [developer.hashicorp.com/terraform/downloads](https://developer.hashicorp.com/terraform/downloads)
2. Extract `terraform.exe`
3. Create the folder `C:\Program Files\Terraform` and move `terraform.exe` into it
4. Add `C:\Program Files\Terraform` to the Windows **PATH** environment variable

```bash
terraform version
```

### Azure CLI

Download the installer from [Microsoft Docs](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows) and follow the setup wizard.

```bash
az version
```

---

## 2. Login to Azure

Open **Git Bash** and authenticate with your Azure account:

```bash
az login
```

This opens a browser window for authentication. Once complete, list your available subscriptions:

```bash
az account list --output table
```

Set the active subscription you want to use:

```bash
az account set --subscription "YOUR_SUBSCRIPTION_NAME"
```

Confirm the active subscription:

```bash
az account show
```

---

## 3. Create a Service Principal

A **Service Principal** is a non-interactive identity used by Terraform to authenticate to Azure. It is the recommended approach for automation — avoid using personal accounts for CI/CD or scripted workflows.

### Create the Service Principal

```bash
az ad sp create-for-rbac \
  --name "terraform-sp-<DEVICE>"
```

The command returns a JSON block similar to this:

```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "password": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

> **Important:** Save this output securely. The `password` value is shown only once and cannot be retrieved later.

Map the JSON output to the corresponding Terraform environment variables:

| Terraform Variable    | Azure JSON Field     |
| --------------------- | -------------------- |
| `ARM_CLIENT_ID`       | `appId`              |
| `ARM_CLIENT_SECRET`   | `password`           |
| `ARM_SUBSCRIPTION_ID` | Your Subscription ID |
| `ARM_TENANT_ID`       | `tenant`             |

Retrieve your Subscription ID with:

```bash
az account show --query id --output tsv
```

---

## 4. Configure Environment Variables

Persist the Service Principal credentials in your Git Bash profile so they are available in every terminal session:

```bash
nano ~/.bashrc
```

Add the following lines, replacing the placeholders with your actual values:

```bash
export ARM_CLIENT_ID="YOUR_APP_ID"
export ARM_CLIENT_SECRET="YOUR_PASSWORD"
export ARM_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
export ARM_TENANT_ID="YOUR_TENANT_ID"
```

Save and exit with `Ctrl+X`, then `Y`, then `Enter`. Reload the profile:

```bash
source ~/.bashrc
```

Verify all variables are set correctly:

```bash
env | grep ARM
```

> **Security note:** Never commit these values to source control. Add any file containing secrets to `.gitignore`.

---

## 5. Assign RBAC to the Terraform Service Principal

Rather than assigning roles directly to the Service Principal, the recommended pattern is to place it in a security group and assign roles to that group.

### Look Up the Service Principal's Object ID

Replace `PASTE_YOUR_APP_ID_FROM_ABOVE` with the `appId` returned in Step 3:

```bash
SP_CLIENT_ID=$(
  az ad sp show \
    --id "PASTE_YOUR_APP_ID_FROM_ABOVE" \
    --query id \
    --output tsv
)
echo "Service Principal Object ID: $SP_CLIENT_ID"
```

### Create a Security Group

```bash
GROUP_ID=$(
  az ad group create \
    --display-name "sg-terraform" \
    --mail-nickname "sg-terraform" \
    --query id \
    --output tsv
)
echo "Security Group ID: $GROUP_ID"
```

### Add the Service Principal to the Group

```bash
az ad group member add \
  --group "$GROUP_ID" \
  --member-id "$SP_CLIENT_ID"
```

### Determine the Assignment Scope

```bash
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
SCOPE="/subscriptions/$SUBSCRIPTION_ID"
echo "Scope: $SCOPE"
```

### Assign the Contributor Role

```bash
MSYS_NO_PATHCONV=1 az role assignment create \
  --assignee-object-id "$GROUP_ID" \
  --assignee-principal-type "Group" \
  --role "Contributor" \
  --scope "$SCOPE"
```

> **Windows (Git Bash / MINGW64) users:** The `MSYS_NO_PATHCONV=1` prefix is required. Without it, Git Bash misinterprets the forward slash in `/subscriptions/...` as a file path and converts it to a Windows directory (e.g., `C:/Program Files/Git/subscriptions/...`), causing an Azure `MissingSubscription` error.
>
> **macOS / Linux users:** Omit the `MSYS_NO_PATHCONV=1` prefix entirely. Standard shells handle forward slashes correctly without it.

---

## 6. Grant Role Assignment Permissions to the Terraform SP (Optional)

> **ATTENTION:** For this Section, you need already created Resource Group with name `myresourcegroup`.

By default, the `Contributor` role allows Terraform to create and manage Azure resources but **cannot create or modify role assignments**. If your Terraform code uses `azurerm_role_assignment` (e.g., to grant a managed identity access to Key Vault, Storage, or AKS), the Service Principal needs additional permission to do so.

The least-privilege approach is to assign the **`User Access Administrator`** role scoped to a specific resource group rather than the entire subscription. This limits what the SP can delegate — it can only manage role assignments within that boundary, not across your whole Azure account.

### Why Not Owner?

The `Owner` role combines `Contributor` + `User Access Administrator` at the subscription level. Granting `Owner` to a Service Principal used in automation is a security anti-pattern — a misconfigured or compromised SP could reassign any role to any principal across your entire subscription.

| Role                        | Manages Resources | Manages Role Assignments | Scope Risk      |
| --------------------------- | ----------------- | ------------------------ | --------------- |
| `Contributor`               | ✅ Yes            | ❌ No                    | Low             |
| `User Access Administrator` | ❌ No             | ✅ Yes                   | Medium (scoped) |
| `Owner`                     | ✅ Yes            | ✅ Yes                   | High — avoid    |

The correct pattern is to combine `Contributor` (subscription-level) with a **scoped** `User Access Administrator` (resource-group level).

---

### Step 1 — Identify the Target Scope

Scope the `User Access Administrator` role to only the resource group where Terraform will manage role assignments. This is typically the resource group containing your application resources, not the backend state resource group.

```bash
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
TARGET_RG="myresourcegroup"

SCOPED_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$TARGET_RG"
echo "Scoped assignment target: $SCOPED_SCOPE"
```

> **Principle of least privilege:** Replace `myresourcegroup` with the specific resource group your Terraform code manages. If you need role assignment capability across multiple resource groups, repeat Step 3 for each one — do not widen the scope to the full subscription.

---

### Step 2 — Retrieve the Security Group ID

If the `GROUP_ID` variable from Section 5 is no longer in your session, retrieve it:

```bash
GROUP_ID=$(
  az ad group show \
    --group "sg-terraform" \
    --query id \
    --output tsv
)
echo "Security Group ID: $GROUP_ID"
```

---

### Step 4 — Add a Condition to Limit Delegatable Roles (Recommended)

Without a condition, the SP can assign _any_ role within the scoped resource group — including privileged ones like `Owner`. Azure RBAC supports **conditions** that restrict which roles the SP is allowed to delegate.

#### Gather the Role GUIDs for the Constraint

We need to capture the unique IDs of the 7 roles you want to allow. Paste this block to fetch and clean those IDs:

```bash

ROLE_1=$(az role definition list --name "Key Vault Secrets Officer" --query "[0].name" --output tsv )
ROLE_2=$(az role definition list --name "Contributor" --query "[0].name" --output tsv)
ROLE_3=$(az role definition list --name "Azure Kubernetes Service RBAC Cluster Admin" --query "[0].name" --output tsv)
ROLE_4=$(az role definition list --name "Key Vault Secrets User" --query "[0].name" --output tsv)
ROLE_5=$(az role definition list --name "Key Vault Administrator" --query "[0].name" --output tsv)
ROLE_6=$(az role definition list --name "AcrPull" --query "[0].name" --output tsv)
ROLE_7=$(az role definition list --name "AcrPush" --query "[0].name" --output tsv)
```

#### Build the Condition String

Next, combine those IDs into the official Azure condition syntax:

```bash
CONDITION="((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {$ROLE_1, $ROLE_2, $ROLE_3, $ROLE_4, $ROLE_5, $ROLE_6, $ROLE_7}))"
```

#### Assingment role with condition

The condition below limits the SP to assigning only the `7` roles as mentioned above:

```bash
MSYS_NO_PATHCONV=1 az role assignment create \
  --assignee-object-id "$GROUP_ID" \
  --assignee-principal-type "Group" \
  --role "User Access Administrator" \
  --scope "$SCOPED_SCOPE" \
  --condition "$CONDITION"
  --condition-version "2.0"
```

> **Windows (Git Bash) users:** `MSYS_NO_PATHCONV=1` is required to prevent path conversion of the `/subscriptions/...` scope string. macOS / Linux users can omit it.

The two GUIDs correspond to:

| GUID                                   | Role                      |
| -------------------------------------- | ------------------------- |
| `b24988ac-6180-42a0-ab88-20f7382dd24c` | Contributor               |
| `b86a8fe4-44ce-4948-aee5-eccb2c155cd7` | Key Vault Secrets Officer |

You can look up any built-in role's ID with:

```bash
az role definition list --name "YOUR_ROLE_NAME" --query "[].name" --output tsv
```

---

### Step 5 — Verify the Role Assignments

Confirm roles are correctly assigned to the security group:

```bash
MSYS_NO_PATHCONV=1 az role assignment list \
  --assignee "$GROUP_ID" \
  --scope "$SCOPED_SCOPE" \
  --query "[].{Role:roleDefinitionName, Assignee:principalName, Condition:condition}" \
  --output table
```

---

### How Terraform Uses This in Practice

Once the SP has the scoped `User Access Administrator` role, it can manage role assignments within that resource group using the `azurerm_role_assignment` resource:

```hcl
# Assign Storage Blob Data Contributor to a managed identity
resource "azurerm_role_assignment" "blob_access" {
  scope                = azurerm_storage_account.example.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.example.principal_id
}
```

Without the scoped `User Access Administrator` role, this block would fail at `terraform apply` with an `AuthorizationFailed` error.

---

## 7. Create a Terraform Project

Create and navigate into a new project directory:

```bash
mkdir terraform-azure-demo
cd terraform-azure-demo
```

Open the project in VS Code:

```bash
code .
```

---

## 8. Configure Remote State in Azure Storage

Storing Terraform state remotely enables team collaboration, prevents state file conflicts, and improves security.

**Benefits of remote state:**

- Centralized, consistent state across all environments
- State locking prevents concurrent modifications
- Versioned, recoverable state history
- Keeps sensitive data off local machines

### Set Variables

```bash
RESOURCE_GROUP="terraform-backend-rg"
LOCATION="centralindia"
STORAGE_ACC_NAME="storage4757"
BLOB_CONTAINER="tfstate"
```

### Create the Backend Resource Group

```bash
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --tags Environment=Production Project=Terraform \
  --output table
```

### Create a Storage Account

> Storage account names must be **globally unique** across all of Azure.

```bash
az storage account create \
  --name $STORAGE_ACC_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Hot \
  --allow-blob-public-access false \
  --tags Environment=Production Project=Terraform \
  --output table
```

### Create a Blob Container

```bash
az storage container create \
  --name $BLOB_CONTAINER \
  --account-name $STORAGE_ACC_NAME
```

---

## 9. Write Terraform Configuration Files

### `providers.tf` — Provider Requirements

```hcl
terraform {
  required_version = ">= 1.5.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

### `backend.tf` — Remote State Configuration

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-backend-rg"
    storage_account_name = "storage4757"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}
```

### `main.tf` — Infrastructure Resources

```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}
```

### `variables.tf` — Input Variables

```hcl
variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "Central India"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "myresourcegroup"
}
```

### `outputs.tf` — Output Values

```hcl
output "resource_group_name" {
  description = "The name of the provisioned resource group"
  value       = azurerm_resource_group.rg.name
}
```

### `terraform.tfvars` — Variable Overrides

```hcl
location            = "centralindia"
resource_group_name = "myresourcegroup"
```

> **Note:** The correct extension is `.tfvars`, not `.tfvars.tf`. Terraform automatically loads `terraform.tfvars` at runtime.

---

## 10. Initialize Terraform

Initialize the working directory and connect to the remote backend:

```bash
terraform init
```

Expected output:

```
Terraform has been successfully initialized!
```

If prompted to migrate existing local state to the remote backend, type `yes`.

---

## 11. Validate Configuration

Format all configuration files to ensure consistent style:

```bash
terraform fmt
```

Validate the configuration for syntax and logical errors:

```bash
terraform validate
```

Expected output:

```
Success! The configuration is valid.
```

---

## 12. Plan and Deploy

### Review the Execution Plan

Preview what Terraform will create, modify, or destroy — without making any actual changes:

```bash
terraform plan
```

Expected output:

```
Plan: 1 to add, 0 to change, 0 to destroy.
```

Review the plan carefully before proceeding.

### Apply the Configuration

Deploy the infrastructure:

```bash
terraform apply
```

Terraform displays the plan again and prompts for confirmation. Type `yes` to proceed.

---

## 13. Verify Remote State

After a successful `apply`, confirm the state file was written to Azure:

1. Open the **Azure Portal**
2. Navigate to your **Storage Account → Containers → `tfstate`**
3. Confirm the file `prod/terraform.tfstate` is present

You can also verify programmatically:

```bash
terraform state list
```

---

## 14. Destroy Resources

To tear down all resources managed by this configuration:

```bash
terraform destroy
```

Terraform displays a destruction plan and prompts for confirmation. Type `yes` to proceed.

> **Warning:** This permanently deletes all resources in the plan. Always review the destroy plan carefully, especially in staging or production environments.

---

## 15. Recommended Project Structure

```
terraform-project/
│
├── environments/
│   ├── dev/
│   │   └── backend-dev.hcl
│   ├── staging/
│   │   └── backend-staging.hcl
│   └── prod/
│       └── backend-prod.hcl
│
├── modules/
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── vm/
│   └── storage/
│
├── backend.tf
├── providers.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── .gitignore
```

### Recommended `.gitignore`

```gitignore
# State files — always store remotely, never commit locally
*.tfstate
*.tfstate.*

# Terraform working directory
.terraform/

# Crash logs
crash.log
crash.*.log

# Variable files may contain sensitive values
*.tfvars
*.tfvars.json

# Provider lock file (optional: include to pin provider versions in VCS)
.terraform.lock.hcl
```

---

## 16. Security Best Practices

### Do

- Use a **Service Principal** with least-privilege RBAC — prefer `Contributor` over `Owner`
- Always store state in a **remote backend** — never commit `.tfstate` files to Git
- Use **separate environments** (dev / staging / prod) with isolated state files
- Store secrets in **Azure Key Vault** rather than environment variables or `.tfvars` files
- Enable **blob versioning** and **soft delete** on the storage account for state recovery
- Rotate Service Principal credentials on a regular schedule

### Avoid

- Hardcoding credentials in `.tf` files or committing them to version control
- Committing `.tfstate` or `.tfvars` files that contain sensitive values
- Using personal accounts for automation or CI/CD pipelines
- Granting the `Owner` role when `Contributor` is sufficient

---

## 17. Common Commands Reference

| Command                                          | Purpose                                                 |
| ------------------------------------------------ | ------------------------------------------------------- |
| `terraform init`                                 | Initialize the working directory and download providers |
| `terraform init -backend-config=backend-dev.hcl` | Initialize with an environment-specific backend config  |
| `terraform fmt`                                  | Format `.tf` files to canonical style                   |
| `terraform validate`                             | Check configuration for syntax and logic errors         |
| `terraform plan`                                 | Preview changes without applying them                   |
| `terraform apply`                                | Apply the configuration and deploy infrastructure       |
| `terraform destroy`                              | Remove all resources managed by the configuration       |
| `terraform state list`                           | List all resources tracked in state                     |
| `terraform output`                               | Display output values from the current state            |

---

## 18. Future Learning Path

Once comfortable with this setup, explore these topics in order:

1. **Terraform Modules** — Build reusable, composable infrastructure components
2. **Variables and Outputs** — Parameterize configurations for flexibility across environments
3. **Azure Networking** — VNets, subnets, NSGs, and VNet peering
4. **AKS Provisioning** — Deploy and manage Kubernetes clusters on Azure
5. **GitHub Actions CI/CD** — Automate `plan` and `apply` on pull requests
6. **OIDC Federation** — Keyless authentication for CI/CD pipelines
7. **Azure Key Vault Integration** — Securely manage and inject secrets into Terraform
8. **Terraform Workspaces** — Manage multiple environments from a single configuration

---

## Official Documentation

| Resource            | Link                                                                                                                       |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Terraform Docs      | [developer.hashicorp.com/terraform/docs](https://developer.hashicorp.com/terraform/docs)                                   |
| AzureRM Provider    | [registry.terraform.io/providers/hashicorp/azurerm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) |
| Azure CLI Reference | [learn.microsoft.com/en-us/cli/azure](https://learn.microsoft.com/en-us/cli/azure/)                                        |

---

## Workflow Summary

```
VS Code + Git Bash
        ↓
   Terraform CLI
        ↓
Azure Service Principal (ARM_* env vars)
        ↓
Azure Storage Backend (remote state)
        ↓
  Azure Infrastructure
```
