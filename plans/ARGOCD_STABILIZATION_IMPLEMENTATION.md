# ArgoCD Stabilization Implementation Guide

**Version:** 1.0  
**Date:** December 25, 2025  
**Environment:** CloudToLocalLLM Kubernetes Deployment  

## Overview

This document provides a comprehensive implementation guide for the ArgoCD stabilization plan for the CloudToLocalLLM web application. The implementation includes diagnostic scripts, configuration files, monitoring setups, and operational procedures designed to ensure successful and reliable deployment.

## Implementation Structure

```
CloudToLocalLLM/
├── plans/
│   ├── argocd_stabilization_plan.md          # Main stabilization plan
│   └── ARGOCD_STABILIZATION_IMPLEMENTATION.md # This file
├── scripts/
│   ├── argocd-health-check.sh               # Comprehensive health monitoring
│   ├── rollback-argocd-app.sh               # Automated rollback procedures
│   ├── argocd-backup-restore.sh             # Backup and restore operations
│   └── deployment-sop.sh                    # Standard operating procedure
├── k8s/argocd-config/
│   ├── argocd-server-ha.yaml                # High availability server config
│   ├── argocd-application-controller-optimized.yaml # Optimized controller
│   ├── argocd-repo-server-optimized.yaml    # Optimized repo server
│   ├── argocd-monitoring-alerts.yaml        # Monitoring and alerting
│   └── enhanced-sync-policies.yaml          # Robust sync policies
└── README.md
```

## Quick Start Guide

### 1. Prerequisites

Ensure the following are installed and configured:
- **kubectl** with cluster access
- **argocd CLI** for ArgoCD operations
- **jq** for JSON processing
- **Prometheus** and **Grafana** for monitoring (optional but recommended)

### 2. Implementation Steps

#### Step 1: Deploy Enhanced ArgoCD Configuration

```bash
# Apply high availability ArgoCD server configuration
kubectl apply -f k8s/argocd-config/argocd-server-ha.yaml

# Apply optimized application controller
kubectl apply -f k8s/argocd-config/argocd-application-controller-optimized.yaml

# Apply optimized repository server
kubectl apply -f k8s/argocd-config/argocd-repo-server-optimized.yaml
```

#### Step 2: Configure Monitoring and Alerting

```bash
# Apply monitoring configuration
kubectl apply -f k8s/argocd-config/argocd-monitoring-alerts.yaml

# Verify monitoring is working
kubectl get servicemonitor -n argocd
kubectl get prometheusrule -n argocd
```

#### Step 3: Deploy Enhanced Sync Policies

```bash
# Apply enhanced sync policies for all applications
kubectl apply -f k8s/argocd-config/enhanced-sync-policies.yaml
```

#### Step 4: Test Diagnostic Scripts

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run health check
./scripts/argocd-health-check.sh

# Test backup functionality
./scripts/argocd-backup-restore.sh backup

# Test rollback functionality
./scripts/rollback-argocd-app.sh --list-points -a cloudtolocalllm-api-backend
```

#### Step 5: Validate Deployment SOP

```bash
# Run deployment SOP in dry-run mode
./scripts/deployment-sop.sh -e production -a api-backend --dry-run

