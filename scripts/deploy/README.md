# CloudToLocalLLM Deployment Scripts

This directory contains the deployment scripts for the CloudToLocalLLM application.

## Architecture Overview

**VPS Deployment (PowerShell-Orchestrated):**
- VPS deployment is orchestrated by PowerShell scripts from Windows
- PowerShell scripts use SSH to execute bash scripts on the remote VPS
- Windows users run `scripts/powershell/Deploy-CloudToLocalLLM.ps1` for deployment
- VPS-side operations use bash scripts (.sh files) for Linux-specific tasks
- **WSL is NOT required for deployment operations**

**Windows Package Management:**
- Windows desktop application packaging (MSI, NSIS, Portable ZIP) handled by PowerShell scripts in `scripts/powershell/`
- Local Windows builds and testing use PowerShell scripts
- Windows-specific dependency management (Chocolatey, Windows features) stays in PowerShell

## Main Deployment Orchestration Script

### `Deploy-CloudToLocalLLM.ps1`
This PowerShell script is the primary entry point for deploying the CloudToLocalLLM application. It orchestrates the entire deployment workflow from a Windows environment, including version management, local desktop application builds, GitHub Release creation, and remote VPS deployment via SSH.

It leverages the following bash scripts on the remote VPS:
- `complete_deployment.sh`: Orchestrates the core VPS deployment, including updates, container management, and verification.
- `sync_versions.sh`: Synchronizes version information across various project files.
- `update_and_deploy.sh`: Handles the core VPS deployment tasks (Git pull, Flutter build, Docker management).
- `verify_deployment.sh`: Performs comprehensive post-deployment health checks and validations.

#### Usage

**Windows Users (Recommended):**
```powershell
# Full deployment with version increment (e.g., patch)
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -VersionIncrement patch

# Full deployment without user interaction (e.g., for CI/CD)
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -Force -VersionIncrement patch

# Dry run (shows what would be done without executing changes)
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -DryRun

# Deploy to Staging environment
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -Environment Staging
```

**VPS-side Bash Scripts (Executed via SSH by `Deploy-CloudToLocalLLM.ps1`):**
These scripts are not intended for direct manual execution unless you are performing specific debugging or maintenance tasks directly on the VPS.
- `complete_deployment.sh`
- `sync_versions.sh`
- `update_and_deploy.sh`
- `verify_deployment.sh`

#### Prerequisites (for the local machine running `Deploy-CloudToLocalLLM.ps1`)
- PowerShell 7+
- Git
- SSH client (usually built-in on Windows)
- GitHub CLI (for automatic GitHub Release creation)
- Flutter SDK (for local desktop builds)
- Node.js and npm (for Playwright E2E tests if enabled)

#### Prerequisites (for the VPS)
- Flutter SDK installed at `/opt/flutter/bin/flutter`
- Docker and Docker Compose (v2) installed
- SSH server configured and accessible by the `cloudllm` user
- Proper file permissions for the `cloudllm` user in `/opt/cloudtolocalllm`
- SSL certificates configured (e.g., Let's Encrypt)

## Other Scripts

### `cleanup_containers.sh`
Utility script to clean up Docker containers and images.

### PowerShell Scripts
Various PowerShell scripts for Windows-based deployment scenarios (legacy).

## Deployment Workflow

### Complete Deployment Process
1. **Local Development**: Make changes and commit locally.
2. **Push to Git**: `git push origin master` (ensure all changes are pushed).
3. **Initiate Deployment**: Run the main PowerShell script from your local Windows machine:
   ```powershell
   .\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -VersionIncrement patch
   ```
   (Adjust `-VersionIncrement` as needed, or add `-Force` for CI/CD environments).
4. **Automated VPS Deployment**: The PowerShell script will handle SSH connection, version synchronization, Flutter desktop builds, GitHub Release creation, and remote execution of the necessary bash scripts on the VPS.
5. **Verification**: The deployment process includes automated verification steps. You can also manually check the application at `https://app.cloudtolocalllm.online`.

### Security Notes
- All deployment operations run as the `cloudllm` user (non-root)
- SSL certificates are managed by Let's Encrypt
- Docker containers run with appropriate security settings

### Troubleshooting
- Check container logs: `docker compose -f docker-compose.yml logs`
- Verify container status: `docker compose -f docker-compose.yml ps`
- Check SSL certificates: `ls -la certbot/conf/live/cloudtolocalllm.online/`

## Cleaned Up Scripts
The following redundant scripts have been removed to maintain a clean and focused deployment workflow:
- `scripts/deploy/deployment_utils.sh`
- `scripts/deploy/deploy_tunnel_system.sh`
- `scripts/deploy/deploy-with-tests.sh`
- `scripts/deploy/Deploy-WithTests.ps1`
- `scripts/deploy/git_monitor.sh`
- `scripts/deploy/install_vps_automation.sh`

This ensures a single, clear deployment workflow orchestrated by `Deploy-CloudToLocalLLM.ps1`.
