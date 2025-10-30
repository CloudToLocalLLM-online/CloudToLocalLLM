# ✅ DigitalOcean Setup Complete!

## What's Been Set Up

### 🛠️ DigitalOcean Infrastructure
- ✅ **doctl CLI installed**: `C:\Users\rightguy\AppData\Local\doctl`
- ✅ **Authenticated**: Using your Personal Access Token
- ✅ **Kubernetes Cluster**: `cloudtolocalllm` (Toronto - tor1)
  - 3 nodes running (v1.33.1)
  - Status: Running
- ✅ **Container Registry**: `registry.digitalocean.com/cloudtolocalllm`
- ✅ **kubectl configured**: Connected to your cluster

### 🤖 MCP Tools Created
- ✅ **DigitalOcean MCP Server** (`config/mcp/servers/digitalocean-server.js`)
  - Cluster management
  - Container registry operations
  - Load balancer configuration
  - Node pool scaling
  
- ✅ **Kubernetes MCP Server** (`config/mcp/servers/kubernetes-server.js`)
  - Pod management
  - Deployment scaling
  - Log viewing
  - Service management
  - Ingress configuration

### 🚀 CI/CD Pipeline
- ✅ **GitHub Actions Workflow** (`.github/workflows/deploy-to-kubernetes.yml`)
  - Automated Docker image building
  - Push to DigitalOcean Container Registry
  - Zero-downtime Kubernetes deployment
  - Automated health checks
  - Deployment status reporting

### 📜 Automation Scripts
- ✅ `scripts/setup-digitalocean.ps1` - DO authentication
- ✅ `scripts/setup-github-secrets.ps1` - GitHub secrets setup
- ✅ `scripts/deploy-complete.ps1` - Complete deployment automation
- ✅ `scripts/mcp-setup.ps1` - MCP tools information

---

## 🎯 Next Steps

### Step 1: Set Up GitHub Secrets (Required for CI/CD)

Run this script to configure all required secrets:

```powershell
.\scripts\setup-github-secrets.ps1
```

**OR** set them manually at:
https://github.com/imrightguy/CloudToLocalLLM/settings/secrets/actions

Required secrets:
- `DIGITALOCEAN_ACCESS_TOKEN` - Your DO API token
- `DOMAIN` - Your domain (e.g., cloudtolocalllm.com)
- `POSTGRES_PASSWORD` - Database password (generate secure)
- `JWT_SECRET` - JWT signing secret (generate secure)
- `AUTH0_DOMAIN` - Your Auth0 tenant
- `AUTH0_AUDIENCE` - Your Auth0 API identifier
- `SENTRY_DSN` - (Optional) Sentry error tracking

### Step 2: Update Kubernetes Manifests

Update `k8s/` files with your actual values:

1. **k8s/configmap.yaml**:
   ```yaml
   DOMAIN: "yourdomain.com"  # Replace with your domain
   ```

2. **k8s/secrets.yaml**:
   ```bash
   cp k8s/secrets.yaml.template k8s/secrets.yaml
   # Edit secrets.yaml with your actual values
   # DO NOT commit secrets.yaml!
   ```

3. **k8s/ingress-nginx.yaml**:
   - Replace all `yourdomain.com` with your actual domain

4. **k8s/cert-manager.yaml**:
   - Replace `admin@yourdomain.com` with your email

5. **k8s/api-backend-deployment.yaml** and **k8s/web-deployment.yaml**:
   - Replace `YOUR_REGISTRY` with `registry.digitalocean.com/cloudtolocalllm`

### Step 3: Deploy to Kubernetes

#### Option A: Automated CI/CD (Recommended)

1. **Set up GitHub secrets** (Step 1 above)
2. **Push to GitHub**:
   ```bash
   git push origin main
   ```
3. **Watch deployment**: 
   https://github.com/imrightguy/CloudToLocalLLM/actions

#### Option B: Manual Deployment

```powershell
# Run complete deployment script
.\scripts\deploy-complete.ps1
```

Or deploy step-by-step:

```bash
# Login to registry
doctl registry login

# Build images
docker build -f config/docker/Dockerfile.web -t registry.digitalocean.com/cloudtolocalllm/web:latest .
docker build -f services/api-backend/Dockerfile.prod -t registry.digitalocean.com/cloudtolocalllm/api:latest .

# Push images
docker push registry.digitalocean.com/cloudtolocalllm/web:latest
docker push registry.digitalocean.com/cloudtolocalllm/api:latest

# Deploy to Kubernetes
cd k8s
./deploy.sh
```

### Step 4: Configure DNS

After deployment, get the Load Balancer IP:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Configure your DNS A records:
```
yourdomain.com     A  <LOAD_BALANCER_IP>
app.yourdomain.com A  <LOAD_BALANCER_IP>
api.yourdomain.com A  <LOAD_BALANCER_IP>
```

### Step 5: Wait for SSL Certificates

After DNS propagates (5-15 minutes), cert-manager will automatically request Let's Encrypt certificates.

Check status:
```bash
kubectl get certificate -n cloudtolocalllm
```

### Step 6: Test Deployment

```bash
# Test web app
curl https://yourdomain.com

# Test API
curl https://api.yourdomain.com/health

# View logs
kubectl logs -n cloudtolocalllm -l app=api-backend -f
```

### Step 7: Launch Desktop App

1. Start your Windows CloudToLocalLLM desktop app
2. Sign in with Auth0
3. Desktop app will connect to `https://api.yourdomain.com`
4. Start chatting with local Ollama!

