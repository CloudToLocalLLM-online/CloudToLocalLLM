# Azure Key Vault Certificate Issuer - Azure-Native Certificate Management

This setup uses **Azure Key Vault Certificate Issuers** to request certificates directly from Azure, without using Let's Encrypt or other ACME providers.

## Azure-Native Certificate Solution

✅ **Fully Azure-Integrated**: Uses Azure Key Vault certificate issuers  
✅ **Enterprise CAs**: DigiCert, GlobalSign, Sectigo, Entrust  
✅ **Automatic Renewal**: Azure Key Vault handles renewal  
✅ **Kubernetes Integration**: Certificates synced to Kubernetes  

## Supported Certificate Authorities

Azure Key Vault supports certificate issuers from these CAs:

1. **DigiCert** - Enterprise-grade certificates
2. **GlobalSign** - Trusted global CA
3. **Sectigo** (formerly Comodo) - Popular commercial CA
4. **Entrust** - Enterprise security solutions

## Prerequisites

1. **Azure Key Vault**: `cloudtolocalllm-kv` (already created ✅)
2. **CA Account**: Account with one of the supported CAs (DigiCert, GlobalSign, Sectigo, or Entrust)
3. **CA API Credentials**: Organization ID and API key from your CA
4. **RBAC Permissions**: Service principal needs Key Vault access (already granted ✅)

⚠️ **Note**: Azure does NOT provide free certificates. You must purchase certificate services from one of the supported CAs.

## Setup Steps

### Step 1: Get CA Account and Credentials

Sign up with one of the supported CAs:
- **DigiCert**: https://www.digicert.com/
- **GlobalSign**: https://www.globalsign.com/
- **Sectigo**: https://www.sectigo.com/
- **Entrust**: https://www.entrust.com/

Get your:
- Organization ID
- API Key
- Certificate product/plan ID (if required)

### Step 2: Create Certificate Issuer in Key Vault

#### Option A: Using Script (Interactive)

```powershell
.\scripts\setup-azure-keyvault-certificate-issuer.ps1
```

#### Option B: Azure CLI

```bash
az keyvault certificate issuer create \
  --vault-name cloudtolocalllm-kv \
  --issuer-name digicert \
  --provider-name DigiCert \
  --account-id <ORG_ID> \
  --api-key <API_KEY>
```

#### Option C: Azure Portal

1. Go to Key Vault: `cloudtolocalllm-kv`
2. **Certificates** → **Certificate issuers** → **Add**
3. Select provider: DigiCert, GlobalSign, Sectigo, or Entrust
4. Enter credentials (Organization ID, API Key)
5. Save

### Step 3: Request Certificate

#### Option A: Using Script

```powershell
.\scripts\request-azure-keyvault-certificate.ps1
```

#### Option B: Azure CLI

Create certificate policy first:

```bash
# Create policy file
cat > cert-policy.json << 'EOF'
{
  "keyProperties": {
    "exportable": true,
    "keyType": "RSA",
    "keySize": 2048,
    "reuseKey": false
  },
  "secretProperties": {
    "contentType": "application/x-pkcs12"
  },
  "x509CertificateProperties": {
    "subject": "CN=cloudtolocalllm.online",
    "subjectAlternativeNames": {
      "dnsNames": ["cloudtolocalllm.online", "*.cloudtolocalllm.online"]
    },
    "validityInMonths": 12,
    "keyUsage": ["digitalSignature", "keyEncipherment"],
    "enhancedKeyUsage": ["1.3.6.1.5.5.7.3.1", "1.3.6.1.5.5.7.3.2"]
  },
  "issuerParameters": {
    "name": "digicert",
    "certificateType": "WildCard"
  }
}
EOF

# Create certificate policy
az keyvault certificate policy create \
  --vault-name cloudtolocalllm-kv \
  --name cloudtolocalllm-wildcard \
  --policy @cert-policy.json

# Request certificate
az keyvault certificate create \
  --vault-name cloudtolocalllm-kv \
  --name cloudtolocalllm-wildcard \
  --policy @cert-policy.json
```

#### Option C: Azure Portal

1. Key Vault: `cloudtolocalllm-kv` → **Certificates** → **Generate/Import**
2. **Method**: Generate
3. Select certificate issuer
4. Configure policy (subject, SANs, validity)
5. Request certificate

### Step 4: Monitor Certificate Status

```bash
# Check certificate status
az keyvault certificate show \
  --vault-name cloudtolocalllm-kv \
  --name cloudtolocalllm-wildcard \
  --query "{Status:attributes.enabled, Expires:attributes.expires, State:attributes.recoveryLevel}" \
  -o table

# Watch for certificate completion
az keyvault certificate pending show \
  --vault-name cloudtolocalllm-kv \
  --name cloudtolocalllm-wildcard
```

### Step 5: Sync Certificate to Kubernetes

