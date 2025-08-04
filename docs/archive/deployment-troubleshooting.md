# Deployment Troubleshooting Guide

This guide provides solutions for common issues encountered during the CloudToLocalLLM automated deployment process. Use this reference to diagnose and resolve problems that may occur during deployment.

## Diagnostic Approach

When troubleshooting deployment issues, follow this systematic approach:

1. **Check the logs** - Review the deployment log file in the `logs/` directory
2. **Identify the failure phase** - Determine which deployment phase failed
3. **Examine specific error messages** - Look for red error messages in the output
4. **Verify environment prerequisites** - Ensure all required components are available
5. **Check VPS connectivity and status** - Verify SSH access and VPS health

## Common Issues by Deployment Phase

### Pre-flight Validation Issues

#### PowerShell Execution Policy Issues

**Symptoms:**
- Error: "Execution of scripts is disabled on this system"
- Error: "PowerShell script cannot be loaded because running scripts is disabled"

**Solutions:**
1. Check current execution policy:
   ```powershell
   Get-ExecutionPolicy
   ```

2. Set execution policy to allow script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. For temporary bypass (single session):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   ```

#### Flutter Not Found on Windows

**Symptoms:**
- Error: "Flutter is not installed or not accessible on Windows"
- Error: "flutter command not found"

**Solutions:**
1. Install Flutter for Windows:
   ```powershell
   # Using Chocolatey (recommended)
   choco install flutter

   # Or download manually from https://flutter.dev/docs/get-started/install/windows
   ```

2. Verify Flutter installation:
   ```powershell
   flutter --version
   flutter doctor
   ```

3. Add Flutter to PATH if needed:
   ```powershell
   $env:PATH += ";C:\tools\flutter\bin"
   # Or add permanently through System Properties > Environment Variables
   ```

#### SSH Connectivity Issues

**Symptoms:**
- Error: "Cannot connect to VPS via SSH. Check SSH keys and network connectivity."

**Solutions:**
1. Verify SSH key configuration:
   ```powershell
   ssh-keygen -l -f ~/.ssh/id_rsa.pub
   ```

2. Test SSH connection manually:
   ```powershell
   ssh -v cloudllm@cloudtolocalllm.online
   ```

3. Ensure SSH key is added to the VPS:
   ```powershell
   ssh-copy-id cloudllm@cloudtolocalllm.online
   ```

4. Check for network connectivity issues:
   ```powershell
   Test-NetConnection cloudtolocalllm.online -Port 22
   ```

5. Run the SSH configuration fix script:
   ```powershell
   .\fix_ssh_config.ps1
   ```

### Version Management Issues

#### Git Repository Not Clean

**Symptoms:**
- Error: "Git working directory is not clean"
- Error: "Version increment failed"

**Solutions:**
1. Check Git status:
   ```powershell
   git status
   ```

2. Commit or stash changes:
   ```powershell
   git add .
   git commit -m "WIP: Save changes before deployment"
   # OR
   git stash
   ```

3. Skip version update if needed:
   ```powershell
   .\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -SkipVersionUpdate
   ```

#### Version Files Inconsistency

**Symptoms:**
- Error: "Version files are inconsistent"
- Error: "Failed to update version in pubspec.yaml"

**Solutions:**
1. Manually synchronize version files:
   ```powershell
   .\scripts\powershell\version_manager.ps1 info
   ```

2. Check version files for consistency:
   ```powershell
   cat pubspec.yaml | grep version
   cat assets/version.json | grep version
   ```

3. Reset version files to last committed state:
   ```powershell
   git checkout -- pubspec.yaml assets/version.json
   ```

### Flutter Build Issues

#### Flutter Build Failures

**Symptoms:**
- Error: "Flutter build failed"
- Error: "build/web directory not found"

**Solutions:**
1. Clean Flutter build cache:
   ```bash
   # Inside WSL
   cd /path/to/project
   flutter clean
   ```

2. Update Flutter dependencies:
   ```bash
   # Inside WSL
   cd /path/to/project
   flutter pub get
   ```

3. Check for Flutter errors:
   ```bash
   # Inside WSL
   cd /path/to/project
   flutter doctor -v
   ```

4. Skip build if you have a pre-built version:
   ```powershell
   .\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -SkipBuild
   ```

#### WSL Path Issues

**Symptoms:**
- Error: "Cannot find project directory in WSL"
- Error: "Path conversion failed"

**Solutions:**
1. Check WSL path mapping:
   ```powershell
   wsl -d Ubuntu-24.04 -e bash -c "echo \$PWD"
   ```

2. Ensure you're running from the project root:
   ```powershell
   cd C:\path\to\cloudtolocalllm
   ```

3. Check WSL mount points:
   ```bash
   # Inside WSL
   mount | grep drvfs
   ```

### VPS Deployment Issues

#### SSH Connection Failures

**Symptoms:**
- Error: "SSH connection failed"
- Error: "Connection timed out during SSH operation"

**Solutions:**
1. Verify VPS is online:
   ```powershell
   Test-NetConnection cloudtolocalllm.online -Port 22
   ```

2. Check SSH configuration:
   ```powershell
   cat ~/.ssh/config
   ```

3. Try connecting with verbose output:
   ```powershell
   ssh -v cloudllm@cloudtolocalllm.online
   ```

4. Ensure proper SSH key permissions:
   ```powershell
   icacls $env:USERPROFILE\.ssh\id_rsa /inheritance:r
   icacls $env:USERPROFILE\.ssh\id_rsa /grant:r "$($env:USERNAME):(R,W)"
   ```

#### VPS Deployment Script Failures

**Symptoms:**
- Error: "VPS deployment failed with exit code X"
- Error: "complete_deployment.sh execution failed"

**Solutions:**
1. Check VPS deployment logs:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "cat /opt/cloudtolocalllm/logs/deployment_latest.log"
   ```

