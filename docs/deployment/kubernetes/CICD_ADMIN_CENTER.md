# Admin Center CI/CD Pipeline

## Overview

This document describes the CI/CD pipeline for deploying the Admin Center feature to Azure Kubernetes Service (AKS).

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflow                   │
│                                                              │
│  1. Build Phase                                             │
│     ├─ Build API Backend Docker Image                      │
│     ├─ Build Web App Docker Image                          │
│     └─ Push to Docker Hub                                   │
│                                                              │
│  2. Deploy Phase                                            │
│     ├─ Update API Backend Deployment                       │
│     ├─ Update Web Deployment                               │
│     ├─ Run Database Migrations                             │
│     └─ Purge Cloudflare Cache                              │
│                                                              │
│  3. Verification Phase                                      │
│     ├─ Wait for Rollout                                    │
│     ├─ Verify Deployment                                   │
│     └─ DNS Validation                                       │
└─────────────────────────────────────────────────────────────┘
```

## Workflow File

Location: `.github/workflows/deploy-aks.yml`

### Triggers

The pipeline is triggered by:

1. **Push to main branch**
   - Automatically deploys to production
   - Runs on every commit to main

2. **Manual workflow dispatch**
   - Allows manual deployment
   - Useful for hotfixes or rollbacks

### Jobs

#### 1. Build Job

Builds and pushes Docker images to Docker Hub.

**Steps:**
1. Checkout code
2. Set up Docker Buildx
3. Log in to Docker Hub
4. Extract metadata for versioning
5. Build and push API image
6. Build and push Web image

**Images:**
- `cloudtolocalllm/cloudtolocalllm-api:latest`
- `cloudtolocalllm/cloudtolocalllm-api:main-<commit-sha>`
- `cloudtolocalllm/cloudtolocalllm-web:latest`
- `cloudtolocalllm/cloudtolocalllm-web:main-<commit-sha>`

#### 2. Deploy Job

Deploys images to AKS and runs migrations.

**Steps:**
1. Checkout code
2. Azure login
3. Get AKS credentials
4. Update API backend deployment
5. Update Web deployment
6. **Run Admin Center database migrations** (NEW)
7. Purge Cloudflare cache
8. Wait for rollout
9. Verify deployment

**Migration Step:**
```yaml
- name: Run Admin Center database migrations
  run: |
    # Delete existing migration job
    kubectl delete job admin-center-migration -n cloudtolocalllm --ignore-not-found=true
    
    # Apply migration job
    kubectl apply -f k8s/admin-center-migration-job.yaml
    
    # Wait for completion (5 min timeout)
    kubectl wait --for=condition=complete --timeout=300s \
      job/admin-center-migration -n cloudtolocalllm
```

#### 3. DNS Validation Job

Configures Cloudflare DNS and SSL.

**Steps:**
1. Azure login
2. Get load balancer IP
3. Configure Cloudflare DNS records
4. Enable SSL/TLS
5. Enable Always Use HTTPS
6. DNS health check

## Database Migrations

### Migration Job

Location: `k8s/admin-center-migration-job.yaml`

The migration job:
1. Runs as a Kubernetes Job
2. Uses the same API backend image
3. Executes migration script
4. Auto-cleans up after 5 minutes
5. Fails deployment if migration fails

### Migration Script

Location: `services/api-backend/database/migrations/run-migration.js`

The script:
1. Connects to PostgreSQL database
2. Checks if tables exist
3. Creates Admin Center tables if needed
4. Inserts default super admin role
5. Logs migration status

### Migration Tables

The migration creates:
- `subscriptions` - User subscription data
- `payment_transactions` - Payment records
- `payment_methods` - User payment methods
- `refunds` - Refund records
- `admin_roles` - Administrator roles
- `admin_audit_logs` - Audit log entries

## Environment-Specific Deployments

### Staging Environment

**Namespace:** `cloudtolocalllm-staging`

**Configuration:**
- Uses Stripe test keys
- Separate database
- Staging domain: `admin-staging.cloudtolocalllm.online`

**Deploy:**
```bash
# Manual staging deployment
kubectl apply -k k8s/overlays/staging/
```

### Production Environment

**Namespace:** `cloudtolocalllm`

**Configuration:**
- Uses Stripe live keys
- Production database
- Production domain: `admin.cloudtolocalllm.online`

**Deploy:**
```bash
# Automatic via GitHub Actions on push to main
# Or manual:
kubectl apply -k k8s/overlays/production/
```

## Required Secrets

### GitHub Secrets

Configure these secrets in GitHub repository settings:

| Secret | Description | Example |
|--------|-------------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub username | `cloudtolocalllm` |
| `DOCKERHUB_TOKEN` | Docker Hub access token | `dckr_pat_...` |
| `AZURE_CREDENTIALS` | Azure service principal | `{"clientId": "...", ...}` |
| `AZURE_CLIENT_ID` | Azure client ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_TENANT_ID` | Azure tenant ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token | `...` |

