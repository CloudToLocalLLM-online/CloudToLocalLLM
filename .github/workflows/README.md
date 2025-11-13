# CI/CD Pipelines for CloudToLocalLLM

This directory contains GitHub Actions workflows for automated building, testing, and deployment of CloudToLocalLLM to Azure AKS.

## Workflows

### 🔨 `build-images.yml`
**Triggers**: Push/PR to relevant files (Dockerfiles, source code)
- Builds Docker images for API backend and web frontend
- Pushes images to Docker Hub with appropriate tags
- Validates Kubernetes manifests
- Runs on every code change

### 🚀 `deploy-aks.yml`
**Triggers**: Push to main branch affecting deployment files, or manual trigger
- Deploys updated images to Azure AKS
- Updates Kubernetes deployments with new image versions
- Validates DNS configuration
- Runs only on main branch after successful build

## Required Secrets

Add these secrets to your GitHub repository settings:

### Docker Hub
```
DOCKERHUB_USERNAME    # Your Docker Hub username
DOCKERHUB_TOKEN       # Docker Hub access token (not password)
```

### Azure
```
AZURE_CLIENT_ID       # Azure service principal client ID
AZURE_TENANT_ID       # Azure tenant ID
AZURE_SUBSCRIPTION_ID # Azure subscription ID
```

## Azure Service Principal Setup

Create a service principal with AKS access:

```bash
# Create service principal
az ad sp create-for-rbac --name "CloudToLocalLLM-CI" --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth

# Grant AKS cluster access
az aks get-credentials --resource-group cloudtolocalllm-rg --name cloudtolocalllm-aks
kubectl create clusterrolebinding github-actions \
  --clusterrole=cluster-admin \
  --serviceaccount=default:default
```

## Manual Deployment

If you need to deploy manually:

```bash
# Build and push images
docker build -f services/api-backend/Dockerfile.prod -t cloudtolocalllm/cloudtolocalllm-api:latest .
docker build -f config/docker/Dockerfile.web -t cloudtolocalllm/cloudtolocalllm-web:latest .
docker push cloudtolocalllm/cloudtolocalllm-api:latest
docker push cloudtolocalllm/cloudtolocalllm-web:latest

# Deploy to AKS
az aks get-credentials --resource-group cloudtolocalllm-rg --name cloudtolocalllm-aks
kubectl apply -f k8s/
```

## Image Tags

- `latest`: Latest build from main branch
- `{branch-name}`: Branch-specific builds
- `main-{sha}`: Commit-specific builds for main branch
- `{branch}-{sha}`: Commit-specific builds for other branches

## Troubleshooting

### Build Failures
- Check Docker Hub credentials
- Verify Dockerfile paths are correct
- Check build logs for dependency issues

### Deployment Failures
- Verify Azure credentials and permissions
- Check AKS cluster status
- Validate Kubernetes manifests
- Ensure DNS records point to correct load balancer IP

### DNS Issues
- Load balancer IP may change - update DNS records
- DNS propagation can take 5-15 minutes
- Use `kubectl get svc -n ingress-nginx` to get current IP
