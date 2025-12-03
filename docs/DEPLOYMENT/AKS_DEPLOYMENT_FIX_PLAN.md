# AKS Deployment Workflow Fix Plan

## Executive Summary

This plan addresses the current limitations of the AKS deployment workflow to make it work seamlessly on a **brand new Azure account** with minimal manual intervention.

## Current Issues

### 1. **Manual Prerequisites**
- Service Principal with federated credentials must be created manually
- GitHub secrets must be set manually
- Azure resources assume pre-existing configuration
- No validation of prerequisites before deployment starts

### 2. **Missing Automation**
- No script to set up Azure infrastructure from scratch
- No automated GitHub OIDC federation setup
- Bootstrap script doesn't create all required resources
- Missing validation of Azure provider registrations

### 3. **Workflow Assumptions**
- Assumes secrets exist (fails silently if missing)
- Assumes service principal has correct permissions
- No clear documentation on first-time setup
- ACR authentication mixing service principal and admin credentials

### 4. **Documentation Gaps**
- Missing step-by-step guide for fresh Azure account
- No troubleshooting guide for common setup issues
- Scattered information across multiple docs

## Solution Architecture

### Phase 1: Azure Infrastructure Setup Script
Create a comprehensive script that:
1. Creates resource group
2. Registers required Azure providers
3. Creates service principal with federated credentials for GitHub Actions
4. Creates ACR with proper permissions
5. Creates Key Vault with proper RBAC
6. Outputs all required values for GitHub secrets

### Phase 2: GitHub Configuration Script
Create a script that:
1. Validates GitHub CLI authentication
2. Sets all required repository secrets
3. Sets repository variables
4. Configures OIDC trust relationship
5. Validates the configuration

### Phase 3: Workflow Improvements
1. Add comprehensive prerequisite validation
2. Implement better error messages
3. Add retry logic for transient failures
4. Improve ACR authentication strategy
5. Add workflow status notifications

### Phase 4: Documentation
1. Create step-by-step first-time setup guide
2. Create troubleshooting guide
3. Update existing documentation
4. Create video walkthrough (optional)

## Detailed Implementation Plan

### 1. Azure Infrastructure Setup Script

**File**: `scripts/setup-azure-aks-infrastructure.sh`

**Purpose**: One-command setup of all Azure resources

**Features**:
```bash
#!/usr/bin/env bash
# Usage: ./scripts/setup-azure-aks-infrastructure.sh [--subscription-id SUB_ID] [--location LOCATION]

# Steps:
1. Check Azure CLI authentication
2. Validate or select subscription
3. Register required resource providers:
   - Microsoft.ContainerService
   - Microsoft.ContainerRegistry
   - Microsoft.KeyVault
   - Microsoft.OperationsManagement
   - Microsoft.Insights
4. Create resource group (idempotent)
5. Create Azure Container Registry (idempotent)
   - Enable admin access
   - Configure proper SKU (Basic for start, can upgrade)
6. Create Azure Key Vault (idempotent)
   - Enable RBAC authorization
   - Configure network access
7. Create Service Principal for GitHub Actions
   - Set federated credential for GitHub OIDC
   - Assign necessary roles:
     * Contributor (for AKS/ACR management)
     * AcrPush (for pushing images)
     * Key Vault Secrets Officer (for secret management)
8. Optionally create AKS cluster (can be skipped if workflow creates it)
9. Output configuration file with all values

# Output example:
# Generated file: .azure-deployment-config.json
# {
#   "AZURE_SUBSCRIPTION_ID": "...",
#   "AZURE_TENANT_ID": "...",
#   "AZURE_CLIENT_ID": "...",
#   "AZURE_CLIENT_SECRET": "..." (only if using secret, not OIDC),
#   "AZURE_RESOURCE_GROUP": "cloudtolocalllm-rg",
#   "ACR_NAME": "cloudtolocalllm",
#   "AZURE_KEY_VAULT_NAME": "cloudtolocalllm-kv",
#   "ACR_LOGIN_SERVER": "cloudtolocalllm.azurecr.io"
# }
```

**Key Features**:
- Idempotent (can be run multiple times)
- Validates each step before proceeding
- Provides clear progress indicators
- Generates configuration file for next steps
- Supports both interactive and non-interactive modes

### 2. GitHub Configuration Script

**File**: `scripts/setup-github-secrets-aks.sh`

**Purpose**: Configure GitHub repository with Azure credentials

