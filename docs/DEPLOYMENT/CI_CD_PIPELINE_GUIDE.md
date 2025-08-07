# CloudToLocalLLM CI/CD Pipeline Guide

This document describes the comprehensive CI/CD pipeline for CloudToLocalLLM that separates local desktop builds from cloud infrastructure deployment.

## Overview

The CI/CD pipeline consists of two main workflows:

1. **Local Desktop Builds**: Handled by PowerShell script for Windows development environment
2. **Cloud Infrastructure Deployment**: Automated via GitHub Actions for Google Cloud Run

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │    │   GitHub Repo    │    │  Cloud Services │
│   Local Build   │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │ 1. PowerShell Script  │                       │
         │ ─────────────────────▶│                       │
         │                       │                       │
         │ 2. Push to releases/* │                       │
         │ ─────────────────────▶│                       │
         │                       │ 3. GitHub Actions    │
         │                       │ ─────────────────────▶│
         │                       │    Desktop Release    │
         │                       │                       │
         │ 4. Push to main       │                       │
         │ ─────────────────────▶│                       │
         │                       │ 5. GitHub Actions    │
         │                       │ ─────────────────────▶│
         │                       │    Cloud Deployment   │
```

## Branch Strategy

### Main Branches

- **`main`**: Primary development branch
  - Triggers cloud deployment to Google Cloud Run
  - Contains source code and configuration
  - Protected branch with required status checks

- **`releases/v*`**: Release artifact branches
  - Created by PowerShell script with build artifacts
  - Triggers desktop application release creation
  - Contains compiled binaries and distribution packages

### Workflow Triggers

| Branch Pattern | Trigger | Action |
|----------------|---------|--------|
| `main` | Push | Cloud deployment to Google Cloud Run |
| `releases/v*` | Push | Desktop app build and GitHub release |
| Manual | Workflow dispatch | Both cloud and desktop workflows |

## Local Desktop Build Process

### Prerequisites

- Windows development environment
- PowerShell 5.1 or later
- Flutter SDK 3.24.3+
- Git with SSH access to GitHub
- GitHub CLI (`gh`) for release creation

### PowerShell Script: `Deploy-CloudToLocalLLM.ps1`

**Location**: `scripts/powershell/Deploy-CloudToLocalLLM.ps1`

**Purpose**: Builds desktop applications and creates GitHub releases

#### Usage

```powershell
# Basic usage - increment patch version
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1

# Increment minor version
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -VersionIncrement minor

# Dry run to test without making changes
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -DryRun

# Skip verification steps
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -SkipVerification
```

#### Process Steps

1. **Prerequisites Check**
   - Verify `pubspec.yaml` exists
   - Check for uncommitted changes
   - Validate Git status

2. **Version Management**
   - Increment version number (patch/minor/major/build)
   - Update version files (`pubspec.yaml`, `assets/version.json`, etc.)
   - Commit and push version changes to `main`

3. **Source Preparation**
   - Validate required files
   - Prepare build environment

4. **Desktop Application Build**
   - Build Windows release packages (ZIP, EXE installer)
   - Build Linux AppImage packages (via WSL)
   - Update AUR PKGBUILD for Arch Linux
   - Create GitHub release with all platform binaries

5. **Build Artifacts Commit**
   - Create `releases/v{version}` branch
   - Add build artifacts to releases branch
   - Push releases branch to trigger GitHub Actions

6. **Verification**
   - Validate build artifacts
   - Confirm GitHub release creation
   - Report success status

### Build Artifacts

The PowerShell script generates the following artifacts:

#### Windows
- `cloudtolocalllm-{version}-portable.zip` - Portable application
- `CloudToLocalLLM-Windows-{version}-Setup.exe` - Windows installer
- SHA256 checksums for all packages

#### Linux
- `cloudtolocalllm-{version}.AppImage` - Universal Linux package
- SHA256 checksums

#### Package Managers
- AUR PKGBUILD updates for Arch Linux
- Manual installation packages for other distributions

## Cloud Infrastructure Deployment

### GitHub Actions Workflow: `cloudrun-deploy.yml`

**Location**: `.github/workflows/cloudrun-deploy.yml`

**Purpose**: Automated deployment to Google Cloud Run

#### Trigger Conditions

- Push to `main` or `master` branch
- Changes to specific paths:
  - `lib/**` (Flutter application code)
  - `services/**` (Backend services)
  - `config/cloudrun/**` (Cloud Run configuration)
  - `scripts/cloudrun/**` (Cloud deployment scripts)
- Manual workflow dispatch

#### Deployment Process

1. **Security and Validation**
   - Validate Cloud Run configuration files
   - Check for accidentally committed secrets
   - Verify required Dockerfiles exist

2. **Container Image Build**
   - Build Docker images for each service:
     - Web service (Flutter web app)
     - API service (Node.js backend)
     - Streaming service (WebSocket proxy)
   - Push images to Google Artifact Registry

3. **Cloud Run Deployment**
   - Deploy web service: `cloudtolocalllm-web`
   - Deploy API service: `cloudtolocalllm-api`
   - Deploy streaming service: `cloudtolocalllm-streaming`
   - Configure environment variables and secrets

4. **Post-Deployment Verification**
   - Health checks for all services
   - Retrieve service URLs
   - Generate deployment summary

### Cloud Services

#### Service Configuration

| Service | Purpose | Resources | URL |
|---------|---------|-----------|-----|
| Web | Flutter web app | 1 CPU, 1GB RAM | `app.cloudtolocalllm.online` |
| API | Node.js backend | 2 CPU, 2GB RAM | Internal/Load balanced |
| Streaming | WebSocket proxy | 1 CPU, 1GB RAM | Internal/Load balanced |

#### Environment Variables

- `NODE_ENV=production`
- `LOG_LEVEL=info`
- `DB_TYPE=sqlite`
- `FIREBASE_PROJECT_ID=cloudtolocalllm-auth`

## Desktop Release Workflow

### GitHub Actions Workflow: `build-release.yml`

**Location**: `.github/workflows/build-release.yml`

**Purpose**: Cross-platform desktop builds and GitHub release creation

#### Trigger Conditions

- Push to `releases/**` branches
- Manual workflow dispatch with version tag

#### Build Matrix

| Platform | OS | Output Format |
|----------|----|--------------| 
| Windows | `windows-latest` | ZIP archive |
| macOS | `macos-latest` | ZIP archive |
| Linux | `ubuntu-latest` | Tar.gz archive |

#### Process Steps

1. **Version Information Extraction**
   - Extract version from `pubspec.yaml` or manual input
   - Generate tag name and release name

2. **Multi-Platform Desktop Builds**
   - Set up Flutter SDK on each platform
   - Install platform-specific dependencies
   - Build desktop applications
   - Create portable packages with checksums

3. **GitHub Release Creation**
   - Collect all platform artifacts
   - Generate release notes
   - Create GitHub release with binaries
   - Upload checksums for verification

## Required Secrets

### GitHub Repository Secrets

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `GOOGLE_CLOUD_CREDENTIALS` | Service account JSON | `{"type": "service_account", ...}` |
| `GCP_PROJECT_ID` | Google Cloud project ID | `cloudtolocalllm-468303` |
| `GCP_REGION` | Deployment region | `us-east4` |
| `FIREBASE_PROJECT_ID` | Firebase project for auth | `cloudtolocalllm-auth` |

See [GitHub Secrets Setup Guide](./GITHUB_SECRETS_SETUP.md) for detailed configuration instructions.

## Developer Workflow

### For Code Changes

1. **Development**
   ```bash
   # Make changes to source code
   git add .
   git commit -m "Feature: Add new functionality"
   git push origin main
   ```

2. **Automatic Cloud Deployment**
   - GitHub Actions automatically deploys to Google Cloud Run
   - Monitor deployment in Actions tab
   - Verify deployment at `app.cloudtolocalllm.online`

### For Desktop Releases

1. **Local Build and Release**
   ```powershell
   # Run PowerShell script to build and release
   .\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -VersionIncrement patch
   ```

2. **Automatic Desktop Release**
   - Script creates `releases/v{version}` branch
   - GitHub Actions builds cross-platform binaries
   - GitHub release created with all platform packages

### For Hotfixes

1. **Emergency Deployment**
   ```bash
   # Make hotfix
   git add .
   git commit -m "Hotfix: Critical bug fix"
   git push origin main
   ```

2. **Manual Desktop Release**
   ```powershell
   # Create emergency desktop release
   .\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -VersionIncrement build -Force
   ```

## Monitoring and Troubleshooting

### GitHub Actions Monitoring

- **Actions Tab**: Monitor workflow execution
- **Deployment Logs**: Review detailed logs for failures
- **Status Checks**: Ensure all checks pass before merging

### Google Cloud Monitoring

- **Cloud Run Console**: Monitor service health and performance
- **Cloud Logging**: Review application logs
- **Cloud Monitoring**: Set up alerts for service issues

### Common Issues

#### Build Failures
- **Flutter SDK Issues**: Verify Flutter version compatibility
- **Dependency Conflicts**: Check `pubspec.yaml` for version conflicts
- **Platform Dependencies**: Ensure all required system packages are installed

#### Deployment Failures
- **Authentication**: Verify GitHub secrets are correctly configured
- **Permissions**: Check service account has required IAM roles
- **Resource Limits**: Monitor Cloud Run resource usage

#### Release Issues
- **GitHub CLI**: Ensure `gh` CLI is authenticated
- **Asset Upload**: Verify build artifacts are generated correctly
- **Version Conflicts**: Check for existing tags/releases

## Best Practices

### Development
- **Commit Messages**: Use conventional commit format
- **Branch Protection**: Require PR reviews for `main` branch
- **Testing**: Run tests before pushing to `main`

### Deployment
- **Gradual Rollout**: Test in staging before production
- **Monitoring**: Set up alerts for deployment failures
- **Rollback Plan**: Have rollback procedures ready

### Security
- **Secret Rotation**: Regularly rotate service account keys
- **Access Control**: Limit repository access to necessary personnel
- **Audit Logs**: Monitor GitHub and Google Cloud audit logs

## Next Steps

1. **Set Up Secrets**: Configure required GitHub repository secrets
2. **Test Pipeline**: Run both workflows to verify functionality
3. **Monitor Deployments**: Set up monitoring and alerting
4. **Documentation**: Keep this guide updated with any changes

For additional help, refer to:
- [GitHub Secrets Setup Guide](./GITHUB_SECRETS_SETUP.md)
- [Complete Deployment Workflow](./COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Scripts Overview](./SCRIPTS_OVERVIEW.md)
