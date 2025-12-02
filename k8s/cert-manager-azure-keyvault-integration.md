# Azure Key Vault Integration with cert-manager

This guide shows how to integrate Azure Key Vault for certificate storage while maintaining platform independence for certificate issuance.

## Architecture

```
ACME CA (Let's Encrypt/ZeroSSL/SSL.com) ← Platform-independent issuance
         ↓
cert-manager ← Issues certificates
         ↓
Kubernetes Secrets ← Primary storage (standard)
         ↓
Azure CSI Secret Store Driver ← Syncs to Key Vault
         ↓
Azure Key Vault ← Azure-integrated storage
```

## Benefits

✅ **Best of Both Worlds**:
- Platform-independent certificate issuance (ACME)
- Azure-integrated certificate storage (Key Vault)
- Centralized management in Azure
- Can export certificates anytime (still portable)

✅ **Maintains Portability**:
- Certificates issued via ACME (platform-independent)
- Certificates can be exported from Key Vault
- Can migrate away from Azure Key Vault anytime
- Low lock-in level

---

## Option 1: Azure CSI Secret Store Driver (Recommended)

Sync certificates from Kubernetes secrets to Azure Key Vault automatically.

### Prerequisites

1. Azure Key Vault created
2. Service Principal with Key Vault access
3. Azure CSI Secret Store Driver installed

### Installation

```bash
# Install Azure Key Vault Provider for Secrets Store CSI Driver

# Or use Helm
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system
```

### Configuration

1. **Create SecretProviderClass**:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-keyvault-certificates
  namespace: cloudtolocalllm
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "<USER_ASSIGNED_IDENTITY_ID>"
    keyvaultName: "cloudtolocalllm-kv"
    tenantId: "<AZURE_TENANT_ID>"
    objects: |
      array:
        - |
          objectName: cloudtolocalllm-wildcard-tls
          objectType: secret
          objectVersion: ""
          objectEncoding: base64
    secretObjects:
      - secretName: cloudtolocalllm-wildcard-tls
        type: kubernetes.io/tls
        data:
          - objectName: cloudtolocalllm-wildcard-tls
            key: tls.crt
          - objectName: cloudtolocalllm-wildcard-tls  
            key: tls.key
```

2. **Use in Deployment/Pod**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-sync
spec:
  template:
    spec:
      containers:
      - name: sync
        image: alpine
        volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets-store"
          readOnly: true
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "azure-keyvault-certificates"
```

---

## Option 2: Manual Sync Script

Sync certificates from Kubernetes secrets to Azure Key Vault periodically.

### Setup Script

```bash
#!/bin/bash
# sync-cert-to-keyvault.sh

NAMESPACE="cloudtolocalllm"
SECRET_NAME="cloudtolocalllm-wildcard-tls"
KEY_VAULT_NAME="cloudtolocalllm-kv"
CERT_NAME="cloudtolocalllm-wildcard"

# Get certificate from Kubernetes secret
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/tls.crt
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/tls.key

# Create PFX file
openssl pkcs12 -export -out /tmp/cert.pfx -inkey /tmp/tls.key -in /tmp/tls.crt -passout pass:

# Import to Azure Key Vault
az keyvault certificate import \
  --vault-name "$KEY_VAULT_NAME" \
  --name "$CERT_NAME" \
  --file /tmp/cert.pfx \
  --password ""

echo "✅ Certificate synced to Azure Key Vault"
```

### Schedule with CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: sync-cert-to-keyvault
  namespace: cloudtolocalllm
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: sync
            image: mcr.microsoft.com/azure-cli:latest
            command:
            - /bin/bash
            - -c
            - |
              # Sync script here
          restartPolicy: OnFailure
```

---

## Option 3: Hybrid Approach (Issued by Azure, Stored in Key Vault)

Use Azure App Service Certificates for issuance (Azure-managed) with Key Vault storage.

### Limitations

⚠️ **Higher Lock-in**:
- Requires Azure App Service
- Certificates are Azure-specific
- Less portable than ACME certificates

### Setup

1. Create App Service Certificate in Azure Portal
2. Certificate automatically stored in Key Vault
3. Import certificate to Kubernetes using CSI driver

### Use Case

- Primarily Azure-only deployments
- Need Azure-managed certificate lifecycle
- Don't require portability

---

## Recommended: Option 1 (CSI Driver)

**Best Practice**: Use cert-manager with ACME + Azure CSI Secret Store Driver

**Benefits**:
- ✅ Platform-independent certificate issuance (ACME)
- ✅ Azure-integrated storage (Key Vault)
- ✅ Automatic sync
- ✅ Certificates exportable from Key Vault
- ✅ Low lock-in level

**Setup Steps**:

1. **Create Azure Key Vault** (if not exists):
```bash
az keyvault create \
  --name cloudtolocalllm-kv \
  --resource-group cloudtolocalllm-rg \
  --location eastus
```

2. **Grant access to Key Vault**:
```bash
# Get service principal or managed identity
az keyvault set-policy \
  --name cloudtolocalllm-kv \
  --object-id <SERVICE_PRINCIPAL_ID> \
  --secret-permissions get list set
```

3. **Install CSI Driver**:
```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system

# Install Azure provider
helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/main/charts
helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --namespace kube-system
```

4. **Configure SecretProviderClass** (see Option 1 above)

5. **cert-manager continues to issue certificates** (no changes needed)

6. **Certificates automatically sync to Key Vault** via CSI driver

---

## Export from Key Vault

Certificates in Key Vault can be exported anytime:

```bash
# Export certificate
az keyvault certificate download \
  --vault-name cloudtolocalllm-kv \
  --name cloudtolocalllm-wildcard \
  --file cert.pfx

# Or export as PEM
az keyvault secret show \
  --vault-name cloudtolocalllm-kv \
  --name cloudtolocalllm-wildcard \
  --query value -o tsv | base64 -d > cert.pem
```

**Portability**: ✅ Certificates are standard X.509 format, fully exportable

---

## Comparison

| Approach | Issuance | Storage | Lock-in | Portability |
|----------|----------|---------|---------|-------------|
| **Option 1 (CSI)** | ACME | Key Vault | Low | ✅ High |
| **Option 2 (Sync)** | ACME | Key Vault | Low | ✅ High |
| **Option 3 (App Service)** | Azure | Key Vault | High | ⚠️ Low |
| **Current (K8s Secrets)** | ACME | K8s Secrets | None | ✅ High |

---

## Recommendation

**Use Option 1 (CSI Driver)** for Azure Key Vault integration while maintaining platform independence.

You get:
- ✅ Azure-integrated certificate management
- ✅ Platform-independent certificate issuance
- ✅ Automatic sync to Key Vault
- ✅ Can export certificates anytime
- ✅ Low vendor lock-in

