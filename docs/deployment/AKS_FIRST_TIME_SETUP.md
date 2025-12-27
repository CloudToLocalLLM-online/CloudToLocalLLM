# AKS Deployment - First Time Setup Guide

This guide walks you through deploying CloudToLocalLLM to Azure Kubernetes Service (AKS) from a **brand new Azure account**. The entire process takes approximately 30-45 minutes.

## Overview

The deployment process consists of three main steps:

1. **Azure Infrastructure Setup** - Create all required Azure resources
2. **GitHub Secrets Configuration** - Configure GitHub repository with Azure credentials
3. **Automated Deployment** - Push to trigger GitHub Actions deployment

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: Azure Setup (10-15 min)                            │
│   • Create Resource Group                                   │
│   • Create Azure Container Registry (ACR)                   │
│   • Create Azure Key Vault                                  │
│   • Create Service Principal with Federated Credentials     │
│   • Assign necessary permissions                            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 2: GitHub Configuration (5-10 min)                    │
│   • Set Azure credentials as GitHub secrets                 │
│   • Set application secrets (auto-generated)                │
│   • Set API keys (Stripe, Cloudflare, etc.)                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 3: Deployment (15-20 min)                             │
│   • Push code to trigger GitHub Actions                     │
│   • Build and push Docker images                            │
│   • Create AKS cluster                                       │
│   • Deploy all services                                      │
│   • Configure DNS and SSL                                    │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

Before you begin, ensure you have:

### 1. Azure Account
- [ ] Active Azure subscription ([create free account](https://azure.microsoft.com/free/))
- [ ] Sufficient quota for:
  - 1 AKS cluster (2-3 nodes)
  - 1 Azure Container Registry
  - 1 Azure Key Vault

### 2. GitHub Repository
- [ ] Fork or clone of CloudToLocalLLM repository
- [ ] Admin access to the repository (to set secrets)

### 3. Required Tools (Installed Locally)
- [ ] **Azure CLI** ([install guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- [ ] **GitHub CLI** ([install guide](https://cli.github.com/))
- [ ] **Git** ([install guide](https://git-scm.com/downloads))
- [ ] **OpenSSL** (usually pre-installed on macOS/Linux)

### 4. Third-Party Services (API Keys)
- [ ] **Stripe** account with test API keys ([sign up](https://stripe.com/))
- [ ] **Cloudflare** account with DNS token ([sign up](https://cloudflare.com/))
- [ ] **Supabase** account with JWT secret ([sign up](https://supabase.com/))
- [ ] **Sentry** account (optional, for error tracking)

### 5. Domain Name (Optional)
- [ ] Domain managed by Cloudflare (for DNS and SSL)
- [ ] Cloudflare Tunnel configured (for HTTPS)

---

## Step 1: Azure Infrastructure Setup

### 1.1 Clone Repository

```bash
# Clone the repository
git clone https://github.com/YOUR-USERNAME/CloudToLocalLLM.git
cd CloudToLocalLLM

# Make scripts executable
chmod +x scripts/*.sh
```

### 1.2 Authenticate to Azure

```bash
# Login to Azure CLI
az login

# Verify you're logged in
az account show

# (Optional) Set specific subscription if you have multiple
az account list --output table
az account set --subscription "YOUR-SUBSCRIPTION-ID"
```

### 1.3 Run Infrastructure Setup Script

```bash
# Run the automated setup script
./scripts/setup-azure-aks-infrastructure.sh
```

**What this script does:**
- Registers required Azure resource providers
- Creates resource group (`cloudtolocalllm-rg`)
- Creates Azure Container Registry (`cloudtolocalllm`)
- Creates Azure Key Vault (`cloudtolocalllm-kv`)
- Creates Service Principal for GitHub Actions with federated credentials
- Assigns necessary permissions (Contributor, AcrPush, Key Vault Secrets Officer)
- Generates configuration file (`.azure-deployment-config.json`)

**Interactive Prompts:**
- Select Azure subscription (if you have multiple)
- Confirm configuration values
- Enter GitHub repository (format: `username/CloudToLocalLLM`)

**Expected Duration:** 10-15 minutes

**Output:**
```
✓ Azure Infrastructure Setup Complete!

GitHub Secrets Required:
  AZURE_CLIENT_ID:         xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  AZURE_TENANT_ID:         xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  AZURE_SUBSCRIPTION_ID:   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  AZURE_KEY_VAULT_NAME:    cloudtolocalllm-kv

Configuration file: .azure-deployment-config.json
```

### 1.4 Verify Setup

```bash
# Validate all Azure resources were created correctly
./scripts/validate-aks-prerequisites.sh --check-azure-only
```

You should see all checks passing:
```
✓ Resource group exists: cloudtolocalllm-rg
✓ ACR exists: cloudtolocalllm
✓ Key Vault exists: cloudtolocalllm-kv
✓ Service principal exists
```

---

## Step 2: GitHub Secrets Configuration

### 2.1 Authenticate to GitHub

```bash
# Login to GitHub CLI
gh auth login

# Follow the prompts to authenticate
# Choose: GitHub.com -> HTTPS -> Login with web browser

# Verify authentication
gh auth status
```

### 2.2 Prepare API Keys

Before running the setup script, gather your API keys:

#### Stripe (Required)
1. Go to [Stripe Dashboard](https://dashboard.stripe.com/)
2. Navigate to **Developers > API keys**
3. Copy your **Secret key** (starts with `sk_test_...`)

#### Cloudflare (Required)
1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **My Profile > API Tokens**
3. Create token with **Zone:DNS:Edit** permissions
4. Copy the token

For Cloudflare Tunnel:
```bash
# Create tunnel
cloudflared tunnel create cloudtolocalllm

# Get tunnel token
cloudflared tunnel token <tunnel-id>
```

#### Supabase (Required)
1. Go to [Supabase Dashboard](https://app.supabase.com/)
2. Select your project
3. Navigate to **Settings > API**
4. Copy **JWT Secret**

#### Sentry (Optional)
1. Go to [Sentry Dashboard](https://sentry.io/)
2. Create new project or use existing
3. Copy **DSN** from project settings

### 2.3 Run Secrets Configuration Script

```bash
# Run the automated secrets setup script
./scripts/setup-github-secrets-aks.sh
```

**What this script does:**
- Reads Azure configuration from `.azure-deployment-config.json`
- Sets Azure credentials as GitHub secrets
- Auto-generates secure passwords for database and JWT
- Prompts for API keys (Stripe, Cloudflare, Supabase, Sentry)
- Validates all secrets are set correctly
- Generates secrets reference file (`.github-secrets-reference.txt`)

**Interactive Prompts:**
- **PostgreSQL Password**: Press Enter to auto-generate
- **JWT Secret**: Press Enter to auto-generate
- **Stripe Test Secret Key**: Enter your Stripe secret key
- **Stripe Publishable Key**: Enter or skip (optional)
- **Cloudflare DNS Token**: Enter your Cloudflare token
- **Cloudflare Tunnel Token**: Enter your tunnel token
- **Supabase JWT Secret**: Enter your Supabase JWT secret
- **Sentry DSN**: Enter or skip (optional)

**Expected Duration:** 5-10 minutes

**Output:**
```
✓ GitHub Secrets Setup Complete!

Repository: username/CloudToLocalLLM

All required secrets configured:
  ✓ AZURE_CLIENT_ID
  ✓ AZURE_TENANT_ID
  ✓ AZURE_SUBSCRIPTION_ID
  ✓ POSTGRES_PASSWORD
  ✓ JWT_SECRET
  ✓ STRIPE_TEST_SECRET_KEY
  ✓ CLOUDFLARE_DNS_TOKEN
  ✓ CLOUDFLARE_TUNNEL_TOKEN
  ✓ SUPABASE_JWT_SECRET

Secrets reference saved to: .github-secrets-reference.txt
```

⚠️ **IMPORTANT:** The `.github-secrets-reference.txt` file contains sensitive information. **Never commit it to git!** It's included in `.gitignore` by default.

### 2.4 Verify Secrets

```bash
# List all secrets (names only, values are hidden)
gh secret list --repo YOUR-USERNAME/CloudToLocalLLM
```

Expected output:
```
AZURE_CLIENT_ID           Updated 2024-XX-XX
AZURE_KEY_VAULT_NAME      Updated 2024-XX-XX
AZURE_SUBSCRIPTION_ID     Updated 2024-XX-XX
AZURE_TENANT_ID           Updated 2024-XX-XX
CLOUDFLARE_DNS_TOKEN      Updated 2024-XX-XX
CLOUDFLARE_TUNNEL_TOKEN   Updated 2024-XX-XX
JWT_SECRET                Updated 2024-XX-XX
POSTGRES_PASSWORD         Updated 2024-XX-XX
STRIPE_TEST_SECRET_KEY    Updated 2024-XX-XX
SUPABASE_JWT_SECRET       Updated 2024-XX-XX
```

---

## Step 3: Deployment

### 3.1 Trigger Deployment

```bash
# Make sure you're on the main branch
git checkout main

# Push to trigger deployment
git push origin main
```

### 3.2 Monitor Deployment

```bash
# Watch the workflow in real-time
gh run watch --repo YOUR-USERNAME/CloudToLocalLLM

# Or view in browser
gh run list --repo YOUR-USERNAME/CloudToLocalLLM
```

### 3.3 Deployment Stages

The GitHub Actions workflow will:

1. **Validate Prerequisites** (2-3 min)
   - Check all secrets are set
   - Validate Azure resources exist
   - Verify permissions

2. **Build Docker Images** (10-12 min)
   - Build base image
   - Build PostgreSQL image
   - Build web application image
   - Build API backend image
   - Build streaming proxy image
   - Push all images to ACR

3. **Deploy Infrastructure** (5-8 min)
   - Create AKS cluster (if doesn't exist)
   - Install Secrets Store CSI Driver
   - Create Kubernetes namespace
   - Configure secrets

4. **Deploy Application** (3-5 min)
   - Deploy PostgreSQL
   - Deploy API backend
   - Deploy web application
   - Deploy streaming proxy
   - Deploy Cloudflare tunnel

5. **Verify Deployment** (1-2 min)
   - Check pod health
   - Verify tunnel connection
   - Test health endpoints
   - Update DNS records

**Total Duration:** 15-20 minutes

### 3.4 Check Deployment Status

```bash
# Get the latest run status
gh run view --repo YOUR-USERNAME/CloudToLocalLLM

# If there are issues, view the logs
gh run view --log --repo YOUR-USERNAME/CloudToLocalLLM
```

### 3.5 Verify Deployment

Once the workflow completes successfully:

```bash
# Connect to your AKS cluster
az aks get-credentials \
  --resource-group cloudtolocalllm-rg \
  --name cloudtolocalllm-aks

# Check pod status
kubectl get pods -n cloudtolocalllm

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# postgres-0                        1/1     Running   0          5m
# api-backend-xxxxxxxxxx-xxxxx      1/1     Running   0          5m
# web-xxxxxxxxxx-xxxxx              1/1     Running   0          5m
# streaming-proxy-xxxxxxxxxx-xxxxx  1/1     Running   0          5m
# cloudflared-xxxxxxxxxx-xxxxx      1/1     Running   0          5m
```

All pods should be in `Running` status with `1/1` ready.

### 3.6 Access Your Application

If using Cloudflare Tunnel, your application is accessible at:

- **Web App**: `https://app.cloudtolocalllm.online/`
- **API**: `https://api.cloudtolocalllm.online/`

Test the health endpoint:
```bash
curl https://app.cloudtolocalllm.online/health
# Expected: {"status":"ok"}
```

---

## Troubleshooting

### Issue: Azure CLI not authenticated

**Symptoms:**
```
ERROR: Please run 'az login' to setup account.
```

**Solution:**
```bash
az login
az account show
```

### Issue: GitHub CLI not authenticated

**Symptoms:**
```
error: not logged in
```

**Solution:**
```bash
gh auth login
gh auth status
```

### Issue: Service Principal creation failed

**Symptoms:**
```
ERROR: Insufficient privileges to complete the operation
```

**Solution:**
- Ensure your Azure account has sufficient permissions
- You need at least `User Access Administrator` or `Owner` role
- Contact your Azure administrator if using a corporate account

### Issue: AKS cluster creation timeout

**Symptoms:**
- Workflow stuck on "Create AKS Cluster" for >20 minutes

**Solution:**
- This is normal on first creation (can take 10-15 minutes)
- If >30 minutes, check Azure portal for cluster status
- Look for quota issues in Azure portal

### Issue: Deployment workflow fails at secret validation

**Symptoms:**
```
✗ Validation failed! Fix errors before deployment.
```

**Solution:**
```bash
# Re-run the validation script
./scripts/validate-aks-prerequisites.sh

# Fix any missing secrets
./scripts/setup-github-secrets-aks.sh

# Re-trigger deployment
git commit --allow-empty -m "Retry deployment"
git push origin main
```

### Issue: Pods in CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pods -n cloudtolocalllm
# NAME                    READY   STATUS             RESTARTS   AGE
# postgres-0              0/1     CrashLoopBackOff   5          5m
```

**Solution:**
```bash
# Check pod logs
kubectl logs -n cloudtolocalllm postgres-0

# Common causes:
# 1. Incorrect database password
# 2. Insufficient resources
# 3. Volume mount issues

# Delete and recreate pod
kubectl delete pod postgres-0 -n cloudtolocalllm --force --grace-period=0
```

### Issue: ACR authentication failure

**Symptoms:**
```
Error: failed to authorize: failed to fetch anonymous token
```

**Solution:**
```bash
# Verify ACR admin is enabled
az acr show --name cloudtolocalllm --query adminUserEnabled

# Enable admin access
az acr update --name cloudtolocalllm --admin-enabled true

# Verify service principal has AcrPush role
az role assignment list --scope $(az acr show --name cloudtolocalllm --query id -o tsv)
```

### Get Help

For more troubleshooting steps, see:
- 
- [GitHub Issues](https://github.com/YOUR-USERNAME/CloudToLocalLLM/issues)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)

---

## Cost Estimation

### Azure Resources

| Resource | SKU/Size | Estimated Monthly Cost |
|----------|----------|------------------------|
| AKS Cluster (1 node) | Standard_B2s | ~$35 |
| Container Registry | Basic | ~$5 |
| Key Vault | Standard | ~$3 |
| Load Balancer | Basic | ~$20 |
| **Total** | | **~$63/month** |

### Cost Optimization Tips

1. **Use Azure Free Tier**
   - $200 credit for 30 days for new accounts
   - Perfect for testing before production

2. **Scale Down Dev Environments**
   ```bash
   # Scale to 0 replicas when not in use
   kubectl scale deployment/api-backend --replicas=0 -n cloudtolocalllm
   kubectl scale deployment/web --replicas=0 -n cloudtolocalllm
   ```

3. **Use Spot Instances for Dev**
   - 70-90% cost savings for non-production workloads

4. **Delete Resources When Not Needed**
   ```bash
   # Delete entire resource group (WARNING: irreversible!)
   az group delete --name cloudtolocalllm-rg --yes --no-wait
   ```

---

## Next Steps

Now that your deployment is complete:

1. **Configure Domain** (if using custom domain)
   - Update Cloudflare DNS records
   - Configure SSL certificates
   - See: 

2. **Set Up Monitoring**
   - Enable Azure Monitor
   - Configure alerts
   - See: 

3. **Configure Backups**
   - Set up database backups
   - Configure disaster recovery
   - See: 

4. **Security Hardening**
   - Review security best practices
   - Configure network policies
   - See: 

5. **Performance Optimization**
   - Configure auto-scaling
   - Optimize resource requests/limits
   - See: 

---

## Summary

Congratulations! 🎉 You've successfully deployed CloudToLocalLLM to Azure AKS.

**What you've accomplished:**
- ✅ Created all necessary Azure infrastructure
- ✅ Configured automated CI/CD with GitHub Actions
- ✅ Deployed a production-ready Kubernetes application
- ✅ Set up secure secret management
- ✅ Configured monitoring and logging

**Your application is now:**
- 🚀 Running on Azure Kubernetes Service
- 🔒 Secured with Azure Key Vault
- 📦 Containerized with Docker
- 🔄 Auto-deployed via GitHub Actions
- 📊 Monitored with Azure Monitor
- 🌍 Accessible via Cloudflare Tunnel

**Resources:**
- Azure Portal: https://portal.azure.com/
- GitHub Actions: https://github.com/YOUR-USERNAME/CloudToLocalLLM/actions
- Application: https://app.cloudtolocalllm.online/

---

**Need Help?**
- 📖 [Full Documentation](../README.md)
- 💬 [GitHub Discussions](https://github.com/YOUR-USERNAME/CloudToLocalLLM/discussions)
- 🐛 [Report Issues](https://github.com/YOUR-USERNAME/CloudToLocalLLM/issues)