**Features**:
```bash
#!/usr/bin/env bash
# Usage: ./scripts/setup-github-secrets-aks.sh [--config-file CONFIG] [--repo OWNER/REPO]

# Steps:
1. Verify GitHub CLI is installed and authenticated
2. Read configuration from .azure-deployment-config.json
3. Prompt for missing secrets:
   - POSTGRES_PASSWORD (auto-generate if empty)
   - JWT_SECRET (auto-generate if empty)
   - STRIPE_TEST_SECRET_KEY (required)
   - SENTRY_DSN (optional)
   - CLOUDFLARE_DNS_TOKEN (required)
   - CLOUDFLARE_TUNNEL_TOKEN (required)
   - SUPABASE_JWT_SECRET (required)
4. Set GitHub repository secrets using gh CLI
5. Set GitHub repository variables
6. Validate all secrets are set correctly
7. Test GitHub Actions can authenticate to Azure (dry-run)

# Auto-generation examples:
# POSTGRES_PASSWORD=$(openssl rand -base64 32)
# JWT_SECRET=$(openssl rand -base64 48)
```

**Key Features**:
- Auto-generates secure passwords
- Validates GitHub authentication before starting
- Checks if secrets already exist (optional override)
- Provides confirmation of all settings
- Can read from environment variables or prompt interactively

### 3. Pre-deployment Validation Script

**File**: `scripts/validate-aks-prerequisites.sh`

**Purpose**: Validate all prerequisites before deployment

**Features**:
```bash
#!/usr/bin/env bash
# Can be run locally or in GitHub Actions

# Validates:
1. Azure CLI authentication
2. Azure subscription access
3. Resource group exists
4. ACR exists and is accessible
5. Key Vault exists and is accessible
6. Service Principal has correct permissions
7. GitHub secrets are set (if running in Actions)
8. AKS cluster exists (or can be created)
9. kubectl is installed (if needed)
10. Required Azure providers are registered

# Exit codes:
# 0 - All checks passed
# 1 - Missing prerequisites (with detailed error messages)
# 2 - Configuration issues
```

### 4. Improved Workflow

**File**: `.github/workflows/deploy-aks.yml`

**Improvements**:

```yaml
jobs:
  # NEW: Prerequisite validation job
  validate_prerequisites:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate Prerequisites
        run: |
          chmod +x scripts/validate-aks-prerequisites.sh
          ./scripts/validate-aks-prerequisites.sh
        env:
          # Pass all required secrets for validation
          POSTGRES_PASSWORD: ${{ secrets.POSTGRES_PASSWORD }}
          # ... other secrets ...

  # IMPROVED: Better error handling in build jobs
  build_base:
    needs: validate_prerequisites  # Add dependency
    runs-on: ubuntu-latest
    steps:
      - name: Azure Login with retry
        uses: nick-fields/retry-action@v2
        with:
          timeout_minutes: 5
          max_attempts: 3
          command: |
            # Use azure/login@v2 with exponential backoff
      
      - name: Setup ACR with validation
        run: |
          # Validate ACR exists before trying to use it
          if ! az acr show --name ${{ env.ACR_NAME }} 2>/dev/null; then
            echo "Creating ACR..."
            az acr create --resource-group ${{ env.AZURE_RESOURCE_GROUP }} \
              --name ${{ env.ACR_NAME }} --sku Basic --admin-enabled true
          fi
          
          # Verify ACR is accessible
          az acr check-health --name ${{ env.ACR_NAME }} --yes

  # IMPROVED: Better secret management in deployment
  deploy_infrastructure:
    steps:
      - name: Validate Secrets Before Deployment
        run: |
          # Comprehensive secret validation with helpful errors
          scripts/validate-aks-prerequisites.sh --check-secrets-only

      - name: Create AKS Cluster with better error handling
        run: |
          if ! az aks show --resource-group ${{ env.AZURE_RESOURCE_GROUP }} \
               --name ${{ env.AZURE_CLUSTER_NAME }} --query "name" -o tsv 2>/dev/null; then
            echo "Creating AKS cluster..."
            
            # Use az aks create with proper error handling
            if ! az aks create \
              --resource-group ${{ env.AZURE_RESOURCE_GROUP }} \
              --name ${{ env.AZURE_CLUSTER_NAME }} \
              --node-count 1 \
              --enable-addons monitoring \
              --enable-msi-auth \
              --enable-oidc-issuer \
              --enable-workload-identity \
              --network-plugin kubenet \
              --location eastus \
              --generate-ssh-keys \
              --attach-acr ${{ env.ACR_NAME }}; then
              
              echo "Failed to create AKS cluster. Checking for partial creation..."
              az aks show --resource-group ${{ env.AZURE_RESOURCE_GROUP }} \
                --name ${{ env.AZURE_CLUSTER_NAME }} || true
              exit 1
            fi
          fi

      # IMPROVED: ACR Integration
      - name: Attach ACR to AKS
        run: |
          # Ensure AKS can pull from ACR
          az aks update \
            --resource-group ${{ env.AZURE_RESOURCE_GROUP }} \
            --name ${{ env.AZURE_CLUSTER_NAME }} \
            --attach-acr ${{ env.ACR_NAME }}
```

