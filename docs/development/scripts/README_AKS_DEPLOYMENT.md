# AKS Deployment Scripts

This directory contains scripts for setting up and managing Azure Kubernetes Service (AKS) deployments for CloudToLocalLLM.

## Overview

These scripts automate the complete deployment process from a brand new Azure account to a fully running application.

## Scripts

### 1. Setup Scripts (Run these first)

#### `setup-azure-aks-infrastructure.sh`

**Purpose**: Creates all required Azure infrastructure for AKS deployment.

**What it does:**
- Registers Azure resource providers
- Creates resource group
- Creates Azure Container Registry (ACR)
- Creates Azure Key Vault
- Creates Service Principal with federated credentials for GitHub Actions
- Assigns necessary permissions
- Generates configuration file

**Usage:**
```bash
# Interactive mode (prompts for values)
./scripts/setup-azure-aks-infrastructure.sh

# Non-interactive mode with custom values
./scripts/setup-azure-aks-infrastructure.sh \
  --subscription-id "your-sub-id" \
  --location "eastus" \
  --resource-group "cloudtolocalllm-rg" \
  --acr-name "cloudtolocalllm" \
  --keyvault-name "cloudtolocalllm-kv" \
  --github-repo "yourusername/CloudToLocalLLM" \
  --non-interactive

# Create AKS cluster immediately (instead of letting workflow create it)
./scripts/setup-azure-aks-infrastructure.sh --create-aks
```

**Prerequisites:**
- Azure CLI installed and authenticated (`az login`)
- Sufficient Azure permissions (Contributor or Owner)

**Output:**
- `.azure-deployment-config.json` - Configuration file for next steps

**Duration:** 10-15 minutes

---

#### `setup-github-secrets-aks.sh`

**Purpose**: Configures GitHub repository with required secrets for AKS deployment.

**What it does:**
- Reads Azure configuration from `.azure-deployment-config.json`
- Auto-generates secure passwords for database and JWT
- Prompts for API keys (Stripe, Cloudflare, Supabase, Sentry)
- Sets all secrets in GitHub repository
- Validates secrets are set correctly
- Generates secrets reference file

**Usage:**
```bash
# Interactive mode (prompts for secrets)
./scripts/setup-github-secrets-aks.sh

# Non-interactive mode with environment variables
export POSTGRES_PASSWORD="your-password"
export JWT_SECRET="your-jwt-secret"
export STRIPE_TEST_SECRET_KEY="sk_test_..."
export CLOUDFLARE_DNS_TOKEN="your-token"
export CLOUDFLARE_TUNNEL_TOKEN="your-token"
export SUPABASE_JWT_SECRET="your-secret"

./scripts/setup-github-secrets-aks.sh --non-interactive

# Use custom config file
./scripts/setup-github-secrets-aks.sh --config-file ./my-config.json

# Skip GitHub CLI authentication check
./scripts/setup-github-secrets-aks.sh --skip-validation
```

**Prerequisites:**
- GitHub CLI installed and authenticated (`gh auth login`)
- `.azure-deployment-config.json` exists (from previous script)
- Admin access to GitHub repository

**Output:**
- GitHub repository secrets configured
- `.github-secrets-reference.txt` - Local reference file (DO NOT COMMIT)

**Duration:** 5-10 minutes

---

### 2. Validation Script

#### `validate-aks-prerequisites.sh`

**Purpose**: Validates all prerequisites before deployment to catch issues early.

**What it does:**
- Checks CLI tools (Azure CLI, kubectl, jq)
- Validates Azure authentication
- Checks Azure resource providers are registered
- Validates Azure resources exist (resource group, ACR, Key Vault)
- Validates service principal and permissions
- Checks GitHub secrets are set
- Validates ACR access

**Usage:**
```bash
# Validate everything
./scripts/validate-aks-prerequisites.sh

# Validate only Azure resources (skip secrets check)
./scripts/validate-aks-prerequisites.sh --check-azure-only

# Validate only GitHub secrets (skip Azure resources)
./scripts/validate-aks-prerequisites.sh --check-secrets-only

# Verbose output
./scripts/validate-aks-prerequisites.sh --verbose

# Custom resource names
./scripts/validate-aks-prerequisites.sh \
  --resource-group "my-rg" \
  --acr-name "myacr" \
  --keyvault-name "my-kv"
```

**Exit Codes:**
- `0` - All checks passed
- `1` - Missing prerequisites (with detailed error messages)
- `2` - Configuration issues

**When to use:**
- Before running deployment workflow
- After making infrastructure changes
- When troubleshooting deployment issues
- As part of CI/CD validation

**Duration:** 1-2 minutes

---

### 3. Legacy/Helper Scripts

#### `bootstrap-azure-infra.sh`

**Purpose**: Legacy bootstrap script (superseded by `setup-azure-aks-infrastructure.sh`).

**Note:** This is the original bootstrap script that's called by the GitHub Actions workflow. The new `setup-azure-aks-infrastructure.sh` is more comprehensive and recommended for first-time setup.

**Usage:**
```bash
./scripts/bootstrap-azure-infra.sh \
  "cloudtolocalllm-rg" \
  "eastus" \
  "cloudtolocalllm" \
  "cloudtolocalllm-kv"
```

---

## Complete Deployment Process

### Step 1: Azure Infrastructure Setup

```bash
# Clone repository
git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git
cd CloudToLocalLLM

# Make scripts executable
chmod +x scripts/*.sh

# Authenticate to Azure
az login

# Run infrastructure setup
./scripts/setup-azure-aks-infrastructure.sh
```

