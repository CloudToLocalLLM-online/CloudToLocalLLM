# ArgoCD Stabilization Plan for CloudToLocalLLM

**Version:** 1.0  
**Date:** December 25, 2025  
**Environment:** Kubernetes Cluster with ArgoCD GitOps  
**Application:** CloudToLocalLLM Web Application  

## Executive Summary

This comprehensive stabilization plan ensures successful and reliable deployment of the CloudToLocalLLM web application using ArgoCD. The plan leverages established GitOps principles, best practices, and operational protocols to maintain deployment consistency and system stability.

## Current ArgoCD Architecture Analysis

### Application Structure
- **Bootstrap Application:** `bootstrap` (namespace: argocd)
- **Managed Applications:** `cloudtolocalllm-services` (namespace: argocd)
- **Local Applications:** `cloudtolocalllm-local-apps` (ApplicationSet)

### Sync Wave Configuration
The current deployment follows a structured sync wave approach:
- **Wave -1:** Infrastructure components
- **Wave 1:** Database (Postgres) and Cache (Redis)
- **Wave 5:** API Backend services
- **Wave 10:** Web Frontend
- **Wave 15:** Monitoring services
- **Wave 20:** Utilities
- **Wave 25:** Ingress (Cloudflared)

### Security Configuration
- **RBAC:** Role-based access control with admin and developer roles
- **Namespace:** Applications deployed to `cloudtolocalllm` namespace
- **Self-healing:** Automated sync with prune and self-heal enabled

## 1. Diagnostic Procedures

### 1.1 ArgoCD Health Monitoring

#### Core Component Health Checks
```bash
# Check ArgoCD server status
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Verify ApplicationSet controller
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller

# Check Application controller
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Verify Repo server
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

#### Application Status Verification
```bash
# List all CloudToLocalLLM applications
kubectl get applications -n argocd -l app.kubernetes.io/part-of=cloudtolocalllm

# Check specific application health
argocd app get cloudtolocalllm-api-backend
argocd app get cloudtolocalllm-web-frontend

# Verify sync status across all applications
argocd app list --output json | jq '.[] | {name: .metadata.name, status: .status.sync.status, health: .status.health.status}'
```

#### Resource Utilization Monitoring
```bash
# Check ArgoCD component resource usage
kubectl top pods -n argocd

# Monitor ApplicationSet controller metrics
kubectl logs -n argocd deployment/argocd-applicationset-controller --tail=100

# Verify Application controller performance
kubectl logs -n argocd deployment/argocd-application-controller --tail=100
```

### 1.2 Git Repository Health

#### Repository Connectivity
```bash
# Test repository access from ArgoCD
argocd repo list

# Verify repository credentials
argocd repo get https://github.com/imrightguy/CloudToLocalLLM

# Check repository sync status
argocd repo list --refresh
```

#### Branch and Commit Verification
```bash
# Verify target branch exists and is accessible
git ls-remote https://github.com/imrightguy/CloudToLocalLLM.git main

# Check recent commits
git log --oneline -5 https://github.com/imrightguy/CloudToLocalLLM.git
```

## 2. Configuration Adjustments

### 2.1 ArgoCD Server Configuration

#### Resource Optimization
```yaml
# argocd-server deployment patch
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
spec:
  template:
    spec:
      containers:
      - name: argocd-server
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        env:
        - name: ARGOCD_SERVER_MAX_CONCURRENT_REQUESTS
          value: "100"
        - name: ARGOCD_SERVER_GRPC_MAX_SIZE
          value: "104857600"  # 100MB
```

#### High Availability Configuration
```yaml
# ArgoCD HA configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

### 2.2 Application Controller Optimization

#### Performance Tuning
```yaml
# argocd-application-controller configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-application-controller
  namespace: argocd
spec:
  template:
    spec:
      containers:
      - name: argocd-application-controller
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        env:
        - name: ARGOCD_CONTROLLER_REPLICAS
          value: "2"
        - name: ARGOCD_CONTROLLER_WORKERS
          value: "20"
        - name: ARGOCD_CONTROLLER_APP_RESYNC
          value: "1800"  # 30 minutes
```

### 2.3 Repository Server Configuration

#### Caching and Performance
```yaml
# argocd-repo-server configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-repo-server
  namespace: argocd
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: argocd-repo-server
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        env:
        - name: ARGOCD_REPO_SERVER_CACHE_EXPIRATION
          value: "20m"
        - name: ARGOCD_REPO_SERVER_PARALLELISM
          value: "10"
```