Once certificate is issued in Key Vault, sync to Kubernetes:

```bash
# Manual sync
kubectl create job --from=cronjob/sync-cert-to-keyvault sync-now -n cloudtolocalllm

# Or wait for automatic sync (every 6 hours)
```

### Step 6: Update Kubernetes Secret

The sync job will create/update the Kubernetes secret. If you need to manually sync:

```bash
# Export certificate from Key Vault
az keyvault certificate download \
  --vault-name cloudtolocalllm-kv \
  --name cloudtolocalllm-wildcard \
  --file cert.pfx

# Convert to PEM
openssl pkcs12 -in cert.pfx -out cert.pem -nodes

# Create Kubernetes secret
kubectl create secret tls cloudtolocalllm-wildcard-tls \
  --cert=cert.pem \
  --key=cert.pem \
  -n cloudtolocalllm \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Certificate Lifecycle

### Automatic Renewal

Azure Key Vault automatically renews certificates when configured:
- Certificates are renewed before expiry
- Renewal happens automatically in Key Vault
- Sync job updates Kubernetes secrets

### Manual Renewal

```bash
# Trigger renewal
az keyvault certificate renew \
  --vault-name cloudtolocalllm-kv \
  --name cloudtolocalllm-wildcard
```

## Cost Considerations

⚠️ **Azure Key Vault Certificate Issuers require PAID certificates**:
- **No free option**: Unlike Let's Encrypt, these are commercial services
- **Pricing varies**: Depends on CA and certificate type
- **Wildcard certificates**: Typically cost more than single-domain
- **Annual renewal**: Certificates need to be renewed annually (unless you have longer validity)

Typical costs:
- DigiCert: ~$200-500/year for wildcard SSL
- GlobalSign: ~$200-400/year for wildcard SSL
- Sectigo: ~$100-300/year for wildcard SSL
- Entrust: ~$200-500/year for wildcard SSL

## Advantages vs ACME

✅ **Azure-Native**: Fully integrated with Azure services  
✅ **Enterprise Support**: Professional CA support and warranties  
✅ **Longer Validity**: Often 1-2 years (vs 90 days for Let's Encrypt)  
✅ **Automatic Renewal**: Azure Key Vault handles renewal  
✅ **Wildcard Support**: Full wildcard certificate support  

## Disadvantages vs ACME

❌ **Cost**: Requires paid certificate (vs free Let's Encrypt)  
❌ **More Setup**: Requires CA account and API credentials  
❌ **CA Dependency**: Tied to specific CA vendor  
⚠️ **Platform Dependency**: More Azure-specific (though certificates are still portable)  

## Architecture

```
Azure Key Vault Certificate Issuer (DigiCert/GlobalSign/Sectigo/Entrust)
         ↓
Azure Key Vault ← Issues and stores certificate
         ↓
CronJob sync ← Syncs every 6 hours
         ↓
Kubernetes Secret ← Used by nginx-ingress
         ↓
TLS Termination
```

## Troubleshooting

### Certificate Issuance Fails

```bash
# Check issuer status
az keyvault certificate issuer show \
  --vault-name cloudtolocalllm-kv \
  --issuer-name digicert

# Check pending certificate
az keyvault certificate pending show \
  --vault-name cloudtolocalllm-kv \
  --name cloudtolocalllm-wildcard

# View certificate operation status
az keyvault certificate operation show \
  --vault-name cloudtolocalllm-kv \
  --name cloudtolocalllm-wildcard
```

### Sync to Kubernetes Fails

- Check RBAC permissions: Service principal needs Key Vault Secrets Officer role
- Check certificate status: Certificate must be in "enabled" state
- Check sync job logs: `kubectl logs -n cloudtolocalllm -l app=cert-sync`

---

## Quick Start (DigiCert Example)

1. **Get DigiCert account**: Sign up at https://www.digicert.com/
2. **Get API credentials**: Organization ID and API key from DigiCert portal
3. **Create issuer**:
   ```bash
   az keyvault certificate issuer create \
     --vault-name cloudtolocalllm-kv \
     --issuer-name digicert \
     --provider-name DigiCert \
     --account-id <DIGICERT_ORG_ID> \
     --api-key <DIGICERT_API_KEY>
   ```
4. **Request certificate**: Use script or Azure CLI (see Step 3 above)
5. **Wait for issuance**: Check status periodically
6. **Sync to Kubernetes**: Automatic or manual sync

---

## Summary

This approach uses **100% Azure-native services**:
- ✅ Azure Key Vault for certificate storage
- ✅ Azure Key Vault Certificate Issuers for certificate issuance
- ✅ Enterprise CAs (DigiCert, GlobalSign, Sectigo, Entrust)
- ✅ No Let's Encrypt or ACME dependencies
- ✅ Automatic renewal through Azure

**Trade-off**: Requires paid certificate service, but provides enterprise-grade Azure-native certificate management.

