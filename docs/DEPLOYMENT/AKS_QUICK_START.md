# AKS Deployment - Quick Start

Deploy CloudToLocalLLM to Azure Kubernetes Service in 30 minutes with these 3 simple steps.

## Prerequisites

- ✅ Azure account ([create free account](https://azure.microsoft.com/free/))
- ✅ GitHub account with repository access
- ✅ [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- ✅ [GitHub CLI](https://cli.github.com/) installed
- ✅ API keys: Stripe, Cloudflare, Supabase

## Step 1: Azure Setup (10-15 min)

```bash
# Clone repository
git clone https://github.com/YOUR-USERNAME/CloudToLocalLLM.git
cd CloudToLocalLLM

# Login to Azure
az login

# Run setup script
./scripts/setup-azure-aks-infrastructure.sh
```

**What it creates:**
- Resource Group
- Container Registry (ACR)
- Key Vault
- Service Principal for GitHub Actions

**Output:** `.azure-deployment-config.json`

## Step 2: GitHub Secrets (5-10 min)

```bash
# Login to GitHub
gh auth login

# Configure secrets
./scripts/setup-github-secrets-aks.sh
```

**What you'll provide:**
- Stripe test secret key
- Cloudflare DNS token
- Cloudflare Tunnel token
- Supabase JWT secret
- Sentry DSN (optional)

**Auto-generated:**
- Database password
- JWT secret

## Step 3: Deploy (15-20 min)

```bash
# Push to trigger deployment
git push origin main

# Monitor deployment
gh run watch
```

## Verify Deployment

```bash
# Connect to cluster
az aks get-credentials \
  --resource-group cloudtolocalllm-rg \
  --name cloudtolocalllm-aks

# Check pods
kubectl get pods -n cloudtolocalllm

# All should show Running with 1/1 ready
```

## Access Your Application

- **Web App**: https://app.cloudtolocalllm.online/
- **API**: https://api.cloudtolocalllm.online/

## Troubleshooting

### Quick Validation

```bash
# Validate everything before deployment
./scripts/validate-aks-prerequisites.sh
```

### Common Issues

**Problem:** Script fails with "not logged in"  
**Solution:** `az login` or `gh auth login`

**Problem:** Service principal creation fails  
**Solution:** Ensure you have Owner/Contributor role

**Problem:** ACR/Key Vault name already taken  
**Solution:** Use custom names:
```bash
./scripts/setup-azure-aks-infrastructure.sh \
  --acr-name "yourname-cloudtolocalllm" \
  --keyvault-name "yourname-cloudtolocalllm-kv"
```

**Problem:** Pods stuck in CrashLoopBackOff  
**Solution:** Check logs:
```bash
kubectl logs -n cloudtolocalllm <pod-name>
```

## Cost Estimation

| Resource | Monthly Cost |
|----------|--------------|
| AKS (1 node) | ~$35 |
| ACR | ~$5 |
| Key Vault | ~$3 |
| Load Balancer | ~$20 |
| **Total** | **~$63** |

💡 **Tip:** New Azure accounts get $200 credit for 30 days!

## Next Steps

-  - Detailed instructions
- [Deployment Plan](./AKS_DEPLOYMENT_FIX_PLAN.md) - Architecture details
- [Script Documentation](../../scripts/README_AKS_DEPLOYMENT.md) - Advanced usage

## Need Help?

- 📖 [Documentation](../README.md)
- 💬 [GitHub Discussions](https://github.com/YOUR-USERNAME/CloudToLocalLLM/discussions)
- 🐛 [Report Issues](https://github.com/YOUR-USERNAME/CloudToLocalLLM/issues)

---

**That's it!** Three commands and you're deployed. 🚀