---

## 🔧 Useful Commands

### MCP Tools Usage

```javascript
// Example: Using DigitalOcean MCP
const doMcp = new DigitalOceanMCPServer();

// List clusters
await doMcp.listClusters();

// Get load balancer
await doMcp.getLoadBalancer();

// Scale node pool
await doMcp.scaleNodePool('cloudtolocalllm', 'cloudtolocalllm', 5);
```

### Kubernetes Management

```bash
# Get all pods
kubectl get pods -n cloudtolocalllm

# View logs
kubectl logs -n cloudtolocalllm -l app=api-backend -f

# Scale deployment
kubectl scale deployment/api-backend --replicas=5 -n cloudtolocalllm

# Restart deployment
kubectl rollout restart deployment/api-backend -n cloudtolocalllm

# Check ingress
kubectl describe ingress -n cloudtolocalllm

# Check certificates
kubectl get certificate -n cloudtolocalllm
```

### DigitalOcean CLI

```bash
# List clusters
doctl kubernetes cluster list

# List registry repos
doctl registry repository list

# Get cluster info
doctl kubernetes cluster get cloudtolocalllm

# List load balancers
doctl compute load-balancer list
```

---

## 📊 What You Get

### Infrastructure
- **Kubernetes Cluster**: 3 nodes in Toronto (tor1)
- **Container Registry**: registry.digitalocean.com/cloudtolocalllm
- **Load Balancer**: Automatically created by nginx-ingress
- **SSL Certificates**: Automatic with Let's Encrypt
- **Auto-scaling**: HPA ready (configure in deployments)

### Services
- **Web App**: 2 replicas (Flutter + Nginx)
- **API Backend**: 2 replicas (Node.js Express)
- **PostgreSQL**: StatefulSet with 10GB storage
- **Ingress**: nginx-ingress with SSL termination

### Automation
- **CI/CD**: GitHub Actions for automated deployment
- **MCP Tools**: DigitalOcean and Kubernetes automation
- **Health Checks**: Automated service monitoring
- **Rollback**: Zero-downtime deployments

---

## 💰 Estimated Monthly Cost

**Current Setup:**
- Kubernetes Control Plane: **Free**
- 3 Worker Nodes (2 vCPU, 4GB RAM): **$72/month**
- Load Balancer: **$12/month**
- Container Registry: **Free** (first 500MB)
- Block Storage (30GB): **$3/month**

**Total: ~$87/month**

**To reduce costs:**
- Use 2 nodes: ~$60/month
- Use smaller nodes (1 vCPU, 2GB): ~$36/month

---

## 🎓 MCP Tools Reference

### Available Tools

#### DigitalOcean MCP
- `list_clusters` - List all Kubernetes clusters
- `get_cluster` - Get cluster details
- `get_kubeconfig` - Download kubeconfig
- `list_registry_repos` - List container images
- `login_registry` - Login to container registry
- `get_load_balancer` - Get load balancer info
- `scale_node_pool` - Scale cluster nodes

#### Kubernetes MCP
- `get_pods` - List pods in namespace
- `get_pod_logs` - View pod logs
- `get_deployments` - List deployments
- `scale_deployment` - Scale a deployment
- `restart_deployment` - Restart a deployment
- `get_services` - List services
- `get_ingress` - List ingress resources
- `apply_manifest` - Apply Kubernetes manifest
- `get_nodes` - List cluster nodes

---

## 🔐 Security Notes

1. **Secrets**: Never commit `k8s/secrets.yaml` or `.deployment-config.json`
2. **Token**: Your DO token is saved in doctl config (`~/.config/doctl/config.yaml`)
3. **GitHub Secrets**: All sensitive values stored encrypted in GitHub
4. **SSL**: Automatic HTTPS with Let's Encrypt
5. **Network Policies**: Configure in Kubernetes for pod-to-pod security

---

## 📚 Documentation

- **Full K8s Guide**: `k8s/README.md`
- **Quick Start**: `KUBERNETES_QUICKSTART.md`
- **Docker Alternative**: `DOCKER_DEPLOYMENT.md`
- **Tunnel Architecture**: `TUNNEL_IMPLEMENTATION_STATUS.md`
- **MCP Configuration**: `config/mcp/digitalocean-mcp.json`

---

## 🆘 Troubleshooting

### Deployment Fails
```bash
# Check workflow logs
# https://github.com/imrightguy/CloudToLocalLLM/actions

# Check pod status
kubectl describe pod -n cloudtolocalllm <pod-name>

# Check logs
kubectl logs -n cloudtolocalllm <pod-name>
```

### SSL Certificate Issues
```bash
# Check certificate status
kubectl describe certificate -n cloudtolocalllm

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Common issue: DNS not propagated (wait 15 minutes)
```

### Can't Connect to Cluster
```bash
# Re-download kubeconfig
doctl kubernetes cluster kubeconfig save cloudtolocalllm

# Verify connection
kubectl cluster-info
```

---

## 🎉 You're All Set!

Your CloudToLocalLLM deployment is ready for:
1. ✅ Automated CI/CD via GitHub Actions
2. ✅ MCP-based automation and management
3. ✅ Production-grade Kubernetes deployment
4. ✅ Automatic SSL certificates
5. ✅ Zero-downtime updates

**Next Command:**
```powershell
.\scripts\setup-github-secrets.ps1
```

Then push to deploy! 🚀

