# CloudToLocalLLM Deployment Workflow

## Deployment Architecture

CloudToLocalLLM uses a Windows-to-Linux VPS deployment workflow with the following components:

### Master Deployment Script
- **Primary Script**: `scripts/powershell/Deploy-CloudToLocalLLM.ps1`
- **VPS Script**: `scripts/deploy/complete_deployment.sh` (runs on Linux VPS)
- **Verification**: `scripts/deploy/verify_deployment.sh` (runs on VPS)

### Deployment Flow
```
Windows Development → PowerShell → SSH to VPS → Docker Containers
```

1. **Windows PowerShell Script** (`Deploy-CloudToLocalLLM.ps1`)
   - Orchestrates entire deployment from Windows
   - Handles version management and Flutter builds
   - Creates GitHub releases
   - SSH to VPS and executes remote scripts

2. **VPS Linux Script** (`complete_deployment.sh`)
   - Runs on cloudtolocalllm.online VPS
   - Handles Docker container deployment
   - Manages SSL certificates via Let's Encrypt
   - Performs service health checks

3. **Verification Script** (`verify_deployment.sh`)
   - Validates deployment success
   - Checks all service endpoints
   - Verifies SSL certificates
   - Tests container health

## Key Configuration

### VPS Details
- **Host**: cloudtolocalllm.online
- **User**: cloudllm
- **Project Path**: /opt/cloudtolocalllm
- **Services**: nginx-proxy, flutter-app, api-backend, postfix-mail, certbot

### Docker Services (from docker-compose.yml)
- **webapp**: Flutter web app with nginx
- **api-backend**: Node.js API server (port 8080)
- **postfix-mail**: Email server for notifications
- **certbot**: SSL certificate management

### Windows PowerShell Requirements
- **PowerShell Version**: 5.1+ (Windows PowerShell or PowerShell Core)
- **Flutter Path**: C:\tools\flutter\bin\flutter (or system PATH)
- **SSH Client**: OpenSSH for Windows (usually pre-installed)
- **Git**: Git for Windows with SSH key configuration

### Linux Build Requirements (Optional)
**Note**: Only required when building Linux versions of the application
- **WSL Distribution**: Ubuntu-24.04 (for Linux builds only)
- **Flutter Path in WSL**: /opt/flutter/bin/flutter (for Linux builds only)

## Deployment Commands

### Manual Deployment
```powershell
# Full deployment with version increment
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1

# Deploy to staging
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -Environment Staging

# Skip build (deploy existing)
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -SkipBuild

# Force deployment without prompts
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1 -Force
```

### VPS Direct Deployment
```bash
# On VPS (cloudtolocalllm.online)
cd /opt/cloudtolocalllm
./scripts/deploy/complete_deployment.sh

# Verification only
./scripts/deploy/verify_deployment.sh
```

## Deployment Phases

1. **Pre-flight Validation**
   - Check PowerShell execution policy and capabilities
   - Validate Flutter installation on Windows
   - Test SSH connectivity to VPS
   - Verify Git repository status

2. **Version Management**
   - Increment version (build/patch/minor/major)
   - Update pubspec.yaml, version.json, assets/version.json
   - Commit version changes to Git

3. **Flutter Build**
   - Execute `flutter pub get` in PowerShell
   - Build web app: `flutter build web --release`
   - Validate build output in build/web/

4. **GitHub Release** (optional)
   - Create GitHub release with version tag
   - Generate release notes from commits
   - Upload build artifacts if needed

5. **VPS Deployment**
   - SSH to cloudllm@cloudtolocalllm.online
   - Execute complete_deployment.sh on VPS
   - Stream deployment logs in real-time
   - Handle Docker container orchestration

6. **Verification**
   - Run verify_deployment.sh on VPS
   - Check all service endpoints
   - Validate SSL certificates
   - Confirm container health

7. **Rollback** (if needed)
   - Git-based rollback on VPS
   - Restart containers with previous version
   - Re-run verification

## Error Handling

### Automatic Rollback Triggers
- Build failures (no rollback needed)
- VPS deployment script failures
- Verification failures
- Container health check failures

### Rollback Process
1. SSH to VPS
2. Git reset to previous commit
3. Restart Docker containers
4. Run verification
5. Confirm rollback success

## Kiro Hook Integration

### Hook Configuration
```json
{
  "name": "Deploy to Production",
  "description": "Deploy CloudToLocalLLM to production VPS",
  "trigger": "manual",
  "command": "powershell",
  "args": [
    "-ExecutionPolicy", "Bypass", 
    "-File", "scripts/powershell/Deploy-CloudToLocalLLM.ps1", 
    "-Environment", "Production", 
    "-Force"
  ],
  "workingDirectory": ".",
  "timeout": 1800
}
```

## Development Workflow

### Local Development
1. Make code changes in Flutter/Dart
2. Test locally with `flutter run -d chrome`
3. Commit changes to Git
4. Run deployment script when ready

### Version Management
- **build**: Patch-level changes, bug fixes
- **patch**: Minor feature additions
- **minor**: Significant new features
- **major**: Breaking changes or major releases

### Testing Strategy
- Unit tests: Flutter/Dart code
- Integration tests: End-to-end deployment
- Verification tests: Post-deployment validation
- Rollback tests: Failure recovery scenarios

## Troubleshooting

### Common Issues
1. **PowerShell execution policy**: Set execution policy to allow scripts
2. **Flutter not found on Windows**: Install Flutter and add to PATH
3. **SSH connection failed**: Check SSH keys and VPS connectivity
4. **Docker build failures**: Check VPS Docker service status
5. **SSL certificate issues**: Check Let's Encrypt configuration

### Debug Commands
```powershell
# Test PowerShell capabilities
$PSVersionTable

# Test SSH connection
ssh cloudllm@cloudtolocalllm.online "echo 'Connection successful'"

# Check Flutter on Windows
flutter --version

# View deployment logs
Get-Content logs/deployment_*.log -Tail 50

# Test WSL availability (only for Linux builds)
wsl -l -v
```

## File Locations

### Windows Development
- **Main Script**: `scripts/powershell/Deploy-CloudToLocalLLM.ps1`
- **Utilities**: `scripts/powershell/BuildEnvironmentUtilities.ps1`
- **Version Manager**: `scripts/version_manager.ps1`
- **Logs**: `logs/deployment_*.log`

### VPS (Linux)
- **Project Root**: `/opt/cloudtolocalllm/`
- **Deployment Script**: `/opt/cloudtolocalllm/scripts/deploy/complete_deployment.sh`
- **Verification**: `/opt/cloudtolocalllm/scripts/deploy/verify_deployment.sh`
- **Docker Config**: `/opt/cloudtolocalllm/docker-compose.yml`

## Security Considerations

- SSH key-based authentication (no passwords)
- SSL certificates via Let's Encrypt
- Container isolation via Docker
- No sensitive data in Git repository
- Environment-specific configuration files