# Admin Center Deployment Guide

## Overview

The Admin Center is integrated into the existing API backend service and does not require a separate deployment. This guide covers the configuration and deployment of the Admin Center feature.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         API Backend Deployment                      │    │
│  │  - Admin API routes (/api/admin/*)                 │    │
│  │  - Payment gateway integration (Stripe)            │    │
│  │  - Database connection pooling                     │    │
│  │  - Webhook handlers                                │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         Web Deployment                              │    │
│  │  - Flutter web app                                 │    │
│  │  - Admin Center UI                                 │    │
│  │  - Settings integration                            │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         PostgreSQL StatefulSet                      │    │
│  │  - User data                                       │    │
│  │  - Subscriptions                                   │    │
│  │  - Payment transactions                            │    │
│  │  - Admin roles                                     │    │
│  │  - Audit logs                                      │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Configuration Files

### Base Configuration

- `k8s/configmap.yaml` - Application configuration
- `k8s/secrets.yaml.template` - Secrets template (copy to secrets.yaml)
- `k8s/api-backend-deployment.yaml` - API backend deployment with Admin Center

### Environment-Specific Overlays

- `k8s/overlays/staging/` - Staging environment (uses Stripe test keys)
- `k8s/overlays/production/` - Production environment (uses Stripe live keys)

## Environment Variables

### Admin Center Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `ADMIN_CENTER_ENABLED` | Enable/disable Admin Center | `true` |
| `ADMIN_EMAIL` | Default super admin email | `cmaltais@cloudtolocalllm.online` |

### Stripe Configuration

| Variable | Description | Environment |
|----------|-------------|-------------|
| `STRIPE_SECRET_KEY` | Stripe secret API key | Test: `sk_test_...`, Live: `sk_live_...` |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key | Test: `pk_test_...`, Live: `pk_live_...` |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret | Test: `whsec_...`, Live: `whsec_...` |

### Database Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_POOL_MAX` | Maximum database connections | `50` |
| `DB_POOL_IDLE_TIMEOUT` | Idle connection timeout (ms) | `600000` (10 min) |
| `DB_POOL_CONNECTION_TIMEOUT` | Connection timeout (ms) | `30000` (30 sec) |

## Deployment Steps

### 1. Configure Secrets

Copy the secrets template and fill in your values:

```bash
cp k8s/secrets.yaml.template k8s/secrets.yaml
```

Edit `k8s/secrets.yaml` and set:

**Stripe Test Keys (for staging):**
```yaml
stripe-test-secret-key: "sk_test_YOUR_KEY_HERE"
stripe-test-publishable-key: "pk_test_YOUR_KEY_HERE"
stripe-test-webhook-secret: "whsec_YOUR_SECRET_HERE"
```

**Stripe Live Keys (for production):**
```yaml
stripe-live-secret-key: "sk_live_YOUR_KEY_HERE"
stripe-live-publishable-key: "pk_live_YOUR_KEY_HERE"
stripe-live-webhook-secret: "whsec_YOUR_SECRET_HERE"
```

**IMPORTANT:** Never commit `k8s/secrets.yaml` to version control!

### 2. Apply Database Migrations

Before deploying, ensure the database schema is up to date:

```bash
# Connect to the API backend pod
kubectl exec -it deployment/api-backend -n cloudtolocalllm -- /bin/sh

# Run migrations
cd /app
node services/api-backend/database/migrations/run-migration.js

# Optional: Seed development data
node services/api-backend/database/seeds/run-seed.js
```

### 3. Deploy to Staging

```bash
# Apply secrets
kubectl apply -f k8s/secrets.yaml -n cloudtolocalllm-staging

# Deploy using kustomize
kubectl apply -k k8s/overlays/staging/
```

### 4. Deploy to Production

```bash
# Apply secrets
kubectl apply -f k8s/secrets.yaml -n cloudtolocalllm

# Deploy using kustomize
kubectl apply -k k8s/overlays/production/
```

### 5. Verify Deployment

```bash
# Check pod status
kubectl get pods -n cloudtolocalllm

# Check logs
kubectl logs -f deployment/api-backend -n cloudtolocalllm

# Test admin API
kubectl port-forward svc/api-backend 3000:3000 -n cloudtolocalllm
curl http://localhost:3000/api/admin/dashboard/metrics \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Stripe Webhook Configuration

### 1. Get Webhook Endpoint URL

The webhook endpoint is: `https://api.cloudtolocalllm.online/api/webhooks/stripe`

### 2. Configure Stripe Webhook

1. Go to Stripe Dashboard > Developers > Webhooks
2. Click "Add endpoint"
3. Enter URL: `https://api.cloudtolocalllm.online/api/webhooks/stripe`
4. Select events to listen for:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
5. Copy the webhook signing secret
6. Update `STRIPE_WEBHOOK_SECRET` in secrets.yaml

### 3. Test Webhook

```bash
# Use Stripe CLI to test webhooks locally
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# Trigger test events
stripe trigger payment_intent.succeeded
```

## Resource Limits

The API backend deployment includes resource limits:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "100m"
  limits:
    memory: "2Gi"
    cpu: "500m"
```

Adjust these based on your workload:

- **Light usage** (< 100 users): Current limits are sufficient
- **Medium usage** (100-1000 users): Increase to 4Gi memory, 1000m CPU
- **Heavy usage** (> 1000 users): Consider horizontal scaling (increase replicas)

## Scaling

### Horizontal Scaling

Increase the number of API backend replicas:

```bash
kubectl scale deployment/api-backend --replicas=3 -n cloudtolocalllm
```

Or update the deployment YAML:

```yaml
spec:
  replicas: 3
```

### Database Connection Pooling

With multiple replicas, adjust the database pool size:

```yaml
# In configmap.yaml
DB_POOL_MAX: "20"  # 20 connections per replica
```

Total connections = `replicas * DB_POOL_MAX`

Example: 3 replicas * 20 connections = 60 total connections

## Monitoring

### Health Checks

The API backend includes health check endpoints:

- Liveness probe: `GET /health`
- Readiness probe: `GET /health`

### Metrics

Admin Center metrics are exposed via Prometheus:

```bash
# Port forward to Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# Query metrics
# - admin_api_requests_total
# - admin_api_response_time
# - payment_gateway_requests_total
# - database_pool_connections
```

### Logs

View logs for troubleshooting:

```bash
# API backend logs
kubectl logs -f deployment/api-backend -n cloudtolocalllm

# Filter for admin actions
kubectl logs deployment/api-backend -n cloudtolocalllm | grep "admin_action"

# Filter for payment errors
kubectl logs deployment/api-backend -n cloudtolocalllm | grep "payment_error"
```

## Troubleshooting

### Admin Center Not Accessible

1. Check if admin routes are registered:
```bash
kubectl logs deployment/api-backend -n cloudtolocalllm | grep "Admin routes"
```

2. Verify admin email configuration:
```bash
kubectl get configmap cloudtolocalllm-config -n cloudtolocalllm -o yaml | grep ADMIN_EMAIL
```

3. Check JWT token:
```bash
# Decode JWT token
echo "YOUR_JWT_TOKEN" | jwt decode -
```

### Payment Gateway Errors

1. Verify Stripe API keys:
```bash
kubectl get secret cloudtolocalllm-secrets -n cloudtolocalllm -o yaml
```

2. Check Stripe API connectivity:
```bash
kubectl exec -it deployment/api-backend -n cloudtolocalllm -- curl https://api.stripe.com/v1/charges -u sk_test_YOUR_KEY:
```

3. Verify webhook secret:
```bash
# Check webhook logs
kubectl logs deployment/api-backend -n cloudtolocalllm | grep "webhook"
```

### Database Connection Issues

1. Check database connectivity:
```bash
kubectl exec -it deployment/api-backend -n cloudtolocalllm -- \
  psql -h postgres.cloudtolocalllm.svc.cluster.local -U appuser -d cloudtolocalllm
```

2. Check connection pool:
```bash
kubectl logs deployment/api-backend -n cloudtolocalllm | grep "pool"
```

3. Verify database migrations:
```bash
kubectl exec -it deployment/api-backend -n cloudtolocalllm -- \
  psql -h postgres.cloudtolocalllm.svc.cluster.local -U appuser -d cloudtolocalllm \
  -c "SELECT * FROM schema_migrations;"
```

## Security Considerations

### Secrets Management

- Never commit `secrets.yaml` to version control
- Use Kubernetes secrets for sensitive data
- Rotate secrets regularly (every 90 days)
- Use separate secrets for staging and production

### Network Security

- Admin API is only accessible via HTTPS
- CORS is restricted to app domain
- Rate limiting is enforced (100 req/min per admin)
- Input validation on all endpoints

### Database Security

- Use SSL/TLS for database connections
- Limit database user privileges
- Use parameterized queries (SQL injection prevention)
- Regular database backups

### Audit Logging

- All admin actions are logged
- Logs are immutable and tamper-proof
- Logs retained for 7 years (compliance)
- Regular audit log reviews

## Rollback Procedure

If deployment fails, rollback to previous version:

```bash
# Rollback API backend
kubectl rollout undo deployment/api-backend -n cloudtolocalllm

# Check rollout status
kubectl rollout status deployment/api-backend -n cloudtolocalllm

# Verify pods are running
kubectl get pods -n cloudtolocalllm
```

## Backup and Disaster Recovery

### Database Backup

```bash
# Create database backup
kubectl exec -it statefulset/postgres -n cloudtolocalllm -- \
  pg_dump -U appuser cloudtolocalllm > backup-$(date +%Y%m%d).sql

# Restore from backup
kubectl exec -i statefulset/postgres -n cloudtolocalllm -- \
  psql -U appuser cloudtolocalllm < backup-20251116.sql
```

### Configuration Backup

```bash
# Backup all Kubernetes resources
kubectl get all,configmap,secret -n cloudtolocalllm -o yaml > k8s-backup.yaml
```

## Support

For issues or questions:

1. Check logs: `kubectl logs deployment/api-backend -n cloudtolocalllm`
2. Review documentation: `docs/API/ADMIN_API.md`
3. Contact: cmaltais@cloudtolocalllm.online