### 2.4 Sync Policy Enhancements

#### Robust Sync Configuration
```yaml
# Enhanced sync policy for critical applications
syncPolicy:
  automated:
    prune: true
    selfHeal: true
    allowEmpty: false
  syncOptions:
    - CreateNamespace=true
    - RespectIgnoreDifferences=true
    - ApplyOutOfSyncOnly=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

## 3. Health Check Procedures

### 3.1 Automated Health Monitoring

#### ArgoCD Health Check Script
```bash
#!/bin/bash
# argocd-health-check.sh

set -e

ARGOCD_NAMESPACE="argocd"
CLOUDTOLOCLLM_NAMESPACE="cloudtolocalllm"

echo "=== ArgoCD Health Check ==="

# Check ArgoCD components
echo "1. Checking ArgoCD components..."
for component in server application-controller repo-server applicationset-controller; do
    POD_COUNT=$(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-$component --field-selector=status.phase=Running --no-headers | wc -l)
    if [ $POD_COUNT -eq 0 ]; then
        echo "❌ ArgoCD $component is not running"
        exit 1
    else
        echo "✅ ArgoCD $component is running ($POD_COUNT pods)"
    fi
done

# Check application health
echo "2. Checking CloudToLocalLLM applications..."
CRITICAL_APPS=("api-backend" "web-frontend" "postgres" "redis")

for app in "${CRITICAL_APPS[@]}"; do
    APP_STATUS=$(argocd app get cloudtolocalllm-$app --output json | jq -r '.status.sync.status')
    APP_HEALTH=$(argocd app get cloudtolocalllm-$app --output json | jq -r '.status.health.status')
    
    if [ "$APP_STATUS" != "Synced" ] || [ "$APP_HEALTH" != "Healthy" ]; then
        echo "❌ Application $app is not healthy (Status: $APP_STATUS, Health: $APP_HEALTH)"
        exit 1
    else
        echo "✅ Application $app is healthy (Status: $APP_STATUS, Health: $APP_HEALTH)"
    fi
done

# Check resource utilization
echo "3. Checking resource utilization..."
kubectl top pods -n $ARGOCD_NAMESPACE --sort-by=memory | head -10

echo "✅ All health checks passed!"
```

#### Continuous Monitoring with Prometheus
```yaml
# ArgoCD monitoring configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-monitoring
  namespace: argocd