### Kubernetes Secrets

Configure these secrets in Kubernetes:

```bash
# Apply secrets
kubectl apply -f k8s/secrets.yaml -n cloudtolocalllm
```

See `k8s/secrets.yaml.template` for required values.

## Deployment Process

### Automatic Deployment

1. Developer pushes code to `main` branch
2. GitHub Actions triggers workflow
3. Build job builds Docker images
4. Deploy job updates Kubernetes deployments
5. Migration job runs database migrations
6. Rollout completes
7. DNS validation ensures accessibility

### Manual Deployment

```bash
# 1. Build images locally (optional)
docker build -f services/api-backend/Dockerfile.prod -t cloudtolocalllm/cloudtolocalllm-api:latest .
docker build -f config/docker/Dockerfile.web -t cloudtolocalllm/cloudtolocalllm-web:latest .

# 2. Push images
docker push cloudtolocalllm/cloudtolocalllm-api:latest
docker push cloudtolocalllm/cloudtolocalllm-web:latest

# 3. Apply Kubernetes manifests
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/api-backend-deployment.yaml
kubectl apply -f k8s/web-deployment.yaml

# 4. Run migrations
kubectl apply -f k8s/admin-center-migration-job.yaml
kubectl wait --for=condition=complete --timeout=300s job/admin-center-migration -n cloudtolocalllm

# 5. Verify deployment
kubectl rollout status deployment/api-backend -n cloudtolocalllm
kubectl rollout status deployment/web -n cloudtolocalllm
```

## Rollback Procedure

### Automatic Rollback

If deployment fails, rollback to previous version:

```bash
# Rollback API backend
kubectl rollout undo deployment/api-backend -n cloudtolocalllm

# Rollback Web
kubectl rollout undo deployment/web -n cloudtolocalllm

# Check status
kubectl rollout status deployment/api-backend -n cloudtolocalllm
kubectl rollout status deployment/web -n cloudtolocalllm
```

### Database Rollback

If migration fails, rollback database:

```bash
# Connect to database
kubectl exec -it statefulset/postgres -n cloudtolocalllm -- \
  psql -U appuser -d cloudtolocalllm

# Drop Admin Center tables (CAUTION!)
DROP TABLE IF EXISTS admin_audit_logs CASCADE;
DROP TABLE IF EXISTS admin_roles CASCADE;
DROP TABLE IF EXISTS refunds CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;
DROP TABLE IF EXISTS payment_transactions CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;

# Or restore from backup
kubectl exec -i statefulset/postgres -n cloudtolocalllm -- \
  psql -U appuser cloudtolocalllm < backup-before-migration.sql
```

## Monitoring Deployment

### View Deployment Status

```bash
# Watch deployment progress
kubectl get pods -n cloudtolocalllm -w

# Check deployment status
kubectl rollout status deployment/api-backend -n cloudtolocalllm

# View logs
kubectl logs -f deployment/api-backend -n cloudtolocalllm
```

### View Migration Logs