# Execute actual deployment
./scripts/deployment-sop.sh -e production -a api-backend
```

## Detailed Implementation Guide

### 1. ArgoCD Component Configuration

#### ArgoCD Server (High Availability)
- **Replicas:** 3 for high availability
- **Resource Limits:** 1Gi memory, 500m CPU
- **Enhanced Features:**
  - GRPC web support
  - Gzip compression
  - Request timeout configuration
  - Health checks and readiness probes

#### Application Controller (Optimized)
- **Replicas:** 2 for performance
- **Resource Limits:** 2Gi memory, 1000m CPU
- **Optimizations:**
  - 20 status processors
  - 10 operation processors
  - 30-minute application resync
  - Enhanced caching

#### Repository Server (Optimized)
- **Replicas:** 2 for performance
- **Resource Limits:** 1Gi memory, 500m CPU
- **Optimizations:**
  - 20-minute cache expiration
  - 10 parallel operations
  - Repository caching

### 2. Monitoring and Alerting Setup

#### Critical Alerts
- **ArgoCD Server Down:** 2-minute threshold
- **Application Sync Failed:** 1-minute threshold
- **High Resource Usage:** 80% threshold with 5-minute duration
- **Application Unhealthy:** 2-minute threshold

#### Metrics Collected
- Application sync status and health
- Component resource utilization
- Repository sync performance
- Cluster connection status

#### Dashboard Configuration
- Grafana dashboards for ArgoCD metrics
- Prometheus alerting rules
- ServiceMonitor configurations

### 3. Enhanced Sync Policies

#### Safety Features
- **Prune Policy:** Foreground deletion
- **Self-Healing:** Automatic recovery
- **Retry Logic:** 5 attempts with exponential backoff
- **Validation:** Server-side apply with validation

#### Sync Waves
- **Wave -1:** Infrastructure components
- **Wave 1:** Database and cache
- **Wave 5:** API backend
- **Wave 10:** Web frontend
- **Wave 15:** Monitoring
- **Wave 20:** Utilities
- **Wave 25:** Ingress

### 4. Diagnostic and Recovery Tools

#### Health Monitoring Script
```bash
# Comprehensive health check
./scripts/argocd-health-check.sh

# Critical components only
./scripts/argocd-health-check.sh --critical

# Generate detailed report
./scripts/argocd-health-check.sh --report
```

#### Backup and Restore
```bash
# Full backup
./scripts/argocd-backup-restore.sh backup

# Selective backup
./scripts/argocd-backup-restore.sh backup --type applications,applicationsets

# Full restore
./scripts/argocd-backup-restore.sh restore /backup/path

# List available backups
./scripts/argocd-backup-restore.sh --list
```

#### Rollback Procedures
```bash
# Emergency rollback
./scripts/rollback-argocd-app.sh -a cloudtolocalllm-api-backend --emergency

# Specific revision rollback
./scripts/rollback-argocd-app.sh -a cloudtolocalllm-api-backend -r HEAD~1

# List rollback points
./scripts/rollback-argocd-app.sh --list-points -a cloudtolocalllm-api-backend
```

### 5. Deployment Standard Operating Procedure

#### Pre-Deployment
1. **Prerequisites Validation**
   - Check tool availability
   - Validate environment and application parameters
   - Verify cluster connectivity

2. **Pre-deployment Validation**
   - Run ArgoCD health check
   - Validate Kubernetes manifests
   - Check resource limits

3. **Backup Creation**
   - Create ArgoCD configuration backup
   - Backup application state

#### Deployment Process
1. **Pause Critical Applications**
   - Pause API backend and web frontend
   - Ensure no conflicting operations

2. **Execute Deployment**
   - Perform application sync
   - Wait for completion with timeout
   - Verify deployment success

3. **Post-deployment Verification**
   - Check application status and health
   - Run smoke tests
   - Resume paused applications

#### Post-deployment
1. **Monitoring**
   - Monitor for 5 minutes post-deployment
   - Verify stability
   - Generate deployment report

2. **Documentation**
   - Log all operations
   - Generate deployment summary
   - Store in centralized location

## Operational Procedures

### Daily Operations

#### Morning Health Check
```bash
# Run comprehensive health check
./scripts/argocd-health-check.sh

# Check for any failed applications
argocd app list --output json | jq '.[] | select(.status.sync.status != "Synced")'
```

#### Application Monitoring
- Monitor sync status across all applications
- Check resource utilization
- Review alert notifications
- Verify backup completion

### Weekly Operations

#### Backup Verification
```bash
# List available backups
./scripts/argocd-backup-restore.sh --list