data:
  argocd-alerts.yml: |
    groups:
    - name: argocd_server_alerts
      interval: 30s
      rules:
      - alert: ArgoCDServerDown
        expr: up{job="argocd-server"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "ArgoCD server is down"
          description: "ArgoCD server has been down for more than 2 minutes"
      
      - alert: ArgoCDHighMemoryUsage
        expr: (container_memory_usage_bytes{pod=~"argocd-.*"} / container_spec_memory_limit_bytes{pod=~"argocd-.*"}) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "ArgoCD component high memory usage"
          description: "ArgoCD component {{ $labels.pod }} is using more than 80% of its memory limit"
      
      - alert: ArgoCDHighCPUUsage
        expr: rate(container_cpu_usage_seconds_total{pod=~"argocd-.*"}[5m]) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "ArgoCD component high CPU usage"
          description: "ArgoCD component {{ $labels.pod }} is using more than 80% CPU"
      
      - alert: ArgoCDApplicationOutOfSync
        expr: argocd_app_sync_total{status!="Synced"} > 0
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "ArgoCD application out of sync"
          description: "Application {{ $labels.name }} is out of sync"
```

### 3.2 Application-Level Health Checks

#### Readiness and Liveness Probes
```yaml
# Enhanced health checks for applications
spec:
  template:
    spec:
      containers:
      - name: api-backend
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
```

## 4. Rollback Strategies

### 4.1 Automated Rollback Configuration

#### Git-Based Rollback
```yaml
# ArgoCD rollback configuration
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudtolocalllm-api-backend
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-options: CreateNamespace=true
    argocd.argoproj.io/compare-options: IgnoreExtraneous
spec:
  source:
    repoURL: https://github.com/imrightguy/CloudToLocalLLM
    targetRevision: main
    path: k8s/apps/managed/api-backend
    kustomize:
      images:
      - cloudtolocalllm/api-backend:v1.0.0  # Pin to specific version
  destination:
    server: https://kubernetes.default.svc
    namespace: cloudtolocalllm
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

#### Manual Rollback Procedures
```bash
#!/bin/bash
# rollback-argocd-app.sh

set -e

APP_NAME=$1
REVISION=$2

if [ -z "$APP_NAME" ] || [ -z "$REVISION" ]; then
    echo "Usage: $0 <app-name> <revision>"
    echo "Example: $0 cloudtolocalllm-api-backend HEAD~1"
    exit 1
fi

echo "Rolling back $APP_NAME to $REVISION..."

# Pause sync
argocd app pause $APP_NAME

# Sync to specific revision
argocd app sync $APP_NAME --revision $REVISION

# Wait for sync completion
argocd app wait $APP_NAME --timeout 300

# Verify health
argocd app get $APP_NAME

# Resume sync
argocd app resume $APP_NAME

echo "Rollback completed successfully!"
```

### 4.2 Disaster Recovery Procedures

#### Backup and Restore Strategy
```bash
#!/bin/bash
# argocd-backup-restore.sh

BACKUP_DIR="/backup/argocd"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup ArgoCD configuration
echo "Creating ArgoCD backup..."
kubectl get applications -n argocd -o yaml > $BACKUP_DIR/applications_$DATE.yaml
kubectl get applicationsets -n argocd -o yaml > $BACKUP_DIR/applicationsets_$DATE.yaml
kubectl get appprojects -n argocd -o yaml > $BACKUP_DIR/appprojects_$DATE.yaml
kubectl get configmaps -n argocd -o yaml > $BACKUP_DIR/configmaps_$DATE.yaml
kubectl get secrets -n argocd -o yaml > $BACKUP_DIR/secrets_$DATE.yaml

# Backup application data
kubectl get applications -n argocd -o json | jq '.items[] | {name: .metadata.name, source: .spec.source, destination: .spec.destination}' > $BACKUP_DIR/applications_summary_$DATE.json

echo "Backup completed: $BACKUP_DIR"
```

#### Recovery Procedures
```bash
#!/bin/bash
# argocd-restore.sh

BACKUP_DIR=$1

if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 <backup-directory>"
    exit 1
fi

echo "Restoring ArgoCD from backup..."

# Restore applications
kubectl apply -f $BACKUP_DIR/applications_*.yaml

# Restore application sets
kubectl apply -f $BACKUP_DIR/applicationsets_*.yaml

# Restore app projects
kubectl apply -f $BACKUP_DIR/appprojects_*.yaml

# Restore configmaps
kubectl apply -f $BACKUP_DIR/configmaps_*.yaml

# Restore secrets
kubectl apply -f $BACKUP_DIR/secrets_*.yaml

echo "Restore completed. Verify applications are syncing correctly."
```

## 5. Preventive Measures

### 5.1 Deployment Safety Mechanisms

#### Pre-deployment Validation
```bash
#!/bin/bash
# pre-deployment-validation.sh

set -e

REPO_URL="https://github.com/imrightguy/CloudToLocalLLM"
BRANCH="main"
PATH_TO_VALIDATE="k8s/apps/managed"

echo "=== Pre-deployment Validation ==="

# Validate Kubernetes manifests
echo "1. Validating Kubernetes manifests..."
find $PATH_TO_VALIDATE -name "*.yaml" -o -name "*.yml" | while read file; do
    if ! kubectl apply --dry-run=client -f "$file" 2>/dev/null; then
        echo "❌ Invalid manifest: $file"
        exit 1
    fi
done

# Validate ArgoCD applications
echo "2. Validating ArgoCD applications..."
argocd app list --output json | jq -r '.[].metadata.name' | while read app; do
    if ! argocd app get "$app" >/dev/null 2>&1; then
        echo "❌ Invalid ArgoCD application: $app"
        exit 1
    fi
done

# Check resource limits
echo "3. Checking resource limits..."
kubectl get nodes --no-headers | awk '{print $2}' | while read node; do
    echo "Node: $node"
    kubectl describe node "$node" | grep -A 5 "Allocated resources"
done

echo "✅ Pre-deployment validation passed!"
```

#### Deployment Gates
```yaml
# Deployment gate configuration
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudtolocalllm-api-backend
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-options: CreateNamespace=true
    argocd.argoproj.io/compare-options: IgnoreExtraneous
    # Deployment gate annotations
    deployment.gate/health-check: "required"
    deployment.gate/resource-check: "required"
    deployment.gate/dependency-check: "required"
spec:
  source:
    repoURL: https://github.com/imrightguy/CloudToLocalLLM
    targetRevision: main
    path: k8s/apps/managed/api-backend
  destination:
    server: https://kubernetes.default.svc
    namespace: cloudtolocalllm
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - RespectIgnoreDifferences=true
      - ApplyOutOfSyncOnly=true
```

### 5.2 Resource Management

#### Resource Quotas and Limits
```yaml
# Resource quota for cloudtolocalllm namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cloudtolocalllm-quota
  namespace: cloudtolocalllm
spec:
  hard:
    requests.cpu: "8"
    requests.memory: "16Gi"
    limits.cpu: "16"
    limits.memory: "32Gi"
    persistentvolumeclaims: "10"
    pods: "50"
    services: "20"
    secrets: "20"
    configmaps: "20"
```

#### Horizontal Pod Autoscaling
```yaml
# HPA for critical applications
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-backend-hpa
  namespace: cloudtolocalllm
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 5.3 Security Hardening

#### Network Policies
```yaml
# Network policy for ArgoCD namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-network-policy
  namespace: argocd
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: cloudtolocalllm
    ports:
    - protocol: TCP
      port: 443
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: cloudtolocalllm
    ports:
    - protocol: TCP
      port: 443
  - to: []
    ports:
    - protocol: TCP
      port: 443
```

#### RBAC Enhancements
```yaml
# Enhanced RBAC configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    # Admin privileges
    g, admin, role:admin
    
    # Developer role with limited access
    p, role:developer, applications, get, cloudtolocalllm/*, allow
    p, role:developer, applications, sync, cloudtolocalllm/*, allow
    p, role:developer, applications, patch, cloudtolocalllm/*, allow
    p, role:developer, logs, get, cloudtolocalllm/*, allow
    
    # Read-only role
    p, role:readonly, applications, get, *, allow
    p, role:readonly, repositories, get, *, allow
    
    # Bind groups to roles
    g, dev-team, role:developer
    g, readonly-team, role:readonly
  
  policy.default: role:readonly
```

## 6. Operational Protocols

### 6.1 Deployment Workflow

#### Standard Operating Procedure
```bash
#!/bin/bash
# deployment-sop.sh

set -e

ENVIRONMENT=$1
APPLICATION=$2

if [ -z "$ENVIRONMENT" ] || [ -z "$APPLICATION" ]; then
    echo "Usage: $0 <environment> <application>"
    echo "Example: $0 production api-backend"
    exit 1
fi

echo "=== CloudToLocalLLM Deployment SOP ==="
echo "Environment: $ENVIRONMENT"
echo "Application: $APPLICATION"
echo "Timestamp: $(date)"

# Step 1: Pre-deployment checks
echo "1. Running pre-deployment validation..."
./pre-deployment-validation.sh

# Step 2: Backup current state
echo "2. Creating backup..."
./argocd-backup-restore.sh

# Step 3: Pause sync for critical applications
echo "3. Pausing sync for critical applications..."
CRITICAL_APPS=("api-backend" "web-frontend")
for app in "${CRITICAL_APPS[@]}"; do
    argocd app pause "cloudtolocalllm-$app"
done

# Step 4: Deploy application
echo "4. Deploying application..."
argocd app sync "cloudtolocalllm-$APPLICATION"

# Step 5: Verify deployment
echo "5. Verifying deployment..."
./argocd-health-check.sh

# Step 6: Resume sync
echo "6. Resuming sync..."
for app in "${CRITICAL_APPS[@]}"; do
    argocd app resume "cloudtolocalllm-$app"
done

# Step 7: Post-deployment monitoring
echo "7. Starting post-deployment monitoring..."
./monitor-argocd.sh &

echo "✅ Deployment completed successfully!"
```

### 6.2 Incident Response Procedures

#### ArgoCD Incident Response
```bash
#!/bin/bash
# argocd-incident-response.sh

INCIDENT_TYPE=$1
SEVERITY=$2

case $INCIDENT_TYPE in
    "sync-failure")
        echo "Handling sync failure..."
        # Check application status
        argocd app list --output json | jq '.[] | select(.status.sync.status != "Synced")'
        
        # Check logs
        kubectl logs -n argocd deployment/argocd-application-controller --tail=100
        
        # Manual sync attempt
        argocd app sync --force cloudtolocalllm-api-backend
        ;;
    
    "component-down")
        echo "Handling component failure..."
        # Check pod status
        kubectl get pods -n argocd
        
        # Restart failed components
        kubectl rollout restart deployment/argocd-server -n argocd
        kubectl rollout restart deployment/argocd-application-controller -n argocd
        ;;
    
    "repository-unavailable")
        echo "Handling repository unavailability..."
        # Check repository connectivity
        argocd repo list
        
        # Switch to backup repository if available
        argocd repo add https://github.com/imrightguy/CloudToLocalLLM-backup --username $GIT_USERNAME --password $GIT_PASSWORD
        ;;
    
    *)
        echo "Unknown incident type: $INCIDENT_TYPE"
        exit 1
        ;;
esac
```

### 6.3 Maintenance Procedures

#### Regular Maintenance Tasks
```bash
#!/bin/bash
# argocd-maintenance.sh

echo "=== ArgoCD Regular Maintenance ==="

# 1. Clean up old application history
echo "1. Cleaning up application history..."
kubectl patch applications -n argocd --all --type='json' -p='[{"op": "replace", "path": "/status/history", "value": []}]'

# 2. Update ArgoCD images
echo "2. Checking for ArgoCD updates..."
kubectl set image deployment/argocd-server -n argocd argocd-server=argoproj/argocd:v2.8.0
kubectl set image deployment/argocd-application-controller -n argocd argocd-application-controller=argoproj/argocd:v2.8.0
kubectl set image deployment/argocd-repo-server -n argocd argocd-repo-server=argoproj/argocd:v2.8.0

# 3. Clean up old pods
echo "3. Cleaning up old pods..."
kubectl delete pods -n argocd --field-selector=status.phase=Failed
kubectl delete pods -n argocd --field-selector=status.phase=Succeeded

# 4. Update application configurations
echo "4. Updating application configurations..."
kubectl patch applications -n argocd --all --type='json' -p='[{"op": "replace", "path": "/spec/syncPolicy/retry", "value": {"limit": 5, "backoff": {"duration": "5s", "factor": 2, "maxDuration": "3m"}}}]'

echo "✅ Maintenance completed!"
```

## 7. Monitoring and Alerting

### 7.1 Key Metrics to Monitor

#### ArgoCD Metrics
- **Application Sync Status:** `argocd_app_sync_total`
- **Application Health:** `argocd_app_health_status`
- **Controller Performance:** `argocd_app_reconcile`
- **Repository Sync Time:** `argocd_repo_sync_duration`
- **Component Resource Usage:** Standard Kubernetes metrics

#### Application Metrics
- **Pod Health:** Readiness and liveness probe failures
- **Resource Utilization:** CPU and memory usage
- **Network Connectivity:** Service mesh metrics
- **Database Performance:** Connection pool and query metrics

### 7.2 Alert Configuration

#### Critical Alerts
```yaml
# Critical ArgoCD alerts
groups:
- name: argocd-critical
  rules:
  - alert: ArgoCDServerDown
    expr: up{job="argocd-server"} == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "ArgoCD server is down"
      runbook_url: "https://argoproj.github.io/argo-cd/operator-manual/troubleshooting/"
  
  - alert: ArgoCDApplicationFailed
    expr: argocd_app_sync_total{status="Failed"} > 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "ArgoCD application sync failed"
      description: "Application {{ $labels.name }} has failed to sync"
  
  - alert: ArgoCDHighErrorRate
    expr: rate(argocd_app_reconcile_error_total[5m]) > 0.1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "ArgoCD high error rate"
      description: "ArgoCD is experiencing a high error rate"
```

### 7.3 Dashboard Configuration

#### Grafana Dashboard
```json
{
  "dashboard": {
    "title": "ArgoCD CloudToLocalLLM",
    "panels": [
      {
        "title": "Application Sync Status",
        "type": "stat",
        "targets": [
          {
            "expr": "argocd_app_sync_total{status=\"Synced\"}",
            "legendFormat": "Synced Applications"
          }
        ]
      },
      {
        "title": "Application Health",
        "type": "graph",
        "targets": [
          {
            "expr": "argocd_app_health_status{status=\"Healthy\"}",
            "legendFormat": "Healthy"
          },
          {
            "expr": "argocd_app_health_status{status=\"Unhealthy\"}",
            "legendFormat": "Unhealthy"
          }
        ]
      }
    ]
  }
}
```

## 8. Best Practices

### 8.1 GitOps Best Practices

#### Repository Structure
- Maintain separate branches for different environments
- Use pull requests for all changes
- Implement code review requirements
- Use semantic versioning for releases

#### Configuration Management
- Store all configurations in version control
- Use environment-specific overlays
- Implement configuration validation
- Use secrets management for sensitive data

### 8.2 Deployment Best Practices

#### Blue-Green Deployments
```yaml
# Blue-green deployment strategy
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudtolocalllm-api-backend
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-options: CreateNamespace=true
spec:
  source:
    repoURL: https://github.com/imrightguy/CloudToLocalLLM
    targetRevision: main
    path: k8s/apps/managed/api-backend
    kustomize:
      images:
      - cloudtolocalllm/api-backend:blue  # Current version
      # - cloudtolocalllm/api-backend:green  # New version (commented out)
```

#### Canary Deployments
```yaml
# Canary deployment with Argo Rollouts
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api-backend-rollout
  namespace: cloudtolocalllm
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 10m}
      - setWeight: 50
      - pause: {duration: 10m}
      - setWeight: 100
  template:
    spec:
      containers:
      - name: api-backend
        image: cloudtolocalllm/api-backend:v2.0.0
```

### 8.3 Security Best Practices

#### Image Security
- Use trusted base images
- Implement image scanning
- Pin image versions
- Use read-only file systems

#### Access Control
- Implement least privilege access
- Use RBAC for all operations
- Regular access reviews
- Multi-factor authentication

## 9. Validation and Testing

### 9.1 Pre-deployment Testing

#### Automated Testing Pipeline
```yaml
# GitHub Actions workflow for ArgoCD validation
name: ArgoCD Validation
on:
  pull_request:
    branches: [main]
jobs:
  validate-argocd:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Validate Kubernetes manifests
      run: |
        find k8s/ -name "*.yaml" | xargs -I {} kubectl apply --dry-run=client -f {}
    - name: Validate ArgoCD applications
      run: |
        argocd app list --output json | jq -r '.[].metadata.name' | xargs -I {} argocd app get {}
```

### 9.2 Post-deployment Validation

#### Smoke Tests
```bash
#!/bin/bash
# smoke-tests.sh

echo "=== Post-deployment Smoke Tests ==="

# Test application endpoints
echo "1. Testing API endpoints..."
curl -f http://api-backend.cloudtolocalllm.online/health || exit 1
curl -f http://web-frontend.cloudtolocalllm.online/ || exit 1

# Test database connectivity
echo "2. Testing database connectivity..."
kubectl exec -n cloudtolocalllm deployment/api-backend -- curl -f http://postgres:5432 || exit 1

# Test Redis connectivity
echo "3. Testing Redis connectivity..."
kubectl exec -n cloudtolocalllm deployment/api-backend -- curl -f http://redis:6379 || exit 1

echo "✅ All smoke tests passed!"
```

## 10. Documentation and Training

### 10.1 Runbooks

#### ArgoCD Troubleshooting Runbook
1. **Application Not Syncing**
   - Check application status: `argocd app get <app-name>`
   - Check logs: `kubectl logs -n argocd deployment/argocd-application-controller`
   - Manual sync: `argocd app sync <app-name>`

2. **ArgoCD Server Unavailable**
   - Check pod status: `kubectl get pods -n argocd`
   - Check service: `kubectl get svc -n argocd`
   - Restart deployment: `kubectl rollout restart deployment/argocd-server -n argocd`

3. **Repository Access Issues**
   - Check repository configuration: `argocd repo list`
   - Verify credentials: `argocd repo get <repo-url>`
   - Test connectivity: `git ls-remote <repo-url>`

### 10.2 Training Materials

#### ArgoCD Operations Training
- **Basic Operations:** Application management, sync operations
- **Advanced Features:** ApplicationSets, sync waves, hooks
- **Troubleshooting:** Common issues and resolution procedures
- **Security:** RBAC, secrets management, access control

## Conclusion

This comprehensive ArgoCD stabilization plan provides a robust framework for ensuring successful and reliable deployment of the CloudToLocalLLM web application. By implementing these procedures, configurations, and best practices, the team can maintain high availability, rapid recovery capabilities, and operational excellence.

### Implementation Timeline

1. **Phase 1 (Week 1):** Implement diagnostic procedures and health monitoring
2. **Phase 2 (Week 2):** Configure enhanced sync policies and resource optimization
3. **Phase 3 (Week 3):** Implement rollback strategies and disaster recovery
4. **Phase 4 (Week 4):** Deploy preventive measures and operational protocols
5. **Phase 5 (Week 5):** Establish monitoring, alerting, and documentation

### Success Metrics

- **Deployment Success Rate:** >99%
- **Mean Time to Recovery (MTTR):** <15 minutes
- **Application Uptime:** >99.9%
- **Sync Success Rate:** >99.5%

Regular review and updates to this plan should be conducted quarterly or as the application architecture evolves.