### 5. Documentation Updates

#### A. First-Time Setup Guide

**File**: `docs/DEPLOYMENT/AKS_FIRST_TIME_SETUP.md`

**Content**:
```markdown
# AKS Deployment - First Time Setup

## Prerequisites
- Azure account with active subscription
- GitHub repository with admin access
- Azure CLI installed locally
- GitHub CLI installed locally
- Domain name with Cloudflare DNS (optional but recommended)

## Step 1: Clone Repository
git clone https://github.com/yourusername/CloudToLocalLLM.git
cd CloudToLocalLLM

## Step 2: Azure Infrastructure Setup
./scripts/setup-azure-aks-infrastructure.sh

Follow the prompts:
- Select your Azure subscription
- Choose location (default: eastus)
- Confirm resource names
- Wait for infrastructure creation (~5-10 minutes)

Output: .azure-deployment-config.json

## Step 3: Configure GitHub Secrets
./scripts/setup-github-secrets-aks.sh

Provide when prompted:
- Stripe API keys (test and live)
- Cloudflare API tokens
- Supabase credentials
- Sentry DSN (optional)

The script will:
- Auto-generate secure passwords for database and JWT
- Set all GitHub secrets
- Validate configuration

## Step 4: Trigger Deployment
git push origin main

The GitHub Actions workflow will automatically:
- Build Docker images
- Push to Azure Container Registry
- Create AKS cluster (if not exists)
- Deploy all services
- Configure DNS (if using Cloudflare)

## Step 5: Verify Deployment
./scripts/verify-aks-deployment.sh

## Troubleshooting
See: docs/DEPLOYMENT/AKS_TROUBLESHOOTING.md
```

#### B. Troubleshooting Guide

**File**: `docs/DEPLOYMENT/AKS_TROUBLESHOOTING.md`

**Content structure**:
- Common error messages and solutions
- Azure CLI authentication issues
- Service Principal permission problems
- ACR authentication failures
- AKS cluster creation failures
- Kubernetes deployment issues
- Network and DNS problems

### 6. Additional Helper Scripts

#### A. Cleanup Script

**File**: `scripts/cleanup-azure-aks-deployment.sh`

**Purpose**: Clean up all Azure resources for fresh start

```bash
#!/usr/bin/env bash
# Safely removes all Azure resources created by the deployment

# Features:
- Lists all resources before deletion
- Asks for confirmation
- Provides option to keep certain resources (like ACR with images)
- Logs all deletion operations
```

#### B. Status Check Script

**File**: `scripts/check-aks-deployment-status.sh`

**Purpose**: Quick status check of deployment

```bash
#!/usr/bin/env bash
# Checks status of entire deployment

# Checks:
1. Azure resources (RG, ACR, AKS, Key Vault)
2. AKS cluster health
3. Pod statuses
4. Service endpoints
5. SSL certificates
6. DNS records (if Cloudflare)
7. Application health endpoints
```

#### C. Cost Estimation Script

**File**: `scripts/estimate-aks-costs.sh`

**Purpose**: Estimate monthly Azure costs

```bash
#!/usr/bin/env bash
# Estimates monthly costs based on current configuration

# Calculates costs for:
- AKS cluster (node pools)
- Container Registry
- Key Vault
- Load Balancer
- Disk storage
- Data transfer

# Provides:
- Current configuration cost
- Recommendations for cost optimization
- Comparison with different SKUs
```

## Implementation Timeline

### Week 1: Core Scripts
- [ ] Day 1-2: Create `setup-azure-aks-infrastructure.sh`
- [ ] Day 3-4: Create `setup-github-secrets-aks.sh`
- [ ] Day 5: Create `validate-aks-prerequisites.sh`

### Week 2: Workflow Improvements
- [ ] Day 1-2: Update `.github/workflows/deploy-aks.yml`
- [ ] Day 3: Add prerequisite validation job
- [ ] Day 4-5: Testing and refinement

