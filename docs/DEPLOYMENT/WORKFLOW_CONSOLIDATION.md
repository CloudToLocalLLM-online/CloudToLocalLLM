# Streamlined Deployment Workflow

## Overview

This document explains the final streamlined approach to GitHub Actions workflows, focusing on deployment-only automation with validation happening before code reaches the main branch.

## Final Workflow Structure

### 1. Single-Purpose Workflows

**Current Setup:**
- `cloudrun-deploy.yml` - **Deploy to Google Cloud Run** - Pure deployment workflow
- `build-release.yml` - **Desktop releases** - Separate purpose (unchanged)
- `Push on main` - **CodeQL security scanning** - Automatic GitHub security (cannot be disabled on public repos)

### 2. Philosophy Change

**OLD Approach (Problematic):**
- Validation during deployment
- Every push triggers deployment
- Multiple workflows running simultaneously
- Slow deployment due to validation overhead

**NEW Approach (Streamlined):**
- Validation happens locally/pre-commit
- Deployment only when explicitly needed
- Single focused deployment workflow
- Fast, reliable deployments

### 3. Deployment Workflow Details

#### Triggers (Intentional Only)
- **Manual dispatch** - Explicit deployment via GitHub Actions UI
- **Deployment file changes** - Only when these paths change:
  - `config/cloudrun/**` - Cloud Run configuration
  - `services/**` - Service code changes
  - `Dockerfile*` - Container definitions
  - `.github/workflows/cloudrun-deploy.yml` - Workflow changes

#### Jobs (Deployment-Focused)
1. **Build** - Container images for all services
2. **Setup Database** - Cloud SQL PostgreSQL (if needed)
3. **Deploy** - Cloud Run services with GCIP API key injection
4. **Verify** - Post-deployment health checks

#### No Validation in Deployment
- **Removed Flutter analyze, tests, Node.js lint** from deployment workflow
- **Assumption: Code reaching main is already validated**
- **Fast deployment without validation overhead**

## GCIP API Key Configuration

### Current Issue
The deployment failures were caused by missing GCIP API key configuration. The key is hardcoded in `lib/config/app_config.dart` but needs to be injected at runtime for Cloud Run.

### Solution Options

#### Option 1: Use GitHub Secrets (Recommended)
```bash
# Add the GCIP API key as a GitHub repository secret
gh secret set GCIP_API_KEY --body "AIzaSyBvOkBwN6Ca6FNaOeMaMfeM1ZuPiKlBqMY"
```

#### Option 2: Use GCP Secret Manager
```bash
# Create the secret in GCP Secret Manager
echo -n "AIzaSyBvOkBwN6Ca6FNaOeMaMfeM1ZuPiKlBqMY" | \
  gcloud secrets create gcip-api-key --data-file=-
```

### How It Works

1. **GitHub Actions** retrieves the GCIP API key from secrets
2. **Cloud Run deployment** passes the key as an environment variable
3. **Container entrypoint** injects the key into `index.html` at runtime
4. **Flutter app** resolves the key from the meta tag

## Workflow Structure

```mermaid
graph TD
    A[Push to main] --> B[Validate]
    C[Pull Request] --> B
    B --> D{Validation Passed?}
    D -->|Yes| E[Build Images]
    D -->|No| F[Stop - Fix Issues]
    E --> G[Setup Database]
    E --> H[Deploy Services]
    G --> H
    H --> I[Verify Deployment]
```

## Trigger Optimization

### Before
- Multiple workflows running simultaneously
- CI only on PRs, deployment without validation
- Redundant security scans and builds

### After
- Single workflow with proper job dependencies
- Validation before deployment
- No redundant runs

## Next Steps

1. **Set the GCIP API key** using Option 1 or 2 above
2. **Push a commit** to trigger the new consolidated workflow
3. **Monitor the deployment** for successful completion
4. **Test the authentication flow** on the deployed web app

## Troubleshooting

### If deployment still fails:

1. **Check GitHub Secrets:**
   ```bash
   gh secret list
   ```

2. **Verify GCP Secret Manager:**
   ```bash
   gcloud secrets list
   ```

3. **Check workflow logs** for specific error messages

4. **Validate GCIP API key** has proper restrictions:
   - Identity Toolkit API enabled
   - API restrictions include Identity Toolkit API
   - HTTP referrers configured for your domain

### Common Issues

- **Missing GCIP_API_KEY**: Set the secret as described above
- **Invalid API key format**: Should start with "AIza"
- **API restrictions**: Ensure the key works with Identity Toolkit API
- **WIF authentication**: Verify workload identity federation is configured

## Benefits

- ✅ **No more redundant workflow runs**
- ✅ **Validation before deployment**
- ✅ **Clear error messages for missing configuration**
- ✅ **Faster feedback on code issues**
- ✅ **Reduced GitHub Actions usage**
- ✅ **Streamlined CI/CD pipeline**