2. Verify VPS disk space:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "df -h"
   ```

3. Check Docker status on VPS:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "docker ps"
   ```

4. Manually run deployment script on VPS:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && ./scripts/deploy/complete_deployment.sh"
   ```

### Verification Issues

#### HTTP/HTTPS Endpoint Failures

**Symptoms:**
- Error: "HTTP endpoint is not accessible"
- Error: "HTTPS endpoint returned non-200 status code"

**Solutions:**
1. Check if the web server is running:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "docker ps | grep nginx"
   ```

2. Verify Nginx configuration:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "docker exec nginx-proxy cat /etc/nginx/conf.d/default.conf"
   ```

3. Check Nginx logs:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "docker logs nginx-proxy"
   ```

4. Test endpoints manually:
   ```powershell
   Invoke-WebRequest -Uri "https://cloudtolocalllm.online" -UseBasicParsing
   ```

#### SSL Certificate Issues

**Symptoms:**
- Error: "SSL certificate check failed"
- Error: "SSL certificate is expired or invalid"

**Solutions:**
1. Check SSL certificate expiration:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "./scripts/check_ssl_expiry.sh"
   ```

2. Verify SSL certificate configuration:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "ls -la /etc/letsencrypt/live/cloudtolocalllm.online/"
   ```

3. Renew SSL certificates if needed:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && ./scripts/ssl/renew_certificates.sh"
   ```

#### Container Health Issues

**Symptoms:**
- Error: "Container X is not running"
- Error: "Recent errors found in container logs"

**Solutions:**
1. Check container status:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && docker compose ps"
   ```

2. View container logs:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && docker compose logs --tail=50 webapp"
   ```

3. Restart containers:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && docker compose restart"
   ```

4. Check system resources:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "free -h && df -h"
   ```

### Rollback Issues

#### Automatic Rollback Failures

**Symptoms:**
- Error: "Automatic rollback failed"
- Error: "Cannot roll back to previous version"

**Solutions:**
1. Check Git history on VPS:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git log --oneline -10"
   ```

2. Manually roll back on VPS:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git checkout HEAD~1 && ./scripts/deploy/complete_deployment.sh"
   ```

3. Roll back to specific version:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git checkout v3.10.2 && ./scripts/deploy/complete_deployment.sh"
   ```

## Kiro Hook Specific Issues

### Hook Execution Failures

**Symptoms:**
- Error: "Hook execution failed"
- Hook doesn't appear in Kiro panel

**Solutions:**
1. Check hook configuration file:
   ```powershell
   cat .kiro/hooks/automated-deployment.kiro.hook
   ```

2. Verify hook permissions:
   ```powershell
   icacls .kiro/hooks/automated-deployment.kiro.hook
   ```

3. Try running the deployment script manually:
   ```powershell
   .\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -Verbose
   ```

### Hook Parameter Issues

