# CloudToLocalLLM - Complete Cloud Run Deployment Guide

This guide provides step-by-step instructions for deploying CloudToLocalLLM to Google Cloud Run with full functionality.

## 🎯 What This Deployment Provides

✅ **Complete Cloud Run Infrastructure**
- Three optimized Cloud Run services (web, api, streaming)
- Automatic database setup and migration
- Cross-service communication with proper CORS
- Secrets management with Google Secret Manager
- Health monitoring and service discovery

✅ **Production-Ready Features**
- Auto-scaling from 0 to handle any traffic
- Proper security with non-root containers
- Database persistence with SQLite/Cloud SQL support
- Environment-specific configuration
- Comprehensive logging and monitoring

✅ **Developer Experience**
- One-command deployment
- Automated CI/CD with Cloud Build
- Cross-platform scripts (Linux/macOS/Windows)
- Detailed health checking and debugging tools

## 🚀 Quick Start (5 Minutes)

### 1. Prerequisites Setup

```bash
# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Authenticate
gcloud auth login
gcloud auth application-default login

# Install Docker (for local testing)
# Follow instructions at: https://docs.docker.com/get-docker/
```

### 2. Initial Configuration

```bash
# Clone and navigate to the repository
git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git
cd CloudToLocalLLM

# Copy and configure environment
cp config/cloudrun/.env.cloudrun.template config/cloudrun/.env.cloudrun

# Edit the configuration file with your values
nano config/cloudrun/.env.cloudrun
```

**Required Configuration:**
```bash
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_REGION=us-central1
AUTH0_DOMAIN=your-auth0-domain.auth0.com
AUTH0_CLIENT_ID=your-auth0-client-id
AUTH0_CLIENT_SECRET=your-auth0-client-secret
JWT_SECRET=your-secure-random-string
```

### 3. One-Command Deployment

```bash
# Complete deployment (setup + build + deploy + configure)
./scripts/cloudrun/deploy-complete.sh

# Or step by step:
./scripts/cloudrun/setup-cloudrun.sh          # Initial setup
./scripts/cloudrun/deploy-to-cloudrun.sh      # Build and deploy
./config/cloudrun/configure-services.sh       # Configure services
```

### 4. Verify Deployment

```bash
# Check service health
./scripts/cloudrun/health-check.sh

# View service URLs
cat config/cloudrun/service-urls.json
```

## 📋 Detailed Deployment Steps

### Step 1: Environment Setup

The setup script configures your Google Cloud environment:

```bash
./scripts/cloudrun/setup-cloudrun.sh
```

**What it does:**
- Enables required Google Cloud APIs
- Creates Artifact Registry repository
- Sets up service accounts and IAM roles
- Creates secrets in Secret Manager
- Configures Cloud SQL (if using PostgreSQL/MySQL)

### Step 2: Build and Deploy Services

```bash
# Deploy all services
./scripts/cloudrun/deploy-to-cloudrun.sh

# Or deploy individual services
./scripts/cloudrun/deploy-to-cloudrun.sh --service web
./scripts/cloudrun/deploy-to-cloudrun.sh --service api
./scripts/cloudrun/deploy-to-cloudrun.sh --service streaming
```

**What it deploys:**
- **Web Service**: Flutter web app with Nginx
- **API Service**: Node.js backend with database
- **Streaming Service**: WebSocket proxy for real-time features

### Step 3: Configure Service Communication

```bash
./config/cloudrun/configure-services.sh
```

**What it configures:**
- CORS settings for cross-service communication
- Service discovery URLs
- Environment variables for each service
- Health check endpoints

### Step 4: Monitor and Verify

```bash
# Continuous health monitoring
./scripts/cloudrun/health-check.sh --continuous

# Check service logs
gcloud logs read "resource.type=cloud_run_revision" --limit=50

# View service details
gcloud run services list --platform=managed --region=us-central1
```

## 🔧 Advanced Configuration

### Custom Domain Setup

```bash
# Map custom domain to web service
gcloud run domain-mappings create \
    --service cloudtolocalllm-web \
    --domain your-domain.com \
    --region us-central1

# Get DNS configuration
gcloud run domain-mappings describe \
    --domain your-domain.com \
    --region us-central1
```

### Database Configuration

**SQLite (Default):**
- Automatically configured
- Data persists in `/app/data` volume
- Suitable for development and small deployments

