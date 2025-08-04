# CloudToLocalLLM Automated Deployment Workflow

This document provides comprehensive guidance for using the automated deployment workflow for CloudToLocalLLM. The workflow enables seamless deployment from a Windows development environment to a Linux VPS using a unified PowerShell script.

## Overview

The automated deployment workflow provides a single entry point for the complete CloudToLocalLLM deployment process. It orchestrates:

- Pre-flight environment validation
- Version management and incrementation
- Flutter web application building
- VPS deployment via SSH
- Post-deployment verification
- Optional GitHub release creation
- Automatic rollback on failure

The workflow can be triggered either manually via PowerShell or through Kiro hooks for automated execution.

## Prerequisites

Before using the deployment workflow, ensure your environment meets these requirements:

- **Windows Development Environment**:
  - PowerShell 5.1+ with execution policy allowing scripts
  - Git installed and configured
  - Flutter SDK installed on Windows
  - SSH key-based access to target VPS configured
  - WSL2 with Ubuntu 24.04 distribution (ONLY for Linux application builds, NOT for deployment)

- **VPS Environment**:
  - Linux VPS with Docker and Docker Compose
  - Project repository cloned to `/opt/cloudtolocalllm` (default)
  - SSH key authentication configured

## Manual Deployment

### Basic Usage

To run a deployment with default settings (production environment, build version increment):

```powershell
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1
```

This will:
1. Validate your environment
2. Increment the build version
3. Build the Flutter web application
4. Deploy to the production VPS
5. Verify the deployment
6. Roll back automatically if verification fails

### Command-Line Parameters

The deployment script supports various parameters to customize the deployment process:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Environment` | Target deployment environment (Local, Staging, Production) | `Production` |
| `-VersionIncrement` | Type of version increment (build, patch, minor, major) | `build` |
| `-VPSHost` | Override default VPS hostname | `cloudtolocalllm.online` |
| `-VPSUser` | Override default VPS username | `cloudllm` |
| `-VPSProjectPath` | Override default VPS project path | `/opt/cloudtolocalllm` |
| `-WSLDistribution` | WSL distribution name | `Ubuntu-24.04` |
| `-TimeoutSeconds` | Maximum timeout for deployment operations | `1800` |
| `-SkipBuild` | Skip the Flutter build process | `false` |
| `-SkipVerification` | Skip post-deployment verification | `false` |
| `-SkipVersionUpdate` | Skip version management and increment | `false` |
| `-Force` | Force deployment without user confirmation prompts | `false` |
| `-AutoRollback` | Enable automatic rollback on deployment failure | `true` |
| `-CreateGitHubRelease` | Create a GitHub release after successful deployment | `false` |
| `-DryRun` | Show what would be done without executing actual changes | `false` |
| `-Verbose` | Enable verbose logging output | `false` |
| `-Help` | Display detailed help information | `false` |

### Examples

**Deploy to staging environment with patch version increment:**
```powershell
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -Environment Staging -VersionIncrement patch
```

**Preview deployment actions without executing:**
```powershell
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -DryRun -Verbose
```

**Force deployment and create GitHub release on success:**
```powershell
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -Force -CreateGitHubRelease
```

**Skip build and deploy existing artifacts:**
```powershell
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -SkipBuild
```

## Deployment Workflow Phases

The deployment process consists of several phases:

1. **Pre-flight Environment Validation**
   - Validates WSL2 and Ubuntu 24.04 distribution
   - Checks Flutter installation in WSL
   - Verifies Git configuration
   - Tests SSH connectivity to VPS

2. **Version Management**
   - Increments version according to specified type
   - Updates version in all required files (pubspec.yaml, version.json)
   - Commits version changes to Git

3. **Flutter Web Application Build**
   - Installs Flutter dependencies
   - Builds Flutter web application in release mode
   - Verifies build output

4. **VPS Deployment**
   - Connects to VPS via SSH
   - Executes existing complete_deployment.sh script
   - Streams deployment logs back to local console

5. **Post-deployment Verification**
   - Runs verify_deployment.sh on VPS
   - Checks HTTP/HTTPS endpoints
   - Validates SSL certificates
   - Verifies container health
   - Checks application functionality

6. **GitHub Release (Optional)**
   - Creates GitHub release with proper version tag
   - Generates release notes from recent commits
   - Tags the release with proper version

7. **Cleanup and Status Reporting**
   - Provides detailed deployment status report
   - Cleans up temporary files
   - Logs deployment results

## Logging and Output

The deployment script provides comprehensive logging:

- Console output with color-coded messages
- Detailed log file in the `logs/` directory
- Progress indicators for long-running operations
- Verbose mode for additional debugging information

Log files are named with timestamps (e.g., `deployment_20250718_015633.log`) and contain all deployment actions and results.

## Strict Verification Policy

The deployment workflow enforces a strict verification policy:

- **Zero Tolerance**: Any warning or error triggers deployment failure
- **Comprehensive Checks**: HTTP/HTTPS endpoints, SSL certificates, container health
- **Automatic Rollback**: Failed deployments trigger automatic rollback
- **Resource Validation**: Checks disk space and memory usage

This ensures only high-quality deployments reach production.

## Troubleshooting

### Common Issues

| Issue | Possible Solution |
|-------|------------------|
| PowerShell execution policy | Set execution policy to allow scripts |
| Flutter not found on Windows | Install Flutter SDK and add to PATH |
| SSH connectivity failure | Check SSH key configuration and network connectivity |
| Version update failure | Ensure Git repository is clean and properly configured |
| Build failure | Check Flutter dependencies and Windows environment |
| Deployment timeout | Increase timeout with `-TimeoutSeconds` parameter |
| Verification failure | Check VPS logs and container status |
| WSL2 not available (Linux builds) | Install WSL2 and Ubuntu 24.04 distribution (only for Linux builds) |

### Rollback Procedure

If automatic rollback fails, you can manually roll back using:

```powershell
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -RollbackToVersion "x.y.z"
```

Or directly on the VPS:

```bash
cd /opt/cloudtolocalllm
git checkout v3.x.y
./scripts/deploy/complete_deployment.sh
```

## Advanced Usage

### Customizing Deployment Configuration

For persistent customization, you can modify the default configuration in the script:

```powershell
$Script:DeploymentConfig = @{
    Environment = $Environment
    VPSHost = if ($VPSHost) { $VPSHost } else { "your-custom-host.com" }
    VPSUser = if ($VPSUser) { $VPSUser } else { "your-username" }
    # Additional configuration...
}
```

### Integration with CI/CD Systems

The deployment script can be integrated with CI/CD systems by using the `-Force` parameter to skip confirmations:

```powershell
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -Force -Environment Production -VersionIncrement patch
```

## Security Considerations

- The script uses SSH key-based authentication for secure VPS access
- No passwords are stored in the script or configuration
- All sensitive operations require proper authentication
- The script validates SSH connectivity before attempting deployment

## Further Reading

- [Deployment Workflow Overview](../DEPLOYMENT_WORKFLOW.md)
- [VPS Deployment Guide](../DEPLOYMENT/vps-deployment-guide.md)
- [Version Management Documentation](../VERSIONING/version-management.md)
- [Release Process Documentation](../RELEASE/release-process.md)