# CloudToLocalLLM - Google Cloud Run Deployment Guide

This guide provides comprehensive instructions for deploying CloudToLocalLLM to Google Cloud Run, including setup, deployment, cost estimation, and performance considerations.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [Deployment Process](#deployment-process)
5. [Configuration](#configuration)
6. [Cost Estimation](#cost-estimation)
7. [Performance Considerations](#performance-considerations)
8. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
9. [Comparison with VPS Deployment](#comparison-with-vps-deployment)
10. [Advanced Configuration](#advanced-configuration)

## Overview

Google Cloud Run is a fully managed serverless platform that automatically scales your containerized applications. This deployment option provides:

- **Automatic scaling**: Scale to zero when not in use, scale up based on demand
- **Pay-per-use pricing**: Only pay for the compute time you actually use
- **Managed infrastructure**: No server management required
- **Global deployment**: Deploy to multiple regions easily
- **Built-in security**: Automatic HTTPS, IAM integration, and container isolation

### Architecture

The CloudToLocalLLM application is deployed as three separate Cloud Run services:

1. **Web Service**: Flutter web application (UI)
2. **API Service**: Node.js backend (authentication, API endpoints)
3. **Streaming Service**: WebSocket proxy for real-time communication

## Prerequisites

### Required Tools

1. **Google Cloud SDK (gcloud)**
   ```bash
   # Install gcloud CLI
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud init
   ```

2. **Docker**
   ```bash
   # Install Docker (Ubuntu/Debian)
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   ```

3. **Git** (for cloning the repository)

### Google Cloud Requirements

1. **Google Cloud Project** with billing enabled
2. **Required IAM Permissions**:
   - Cloud Run Admin
   - Service Account Admin
   - IAM Admin
   - Cloud Build Editor
   - Artifact Registry Admin

3. **Enabled APIs** (automatically enabled by setup script):
   - Cloud Run API
   - Cloud Build API
   - Artifact Registry API
   - IAM API

### Authentication Setup

1. **Authenticate with Google Cloud**:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Set default project**:
   ```bash
   gcloud config set project YOUR_PROJECT_ID
   ```

## Initial Setup

### 1. Run the Setup Script

The setup script configures your Google Cloud environment:

```bash
# Make the script executable
chmod +x scripts/cloudrun/setup-cloudrun.sh

# Run interactive setup
./scripts/cloudrun/setup-cloudrun.sh

# Or specify project and region directly
./scripts/cloudrun/setup-cloudrun.sh my-project-id us-central1
```

This script will:
- Enable required Google Cloud APIs
- Create Artifact Registry repository
- Set up service accounts and IAM roles
- Generate environment configuration template

### 2. Configure Environment Variables

For a comprehensive guide on managing secrets, refer to the [Secrets Management Guide](./SECRETS_MANAGEMENT.md).

Copy and customize the environment configuration:

```bash
cp config/cloudrun/.env.cloudrun.template config/cloudrun/.env.cloudrun
```

Edit `config/cloudrun/.env.cloudrun` with your specific values:

```bash
# Required: Update these values
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_REGION=us-central1
AUTH0_DOMAIN=your-auth0-domain.auth0.com
AUTH0_CLIENT_ID=your-auth0-client-id
AUTH0_CLIENT_SECRET=your-auth0-client-secret
JWT_SECRET=your-secure-jwt-secret
```

### 3. Set Up Secrets (Optional but Recommended)

For production deployments, store sensitive data in Google Secret Manager:

```bash
# Create secrets
echo -n "your-auth0-client-secret" | gcloud secrets create auth0-client-secret --data-file=-
echo -n "your-jwt-secret" | gcloud secrets create jwt-secret --data-file=-

# Grant access to service account
gcloud secrets add-iam-policy-binding auth0-client-secret \
    --member="serviceAccount:cloudtolocalllm-runner@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

## Deployment Process

### Quick Deployment

Deploy all services with a single command:

```bash
# Make the deployment script executable
chmod +x scripts/cloudrun/deploy-to-cloudrun.sh

# Deploy all services
./scripts/cloudrun/deploy-to-cloudrun.sh
```

### Selective Deployment

Deploy specific services:

```bash
# Deploy only the web application
./scripts/cloudrun/deploy-to-cloudrun.sh --service web

# Deploy only the API backend
./scripts/cloudrun/deploy-to-cloudrun.sh --service api

# Deploy only the streaming service
./scripts/cloudrun/deploy-to-cloudrun.sh --service streaming
```

### Build and Deploy Separately

For CI/CD pipelines or when you want more control:

```bash
# Build container images only
./scripts/cloudrun/deploy-to-cloudrun.sh --build-only

# Deploy using pre-built images
./scripts/cloudrun/deploy-to-cloudrun.sh --deploy-only
```

### Dry Run

See what would be deployed without actually deploying:

```bash
./scripts/cloudrun/deploy-to-cloudrun.sh --dry-run
```

## Configuration

### Service Configuration

Each service can be configured independently:

#### Web Service (Flutter App)
- **CPU**: 1 vCPU
- **Memory**: 1 GB
- **Concurrency**: 80 requests per instance
- **Scaling**: 0-10 instances

#### API Service (Node.js Backend)
- **CPU**: 2 vCPUs
- **Memory**: 2 GB
- **Concurrency**: 100 requests per instance
- **Scaling**: 0-20 instances

#### Streaming Service (WebSocket Proxy)
- **CPU**: 1 vCPU
- **Memory**: 1 GB
- **Concurrency**: 50 requests per instance
- **Scaling**: 0-15 instances

### Custom Domain Setup

1. **Map custom domain**:
   ```bash
   gcloud run domain-mappings create \
       --service cloudtolocalllm-web \
       --domain your-domain.com \
       --region us-central1
   ```

2. **Configure DNS**: Add the CNAME record provided by Cloud Run to your DNS

3. **SSL Certificate**: Automatically provisioned by Google

### Environment Variables

Key environment variables for each service:

```bash
# Common
NODE_ENV=production
LOG_LEVEL=info
PORT=8080

# API Service specific
AUTH0_DOMAIN=your-domain.auth0.com
AUTH0_CLIENT_ID=your-client-id
JWT_SECRET=your-jwt-secret
DB_TYPE=sqlite
```

## Cost Estimation

### Pricing Model

Cloud Run uses a pay-per-use model based on:

1. **CPU allocation** (per vCPU-second)
2. **Memory allocation** (per GB-second)
3. **Requests** (per million requests)
4. **Networking** (egress traffic)

### Cost Calculator

**Monthly estimates for different usage levels:**

#### Light Usage (1,000 requests/month)
- **Web Service**: ~$0.50/month
- **API Service**: ~$1.00/month
- **Streaming Service**: ~$0.30/month
- **Total**: ~$1.80/month

#### Medium Usage (50,000 requests/month)
- **Web Service**: ~$5.00/month
- **API Service**: ~$15.00/month
- **Streaming Service**: ~$8.00/month
- **Total**: ~$28.00/month

#### High Usage (500,000 requests/month)
- **Web Service**: ~$25.00/month
- **API Service**: ~$75.00/month
- **Streaming Service**: ~$40.00/month
- **Total**: ~$140.00/month

### Cost Optimization Tips

1. **Right-size resources**: Start with minimal CPU/memory and scale up as needed
2. **Optimize cold starts**: Use smaller container images and faster startup code
3. **Use minimum instances**: Set min instances to 1 for frequently used services
4. **Monitor usage**: Use Cloud Monitoring to track actual resource usage
5. **Regional deployment**: Deploy in regions closest to your users

### Cost Comparison Tools

Use the [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator) for detailed estimates based on your specific usage patterns.

## Performance Considerations

### Cold Start Optimization

Cloud Run may experience cold starts when scaling from zero. To minimize impact:

1. **Optimize container size**: Use multi-stage builds and minimal base images
2. **Reduce startup time**: Minimize initialization code and dependencies
3. **Use minimum instances**: Set min instances to 1 for critical services
4. **Implement health checks**: Proper health checks help with faster scaling

### Scaling Configuration

```bash
# Configure scaling for better performance
gcloud run services update cloudtolocalllm-api \
    --min-instances=1 \
    --max-instances=20 \
    --concurrency=100 \
    --cpu=2 \
    --memory=2Gi
```

### Performance Monitoring

Monitor key metrics:
- **Request latency**: Target < 200ms for API calls
- **Cold start frequency**: Should be < 5% of requests
- **Error rate**: Target < 0.1%
- **CPU/Memory utilization**: Target 60-80% average

### WebSocket Considerations

Cloud Run has limitations for WebSocket connections:
- **Connection timeout**: 60 minutes maximum
- **Concurrent connections**: Limited by instance concurrency
- **Cold starts**: May affect real-time features

Consider using Google Cloud Pub/Sub for high-volume real-time messaging.

## Monitoring and Troubleshooting

### Built-in Monitoring

Cloud Run provides built-in monitoring through Google Cloud Console:

1. **Service metrics**: Request count, latency, error rate
2. **Resource utilization**: CPU, memory usage
3. **Scaling events**: Instance creation/destruction
4. **Logs**: Application and system logs

### Custom Monitoring

Set up custom monitoring:

```bash
# Install monitoring agent in your application
npm install @google-cloud/monitoring
```

### Common Issues and Solutions

#### 1. Cold Start Latency
**Problem**: Slow response times on first request
**Solution**: 
- Set minimum instances to 1
- Optimize container startup time
- Use Cloud Run's always-on CPU allocation

#### 2. Memory Limits
**Problem**: Container killed due to memory usage
**Solution**:
- Increase memory allocation
- Optimize application memory usage
- Use memory profiling tools

#### 3. Request Timeout
**Problem**: Requests timing out
**Solution**:
- Increase timeout settings
- Optimize slow operations
- Use asynchronous processing

#### 4. Authentication Issues
**Problem**: Auth0 integration not working
**Solution**:
- Verify environment variables
- Check Auth0 configuration
- Review CORS settings

### Debugging Commands

```bash
# View service logs
gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=cloudtolocalllm-api" --limit=50

# Check service status
gcloud run services describe cloudtolocalllm-api --region=us-central1

# View service metrics
gcloud monitoring metrics list --filter="resource.type=cloud_run_revision"
```

## Comparison with VPS Deployment

### Cloud Run vs VPS: Decision Matrix

| Factor | Cloud Run | VPS Deployment | Winner |
|--------|-----------|----------------|---------|
| **Setup Complexity** | Low (managed) | High (manual setup) | Cloud Run |
| **Maintenance** | None (fully managed) | High (OS updates, security) | Cloud Run |
| **Scaling** | Automatic (0-1000+ instances) | Manual (fixed resources) | Cloud Run |
| **Cost (Low Traffic)** | Very low ($1-10/month) | Fixed ($20-100/month) | Cloud Run |
| **Cost (High Traffic)** | Variable ($50-500/month) | Fixed ($20-100/month) | Depends |
| **Performance** | Cold starts possible | Consistent performance | VPS |
| **Control** | Limited (managed platform) | Full control | VPS |
| **Security** | Managed (automatic updates) | Manual (your responsibility) | Cloud Run |
| **Global Deployment** | Easy (multiple regions) | Complex (multiple servers) | Cloud Run |
| **WebSocket Support** | Limited (60min timeout) | Full support | VPS |

### When to Choose Cloud Run

✅ **Choose Cloud Run if:**
- You have variable or unpredictable traffic
- You want minimal operational overhead
- You need automatic scaling
- You're building a new application
- You want global deployment
- You prefer pay-per-use pricing
- You need rapid deployment and iteration

### When to Choose VPS

✅ **Choose VPS if:**
- You have consistent, predictable traffic
- You need full control over the environment
- You have long-running WebSocket connections
- You have specific OS or software requirements
- You want predictable monthly costs
- You have existing VPS expertise
- You need custom networking configurations

### Migration Strategy

If you're currently using VPS and want to evaluate Cloud Run:

1. **Parallel Deployment**: Deploy to Cloud Run alongside VPS
2. **Traffic Splitting**: Route a percentage of traffic to Cloud Run
3. **Performance Testing**: Compare metrics between both deployments
4. **Cost Analysis**: Monitor actual costs for your traffic patterns
5. **Feature Validation**: Ensure all features work correctly on Cloud Run
6. **Gradual Migration**: Increase Cloud Run traffic percentage over time

## Advanced Configuration

### CI/CD Integration

#### GitHub Actions Workflow

Create `.github/workflows/cloudrun-deploy.yml`:

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  PROJECT_ID: your-project-id
  REGION: us-central1

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Google Cloud SDK
      uses: google-github-actions/setup-gcloud@v1
      with:
        project_id: ${{ env.PROJECT_ID }}
        service_account_key: ${{ secrets.GCP_SA_KEY }}
        export_default_credentials: true

    - name: Configure Docker
      run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

    - name: Deploy to Cloud Run
      run: ./scripts/cloudrun/deploy-to-cloudrun.sh
```

#### GitLab CI/CD

Create `.gitlab-ci.yml`:

```yaml
stages:
  - build
  - deploy

variables:
  PROJECT_ID: your-project-id
  REGION: us-central1

deploy_cloudrun:
  stage: deploy
  image: google/cloud-sdk:alpine
  script:
    - gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS
    - gcloud config set project $PROJECT_ID
    - ./scripts/cloudrun/deploy-to-cloudrun.sh
  only:
    - main
```

### Load Balancing and Traffic Management

#### Global Load Balancer

For global deployment with custom domains:

```bash
# Create global load balancer
gcloud compute url-maps create cloudtolocalllm-lb \
    --default-service=cloudtolocalllm-web-neg

# Create SSL certificate
gcloud compute ssl-certificates create cloudtolocalllm-ssl \
    --domains=your-domain.com,www.your-domain.com

# Create HTTPS proxy
gcloud compute target-https-proxies create cloudtolocalllm-https-proxy \
    --url-map=cloudtolocalllm-lb \
    --ssl-certificates=cloudtolocalllm-ssl
```

#### Traffic Splitting

Deploy new versions with gradual traffic migration:

```bash
# Deploy new version with tag
gcloud run deploy cloudtolocalllm-web \
    --image=gcr.io/project/web:v2 \
    --tag=v2 \
    --no-traffic

# Split traffic between versions
gcloud run services update-traffic cloudtolocalllm-web \
    --to-tags=v1=80,v2=20
```

### Database Integration

#### Cloud SQL Setup

```bash
# Create Cloud SQL instance
gcloud sql instances create cloudtolocalllm-db \
    --database-version=POSTGRES_13 \
    --tier=db-f1-micro \
    --region=us-central1

# Create database
gcloud sql databases create cloudtolocalllm \
    --instance=cloudtolocalllm-db

# Create user
gcloud sql users create appuser \
    --instance=cloudtolocalllm-db \
    --password=secure-password
```

#### Connection Configuration

Update your Cloud Run service to connect to Cloud SQL:

```bash
gcloud run services update cloudtolocalllm-api \
    --add-cloudsql-instances=project:region:cloudtolocalllm-db \
    --set-env-vars="DB_HOST=/cloudsql/project:region:cloudtolocalllm-db"
```

### Security Hardening

#### IAM and Service Accounts

```bash
# Create minimal service account
gcloud iam service-accounts create cloudtolocalllm-minimal \
    --display-name="CloudToLocalLLM Minimal Access"

# Grant only necessary permissions
gcloud projects add-iam-policy-binding project-id \
    --member="serviceAccount:cloudtolocalllm-minimal@project-id.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"
```

#### VPC Connector

For private networking:

```bash
# Create VPC connector
gcloud compute networks vpc-access connectors create cloudtolocalllm-connector \
    --region=us-central1 \
    --subnet=default \
    --subnet-project=project-id \
    --min-instances=2 \
    --max-instances=10

# Update service to use VPC
gcloud run services update cloudtolocalllm-api \
    --vpc-connector=cloudtolocalllm-connector \
    --vpc-egress=private-ranges-only
```

### Backup and Disaster Recovery

#### Automated Backups

Create a backup script for your data:

```bash
#!/bin/bash
# backup-cloudrun.sh

# Backup Cloud SQL
gcloud sql export sql cloudtolocalllm-db \
    gs://your-backup-bucket/sql-backup-$(date +%Y%m%d).sql \
    --database=cloudtolocalllm

# Backup container images
gcloud container images list-tags gcr.io/project/web \
    --format="get(digest)" \
    --limit=5 > image-backups.txt
```

#### Disaster Recovery Plan

1. **Data Recovery**: Restore from Cloud SQL backups
2. **Service Recovery**: Redeploy from container registry
3. **Configuration Recovery**: Store configs in version control
4. **DNS Recovery**: Update DNS to backup region

### Performance Optimization

#### Container Optimization

```dockerfile
# Use multi-stage builds
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine
COPY --from=builder /app/node_modules ./node_modules
COPY . .
CMD ["node", "server.js"]
```

#### Caching Strategy

```bash
# Enable Cloud CDN for static assets
gcloud compute backend-services update cloudtolocalllm-web-backend \
    --enable-cdn \
    --cache-mode=CACHE_ALL_STATIC
```

### Monitoring and Alerting

#### Custom Metrics

```javascript
// In your Node.js application
const monitoring = require('@google-cloud/monitoring');
const client = new monitoring.MetricServiceClient();

// Create custom metric
const customMetric = {
  type: 'custom.googleapis.com/cloudtolocalllm/active_users',
  labels: [
    {
      key: 'service',
      valueType: 'STRING',
      description: 'Service name'
    }
  ],
  metricKind: 'GAUGE',
  valueType: 'INT64'
};
```

#### Alerting Policies

```bash
# Create alerting policy for high error rate
gcloud alpha monitoring policies create \
    --policy-from-file=alerting-policy.yaml
```

## Conclusion

Google Cloud Run provides a modern, scalable deployment option for CloudToLocalLLM with several advantages:

### Key Benefits
- **Zero server management**: Focus on your application, not infrastructure
- **Automatic scaling**: Handle traffic spikes without manual intervention
- **Cost efficiency**: Pay only for what you use
- **Global reach**: Deploy to multiple regions easily
- **Security**: Built-in security features and automatic updates

### Considerations
- **Cold starts**: May affect performance for infrequent requests
- **WebSocket limitations**: 60-minute timeout for persistent connections
- **Vendor lock-in**: Tied to Google Cloud ecosystem
- **Learning curve**: New concepts and tools to master

### Recommendation

Cloud Run is an excellent choice for CloudToLocalLLM if you:
- Want to minimize operational overhead
- Have variable or growing traffic patterns
- Need global deployment capabilities
- Prefer modern, cloud-native architectures

For production deployments, consider starting with Cloud Run for new features while maintaining your existing VPS deployment, allowing you to gradually migrate and compare performance and costs.

## Support and Resources

- **Google Cloud Run Documentation**: https://cloud.google.com/run/docs
- **Cloud Run Pricing**: https://cloud.google.com/run/pricing
- **Best Practices**: https://cloud.google.com/run/docs/best-practices
- **Community Support**: https://stackoverflow.com/questions/tagged/google-cloud-run

For CloudToLocalLLM specific issues, please refer to the main project documentation or create an issue in the GitHub repository.
