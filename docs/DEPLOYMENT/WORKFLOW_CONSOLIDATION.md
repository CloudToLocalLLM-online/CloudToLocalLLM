# GitHub Actions Workflow Consolidation

## Overview

This document explains the consolidation of GitHub Actions workflows to eliminate redundant runs and fix deployment issues.

## Changes Made

### 1. Workflow Consolidation

**Before:**
- `cloudrun-deploy.yml` - Cloud Run deployment (triggered on push to main)
- `ci.yml` - CI validation (triggered only on PRs)
- `build-release.yml` - Desktop releases (triggered on tags)

**After:**
- `cloudrun-deploy.yml` - **Renamed to CI/CD Pipeline** - Combined validation and deployment
- `build-release.yml` - **Unchanged** - Desktop releases (separate purpose)

### 2. Key Improvements

#### Validation Before Deployment
- **CI validation now runs on both PRs and pushes** to main/master
- **Deployment only occurs after successful validation**
- **No more failed deployments due to code issues**

#### GCIP API Key Validation
- **Added explicit GCIP API key validation** before deployment
- **Clear error messages** if the key is missing or invalid
- **Supports both GitHub Secrets and GCP Secret Manager**

#### Conditional Execution
- **Validation runs on all events** (PRs and pushes)
- **Build/Deploy only runs on pushes** to main/master
- **Eliminates redundant workflow runs**

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
