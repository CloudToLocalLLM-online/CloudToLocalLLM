# Docker Image Versioning System

## Overview

The CloudToLocalLLM project uses semantic versioning for all Docker images. The **web deployment is the source of truth** for the application version.

## Version Format

```
<major>.<minor>.<patch>
```

Example: `4.20.5`

### Service-Specific Tags

Each service gets tagged with both the app version and a service identifier:

- **Web**: `4.20.5`
- **API**: `4.20.5-api`
- **Streaming Proxy**: `4.20.5-proxy`
- **Postgres**: `4.20.5-postgres`
- **Base**: `4.20.5-base`

### Additional Tags

Every image also gets tagged with:
- **Git SHA**: `abc123def456...` (for traceability)
- **Latest**: `latest` (for convenience)

## Version File

Version information is stored in `assets/version.json`:

```json
{
  "version": "4.20.5",
  "build_number": "202512031420",
  "build_date": "2025-12-03T14:20:00Z",
  "git_commit": "b61da9d3",
  "buildTimestamp": "2025-12-03 14:20:00"
}
```

## Automatic Version Bumping

### During Web Builds

When `lib/**`, `web/**`, or `pubspec.**` files change:

1. **Version is auto-bumped** (patch by default)
2. **version.json is updated**
3. **Change is committed** with `[skip ci]`
4. **Docker image is tagged** with new version

### Bump Types

- **Patch** (4.20.5 → 4.20.5): Bug fixes, minor changes
- **Minor** (4.20.5 → 4.20.5): New features, backwards compatible
- **Major** (4.20.5 → 5.0.0): Breaking changes

## Manual Version Bumping

To manually bump the version:

```bash
# Bump patch (default)
./scripts/bump-version.sh patch

# Bump minor
./scripts/bump-version.sh minor

# Bump major
./scripts/bump-version.sh major
```

The script will:
1. Read current version from `assets/version.json`
2. Increment the appropriate component
3. Update version.json with new version, build number, and git commit
4. Display the new version

**Note**: You still need to commit and push the changes manually when using the script locally.

## Deployment Behavior

### When Services are Built

If a service's source files changed:
- ✅ **Uses semantic version tag** (e.g., `4.20.5-api`)
- ✅ Image is freshly built and tagged
- ✅ Version is tracked and traceable

### When Services are NOT Built

If a service's source files didn't change:
- ✅ **Uses `:latest` tag**
- ✅ Reuses existing image (faster deployment)
- ✅ No unnecessary rebuilds

## Version Tracking

### In Kubernetes

Deployments get annotated with versions:

```yaml
metadata:
  annotations:
    kubernetes.io/revision: "4.20.5"
    deployment.kubernetes.io/timestamp: "2025-12-03T14:20:00Z"
```

### In ACR (Azure Container Registry)

Images are stored with multiple tags:

```
imrightguycloudtolocalllm.azurecr.io/web:4.20.5
imrightguycloudtolocalllm.azurecr.io/web:b61da9d3
imrightguycloudtolocalllm.azurecr.io/web:latest
```

## Release Process

### For New Releases

1. **Web build automatically bumps version**
2. **Version.json is committed** (shows in git history)
3. **All services use the same base version** (with service suffixes)
4. **Tagged images are immutable** (can always rollback)

### Rollback

To rollback to a previous version:

```bash
# List available versions
az acr repository show-tags --name imrightguycloudtolocalllm --repository web --orderby time_desc

# Update deployment to use specific version
kubectl set image deployment/web web=imrightguycloudtolocalllm.azurecr.io/web:4.20.5 -n cloudtolocalllm
```

## Benefits

1. **Clear Version History**: Every deployment has a semantic version
2. **Easy Rollbacks**: All versions are tagged and immutable
3. **Traceable**: Git commit SHA is included in every image
4. **Efficient**: Only changed services are rebuilt
5. **Consistent**: Web version is the source of truth for the entire app

## Example Deployment Scenario

### Scenario: Fix Bug in API Backend

```
Changes detected: services/api-backend/**
Current version: 4.20.5

Build Process:
├─ Web: SKIP (no changes) → use 4.20.5 (latest)
├─ API: BUILD → tag as 4.20.5-api
├─ Proxy: SKIP (no changes) → use latest
└─ Postgres: SKIP (no changes) → use latest

Deployment:
├─ Web: 4.20.5 (cached)
├─ API: 4.20.5-api (new)
├─ Proxy: latest (cached)
└─ Postgres: latest (cached)
```

### Scenario: New Feature in Web

```
Changes detected: lib/**, web/**
Current version: 4.20.5

Versioning:
└─ Bump to: 4.20.5 (patch bump)

Build Process:
├─ Web: BUILD → tag as 4.20.5, 4.20.5-api, etc.
├─ API: SKIP → use latest
├─ Proxy: SKIP → use latest
└─ Postgres: SKIP → use latest

Deployment:
├─ Web: 4.20.5 (new version!)
├─ API: latest (cached)
├─ Proxy: latest (cached)
└─ Postgres: latest (cached)
```

## CI/CD Integration

The versioning system is fully integrated into `.github/workflows/deploy-aks.yml`:

- **Automatic detection** of file changes
- **Automatic version bumping** for web builds
- **Automatic tagging** of all Docker images
- **Automatic commit** of version.json
- **Deployment with correct versions**

## Security Note

- ✅ Scoped Cloudflare API token for cache purging
- ✅ No Global API Key in CI/CD
- ✅ Semantic versions for all services
- ✅ Immutable tags for rollback safety