**Symptoms:**
- Error: "Parameter X not found"
- Parameters not being passed correctly

**Solutions:**
1. Check parameter names in hook configuration:
   ```powershell
   cat .kiro/hooks/automated-deployment.kiro.hook | Select-String "parameters"
   ```

2. Verify parameter placeholders in script arguments:
   ```powershell
   cat .kiro/hooks/automated-deployment.kiro.hook | Select-String "args"
   ```

## Advanced Troubleshooting

### Deployment Script Debugging

To enable detailed debugging of the deployment script:

```powershell
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -Verbose
```

### PowerShell Deployment Debugging

To troubleshoot PowerShell deployment issues:

```powershell
# Check PowerShell version and capabilities
$PSVersionTable

# Test module imports
Import-Module -Name Microsoft.PowerShell.Management -Force
Import-Module -Name Microsoft.PowerShell.Utility -Force

# Check available cmdlets
Get-Command -Module Microsoft.PowerShell.*

# Test network connectivity to VPS
Test-NetConnection cloudtolocalllm.online -Port 22 -InformationLevel Detailed

# Check PowerShell execution context
Get-ExecutionPolicy -List
```

### Linux Build Environment (WSL) Debugging

**Note**: WSL is only required for building Linux versions of the application, not for deployment operations.

To troubleshoot Linux build issues when building Linux packages:

```powershell
# Check WSL status (only needed for Linux builds)
wsl --status

# List WSL distributions (only needed for Linux builds)
wsl --list --verbose

# Restart WSL (only needed for Linux builds)
wsl --shutdown
wsl -d Ubuntu-24.04

# Check WSL logs (only needed for Linux builds)
Get-EventLog Application -Source "WSL" -Newest 20
```

### SSH Debugging

For detailed SSH connection debugging:

```powershell
# Enable SSH debugging
$env:GIT_SSH_COMMAND="ssh -vvv"

# Test SSH connection with maximum verbosity
ssh -vvv cloudllm@cloudtolocalllm.online

# Check SSH agent
ssh-add -l
```

### Docker Container Debugging

To debug Docker container issues on the VPS:

```powershell
# Connect to VPS and run these commands
ssh cloudllm@cloudtolocalllm.online

# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"

# Inspect container
docker inspect webapp

# View container logs with timestamps
docker logs --timestamps --tail=100 webapp

# Check container resource usage
docker stats --no-stream
```

## Recovery Procedures

### Manual Deployment Recovery

If automated deployment fails and cannot be recovered automatically:

1. Connect to the VPS:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online
   ```

2. Navigate to the project directory:
   ```bash
   cd /opt/cloudtolocalllm
   ```

3. Check Git status and history:
   ```bash
   git status
   git log --oneline -10
   ```

4. Reset to the last known good state:
   ```bash
   git checkout v3.10.2  # Replace with last known good version
   ```

5. Run the deployment script manually:
   ```bash
   ./scripts/deploy/complete_deployment.sh
   ```

6. Verify the deployment:
   ```bash
   ./scripts/deploy/verify_deployment.sh
   ```

### Emergency Rollback

For critical failures requiring immediate rollback:

1. Connect to the VPS:
   ```powershell
   ssh cloudllm@cloudtolocalllm.online
   ```

2. Execute emergency rollback script:
   ```bash
   cd /opt/cloudtolocalllm
   ./scripts/deploy/emergency_rollback.sh
   ```

3. Verify services are restored:
   ```bash
   docker compose ps
   curl -I https://cloudtolocalllm.online
   ```

## Contacting Support

If you cannot resolve the deployment issues using this guide:

1. Collect diagnostic information:
   ```powershell
   .\scripts\powershell\Collect-DiagnosticInfo.ps1
   ```

2. Contact the CloudToLocalLLM development team with:
   - Deployment log files from the `logs/` directory
   - Output of the diagnostic script
   - Description of the issue and steps to reproduce
   - Any error messages or screenshots

## Preventive Measures

To minimize deployment issues:

1. **Regular Testing**: Perform regular dry-run deployments to staging
2. **Clean Repository**: Ensure Git repository is clean before deployment
3. **Resource Monitoring**: Monitor VPS resources to prevent resource exhaustion
4. **Backup Configuration**: Maintain backups of critical configuration files
5. **Certificate Monitoring**: Set up alerts for SSL certificate expiration
6. **Log Rotation**: Ensure logs are properly rotated to prevent disk space issues