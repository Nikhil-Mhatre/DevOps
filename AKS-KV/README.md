# **AKS + Azure Key Vault Integration Guide**

A step-by-step guide to configuring an Azure Kubernetes Service (AKS) cluster integrated with Azure Key Vault using **Workload Identity** and the **Secrets Store CSI Driver**.

## **Prerequisites**

- **Azure CLI** installed and authenticated (az login)
- **kubectl** installed and configured
- **Subscription Permissions**: Sufficient IAM privileges (e.g., Owner or Contributor) on your Azure subscription

## **1\. Subscription & Environment Setup**

### **Define Environment Variables**

Set these variables at the beginning of your session to ensure consistency across all commands.

```Bash
# -----------------------------------------------------------------------------
# Core Infrastructure Configuration
# -----------------------------------------------------------------------------
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export LOCATION="eastus"
export RESOURCE_GROUP="keyvault-demo-rg"
export CLUSTER_NAME="keyvault-demo-cluster"
export KEYVAULT_NAME="keyvault-demo-kv"
export UAMI="keyvault-demo-mi"

# -----------------------------------------------------------------------------
# Windows / Git Bash Path Fix (Crucial for Windows Users)
# Prevents Git Bash from erroneously converting Azure resource IDs into local paths
# -----------------------------------------------------------------------------
export MSYS_NO_PATHCONV=1
```

### **Set the Active Subscription**

```Bash
# Verify available subscriptions
az account list --output table

# Set target subscription using the ID populated from your environment variables
az account set --subscription "$SUBSCRIPTION_ID"

# Confirm the active subscription context
az account show --output table
```

---

## **2\. Resource Group**

```Bash
# Create the resource group containing all resources
az group create \
 --name "$RESOURCE_GROUP" \
 --location "$LOCATION"

# Verify resource group creation
az group list --output table
```

---

## **3\. AKS Cluster Configuration**

### **Create the Cluster**

This provisions an AKS cluster with the **OIDC Issuer** and **Workload Identity** features enabled, alongside the **Azure Key Vault Secrets Provider** add-on.

```Bash
az aks create \
 --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
 --node-count 1 \
 --node-vm-size Standard_A2_v2 \
 --enable-addons azure-keyvault-secrets-provider \ # Installs Secrets Store CSI Driver + Azure Provider
 --enable-oidc-issuer \ # Required for Workload Identity federation
 --enable-workload-identity \ # Enables mutating admission webhook for pods
 --ssh-access disabled \
 --generate-ssh-keys

# Cache the cluster credentials locally in \~/.kube/config
az aks get-credentials \
 --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP"
```

### **Verify CSI Driver Pod status**

Ensure that both the core CSI driver daemonset and the Azure-specific provider pods are fully operational across your nodes:

```Bash
kubectl get pods -n kube-system \
 -l 'app in (secrets-store-csi-driver,secrets-store-provider-azure)' \
 -o wide
```

---

## **4\. Azure Key Vault Provisioning**

```Bash
# Create the Key Vault with Azure RBAC enabled (instead of legacy Access Policies)
az keyvault create \
 --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
 --location "$LOCATION" \
 --enable-rbac-authorization true \
 --retention-days 7

# Dynamically extract and save the Key Vault Resource ID for future role assignments
export KEYVAULT_SCOPE=$(az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
```

---

## **5\. Role Assignments & Secret Creation**

### **Grant Administrator Access to Current User**

This step grants your logged-in Azure CLI user the rights to create and manage secrets within the vault.

```Bash
# Assign Key Vault Secrets Officer role to yourself
az role assignment create \
 --role "Key Vault Secrets Officer" \
 --assignee $(az ad signed-in-user show --query id -o tsv) \
  --scope "$KEYVAULT_SCOPE"
```

**Git Bash Note:** If you encounter path resolution errors despite setting MSYS_NO_PATHCONV=1, you can manually escape the scope flag by adding an extra leading slash: --scope "/$KEYVAULT_SCOPE".

### **Create a Test Secret**

```Bash
az keyvault secret set \
 --vault-name "$KEYVAULT_NAME" \
 --name "db-password" \
 --value "SuperSecret123"
```

---

## **6\. Managed Identity & Federation Setup**

### **Create User-Assigned Managed Identity (UAMI)**

This identity will be assumed by your Kubernetes applications to authenticate against Azure resources.

