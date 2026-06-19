# AKS Key Vault Integration via Terraform

This repository contains the infrastructure and Kubernetes configurations required to securely bridge \***\*Azure Key Vault\*\*** secrets directly into an \***\*Azure Kubernetes Service (AKS)\*\*** cluster. This setup leverages \***\*User-Assigned Managed Identities (UAMI)\*\*** and \***\*Federated Identity Credentials\*\*** to eliminate the need for hardcoded passwords or connection strings in your application.

---

## 📋 Prerequisites

Before deploying, ensure you have the following CLI tools installed locally and authenticated:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az login`)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (`>= 1.5.0`)
- [Kubernetes CLI](https://kubernetes.io/docs/tasks/tools/) (`kubectl`)
- Terraform Service Principal create on Azure EntraID with **Contributor** RBAC Role assigned.
- Storage Account for storing terraform state files remotely.

---

## **🚀 Step 1: Deploy the Core Infrastructure**

1. Initialize and apply the Terraform configuration from your root directory one by one:

   ```bash
   # Execute these commands one by one util there is no errors
   terraform init
   terraform fmt
   terraform validate
   terraform plan | grep "will be created"
   terraform apply --auto-approve

   ```

2. Once the build finishes, capture the output values (key_vault_name, managed_identity_client_id, and your Azure tenant_id).
3. Authenticate your local kubectl context to your new cluster using the dynamically generated connection output:

```Bash
# Paste your custom output connection command here:
az aks get-credentials --resource-group <your-rg> --name <your-aks-cluster> --overwrite-existing
```

## **🛠️ Step 2: Update Kubernetes Manifests**

Navigate to your ./k8s/ folder and update the placeholder parameters inside your YAML definitions with the Terraform output tokens.

### **1. Secret Provider Class (./k8s/secret-provider-class.yaml)**

Ensure the following metadata blocks match your cloud environment variables:

```bash
YAML
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
 name: azure-kvname-wi
 namespace: default
spec:
 provider: azure
 parameters:
 usePodIdentity: "false"
 useVMManagedIdentity: "false"
 clientID: "YOUR_MANAGED_IDENTITY_CLIENT_ID" # 👈 Replace this
 keyvaultName: "YOUR_KEY_VAULT_NAME" # 👈 Replace this
 tenantId: "YOUR_AZURE_TENANT_ID" # 👈 Replace this
 objects: |
 array:
 - |
 objectName: db-password # 👈 Must match your Key Vault secret key
 objectType: secret
```

### **2. Service Account (./k8s/service-account.yaml)**

Ensure the annotations link directly back to your User-Assigned Managed Identity Client ID:

```bash
YAML
apiVersion: v1
kind: ServiceAccount
metadata:
 name: workload-identity-sa
 namespace: default
 annotations:
 azure.workload.identity/client-id: "YOUR_MANAGED_IDENTITY_CLIENT_ID" # 👈 Replace this
```

## **🚢 Step 3: Deploy to Kubernetes**

Execute the following commands to apply your manifests sequentially into the cluster:

#### 1. Apply the Secret Provider Class to map Azure KV to the CSI driver

```Bash

kubectl apply -f ./k8s/secret-provider-class.yaml
```

#### 2. Apply the Service Account backed by Entra ID workload identity federation

```Bash
kubectl apply -f ./k8s/service-account.yaml
```

#### 3. Spin up the validation/application Pod

```Bash
kubectl apply -f ./k8s/test-pod.yaml
```

## **🛡️ Step 4: Verification & Secret Validation**

Once the validation pod status changes to Running, execute these runtime checks to ensure secrets are mounting dynamically out of the cloud and into your application memory container.

### **1. Confirm Secret Volume Mount**

Verify that the Secret Store CSI driver successfully created the file mapping block inside the target container path:

```Bash
kubectl exec busybox-secrets-store-inline-wi -- ls /mnt/secrets-store/
```

_Expected Output:_ db-password

### **2. Read Mounted Secret Payload**

Read the plaintext execution payload from inside the container to confirm absolute zero-trust verification:

```Bash
kubectl exec busybox-secrets-store-inline-wi -- cat /mnt/secrets-store/db-password
```

_Expected Output:_ SuperSecret123 _(or your configured custom secret string)_

## **🧹 Cleanup**

To prevent incurring continuous cloud computing costs on your subscription, completely destroy all assets when you are done testing:

#### 1. Delete Kubernetes resources

```Bash

kubectl delete -f ./k8s/
```

#### 2. Teardown cloud resources via Terraform

```bash
terraform destroy -auto-approve
```

---

