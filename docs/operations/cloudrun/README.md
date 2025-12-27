# CloudToLocalLLM - Google Cloud Run Deployment

This directory contains all the necessary files and configurations for deploying CloudToLocalLLM to Google Cloud Run.

## 📁 Directory Structure

```
config/cloudrun/
├── README.md                           # This file
├── Dockerfile.web-cloudrun             # Optimized Flutter web app container
├── Dockerfile.api-cloudrun             # Optimized Node.js API backend container
├── Dockerfile.streaming-proxy-cloudrun # Optimized streaming proxy container
├── nginx-cloudrun.conf                 # Nginx configuration for Cloud Run
├── cloudrun-config.yaml               # Cloud Run service configurations
└── .env.cloudrun.template             # Environment variables template

scripts/cloudrun/
├── setup-cloudrun.sh                  # Initial Google Cloud setup
├── deploy-to-cloudrun.sh              # Deployment automation script
├── estimate-costs.sh                  # Cost estimation tool
└── health-check.sh                    # Service health monitoring

.github/workflows/
└── cloudrun-deploy.yml                # GitHub Actions CI/CD workflow
```

## 🚀 Quick Start

### 1. Prerequisites

- **Google Cloud SDK**: [Install gcloud CLI](https://cloud.google.com/sdk/docs/install)
- **Docker**: [Install Docker](https://docs.docker.com/get-docker/)
- **Google Cloud Project** with billing enabled
- **Required IAM permissions** (see documentation)

### 2. Initial Setup

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud auth application-default login

# Run the setup script (Linux/macOS)
./scripts/cloudrun/setup-cloudrun.sh

# Or specify project and region directly
./scripts/cloudrun/setup-cloudrun.sh my-project-id us-central1
```

**Windows Users**: Run the setup script in Git Bash or WSL:
```bash
bash scripts/cloudrun/setup-cloudrun.sh
```

### 3. Configure Environment

```bash
# Copy the template and customize
cp config/cloudrun/.env.cloudrun.template config/cloudrun/.env.cloudrun

# Edit the configuration file
nano config/cloudrun/.env.cloudrun
```

**Required Configuration**:
- `GOOGLE_CLOUD_PROJECT`: Your Google Cloud project ID
- `GOOGLE_CLOUD_REGION`: Deployment region (e.g., us-central1)
- `AUTH0_DOMAIN`: Your Auth0 domain
- `AUTH0_CLIENT_ID`: Your Auth0 client ID
- `AUTH0_CLIENT_SECRET`: Your Auth0 client secret
- `JWT_SECRET`: A secure random string for JWT signing

### 4. Deploy to Cloud Run

```bash
# Deploy all services
./scripts/cloudrun/deploy-to-cloudrun.sh

# Deploy specific service
./scripts/cloudrun/deploy-to-cloudrun.sh --service web

# Dry run (see what would be deployed)
./scripts/cloudrun/deploy-to-cloudrun.sh --dry-run
```

## 📊 Cost Estimation

Use the cost estimation tool to understand potential costs:

```bash
# Basic estimation
./scripts/cloudrun/estimate-costs.sh

# High traffic scenario
./scripts/cloudrun/estimate-costs.sh --requests 100000 --duration 500

# Show detailed breakdown
./scripts/cloudrun/estimate-costs.sh --verbose
```

**Cost Examples**:
- **Light usage** (1,000 requests/month): ~$1.80/month
- **Medium usage** (50,000 requests/month): ~$28.00/month
- **High usage** (500,000 requests/month): ~$140.00/month

## 🔍 Health Monitoring

Monitor your deployed services:

```bash
# One-time health check
./scripts/cloudrun/health-check.sh

# Continuous monitoring
./scripts/cloudrun/health-check.sh --continuous --interval 60

# JSON output for automation
./scripts/cloudrun/health-check.sh --format json
```

## 🏗️ Architecture

CloudToLocalLLM is deployed as three separate Cloud Run services:

1. **Web Service** (`cloudtolocalllm-web`)
   - Flutter web application
   - Serves the user interface
   - 1 vCPU, 1GB RAM
   - Auto-scales 0-10 instances

2. **API Service** (`cloudtolocalllm-api`)
   - Node.js backend
   - Handles authentication and API requests
   - 2 vCPUs, 2GB RAM
   - Auto-scales 0-20 instances

3. **Streaming Service** (`cloudtolocalllm-streaming`)
   - WebSocket proxy
   - Real-time communication
   - 1 vCPU, 1GB RAM
   - Auto-scales 0-15 instances

## 🔧 Configuration Options

### Service Configuration

Each service can be customized in the deployment script:

```bash
# Example: Update API service configuration
gcloud run services update cloudtolocalllm-api \
    --memory=4Gi \
    --cpu=2 \
    --min-instances=1 \
    --max-instances=50 \
    --concurrency=200
```

### Environment Variables

Key environment variables for each service:

**Common**:
- `NODE_ENV=production`
- `LOG_LEVEL=info`
- `PORT=8080` (automatically set by Cloud Run)

**API Service**:
- `AUTH0_DOMAIN`: Auth0 authentication domain
- `AUTH0_CLIENT_ID`: Auth0 client ID
- `AUTH0_CLIENT_SECRET`: Auth0 client secret (use Secret Manager)
- `JWT_SECRET`: JWT signing secret (use Secret Manager)

### Custom Domains

Set up custom domains for your services:

```bash
# Map custom domain
gcloud run domain-mappings create \
    --service cloudtolocalllm-web \
    --domain your-domain.com \
    --region us-central1

# Get DNS configuration
gcloud run domain-mappings describe \
    --domain your-domain.com \
    --region us-central1
```

## 🔐 Security

### Secrets Management

Store sensitive data in Google Secret Manager:

```bash
# Create secrets
echo -n "your-auth0-client-secret" | gcloud secrets create auth0-client-secret --data-file=-
echo -n "your-jwt-secret" | gcloud secrets create jwt-secret --data-file=-

# Grant access to service account
gcloud secrets add-iam-policy-binding auth0-client-secret \
    --member="serviceAccount:cloudtolocalllm-runner@PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

### IAM and Service Accounts

The setup script creates a minimal service account with only necessary permissions:
- Cloud Run Invoker
- Cloud SQL Client (if using Cloud SQL)
- Secret Manager Secret Accessor

## 🚀 CI/CD Integration

### GitHub Actions

The included GitHub Actions workflow (`.github/workflows/cloudrun-deploy.yml`) provides:
- Automated builds on push to main/master
- Security checks and validation
- Multi-service deployment
- Health verification
- Deployment summaries

**Required Secrets**:
- `GCP_PROJECT_ID`: Your Google Cloud project ID
- `GCP_REGION`: Deployment region
- `GCP_SA_KEY`: Service account key (JSON format)

### Manual Deployment

For manual deployments or other CI/CD systems:

```bash
# Build and push images
docker build -f config/cloudrun/Dockerfile.web-cloudrun -t gcr.io/PROJECT_ID/web:latest .
docker push gcr.io/PROJECT_ID/web:latest

# Deploy to Cloud Run
gcloud run deploy cloudtolocalllm-web \
    --image=gcr.io/PROJECT_ID/web:latest \
    --platform=managed \
    --region=us-central1 \
    --allow-unauthenticated
```

## 📈 Performance Optimization

### Cold Start Optimization

- Use minimal base images (Alpine Linux)
- Optimize container startup time
- Set minimum instances for critical services
- Use Cloud Run's always-on CPU allocation

### Scaling Configuration

```bash
# Optimize for performance
gcloud run services update cloudtolocalllm-api \
    --min-instances=1 \
    --max-instances=20 \
    --concurrency=100 \
    --cpu-throttling=false
```

### Monitoring

Set up monitoring and alerting:
- Cloud Run metrics in Google Cloud Console
- Custom metrics with Cloud Monitoring
- Alerting policies for error rates and latency
- Log-based metrics for application insights

## 🆚 Cloud Run vs VPS Comparison

| Factor | Cloud Run | VPS | Winner |
|--------|-----------|-----|---------|
| Setup | Easy (managed) | Complex | Cloud Run |
| Scaling | Automatic | Manual | Cloud Run |
| Cost (Low Traffic) | $1-10/month | $20-100/month | Cloud Run |
| Cost (High Traffic) | Variable | Fixed | Depends |
| Maintenance | None | High | Cloud Run |
| Performance | Cold starts | Consistent | VPS |
| Control | Limited | Full | VPS |

## 🛠️ Troubleshooting

### Common Issues

1. **Cold Start Latency**
   - Set minimum instances to 1
   - Optimize container startup time
   - Use smaller images

2. **Memory Limits**
   - Increase memory allocation
   - Optimize application memory usage
   - Monitor memory usage patterns

3. **Authentication Issues**
   - Verify Auth0 configuration
   - Check environment variables
   - Review CORS settings

### Debugging Commands

```bash
# View service logs
gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=cloudtolocalllm-api" --limit=50

# Check service status
gcloud run services describe cloudtolocalllm-api --region=us-central1

# Test service health
curl https://SERVICE_URL/health
```

## 📚 Additional Resources

- 
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Run Pricing Calculator](https://cloud.google.com/products/calculator)
- [Best Practices Guide](https://cloud.google.com/run/docs/best-practices)

## 🆘 Support

For issues specific to CloudToLocalLLM Cloud Run deployment:
1. Check the 
2. Review service logs in Google Cloud Console
3. Create an issue in the GitHub repository
4. Consult the main project documentation

---

**Note**: This Cloud Run deployment is an additional deployment option alongside existing VPS deployment methods. All existing deployment configurations are preserved and unmodified.