```Bash

# Create the identity

az identity create --name "$UAMI" --resource-group "$RESOURCE_GROUP"

# Fetch and store the Identity's Client ID

export USER_ASSIGNED_CLIENT_ID=$(az identity show --name "$UAMI" --resource-group "$RESOURCE_GROUP" --query clientId -o tsv)

# Fetch the AKS Cluster's OIDC Issuer URL

export AKS_OIDC_ISSUER=$(az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Fetch the Identity Tenant ID

export IDENTITY_TENANT=$(az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query identity.tenantId -o tsv)
```

### **Authorize the Managed Identity**

Grant the identity reading permissions strictly for secrets.

```Bash

# Assign Key Vault Secrets User role to the Managed Identity

az role assignment create \
 --role "Key Vault Secrets User" \
 --assignee "$USER_ASSIGNED_CLIENT_ID" \
  --scope "$KEYVAULT_SCOPE"

```

**Security Note:** The Key Vault Secrets User role restricts access strictly to Secrets. Attempts to fetch Keys or Certificates using this identity will be explicitly denied.

## **7\. Kubernetes Configuration**

### **Create Service Account**

The service account must be annotated with the Managed Identity’s Client ID. The Workload Identity webhook uses this annotation to inject the proper token into matching pods.

```YAML
export SERVICE_ACCOUNT_NAME="workload-identity-sa"
export SERVICE_ACCOUNT_NAMESPACE="default"

cat \<\<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
 name: ${SERVICE_ACCOUNT_NAME}
 namespace: ${SERVICE_ACCOUNT_NAMESPACE}
 annotations:

# Links the K8s service account to your specific Azure Managed Identity

azure.workload.identity/client-id: ${USER_ASSIGNED_CLIENT_ID}
EOF
```

### **Establish Federated Identity Credential**

This creates a trust relationship between Azure AD (Entra ID) and your AKS cluster's OIDC issuer for this specific service account.

```Bash
az identity federated-credential create \
 --name "aksfederatedidentity" \
 --identity-name "$UAMI" \
  --resource-group "$RESOURCE_GROUP" \
 --issuer "${AKS_OIDC_ISSUER}" \
  --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}"
```

### **Create the SecretProviderClass**

This resource instructs the Secrets Store CSI Driver _which_ secrets to pull from the specific Key Vault instance.

```YAML
cat \<\<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
 name: azure-kvname-wi
 namespace: ${SERVICE_ACCOUNT_NAMESPACE}
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"                   # Set to false when utilizing Workload Identity
    clientID: "${USER_ASSIGNED_CLIENT_ID}" # Managed Identity Client ID
 keyvaultName: "${KEYVAULT_NAME}"
    tenantId: "${IDENTITY_TENANT}"
 objects: |
 array:

- |
   objectName: db-password # Secret identifier in Azure Key Vault
   objectType: secret # Options: secret, key, or cert
   objectVersion: "" # Empty string defaults to tracking the latest version
  EOF
```

### **Deploy Test Pod**

Deploy a pod that references your configured Service Account and mounts the Key Vault secret volume via the CSI driver.

```YAML
cat \<\<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
 name: busybox-secrets-store-inline-wi
 namespace: ${SERVICE_ACCOUNT_NAMESPACE}
 labels:

# Explicitly triggers the Workload Identity sidecar/token injection mutation

azure.workload.identity/use: "true"
spec:
 serviceAccountName: ${SERVICE_ACCOUNT_NAME}
 containers:

- name: busybox
  image: registry.k8s.io/e2e-test-images/busybox:1.29-4
  command:
- "/bin/sleep"
- "10000"
  volumeMounts:
- name: secrets-store01-inline
  mountPath: "/mnt/secrets-store"
  readOnly: true
  volumes:
- name: secrets-store01-inline
   csi:
   driver: secrets-store.csi.k8s.io
   readOnly: true
   volumeAttributes:
   secretProviderClass: "azure-kvname-wi" # References the SecretProviderClass created above
  EOF
```

## **8\. Verification**

**Note:** The double slashes (//) in the paths below are standard workarounds to bypass local path mutations inside Windows terminal emulators (like Git Bash).

### **Confirm Secret Volume Mount**

```Bash

# List all secrets mounted dynamically into the container path

kubectl exec busybox-secrets-store-inline-wi -- ls //mnt/secrets-store/
```

_Expected Output:_ A file named db-password should appear in the directory layout.

### **Read Secret Payload**

```Bash

# Print out the value of the mounted secret file

kubectl exec busybox-secrets-store-inline-wi -- cat //mnt/secrets-store/db-password
```

_Expected Output:_ SuperSecret123