### Week 3: Documentation & Helper Scripts
- [ ] Day 1-2: Write comprehensive documentation
- [ ] Day 3: Create helper scripts (cleanup, status, cost estimation)
- [ ] Day 4-5: End-to-end testing on fresh Azure account

### Week 4: Testing & Refinement
- [ ] Day 1-3: Test on multiple fresh Azure accounts
- [ ] Day 4: Fix issues found during testing
- [ ] Day 5: Final documentation review and release

## Testing Plan

### Test Scenarios

1. **Fresh Azure Account (Free Trial)**
   - Create new Azure free trial account
   - Run setup scripts from scratch
   - Verify successful deployment
   - Verify cost is within free tier

2. **Existing Azure Account (Clean State)**
   - Use existing subscription with no resources
   - Run setup scripts
   - Verify idempotent behavior
   - Verify no conflicts

3. **Existing Azure Account (With Resources)**
   - Use subscription with existing resources
   - Run setup scripts with custom names
   - Verify no conflicts with existing resources
   - Verify cleanup script works correctly

4. **GitHub Actions Integration**
   - Fork repository to test account
   - Run setup scripts
   - Trigger workflow via push
   - Verify successful deployment
   - Verify application is accessible

5. **Failure Recovery**
   - Simulate various failure scenarios
   - Verify error messages are helpful
   - Verify recovery procedures work
   - Verify cleanup and retry works

### Success Criteria

- [ ] Setup scripts work on fresh Azure free trial account
- [ ] All steps clearly documented
- [ ] Error messages are actionable
- [ ] Deployment completes in < 30 minutes
- [ ] Application is accessible after deployment
- [ ] All tests pass on at least 3 different Azure accounts
- [ ] Documentation reviewed by someone unfamiliar with the codebase
- [ ] Cost estimation is accurate (±10%)

## Risk Mitigation

### Risk 1: Azure Free Trial Limitations
**Mitigation**: Document limitations clearly, provide alternative configurations for paid accounts

### Risk 2: GitHub Actions Minutes
**Mitigation**: Optimize build times, provide option for self-hosted runners

### Risk 3: Azure Provider Registration Delays
**Mitigation**: Add retry logic, clear progress indicators, estimated wait times

### Risk 4: Breaking Changes in Azure APIs
**Mitigation**: Pin Azure CLI version in workflows, document tested versions

### Risk 5: Service Principal Permission Issues
**Mitigation**: Comprehensive permission validation, detailed troubleshooting guide

## Future Enhancements

1. **Terraform Implementation** (Alternative to scripts)
   - Infrastructure as Code approach
   - Better state management
   - Easier to version and review changes

2. **Multi-Region Deployment**
   - Support for multiple regions
   - Automatic failover configuration
   - Geo-distributed deployment

3. **Cost Optimization**
   - Auto-scaling based on traffic
   - Spot instances for non-production
   - Reserved instances for production
   - Azure Advisor integration

4. **Enhanced Monitoring**
   - Azure Monitor integration
   - Custom dashboards
   - Alerting rules
   - Cost alerts

5. **Disaster Recovery**
   - Automated backups
   - Cross-region replication
   - Restore procedures
   - Business continuity planning

## Maintenance Plan

### Monthly
- [ ] Review Azure costs
- [ ] Update Azure CLI version if needed
- [ ] Review and update documentation
- [ ] Test deployment on fresh account

### Quarterly
- [ ] Update all dependencies
- [ ] Security audit
- [ ] Performance optimization review
- [ ] Cost optimization review

### Annually
- [ ] Major version updates
- [ ] Architecture review
- [ ] Disaster recovery test
- [ ] Capacity planning

## Success Metrics

- **Setup Time**: < 30 minutes from fresh Azure account to deployed application
- **Success Rate**: > 95% successful deployments on first try
- **Documentation Quality**: No questions from new users on clearly documented topics
- **Support Burden**: < 5 support requests per month for deployment issues
- **Cost Predictability**: Actual costs within 10% of estimated costs

## Conclusion

This plan provides a comprehensive approach to fixing the AKS deployment workflow. By implementing these changes, we will:

1. **Reduce Setup Time**: From hours to minutes
2. **Improve Reliability**: From ~70% success rate to >95%
3. **Better Documentation**: Clear, step-by-step guides
4. **Lower Barrier to Entry**: Anyone can deploy to their own Azure account
5. **Easier Maintenance**: Clear procedures for updates and troubleshooting

The implementation will be done in phases, with each phase tested thoroughly before moving to the next. The end result will be a production-ready deployment system that works seamlessly on brand new Azure accounts.

