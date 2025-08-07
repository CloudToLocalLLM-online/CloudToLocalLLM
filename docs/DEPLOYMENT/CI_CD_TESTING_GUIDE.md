# CI/CD Pipeline Testing and Validation Guide

This document provides comprehensive testing procedures for the CloudToLocalLLM CI/CD pipeline to ensure all components work correctly.

## Pre-Testing Setup

### 1. GitHub Repository Secrets

Before testing, ensure all required secrets are configured:

```bash
# Verify secrets are set (will show names only, not values)
gh secret list
```

**Required secrets:**
- `GOOGLE_CLOUD_CREDENTIALS`
- `GCP_PROJECT_ID` 
- `GCP_REGION`
- `FIREBASE_PROJECT_ID`

### 2. Local Environment Setup

**Windows Development Environment:**
```powershell
# Verify PowerShell version
$PSVersionTable.PSVersion

# Verify Flutter installation
flutter --version

# Verify Git configuration
git config --list

# Verify GitHub CLI
gh --version

# Test GitHub authentication
gh auth status
```

**Required tools:**
- PowerShell 5.1+
- Flutter SDK 3.24.3+
- Git with SSH access
- GitHub CLI (`gh`)

### 3. Google Cloud Setup

```bash
# Verify service account permissions
gcloud auth activate-service-account --key-file=service-account-key.json
gcloud projects list
gcloud run services list --region=us-east4
```

## Testing Procedures

### Phase 1: Local Desktop Build Testing

#### Test 1.1: PowerShell Script Validation

```powershell
# Test script syntax and parameters
Get-Help .\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -Full

# Dry run test
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -DryRun -Verbose
```

**Expected Results:**
- ✅ Script loads without syntax errors
- ✅ All parameters are recognized
- ✅ Dry run completes without errors
- ✅ All prerequisite checks pass

#### Test 1.2: Version Management

```powershell
# Test version increment
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -VersionIncrement build -DryRun
```

**Validation Checklist:**
- [ ] Version extracted from `pubspec.yaml`
- [ ] Version incremented correctly
- [ ] Version files updated (`pubspec.yaml`, `assets/version.json`, etc.)
- [ ] Git commit message generated correctly

#### Test 1.3: Build Process

```powershell
# Test actual build (without dry run)
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -VersionIncrement patch
```

**Validation Checklist:**
- [ ] Flutter dependencies installed successfully
- [ ] Windows desktop build completes
- [ ] Linux AppImage build attempts (may fail in WSL)
- [ ] Build artifacts generated in `dist/` directory
- [ ] SHA256 checksums created

#### Test 1.4: GitHub Release Creation

**Validation Checklist:**
- [ ] Git tag created with correct version
- [ ] GitHub release created successfully
- [ ] Release assets uploaded (Windows ZIP, Linux AppImage)
- [ ] SHA256 checksums included
- [ ] Release notes generated correctly

#### Test 1.5: Releases Branch Creation

**Validation Checklist:**
- [ ] `releases/v{version}` branch created
- [ ] Build artifacts committed to releases branch
- [ ] Branch pushed to GitHub successfully
- [ ] GitHub Actions triggered by releases branch push

### Phase 2: Cloud Deployment Testing

#### Test 2.1: GitHub Actions Workflow Validation

```bash
# Trigger cloud deployment workflow
git add .
git commit -m "test: Trigger cloud deployment"
git push origin main
```

**Monitor in GitHub Actions:**
1. Go to repository → Actions tab
2. Find "Deploy to Google Cloud Run" workflow
3. Monitor execution progress

**Validation Checklist:**
- [ ] Workflow triggered by main branch push
- [ ] Security and validation checks pass
- [ ] Container images build successfully
- [ ] Images pushed to Artifact Registry
- [ ] Cloud Run services deploy successfully
- [ ] Health checks pass
- [ ] Deployment summary generated

#### Test 2.2: Service Deployment Verification

```bash
# Check deployed services
gcloud run services list --region=us-east4

# Get service URLs
gcloud run services describe cloudtolocalllm-web --region=us-east4 --format='value(status.url)'
gcloud run services describe cloudtolocalllm-api --region=us-east4 --format='value(status.url)'
gcloud run services describe cloudtolocalllm-streaming --region=us-east4 --format='value(status.url)'
```

**Validation Checklist:**
- [ ] All three services deployed (web, api, streaming)
- [ ] Services are in "Ready" state
- [ ] Service URLs accessible
- [ ] Health endpoints respond correctly

#### Test 2.3: Manual Workflow Dispatch

```bash
# Test manual deployment via GitHub Actions
# Go to Actions → Deploy to Google Cloud Run → Run workflow
```

**Test Parameters:**
- Service: `all`
- Environment: `production`

**Validation Checklist:**
- [ ] Manual workflow dispatch works
- [ ] Service selection parameter works
- [ ] Environment parameter works
- [ ] Deployment completes successfully

### Phase 3: Desktop Release Workflow Testing

#### Test 3.1: Releases Branch Trigger

**Automatic Trigger:**
The PowerShell script should have created a `releases/v*` branch that triggers the desktop build workflow.

**Manual Trigger:**
```bash
# Go to Actions → Build Desktop Apps & Create Release → Run workflow
# Set version_tag: v4.0.87 (or current version)
# Set create_release: true
```

