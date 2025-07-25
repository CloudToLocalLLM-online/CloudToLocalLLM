# CloudToLocalLLM VPS Quality Gates Specification

## Overview

This document specifies the comprehensive quality gates and rollback mechanisms implemented in the restored VPS-based deployment methodology. The system enforces zero-tolerance quality standards for production deployments.

## Quality Gate Architecture

### 1. Pre-Deployment Quality Gates

#### Environment Validation
- **User Verification**: Must run as `cloudllm` user
- **Directory Validation**: Must execute from `/opt/cloudtolocalllm`
- **Command Availability**: Git, Flutter, Docker, Docker Compose, curl
- **Docker Daemon**: Must be running and accessible
- **Compose File**: `docker-compose.yml` must exist and be valid
- **Script Permissions**: All deployment scripts must be executable

#### Repository State Validation
- **Git Repository**: Must be a valid Git repository
- **Branch Verification**: Must be on master branch
- **Clean State**: Automatic cleanup of uncommitted changes (VPS is ephemeral)
- **Remote Connectivity**: Must be able to fetch from origin

### 2. Build Quality Gates

#### Flutter Build Validation
- **Clean Build**: Previous build artifacts removed
- **Dependency Resolution**: `flutter pub get` must succeed
- **Build Execution**: `flutter build web --release` must complete
- **Output Verification**: `build/web/index.html` must exist
- **Build Integrity**: Web build directory structure validated

#### Version Synchronization
- **Version Consistency**: All version files must be synchronized
- **Build Number Validation**: Build numbers must be properly incremented
- **Timestamp Injection**: Build timestamps must be current
- **File Integrity**: All version files must be readable and valid

### 3. Container Quality Gates

#### Container Management
- **Clean Shutdown**: Existing containers stopped gracefully (30s timeout)
- **Orphan Cleanup**: Orphaned containers removed
- **Build Success**: New containers must build without errors
- **Startup Verification**: All containers must start successfully
- **Health Checks**: Container health status monitored

#### Container Health Monitoring
```bash
# Health check validation
running_containers=$(docker-compose -f "$COMPOSE_FILE" ps -q | wc -l)
total_containers=$(docker-compose -f "$COMPOSE_FILE" config --services | wc -l)
unhealthy_containers=$(docker-compose -f "$COMPOSE_FILE" ps --filter "health=unhealthy" -q | wc -l)

# Quality gate: All containers must be running and healthy
if [[ $running_containers -eq $total_containers && $unhealthy_containers -eq 0 ]]; then
    # PASS
else
    # FAIL - Trigger rollback
fi
```

### 4. Application Quality Gates

#### Connectivity Validation
- **Application Accessibility**: HTTPS endpoint must respond with 200
- **Response Time**: Must respond within 10 seconds
- **SSL Certificate**: Must be valid and not expired
- **Version Endpoint**: `/version.json` must be accessible
- **Health Endpoints**: All health checks must pass

#### Performance Thresholds
- **Response Time**: Maximum 5000ms average response time
- **Availability**: 99.0% minimum uptime requirement
- **Error Rate**: Maximum 0.1% error rate tolerance
- **SSL Expiry**: Certificates must have >7 days until expiry

### 5. Security Quality Gates

#### SSL Certificate Validation
```bash
# SSL certificate verification
ssl_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
not_after=$(echo "$ssl_info" | grep "notAfter" | cut -d'=' -f2)
days_until_expiry=$(( (expiry_date - current_date) / 86400 ))

# Quality gate: Certificate must be valid and not expiring soon
if [[ $days_until_expiry -gt 7 ]]; then
    # PASS
else
    # FAIL - Certificate expiring soon
fi
```

#### Security Headers Validation
- **X-Frame-Options**: Must be present
- **X-Content-Type-Options**: Must be present  
- **X-XSS-Protection**: Must be present
- **Content Security Policy**: Recommended but not required

## Rollback Mechanisms

### 1. Automatic Rollback Triggers

#### Deployment Failure Points
- Pre-deployment validation failure
- Git pull failure
- Flutter build failure
- Container startup failure
- Health check failure
- Application accessibility failure
- SSL certificate validation failure

#### Rollback Decision Matrix
```bash
# Rollback logic in complete_deployment.sh
if [[ "$deployment_failed" == "true" ]]; then
    if [[ "$ROLLBACK_ON_FAILURE" == "true" ]]; then
        rollback_deployment
        return 3  # Rollback performed
    else
        return 1  # Deployment failed, no rollback
    fi
fi
```

### 2. Rollback Implementation

#### Backup Strategy
- **Pre-deployment Backup**: Current web build backed up before deployment
- **Backup Location**: `/opt/cloudtolocalllm/backups/deployment_backup_YYYYMMDD_HHMMSS`
- **Backup Validation**: Backup creation verified before proceeding
- **Retention Policy**: Backups maintained for rollback purposes

