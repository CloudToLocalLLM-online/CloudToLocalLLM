# Azure SSL Certificate Configuration

This document describes the Azure-native SSL certificate options for CloudToLocalLLM on AKS.

## Current Configuration: cert-manager with Azure DNS-01 Challenge

The current setup uses **cert-manager with Azure DNS-01 challenge**, which:
- ✅ Uses **Azure DNS** for domain validation (Azure-native)
- ✅ Automatically provisions and renews certificates
- ⚠️ Still uses Let's Encrypt as the Certificate Authority (CA)
- ✅ Certificates are stored in Kubernetes secrets

### Why Azure DNS-01 instead of fully managed?

Fully Azure-managed SSL certificates (issued by Azure) require:
- **Azure Application Gateway** or **Azure Front Door** for SSL termination
- Cannot be directly used with nginx-ingress controller

Since we're using **nginx-ingress**, cert-manager with Azure DNS-01 is the most Azure-native approach available.

---

## Fully Azure-Managed Certificate Options

If you want **100% Azure-managed certificates** (no Let's Encrypt), you have these options:

### Option 1: Azure Application Gateway with Managed Certificates

**Fully Azure-managed certificates** require switching from nginx-ingress to **Azure Application Gateway**.

```bash
# Deploy Application Gateway Ingress Controller (AGIC)
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update
helm install ingress-azure application-gateway-kubernetes-ingress/ingress-azure \
  --set appgw.subscriptionId=<SUBSCRIPTION_ID> \
  --set appgw.resourceGroup=cloudtolocalllm-rg \
  --set appgw.name=<APP_GATEWAY_NAME> \
  --set appgw.shared=false
```

**Benefits:**
- ✅ Fully Azure-managed certificates
- ✅ Automatic certificate provisioning and renewal
- ✅ No external CA dependencies
- ✅ Integrated with Azure Key Vault

**Trade-offs:**
- ❌ Requires Application Gateway (additional cost)
- ❌ Different ingress controller (would need to migrate from nginx-ingress)

### Option 2: Azure Key Vault with Imported Certificates

Import your own certificates into Azure Key Vault and mount them using CSI driver:

```bash
# Install Azure Key Vault CSI driver
helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
helm install csi-secrets-store-provider-azure csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
  --namespace kube-system

# Create SecretProviderClass to mount certificates from Key Vault
kubectl apply -f k8s/azure-keyvault-secret-provider.yaml
```

**Benefits:**
- ✅ Uses Azure Key Vault for certificate storage
- ✅ Works with existing nginx-ingress
- ✅ Full control over certificate source

**Trade-offs:**
- ❌ Manual certificate import/rotation
- ❌ Need to obtain certificates from a CA (DigiCert, GlobalSign, etc.)

---

## Current Setup Details

### Prerequisites

1. **Azure DNS Zone** created:
   ```bash
   az network dns zone create \
     --resource-group cloudtolocalllm-rg \
     --name cloudtolocalllm.online
   ```

2. **Service Principal** with **DNS Zone Contributor** role:
   ```bash
   # Get the DNS zone resource ID
   ZONE_ID=$(az network dns zone show \
     --resource-group cloudtolocalllm-rg \
     --name cloudtolocalllm.online \
     --query id -o tsv)
   
   # Assign DNS Zone Contributor role
   az role assignment create \
     --role "DNS Zone Contributor" \
     --assignee <SERVICE_PRINCIPAL_ID> \
     --scope $ZONE_ID
   ```

3. **GitHub Secrets** configured:
   - `AZURE_CLIENT_ID` - Service Principal Client ID
   - `AZURE_CLIENT_SECRET` - Service Principal Client Secret
   - `AZURE_SUBSCRIPTION_ID` - Azure Subscription ID
   - `AZURE_TENANT_ID` - Azure Tenant ID

### How It Works

1. **cert-manager** requests a certificate from Let's Encrypt
2. **Let's Encrypt** requires domain validation
3. **cert-manager** uses **Azure DNS-01 challenge**:
   - Creates TXT record in Azure DNS zone
   - Validates domain ownership via Azure DNS
   - Removes TXT record after validation
4. **Let's Encrypt** issues the certificate
5. **cert-manager** stores certificate in Kubernetes secret
6. **nginx-ingress** uses the secret for TLS termination

### Certificate Lifecycle

- **Provisioning**: Automatic on first deployment
- **Renewal**: Automatic (cert-manager renews ~30 days before expiry)
- **Validation**: Uses Azure DNS zone (no external dependencies)

---

## Switching to Fully Azure-Managed Certificates

To switch to **Azure Application Gateway with managed certificates**, see `docs/AZURE_APPLICATION_GATEWAY.md` (if created).

Otherwise, the current setup with **Azure DNS-01** is the most practical Azure-native solution for nginx-ingress.

