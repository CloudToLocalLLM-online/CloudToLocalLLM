# ✅ Pre-Deployment Checklist - DigitalOcean Kubernetes

## Before You Begin

Ensure you have completed all prerequisites before deploying CloudToLocalLLM to DigitalOcean Kubernetes.

---

## 1. Account Setup

### DigitalOcean Account
- [ ] DigitalOcean account created
- [ ] Payment method added
- [ ] Personal Access Token generated (with read/write scopes)
  - Generate at: https://cloud.digitalocean.com/account/api/tokens
  - Save token securely (you'll only see it once)

### Domain Registration
- [ ] Domain `cloudtolocalllm.online` registered
- [ ] Access to domain registrar DNS settings
- [ ] Ready to update nameservers

---

## 2. Tools Installation

### Required Tools
- [ ] **doctl** installed and configured
  ```bash
  # Install: https://docs.digitalocean.com/reference/doctl/how-to/install/
  doctl version
  
  # Authenticate:
  doctl auth init
  # Paste your Personal Access Token when prompted
  
  # Verify:
  doctl account get
  ```

- [ ] **kubectl** installed
  ```bash
  # Verify:
  kubectl version --client
  ```

- [ ] **Docker** installed and running
  ```bash
  # Verify:
  docker version
  docker ps
  ```

- [ ] **Git** installed
  ```bash
  # Verify:
  git --version
  ```

### Optional Tools
- [ ] **helm** (for future use)
- [ ] **k9s** (Kubernetes CLI UI - highly recommended)

---

## 3. DigitalOcean Resources

### Kubernetes Cluster
- [ ] Kubernetes cluster created
  ```bash
  # Option 1: Via Dashboard
  # https://cloud.digitalocean.com/kubernetes/clusters/new
  
  # Option 2: Via CLI
  doctl kubernetes cluster create cloudtolocalllm \
    --region nyc1 \
    --version latest \
    --node-pool "name=worker-pool;size=s-2vcpu-4gb;count=3"
  ```

- [ ] Cluster is running and healthy
  ```bash
  doctl kubernetes cluster list
  # Should show STATUS: running
  ```

- [ ] kubectl configured for cluster
  ```bash
  doctl kubernetes cluster kubeconfig save cloudtolocalllm
  kubectl cluster-info
  kubectl get nodes
  # All nodes should be Ready
  ```

### Container Registry
- [ ] DigitalOcean Container Registry created
  ```bash
  # Option 1: Via Dashboard
  # https://cloud.digitalocean.com/registry
  
  # Option 2: Via CLI
  doctl registry create cloudtolocalllm
  ```

- [ ] Registry integrated with cluster
  ```bash
  # Verify:
  doctl registry get
  # Shows: cloudtolocalllm
  ```

---

## 4. Secrets Generation

Generate all required secrets before deployment:

### Database Password
- [ ] Strong PostgreSQL password generated
  ```bash
  # Generate secure password:
  openssl rand -base64 32
  # Or use a password manager
  ```

### JWT Secret
- [ ] JWT secret generated
  ```bash
  openssl rand -base64 32
  ```

### Auth0 Credentials
- [ ] Auth0 account created (free tier)
- [ ] Auth0 Application created
- [ ] Auth0 Domain noted: `your-tenant.us.auth0.com`
- [ ] Auth0 Audience configured

---

## 5. GitHub Setup

### Repository
- [ ] Code pushed to GitHub repository
- [ ] Repository is `CloudToLocalLLM-online/CloudToLocalLLM`

### GitHub Secrets
Configure these secrets in repository settings:
- [ ] `DIGITALOCEAN_ACCESS_TOKEN` - Your DigitalOcean PAT
- [ ] `DOMAIN` - `cloudtolocalllm.online`
- [ ] `POSTGRES_PASSWORD` - From step 4
- [ ] `JWT_SECRET` - From step 4
- [ ] `AUTH0_DOMAIN` - From Auth0 setup
- [ ] `AUTH0_AUDIENCE` - From Auth0 setup
- [ ] `SENTRY_DSN` - (Optional) For error tracking

To set secrets:
```bash
# Via GitHub CLI:
gh secret set DIGITALOCEAN_ACCESS_TOKEN
gh secret set DOMAIN --body "cloudtolocalllm.online"
gh secret set POSTGRES_PASSWORD
gh secret set JWT_SECRET
gh secret set AUTH0_DOMAIN
gh secret set AUTH0_AUDIENCE
```

Or use the automated script:
```powershell
.\scripts\setup-github-secrets.ps1
```

---

## 6. Configuration Files

### Kubernetes Manifests
- [ ] All files in `k8s/` folder reviewed
- [ ] `k8s/secrets.yaml` created from template
  ```bash
  cd k8s
  cp secrets.yaml.template secrets.yaml
  # Edit secrets.yaml with your actual values
  ```
- [ ] Secrets file uses base64 encoding
  ```bash
  # Encode secrets:
  echo -n "your-password" | base64
  ```
- [ ] Domain updated in `k8s/configmap.yaml`
- [ ] Domain updated in `k8s/ingress-nginx.yaml`
- [ ] Email updated in `k8s/cert-manager.yaml`

### Docker Images
- [ ] `config/docker/Dockerfile.web` exists and builds
- [ ] `services/api-backend/Dockerfile.prod` exists and builds
- [ ] Test build locally:
  ```bash
  docker build -f config/docker/Dockerfile.web -t test-web .
  docker build -f services/api-backend/Dockerfile.prod -t test-api .
  ```

---

## 7. Pre-Deployment Tests

### Local Testing
- [ ] Web app builds successfully
  ```bash
  flutter build web
  ```
- [ ] API backend runs locally
  ```bash
  cd services/api-backend
  npm install
  npm test
  ```

### Docker Registry Test
- [ ] Can login to DigitalOcean registry
  ```bash
  doctl registry login
  ```
- [ ] Can push test image
  ```bash
  docker tag test-web registry.digitalocean.com/cloudtolocalllm/test:latest
  docker push registry.digitalocean.com/cloudtolocalllm/test:latest
  doctl registry repository list-tags test
  ```

### Cluster Access Test
- [ ] Can access cluster
  ```bash
  kubectl get nodes
  kubectl get namespaces
  ```
- [ ] Can create test resources
  ```bash
  kubectl create namespace test-namespace
  kubectl delete namespace test-namespace
  ```

---

## 8. Deployment Execution

### Choose Deployment Method

**Option A: Automated PowerShell Script** (Windows)
- [ ] Run deployment script:
  ```powershell
  .\scripts\deploy-digitalocean.ps1
  ```

**Option B: Automated Bash Script** (Linux/macOS)
- [ ] Make scripts executable:
  ```bash
  chmod +x k8s/deploy.sh
  chmod +x k8s/setup-dns.sh
  ```
- [ ] Run deployment:
  ```bash
  cd k8s
  ./deploy.sh
  ```

**Option C: GitHub Actions** (Automated CI/CD)
- [ ] Push to main branch
- [ ] Monitor workflow: https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/actions
- [ ] Check deployment status

**Option D: Manual Step-by-Step** (Advanced)
- [ ] Follow `k8s/README.md` manual deployment section

---

## 9. DNS Configuration

### After Deployment
- [ ] Get Load Balancer IP:
  ```bash
  kubectl get svc -n ingress-nginx ingress-nginx-controller
  # Note the EXTERNAL-IP
  ```

### Setup DNS
- [ ] Run DNS setup script:
  ```bash
  cd k8s
  ./setup-dns.sh
  ```
  
- [ ] **OR** Configure manually:
  - [ ] Add domain to DigitalOcean DNS
  - [ ] Create A records for:
    - `cloudtolocalllm.online`
    - `app.cloudtolocalllm.online`
    - `api.cloudtolocalllm.online`
    - `auth.cloudtolocalllm.online`

### Update Nameservers
- [ ] Login to domain registrar
- [ ] Update nameservers to:
  ```
  ns1.digitalocean.com
  ns2.digitalocean.com
  ns3.digitalocean.com
  ```

### DNS Verification
- [ ] Wait 5-15 minutes for propagation
- [ ] Test DNS resolution:
  ```bash
  dig cloudtolocalllm.online +short
  dig app.cloudtolocalllm.online +short
  dig api.cloudtolocalllm.online +short
  dig auth.cloudtolocalllm.online +short
  ```

---

## 10. Post-Deployment Verification

### Kubernetes Resources
- [ ] All pods running:
  ```bash
  kubectl get pods -n cloudtolocalllm
  # All should show STATUS: Running, READY: 1/1
  ```

- [ ] Services created:
  ```bash
  kubectl get svc -n cloudtolocalllm
  ```

- [ ] Ingress configured:
  ```bash
  kubectl get ingress -n cloudtolocalllm
  ```

- [ ] SSL certificates ready:
  ```bash
  kubectl get certificate -n cloudtolocalllm
  # Should show READY: True (may take 5-10 minutes)
  ```

### Application Health
- [ ] Web app accessible:
  ```bash
  curl -I https://cloudtolocalllm.online
  # Should return HTTP/2 200
  ```

- [ ] App subdomain accessible:
  ```bash
  curl -I https://app.cloudtolocalllm.online
  # Should return HTTP/2 200
  ```

- [ ] API health check:
  ```bash
  curl https://api.cloudtolocalllm.online/health
  # Should return {"status": "ok"}
  ```

- [ ] Browser test:
  - [ ] Open https://cloudtolocalllm.online
  - [ ] SSL certificate valid (🔒 padlock)
  - [ ] Page loads without errors
  - [ ] No console errors (F12 → Console)

### Database
- [ ] PostgreSQL running:
  ```bash
  kubectl exec -n cloudtolocalllm -it postgres-0 -- psql -U appuser -d cloudtolocalllm -c '\dt'
  ```

### Logs Check
- [ ] API logs clean:
  ```bash
  kubectl logs -n cloudtolocalllm -l app=api-backend --tail=50
  ```

- [ ] Web logs clean:
  ```bash
  kubectl logs -n cloudtolocalllm -l app=web --tail=50
  ```

- [ ] No error spam in ingress:
  ```bash
  kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
  ```

---

## 11. Monitoring Setup (Optional)

- [ ] Set up monitoring dashboard
- [ ] Configure alerts
- [ ] Set up log aggregation
- [ ] Configure backups

---

## 12. Security Review

- [ ] Secrets not committed to Git:
  ```bash
  git status
  # k8s/secrets.yaml should be in .gitignore
  ```

- [ ] HTTPS working (not HTTP)
- [ ] SSL certificate valid
- [ ] Security headers present:
  ```bash
  curl -I https://cloudtolocalllm.online | grep -i security
  ```

- [ ] Rate limiting configured
- [ ] CORS configured correctly
- [ ] Database not exposed publicly:
  ```bash
  kubectl get svc -n cloudtolocalllm postgres
  # TYPE should be ClusterIP, not LoadBalancer
  ```

---

## 13. Desktop App Connection

- [ ] Desktop app can reach API
  ```bash
  # From desktop app, test:
  curl https://api.cloudtolocalllm.online/health
  ```

- [ ] Auth0 authentication works
- [ ] Desktop app can register with bridge
- [ ] WebSocket tunnel connects
- [ ] Can send/receive messages

---

## Troubleshooting Checklist

If something goes wrong:

### Pods not starting?
- [ ] Check pod logs: `kubectl describe pod <pod-name> -n cloudtolocalllm`
- [ ] Check events: `kubectl get events -n cloudtolocalllm --sort-by='.lastTimestamp'`
- [ ] Verify secrets exist: `kubectl get secrets -n cloudtolocalllm`

### SSL certificate not ready?
- [ ] Check DNS propagation: https://dnschecker.org
- [ ] Check cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`
- [ ] Describe certificate: `kubectl describe certificate -n cloudtolocalllm cloudtolocalllm-tls`

### Can't access website?
- [ ] DNS resolves correctly: `dig cloudtolocalllm.online`
- [ ] Load Balancer has IP: `kubectl get svc -n ingress-nginx`
- [ ] Firewall not blocking: Check DigitalOcean firewall rules
- [ ] Try HTTP first: `curl http://cloudtolocalllm.online`

### Database connection failed?
- [ ] PostgreSQL pod running: `kubectl get pods -n cloudtolocalllm -l app=postgres`
- [ ] Test connection: `kubectl exec -it postgres-0 -n cloudtolocalllm -- psql -U appuser -d cloudtolocalllm`
- [ ] Check secrets: Verify postgres-password is set correctly

---

## Cost Estimate

**Monthly DigitalOcean Costs:**
- Kubernetes Cluster: $0 (free control plane)
- 3 Worker Nodes (s-2vcpu-4gb): ~$72
- Load Balancer: ~$12
- Container Registry: $0 (< 500MB)
- Block Storage (30GB): ~$3
- **Total: ~$87/month**

**Cost Optimization:**
- Use 2 nodes instead of 3: ~$60/month
- Use smaller nodes: ~$36/month
- Use DigitalOcean credits if available

---

## Next Steps After Deployment

1. **Monitor for 24-48 hours** - Ensure stability
2. **Set up backups** - PostgreSQL automated backups
3. **Configure monitoring** - Prometheus + Grafana
4. **Implement SuperTokens** - Replace Auth0
5. **Test tunnel functionality** - Desktop app integration
6. **Set up CI/CD** - Automated deployments
7. **Configure auto-scaling** - HPA for traffic spikes

---

**You're ready to deploy!** 🚀

Review this checklist completely, check all boxes, then proceed with deployment.

Good luck!