```bash
# View migration job logs
kubectl logs job/admin-center-migration -n cloudtolocalllm

# Check migration job status
kubectl get job admin-center-migration -n cloudtolocalllm

# Describe migration job
kubectl describe job admin-center-migration -n cloudtolocalllm
```

### Health Checks

```bash
# Check API health
kubectl port-forward svc/api-backend 3000:3000 -n cloudtolocalllm
curl http://localhost:3000/health

# Check admin API
curl http://localhost:3000/api/admin/dashboard/metrics \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Troubleshooting

### Build Failures

**Issue: Docker build fails**

```bash
# Check build logs in GitHub Actions
# View "Build and push API image" step

# Test build locally
docker build -f services/api-backend/Dockerfile.prod -t test-api .
```

**Issue: Image push fails**

```bash
# Verify Docker Hub credentials
docker login -u cloudtolocalllm

# Check GitHub secrets
# Ensure DOCKERHUB_USERNAME and DOCKERHUB_TOKEN are set
```

### Deployment Failures

**Issue: Deployment rollout fails**

```bash
# Check pod status
kubectl get pods -n cloudtolocalllm

# View pod logs
kubectl logs deployment/api-backend -n cloudtolocalllm

# Describe pod for events
kubectl describe pod <pod-name> -n cloudtolocalllm
```

**Issue: Image pull error**

```bash
# Verify image exists
docker pull cloudtolocalllm/cloudtolocalllm-api:latest

# Check image pull policy
kubectl get deployment api-backend -n cloudtolocalllm -o yaml | grep imagePullPolicy
```

### Migration Failures

**Issue: Migration job fails**

```bash
# View migration logs
kubectl logs job/admin-center-migration -n cloudtolocalllm

# Check database connectivity
kubectl exec -it deployment/api-backend -n cloudtolocalllm -- \
  psql -h $DB_HOST -U $DB_USER -d $DB_NAME

# Manually run migration
kubectl exec -it deployment/api-backend -n cloudtolocalllm -- \
  node services/api-backend/database/migrations/run-migration.js
```

**Issue: Migration timeout**

```bash
# Increase timeout in workflow
kubectl wait --for=condition=complete --timeout=600s \
  job/admin-center-migration -n cloudtolocalllm

# Or run migration manually after deployment
```

### DNS Issues

**Issue: Domain not accessible**

```bash
# Check load balancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Check DNS records
nslookup admin.cloudtolocalllm.online

# Check Cloudflare DNS
curl -X GET "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

## Performance Optimization

### Build Cache

The pipeline uses GitHub Actions cache for Docker builds:

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

This speeds up builds by reusing layers.

### Parallel Builds

API and Web images are built in parallel:

```yaml
- name: Build and push API image
  uses: docker/build-push-action@v5
  # Runs in parallel with Web build
```

### Rolling Updates

Deployments use rolling updates to minimize downtime:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

## Security Considerations

### Image Scanning

Consider adding image scanning:

```yaml
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: cloudtolocalllm/cloudtolocalllm-api:latest
    format: 'sarif'
    output: 'trivy-results.sarif'
```

### Secret Management

- Never commit secrets to repository
- Use GitHub secrets for CI/CD
- Use Kubernetes secrets for runtime
- Rotate secrets regularly

### Access Control

- Limit who can trigger deployments
- Use branch protection rules
- Require code reviews
- Enable deployment approvals

## Best Practices

1. **Test before deploying**
   - Run tests in CI pipeline
   - Test migrations locally
   - Use staging environment

2. **Monitor deployments**
   - Watch logs during deployment
   - Check health endpoints
   - Verify functionality

3. **Have rollback plan**
   - Keep previous versions
   - Test rollback procedure
   - Document rollback steps

4. **Document changes**
   - Update CHANGELOG.md
   - Document breaking changes
   - Update API documentation

5. **Communicate deployments**
   - Notify team before deployment
   - Schedule maintenance windows
   - Announce completion

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Docker Build Documentation](https://docs.docker.com/engine/reference/commandline/build/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
