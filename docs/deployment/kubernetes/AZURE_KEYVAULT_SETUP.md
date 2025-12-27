# Azure Key Vault Certificate Sync Setup

This document provides instructions for completing the Azure Key Vault integration.

## ✅ Completed Setup

1. ✅ Azure Key Vault created: `cloudtolocalllm-kv`
2. ✅ CronJob configured to sync certificates every 6 hours
3. ✅ Service account and RBAC configured
4. ✅ Secrets created with Azure credentials
5. ⚠️ RBAC permissions need to be granted manually

---

## ⚠️ Required: Grant RBAC Permissions

The service principal needs **Key Vault Secrets Officer** role to sync certificates.

### Option 1: Azure CLI (Recommended)

Run this command with an account that has "Owner" or "User Access Administrator" role:

```bash
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee 9a038fed-3241-4bf9-9bb5-bc489e8a4b27 \
  --scope "/subscriptions/ba58d2e9-b162-470d-ac9d-365fb31540de/resourceGroups/cloudtolocalllm-rg/providers/Microsoft.KeyVault/vaults/cloudtolocalllm-kv"
```

### Option 2: Azure Portal

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Key Vault**: `cloudtolocalllm-kv`
3. Click **Access control (IAM)** in left menu
4. Click **+ Add** → **Add role assignment**
5. Select role: **Key Vault Secrets Officer**
6. Assign access to: **Service Principal**
7. Search for: `9a038fed-3241-4bf9-9bb5-bc489e8a4b27`
8. Click **Save**

---

## How It Works

### Certificate Flow

```
1. cert-manager issues certificate via ACME (Let's Encrypt/ZeroSSL/etc.)
   ↓
2. Certificate stored in Kubernetes secret: cloudtolocalllm-wildcard-tls
   ↓
3. CronJob runs every 6 hours (sync-cert-to-keyvault)
   ↓
4. Sync job exports certificate from Kubernetes secret
   ↓
5. Certificate imported to Azure Key Vault: cloudtolocalllm-wildcard
   ↓
6. Certificate available in Azure Key Vault for Azure services
```

### Schedule

- **Automatic sync**: Every 6 hours (via CronJob)
- **Manual sync**: Create job from cronjob anytime:
  ```bash
  kubectl create job --from=cronjob/sync-cert-to-keyvault manual-sync-$(date +%Y%m%d%H%M%S) -n cloudtolocalllm
  ```

---

## Verify Setup

### Check CronJob

```bash
kubectl get cronjob sync-cert-to-keyvault -n cloudtolocalllm
```

### Check Sync Job Status

```bash
kubectl get jobs -n cloudtolocalllm -l app=cert-sync
```

### View Sync Logs

```bash
kubectl logs -n cloudtolocalllm -l app=cert-sync --tail=50
```

### Check Key Vault

```bash
# List secrets in Key Vault
az keyvault secret list --vault-name cloudtolocalllm-kv -o table

# Get certificate from Key Vault
az keyvault secret show --vault-name cloudtolocalllm-kv --name cloudtolocalllm-wildcard -o json
```

---

## Current Status

- ✅ Azure Key Vault: `cloudtolocalllm-kv` (created)
- ✅ CronJob: `sync-cert-to-keyvault` (configured, runs every 6 hours)
- ✅ Service Account: `cert-sync` (created with RBAC)
- ✅ Secrets: `azure-keyvault-sync` (contains Azure credentials)
- ⚠️ RBAC: **Needs manual grant** (see instructions above)
- ⏸️ Certificate: Waiting for Let's Encrypt rate limit (2025-11-19 09:11:10 UTC)

---

## What Happens Next

1. **Once RBAC is granted**: The sync job will have permissions to write to Key Vault
2. **Once certificate is issued**: The next sync job (within 6 hours) will automatically copy the certificate to Key Vault
3. **Manual sync**: You can trigger a sync immediately once certificate is ready:
   ```bash
   kubectl create job --from=cronjob/sync-cert-to-keyvault manual-sync-$(date +%Y%m%d%H%M%S) -n cloudtolocalllm
   ```

---

## Benefits

✅ **Azure Integration**: Certificates available in Azure Key Vault  
✅ **Platform Independence**: Certificates still issued via ACME (platform-independent)  
✅ **Automatic Sync**: Runs every 6 hours automatically  
✅ **Portable**: Certificates exportable from Key Vault (standard X.509 format)  
✅ **Low Lock-in**: Can migrate away from Azure Key Vault anytime  

---

## Troubleshooting

### Sync Job Fails with "Forbidden"

**Cause**: RBAC permissions not granted  
**Solution**: Grant "Key Vault Secrets Officer" role (see instructions above)

### Sync Job Skips with "Secret not found"

**Cause**: Certificate not issued yet  
**Solution**: Wait for certificate to be issued, or switch to a different CA (SSL.com, Actalis, etc.)

### Check RBAC Permissions

```bash
az role assignment list \
  --scope "/subscriptions/ba58d2e9-b162-470d-ac9d-365fb31540de/resourceGroups/cloudtolocalllm-rg/providers/Microsoft.KeyVault/vaults/cloudtolocalllm-kv" \
  --assignee 9a038fed-3241-4bf9-9bb5-bc489e8a4b27 \
  -o table
```

---

## Next Steps

1. **Grant RBAC permissions** (see instructions above)
2. **Wait for certificate issuance** or switch to SSL.com/Actalis for immediate certificate
3. **Verify sync** once certificate is ready:
   ```bash
   kubectl create job --from=cronjob/sync-cert-to-keyvault manual-sync-test -n cloudtolocalllm
   kubectl logs -n cloudtolocalllm job/manual-sync-test
   ```

---

## Summary

The Azure Key Vault integration is configured and ready. Once you:
1. Grant RBAC permissions, and
2. Have a certificate issued

The automatic sync will keep Azure Key Vault in sync with your Kubernetes certificates every 6 hours.