**Cloud SQL (Production):**
```bash
# Update .env.cloudrun
DB_TYPE=postgresql
DB_HOST=/cloudsql/project:region:instance
DB_NAME=cloudtolocalllm
DB_USER=appuser
DB_PASSWORD=secure-password

# Redeploy with Cloud SQL
./scripts/cloudrun/deploy-to-cloudrun.sh --service api
```

### Scaling Configuration

```bash
# Configure auto-scaling
gcloud run services update cloudtolocalllm-api \
    --min-instances=1 \
    --max-instances=50 \
    --concurrency=200 \
    --cpu=2 \
    --memory=4Gi
```

### Monitoring and Alerting

```bash
# Set up monitoring
gcloud alpha monitoring policies create \
    --policy-from-file=monitoring/cloudrun-policy.yaml

# View metrics
gcloud monitoring metrics list \
    --filter="resource.type=cloud_run_revision"
```

## 🛠️ Troubleshooting

### Common Issues

**1. Build Failures**
```bash
# Check build logs
gcloud builds list --limit=5
gcloud builds log BUILD_ID

# Common fixes:
# - Verify Dockerfile paths
# - Check environment variables
# - Ensure proper permissions
```

**2. Service Communication Issues**
```bash
# Check CORS configuration
curl -H "Origin: https://your-web-service.run.app" \
     https://your-api-service.run.app/health

# Update CORS settings
./config/cloudrun/configure-services.sh
```

**3. Database Issues**
```bash
# Check database migration logs
gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=cloudtolocalllm-api" --limit=20

# Manual migration
gcloud run jobs execute migrate-database --region=us-central1
```

**4. Authentication Issues**
```bash
# Verify Auth0 configuration
curl https://your-api-service.run.app/api/auth/config

# Check secrets
gcloud secrets versions list auth0-client-secret
```

### Debug Commands

```bash
# Service status
gcloud run services describe SERVICE_NAME --region=REGION

# View environment variables
gcloud run services describe SERVICE_NAME --format="export"

# Check service logs
gcloud logs tail "resource.type=cloud_run_revision AND resource.labels.service_name=SERVICE_NAME"

# Test connectivity
curl -v https://SERVICE_URL/health
```

## 💰 Cost Optimization

### Monitoring Costs

```bash
# Estimate costs
./scripts/cloudrun/estimate-costs.sh --requests 50000 --duration 300

# View actual costs
gcloud billing budgets list
```

### Optimization Tips

1. **Right-size resources**: Start small and scale up based on usage
2. **Use minimum instances**: Set to 1 for frequently used services
3. **Optimize cold starts**: Use smaller images and faster startup code
4. **Monitor usage**: Track actual vs estimated costs weekly

## 📊 Performance Monitoring

### Key Metrics

- **Request latency**: Target < 200ms for API calls
- **Cold start frequency**: Should be < 5% of requests
- **Error rate**: Target < 0.1%
- **CPU/Memory utilization**: Target 60-80% average

### Monitoring Commands

```bash
# Real-time monitoring
./scripts/cloudrun/health-check.sh --continuous --interval 10

# Performance metrics
gcloud monitoring metrics list --filter="resource.type=cloud_run_revision"

# Service analytics
gcloud run services describe SERVICE_NAME --format="table(status.traffic[].percent,status.traffic[].latestRevision)"
```

## 🔄 CI/CD Integration

### Automatic Deployment

The Cloud Build trigger automatically deploys on push to main branch:

```yaml
# .github/workflows/cloudrun-deploy.yml
name: Deploy to Cloud Run
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/setup-gcloud@v1
      - run: ./scripts/cloudrun/deploy-to-cloudrun.sh
```

### Manual Deployment

```bash
# Trigger manual deployment
gcloud builds triggers run cloudtolocalllm-trigger --branch=main

# Deploy specific commit
gcloud builds submit --config=cloudbuild.yaml .
```

## 📚 Additional Resources

- **Complete Documentation**: 
- **Cost Analysis**: [scripts/cloudrun/estimate-costs.sh](../../scripts/cloudrun/estimate-costs.sh)
- **Health Monitoring**: [scripts/cloudrun/health-check.sh](../../scripts/cloudrun/health-check.sh)
- **Google Cloud Run Docs**: https://cloud.google.com/run/docs

## 🆘 Support

For issues specific to this deployment:

1. Check the [troubleshooting section](#troubleshooting)
2. Review service logs in Google Cloud Console
3. Run health checks: `./scripts/cloudrun/health-check.sh`
4. Create an issue in the GitHub repository

---

**🎉 Congratulations!** You now have a fully functional CloudToLocalLLM deployment on Google Cloud Run with automatic scaling, proper security, and production-ready features!