**Validation Checklist:**
- [ ] Workflow triggered by releases branch push
- [ ] Version information extracted correctly
- [ ] Multi-platform builds start (Windows, macOS, Linux)

#### Test 3.2: Cross-Platform Builds

**Monitor build matrix execution:**
- Windows build on `windows-latest`
- macOS build on `macos-latest`  
- Linux build on `ubuntu-latest`

**Validation Checklist:**
- [ ] Flutter SDK installed on all platforms
- [ ] Platform dependencies installed correctly
- [ ] Desktop applications build successfully
- [ ] Portable packages created (ZIP, tar.gz)
- [ ] SHA256 checksums generated
- [ ] Build artifacts uploaded

#### Test 3.3: GitHub Release Creation

**Validation Checklist:**
- [ ] All platform artifacts downloaded
- [ ] Release assets prepared correctly
- [ ] GitHub release created with correct tag
- [ ] Release notes generated
- [ ] All platform binaries attached to release
- [ ] Checksums included in release

### Phase 4: End-to-End Integration Testing

#### Test 4.1: Complete Workflow

1. **Make a code change**
2. **Run PowerShell script**
3. **Verify cloud deployment**
4. **Verify desktop release**

```powershell
# Complete end-to-end test
git checkout main
# Make a small change (e.g., update a comment)
git add .
git commit -m "test: End-to-end CI/CD pipeline test"
git push origin main

# Run desktop build
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -VersionIncrement patch
```

**Validation Checklist:**
- [ ] Code changes trigger cloud deployment
- [ ] PowerShell script creates desktop release
- [ ] Both workflows complete successfully
- [ ] No conflicts between workflows
- [ ] All services remain operational

#### Test 4.2: Rollback Testing

```bash
# Test rollback capability
gcloud run services update cloudtolocalllm-web \
  --image=us-east4-docker.pkg.dev/cloudtolocalllm-468303/cloud-run-source-deploy/web:previous-sha \
  --region=us-east4
```

**Validation Checklist:**
- [ ] Previous version can be deployed
- [ ] Services remain healthy during rollback
- [ ] Rollback completes successfully

## Troubleshooting Common Issues

### PowerShell Script Issues

#### Issue: "Execution Policy" Error
```powershell
# Solution: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Issue: "GitHub CLI not found"
```powershell
# Solution: Install GitHub CLI
winget install GitHub.cli
# Or download from https://cli.github.com/
```

#### Issue: "Flutter not found"
```powershell
# Solution: Add Flutter to PATH
$env:PATH += ";C:\flutter\bin"
```

### GitHub Actions Issues

#### Issue: "Authentication failed"
**Solution:** Verify `GOOGLE_CLOUD_CREDENTIALS` secret contains valid JSON

#### Issue: "Permission denied"
**Solution:** Check service account has required IAM roles

#### Issue: "Build timeout"
**Solution:** Increase timeout in workflow or optimize build process

### Cloud Deployment Issues

#### Issue: "Service not found"
**Solution:** Verify service names match configuration

#### Issue: "Image not found"
**Solution:** Check Artifact Registry for pushed images

#### Issue: "Health check failed"
**Solution:** Verify application starts correctly and health endpoints work

## Performance Benchmarks

### Expected Build Times

| Component | Expected Duration |
|-----------|------------------|
| PowerShell Script | 10-15 minutes |
| Cloud Deployment | 8-12 minutes |
| Desktop Builds | 15-25 minutes |
| Total Pipeline | 20-30 minutes |

### Resource Usage

| Service | CPU | Memory | Expected Load |
|---------|-----|--------|---------------|
| Web | 1 vCPU | 1GB | Low-Medium |
| API | 2 vCPU | 2GB | Medium |
| Streaming | 1 vCPU | 1GB | Low |

## Success Criteria

### ✅ Pipeline Validation Complete

- [ ] PowerShell script builds desktop apps without cloud deployment
- [ ] GitHub Actions automatically deploys cloud infrastructure on main branch changes
- [ ] GitHub releases are created automatically with cross-platform desktop binaries
- [ ] No overlap between local and cloud build processes
- [ ] Existing cloud deployment functionality preserved and automated
- [ ] All documentation updated and accurate

### ✅ Quality Gates

- [ ] All builds complete successfully
- [ ] All tests pass
- [ ] Security scans pass
- [ ] Performance benchmarks met
- [ ] Documentation complete and accurate

## Monitoring and Maintenance

### Ongoing Monitoring

1. **GitHub Actions**: Monitor workflow success rates
2. **Google Cloud**: Monitor service health and performance
3. **Releases**: Monitor download statistics and user feedback

### Regular Maintenance

1. **Dependencies**: Update Flutter SDK and dependencies monthly
2. **Secrets**: Rotate service account keys quarterly
3. **Documentation**: Update guides when processes change

## Next Steps After Validation

1. **Production Deployment**: Deploy to production environment
2. **User Training**: Train team on new CI/CD processes
3. **Monitoring Setup**: Configure alerts and dashboards
4. **Backup Procedures**: Implement backup and disaster recovery

For additional support, refer to:
- [CI/CD Pipeline Guide](./CI_CD_PIPELINE_GUIDE.md)
- [GitHub Secrets Setup](./GITHUB_SECRETS_SETUP.md)
- [Complete Deployment Workflow](./COMPLETE_DEPLOYMENT_WORKFLOW.md)