### Step 2: GitHub Secrets Configuration

```bash
# Authenticate to GitHub
gh auth login

# Run secrets setup
./scripts/setup-github-secrets-aks.sh
```

### Step 3: Validate Setup

```bash
# Validate all prerequisites
./scripts/validate-aks-prerequisites.sh
```

### Step 4: Deploy

```bash
# Push to trigger deployment
git push origin main

# Monitor deployment
gh run watch
```

---

## Troubleshooting

### Common Issues

#### 1. Azure CLI Not Authenticated

**Error:**
```
ERROR: Please run 'az login' to setup account.
```

**Solution:**
```bash
az login
az account show
```

#### 2. Insufficient Azure Permissions

**Error:**
```
ERROR: Insufficient privileges to complete the operation
```

**Solution:**
- Ensure your Azure account has `Contributor` or `Owner` role
- Contact your Azure administrator if using corporate account

#### 3. GitHub CLI Not Authenticated

**Error:**
```
error: not logged in
```

**Solution:**
```bash
gh auth login
gh auth status
```

#### 4. Service Principal Creation Failed

**Error:**
```
ERROR: The directory object quota limit for the Principal has been exceeded.
```

**Solution:**
- You may have too many existing service principals
- Delete unused service principals in Azure Portal
- Or use an existing service principal

#### 5. ACR Name Not Available

**Error:**
```
ERROR: The registry name 'cloudtolocalllm' is not available.
```

**Solution:**
```bash
# Use a unique name with your username or organization
./scripts/setup-azure-aks-infrastructure.sh --acr-name "yourusername-cloudtolocalllm"
```

#### 6. Key Vault Name Not Available

**Error:**
```
ERROR: Vault name 'cloudtolocalllm-kv' is already in use.
```

**Solution:**
```bash
# Use a unique name
./scripts/setup-azure-aks-infrastructure.sh --keyvault-name "yourusername-cloudtolocalllm-kv"
```

---

## Advanced Usage

### Using Custom Resource Names

If the default names are taken or you want to use custom names:

```bash
# Setup with custom names
./scripts/setup-azure-aks-infrastructure.sh \
  --resource-group "my-custom-rg" \
  --acr-name "mycustomacr" \
  --keyvault-name "my-custom-kv" \
  --aks-name "my-custom-aks"

# Validation with custom names
./scripts/validate-aks-prerequisites.sh \
  --resource-group "my-custom-rg" \
  --acr-name "mycustomacr" \
  --keyvault-name "my-custom-kv"
```

**Note:** If using custom names, you'll need to update the GitHub Actions workflow (`.github/workflows/deploy-aks.yml`) with your custom names.

### Non-Interactive Mode (CI/CD)

For automation in CI/CD pipelines:

```bash
# Set all values as environment variables
export SUBSCRIPTION_ID="your-subscription-id"
export LOCATION="eastus"
export RESOURCE_GROUP="cloudtolocalllm-rg"
export ACR_NAME="cloudtolocalllm"
export KEYVAULT_NAME="cloudtolocalllm-kv"
export GITHUB_REPO="yourusername/CloudToLocalLLM"

# Set application secrets
export POSTGRES_PASSWORD="secure-password"
export JWT_SECRET="secure-jwt-secret"
export STRIPE_TEST_SECRET_KEY="sk_test_..."
export CLOUDFLARE_DNS_TOKEN="your-token"
export CLOUDFLARE_TUNNEL_TOKEN="your-token"
export SUPABASE_JWT_SECRET="your-secret"

# Run scripts in non-interactive mode
./scripts/setup-azure-aks-infrastructure.sh --non-interactive
./scripts/setup-github-secrets-aks.sh --non-interactive
./scripts/validate-aks-prerequisites.sh
```

### Cleanup

To remove all Azure resources:

```bash
# Delete resource group (WARNING: irreversible!)
az group delete --name cloudtolocalllm-rg --yes --no-wait

# Remove local configuration files
rm .azure-deployment-config.json
rm .github-secrets-reference.txt
```

---

## Security Best Practices

1. **Never commit sensitive files:**
   - `.azure-deployment-config.json`
   - `.github-secrets-reference.txt`
   - These are in `.gitignore` by default

2. **Rotate secrets regularly:**
   - Database passwords
   - JWT secrets
   - API keys

3. **Use federated credentials:**
   - No long-lived secrets in GitHub
   - OIDC-based authentication
   - Automatic key rotation

4. **Limit service principal permissions:**
   - Grant minimum required permissions
   - Use RBAC for fine-grained access control

5. **Enable Azure Key Vault:**
   - Store secrets in Key Vault
   - Use managed identities where possible

---

## Related Documentation

- [AKS Deployment Fix Plan](../docs/DEPLOYMENT/AKS_DEPLOYMENT_FIX_PLAN.md) - Comprehensive plan and architecture
-  - Step-by-step guide for new users
- [CI/CD Setup Guide](../docs/ops/cicd/CICD_SETUP_GUIDE.md) - GitHub Actions workflow documentation
- [Azure Key Vault Setup](../k8s/AZURE_KEYVAULT_SETUP.md) - Key Vault integration guide

---

## Support

For issues or questions:
- 📖 [Documentation](../docs/README.md)
- 💬 [GitHub Discussions](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/discussions)
- 🐛 [Report Issues](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)

---

## Contributing

Improvements to these scripts are welcome! Please:
1. Test thoroughly on a clean Azure account
2. Update documentation
3. Follow existing code style
4. Add comments for complex logic

---

**Last Updated:** 2024-12-03

