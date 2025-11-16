# GitHub Actions Workflows

This directory contains all CI/CD workflows for CloudToLocalLLM.

## Workflow Overview

### 1. **CI/CD Pipeline** (`ci-cd-pipeline.yml`)
**Primary deployment workflow for production**

- **Trigger:** Push to `main` branch with changes to:
  - `k8s/**` - Kubernetes manifests
  - `services/**` - Backend services
  - `config/**` - Configuration files
  - `lib/**` - Flutter app code
  - `web/**` - Web assets
  - `pubspec.yaml` - Flutter dependencies
  - `package.json` - Node.js dependencies

- **Jobs:**
  1. **build-images** - Builds and pushes Docker images to Docker Hub
     - API image: `cloudtolocalllm/cloudtolocalllm-api:main-{commit-sha}`
     - Web image: `cloudtolocalllm/cloudtolocalllm-web:main-{commit-sha}`
  
  2. **deploy** - Deploys to Azure AKS
     - Updates Kubernetes deployments with new images
     - Waits for rollout completion
     - Verifies deployment health
     - Purges Cloudflare cache
     - Configures DNS and SSL

- **Status:** ✅ Active and primary deployment pipeline

---

### 2. **Build Docker Images** (`build-images.yml`)
**Validation workflow for PRs and develop branch**

- **Triggers:**
  - Push to `develop` branch
  - Pull requests to `main` or `develop`

- **Jobs:**
  1. **build-api** - Builds API Docker image
  2. **build-web** - Builds Web Docker image
  3. **test-deploy** - Validates Kubernetes manifests (PRs only)

- **Purpose:** 
  - Validate Docker builds on PRs before merging
  - Build images for develop branch
  - Test Kubernetes manifests

- **Status:** ✅ Active for PRs and develop

---

### 3. **Build Release** (`build-release.yml`)
**Desktop application build and release**

- **Trigger:** Push of version tags (e.g., `v4.5.0`)

- **Jobs:**
  1. **version-info** - Extracts version from pubspec.yaml
  2. **build-desktop** - Builds Windows desktop app
  3. **create-release** - Creates GitHub release with artifacts

- **Artifacts:**
  - Windows installer (.exe)
  - Portable package (.zip)
  - SHA256 checksums

- **Status:** ✅ Active for releases

---

### 4. **Bootstrap Secrets** (`bootstrap-secrets.yml`)
**Secrets management workflow**

- **Purpose:** Initialize and manage GitHub secrets
- **Status:** ✅ Available for manual dispatch

---

## Workflow Execution Flow

### For Main Branch (Production)
```
Push to main
    ↓
CI/CD Pipeline triggers
    ├─ Build Images
    │  ├─ Build API image
    │  └─ Build Web image
    ├─ Deploy (waits for build)
    │  ├─ Update AKS deployments
    │  ├─ Wait for rollout
    │  ├─ Verify health
    │  └─ Purge cache & configure DNS
    └─ Complete
```

### For Develop Branch
```
Push to develop
    ↓
Build Images workflow triggers
    ├─ Build API image
    ├─ Build Web image
    └─ Complete (no deployment)
```

### For Pull Requests
```
Create/Update PR
    ↓
Build Images workflow triggers
    ├─ Build API image
    ├─ Build Web image
    ├─ Validate K8s manifests
    └─ Complete (no deployment)
```

### For Releases
```
Push tag (v*.*.*)
    ↓
Build Release workflow triggers
    ├─ Extract version
    ├─ Build desktop app
    ├─ Create GitHub release
    └─ Complete
```

## Environment Variables

All workflows use these environment variables:

```yaml
REGISTRY: cloudtolocalllm
API_IMAGE: cloudtolocalllm/cloudtolocalllm-api
WEB_IMAGE: cloudtolocalllm/cloudtolocalllm-web
```

## Required Secrets

For workflows to function, these secrets must be configured:

- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token
- `AZURE_CREDENTIALS` - Azure service principal credentials (JSON)
- `CLOUDFLARE_API_TOKEN` - Cloudflare API token (optional, for cache purge)

## Troubleshooting

### Workflow Not Triggering
1. Check branch name matches trigger condition
2. Verify path filters match changed files
3. Check secrets are configured
4. Review workflow syntax in GitHub Actions UI

### Build Failures
1. Check Docker Hub credentials
2. Verify Dockerfile paths are correct
3. Review build logs in GitHub Actions

### Deployment Failures
1. Verify Azure credentials
2. Check AKS cluster is accessible
3. Verify Kubernetes manifests are valid
4. Check image tags match deployed versions

## Best Practices

1. **Always test on develop first** - Use develop branch to validate changes
2. **Use PRs for review** - Build images run on PRs for validation
3. **Tag for releases** - Use semantic versioning for desktop releases
4. **Monitor deployments** - Check GitHub Actions for deployment status
5. **Keep secrets secure** - Never commit secrets to repository

## Future Improvements

- [ ] Add automated testing to CI/CD pipeline
- [ ] Add security scanning for Docker images
- [ ] Add performance benchmarking
- [ ] Add automated rollback on deployment failure
- [ ] Add Slack notifications for deployment status