# Test restore procedure (in staging environment)
./scripts/argocd-backup-restore.sh restore /backup/path
```

#### Configuration Review
- Review sync policies for optimization opportunities
- Check resource limits and adjust if needed
- Update monitoring thresholds based on usage patterns

### Monthly Operations

#### Performance Analysis
- Analyze ArgoCD component performance
- Review sync times and optimize if needed
- Check for any deprecated configurations

#### Security Review
- Review RBAC configurations
- Check for any security vulnerabilities
- Update ArgoCD version if needed

## Troubleshooting Guide

### Common Issues

#### Application Not Syncing
```bash
# Check application status
argocd app get cloudtolocalllm-api-backend

# Check sync history
argocd app history cloudtolocalllm-api-backend

# Force sync
argocd app sync cloudtolocalllm-api-backend --force
```

#### ArgoCD Server Unavailable
```bash
# Check pod status
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Check service
kubectl get svc -n argocd -l app.kubernetes.io/name=argocd-server

# Restart deployment
kubectl rollout restart deployment/argocd-server -n argocd
```

#### Repository Access Issues
```bash
# Check repository configuration
argocd repo list

# Test repository access
argocd repo get https://github.com/imrightguy/CloudToLocalLLM

# Refresh repository
argocd repo list --refresh
```

### Emergency Procedures

#### Complete ArgoCD Recovery
```bash
# Restore from backup
./scripts/argocd-backup-restore.sh restore /backup/path

# Verify restoration
argocd app list

# Resume all applications
argocd app resume --all
```

#### Application Rollback
```bash
# Emergency rollback
./scripts/rollback-argocd-app.sh -a cloudtolocalllm-api-backend --emergency

# Verify rollback
argocd app get cloudtolocalllm-api-backend
```

## Success Metrics

### Deployment Success Rate
- **Target:** >99%
- **Measurement:** Successful deployments / Total deployment attempts

### Mean Time to Recovery (MTTR)
- **Target:** <15 minutes
- **Measurement:** Time from failure detection to service restoration

### Application Uptime
- **Target:** >99.9%
- **Measurement:** Uptime / Total time

### Sync Success Rate
- **Target:** >99.5%
- **Measurement:** Successful syncs / Total sync attempts

## Maintenance Schedule

### Automated Tasks
- **Health Checks:** Every 5 minutes via monitoring scripts
- **Backups:** Daily at 2 AM via cron job
- **Log Rotation:** Weekly via logrotate

### Manual Tasks
- **Health Review:** Daily morning
- **Backup Verification:** Weekly
- **Performance Analysis:** Monthly
- **Security Review:** Monthly

## Support and Escalation

### Level 1 Support
- **Scope:** Basic health checks, application status verification
- **Tools:** Health check scripts, ArgoCD CLI
- **Response Time:** 15 minutes

### Level 2 Support
- **Scope:** Component failures, sync issues, rollback procedures
- **Tools:** All diagnostic scripts, Kubernetes CLI
- **Response Time:** 30 minutes

### Level 3 Support
- **Scope:** Complete system failures, data recovery
- **Tools:** Full diagnostic suite, emergency procedures
- **Response Time:** 1 hour

## Conclusion

This implementation provides a comprehensive ArgoCD stabilization solution for the CloudToLocalLLM web application. The combination of enhanced configurations, monitoring, diagnostic tools, and operational procedures ensures reliable and successful deployments.

Regular review and updates to this implementation should be conducted quarterly or as the application architecture evolves to maintain optimal performance and reliability.

## Contact Information

For questions or issues related to this implementation:
- **Documentation:** [plans/argocd_stabilization_plan.md](plans/argocd_stabilization_plan.md)
- **Scripts:** [scripts/](scripts/)
- **Configuration:** [k8s/argocd-config/](k8s/argocd-config/)

**Last Updated:** December 25, 2025