#### Rollback Execution
```bash
rollback_deployment() {
    log_error "🔄 Initiating deployment rollback..."
    
    # Stop current containers
    docker-compose -f "$COMPOSE_FILE" down --timeout 30 2>/dev/null || true
    
    # Restore from backup if available
    latest_backup=$(ls -t "$BACKUP_DIR"/ 2>/dev/null | head -n1)
    if [[ -n "$latest_backup" && -d "$BACKUP_DIR/$latest_backup" ]]; then
        rm -rf build/web 2>/dev/null || true
        cp -r "$BACKUP_DIR/$latest_backup" build/web
        
        # Restart containers with backup
        docker-compose -f "$COMPOSE_FILE" up -d 2>/dev/null || true
    fi
}
```

### 3. Git-based Rollback

#### Repository Rollback
- **Hard Reset**: `git reset --hard HEAD` to clean state
- **Force Clean**: `git clean -fd` to remove untracked files
- **Previous Commit**: Rollback to last known good commit
- **Force Push**: `git push --force-with-lease` when necessary

#### State Management
- **Lock Files**: Prevent concurrent deployments during rollback
- **State Tracking**: Monitor deployment state and history
- **Recovery Procedures**: Documented recovery from various failure scenarios

## Quality Gate Configuration

### Configurable Thresholds

#### Performance Thresholds
```bash
# Configurable in verify_deployment.sh
MAX_RESPONSE_TIME=5000  # milliseconds
MIN_UPTIME_PERCENTAGE=99.0
MAX_ERROR_RATE=0.1
TIMEOUT_SECONDS=30
MAX_RETRIES=3
```

#### Deployment Settings
```bash
# Configurable in complete_deployment.sh
DEPLOYMENT_TIMEOUT=1800  # 30 minutes
MAX_DEPLOYMENT_RETRIES=2
DEPLOYMENT_COOLDOWN=300  # 5 minutes between deployments
```

### Strict Mode Operation

#### Zero-Tolerance Policy
- **Warnings as Failures**: In strict mode, warnings count as failures
- **No Partial Deployments**: All quality gates must pass
- **Automatic Rollback**: Any failure triggers immediate rollback
- **Comprehensive Logging**: All failures logged with detailed context

#### Quality Gate Enforcement
```bash
# Strict mode in verify_deployment.sh
if [[ $FAILED_TESTS -gt 0 ]]; then
    exit_code=1  # Hard failure
elif [[ $WARNING_TESTS -gt 0 && "$STRICT_MODE" == "true" ]]; then
    exit_code=1  # Warnings treated as failures in strict mode
else
    exit_code=0  # Success
fi
```

## Monitoring and Alerting

### Deployment Monitoring

#### Git Monitor Integration
- **Automatic Deployment**: Triggered by Git commits
- **Cooldown Periods**: Prevent rapid successive deployments
- **Lock File Management**: Prevent concurrent deployments
- **State Persistence**: Track deployment history and status

#### Logging Strategy
- **Centralized Logging**: `/var/log/cloudtolocalllm/git_monitor.log`
- **Structured Logging**: Timestamp, level, component, message
- **Log Rotation**: Automatic log rotation and retention
- **Error Aggregation**: Failed deployments tracked and reported

### Health Monitoring

#### Continuous Monitoring
- **Container Health**: Docker health checks monitored
- **Application Health**: HTTP endpoint monitoring
- **SSL Certificate**: Expiry monitoring and alerts
- **Performance Metrics**: Response time and availability tracking

#### Alert Thresholds
- **Deployment Failures**: Immediate alert on any deployment failure
- **Certificate Expiry**: Alert when <30 days until expiry
- **Performance Degradation**: Alert when response time >5s
- **Container Failures**: Alert on any unhealthy containers

## Integration with Windows Orchestration

### PowerShell Integration

#### Enhanced Error Handling
```powershell
# Updated Deploy-CloudToLocalLLM.ps1
$vpsDeploymentScript = "$VPSProjectPath/scripts/deploy/complete_deployment.sh"
$deploymentCommand = "cd $VPSProjectPath && $vpsDeploymentScript --force"

ssh $VPSUser@$VPSHost "$deploymentCommand"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: VPS deployment failed with exit code $LASTEXITCODE" -ForegroundColor Red
    Write-Host "The VPS deployment script includes automatic rollback on failure" -ForegroundColor Yellow
    exit 1
}
```

#### Quality Gate Reporting
- **Real-time Feedback**: SSH output streamed to Windows console
- **Exit Code Propagation**: VPS exit codes propagated to Windows
- **Error Context**: Detailed error information provided
- **Rollback Notification**: Windows notified of automatic rollbacks

## Conclusion

The restored VPS-based deployment methodology implements comprehensive quality gates and rollback mechanisms that ensure:

1. **Zero-Tolerance Quality**: No partial or degraded deployments allowed
2. **Automatic Recovery**: Immediate rollback on any failure
3. **Comprehensive Validation**: All aspects of deployment verified
4. **Environment Separation**: Windows development, VPS production
5. **Augment Agent Integration**: Automated monitoring and deployment
6. **Proven Methodology**: Based on pre-GitHub Actions working system

This system provides enterprise-grade deployment reliability while maintaining the simplicity and directness of the original Windows-to-VPS orchestration model.
