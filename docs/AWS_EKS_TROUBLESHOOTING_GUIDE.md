# AWS EKS Troubleshooting Guide

This guide provides solutions for common issues encountered during AWS EKS deployment and operation.

## Table of Contents

1. [OIDC Authentication Issues](#oidc-authentication-issues)
2. [EKS Cluster Issues](#eks-cluster-issues)
3. [Kubernetes Deployment Issues](#kubernetes-deployment-issues)
4. [Networking and DNS Issues](#networking-and-dns-issues)
5. [SSL/TLS Certificate Issues](#ssltls-certificate-issues)
6. [Performance and Resource Issues](#performance-and-resource-issues)
7. [Monitoring and Logging Issues](#monitoring-and-logging-issues)
8. [GitHub Actions Workflow Issues](#github-actions-workflow-issues)

## OIDC Authentication Issues

### Issue: "AssumeRoleUnauthorizedOperation" in GitHub Actions

**Symptoms:**
- GitHub Actions workflow fails with AssumeRoleUnauthorizedOperation error
- OIDC token exchange fails
- Deployment cannot authenticate to AWS

**Root Causes:**
1. Trust policy doesn't match repository/branch
2. OIDC provider not configured correctly
3. IAM role doesn't exist or is misconfigured
4. GitHub Actions workflow missing `id-token: write` permission

**Solutions:**

**Step 1: Verify Trust Policy**
```bash
aws iam get-role --role-name github-actions-role \
  --query 'Role.AssumeRolePolicyDocument' | jq .
```

Check that the trust policy includes:
- Correct OIDC provider ARN
- Correct repository: `repo:cloudtolocalllm/cloudtolocalllm`
- Correct branch: `ref:refs/heads/main`

**Step 2: Verify Workflow Permissions**
```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # REQUIRED for OIDC
```

**Step 3: Update Trust Policy if Needed**
```bash
# Get current policy
aws iam get-role --role-name github-actions-role \
  --query 'Role.AssumeRolePolicyDocument' > trust-policy.json

# Edit trust-policy.json to fix the issue

# Update the role
aws iam update-assume-role-policy \
  --role-name github-actions-role \
  --policy-document file://trust-policy.json
```

**Step 4: Test OIDC Authentication**
```bash
# Manually trigger test workflow
gh workflow run test-oidc-auth.yml

# Monitor the run
gh run list --workflow=test-oidc-auth.yml
```

### Issue: "InvalidParameterException: Invalid thumbprint"

**Symptoms:**
- OIDC provider creation fails with invalid thumbprint error
- Existing OIDC provider has invalid thumbprint

**Root Causes:**
1. GitHub's SSL certificate changed
2. Thumbprint was entered incorrectly
3. OIDC provider thumbprint is outdated

**Solutions:**

**Step 1: Get Current Thumbprint**
```bash
# Get the current thumbprint from GitHub's certificate
openssl s_client -servername token.actions.githubusercontent.com \
  -connect token.actions.githubusercontent.com:443 2>/dev/null | \
  openssl x509 -fingerprint -noout | sed 's/://g' | awk '{print $NF}'
```

Expected output: A 40-character hex string (e.g., `6938fd4d98bab03faadb97b34396831e3780aea1`)

**Step 2: Update OIDC Provider Thumbprint**
```bash
aws iam update-open-id-connect-provider-thumbprint \
  --open-id-connect-provider-arn arn:aws:iam::422017356244:oidc-provider/token.actions.githubusercontent.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**Step 3: Verify Update**
```bash
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::422017356244:oidc-provider/token.actions.githubusercontent.com
```

### Issue: "AccessDenied: User is not authorized"

**Symptoms:**
- OIDC provider setup script fails with access denied
- Cannot create or update OIDC provider
- Cannot create IAM role

**Root Causes:**
1. AWS credentials don't have IAM permissions
2. User doesn't have permission to create OIDC providers
3. User doesn't have permission to create IAM roles

**Solutions:**

**Step 1: Check AWS Credentials**
```bash
aws sts get-caller-identity
```

**Step 2: Verify IAM Permissions**

Ensure your AWS user/role has these permissions:
- `iam:CreateOpenIDConnectProvider`
- `iam:CreateRole`
- `iam:AttachRolePolicy`
- `iam:GetRole`
- `iam:GetOpenIDConnectProvider`
- `iam:UpdateAssumeRolePolicy`

**Step 3: Contact AWS Administrator**

If you don't have these permissions, contact your AWS administrator to grant them.

## EKS Cluster Issues

### Issue: "Cluster creation failed" or "Stack creation failed"

**Symptoms:**
- CloudFormation stack creation fails
- EKS cluster doesn't appear in AWS console
- Error message in CloudFormation events

**Root Causes:**
1. Insufficient IAM permissions
2. VPC/subnet configuration issues
3. Security group misconfiguration
4. Resource limits exceeded

**Solutions:**

**Step 1: Check CloudFormation Events**
```bash
aws cloudformation describe-stack-events \
  --stack-name cloudtolocalllm-eks \
  --region us-east-1 \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' \
  --output table
```

**Step 2: Check VPC and Subnets**
```bash
# Verify VPC exists
aws ec2 describe-vpcs --filters Name=tag:Name,Values=cloudtolocalllm-vpc

# Verify subnets exist
aws ec2 describe-subnets --filters Name=tag:Name,Values=cloudtolocalllm-*

# Verify security groups exist
aws ec2 describe-security-groups --filters Name=tag:Name,Values=cloudtolocalllm-*
```

**Step 3: Check IAM Roles**
```bash
# Verify EKS service role
aws iam get-role --role-name eks-service-role

# Verify node instance role
aws iam get-role --role-name eks-node-instance-role
```

**Step 4: Delete and Retry**
```bash
# Delete the failed stack
aws cloudformation delete-stack --stack-name cloudtolocalllm-eks

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name cloudtolocalllm-eks

# Retry creation
aws cloudformation create-stack --stack-name cloudtolocalllm-eks ...
```

### Issue: "Nodes not ready" or "Nodes in NotReady state"

**Symptoms:**
- `kubectl get nodes` shows nodes in NotReady state
- Pods cannot be scheduled
- Cluster appears unhealthy

**Root Causes:**
1. Node initialization still in progress
2. Security group blocks required traffic
3. IAM role doesn't have required permissions
4. Insufficient resources (CPU/memory)

**Solutions:**

**Step 1: Check Node Status**
```bash
# Get detailed node information
kubectl describe nodes

# Check node events
kubectl get events --all-namespaces | grep -i node
```

**Step 2: Check Node Logs**
```bash
# SSH into node (requires EC2 key pair)
aws ec2 describe-instances \
  --filters Name=tag:Name,Values=cloudtolocalllm-* \
  --query 'Reservations[0].Instances[0].PublicIpAddress'

# SSH to the node
ssh -i your-key.pem ec2-user@<node-ip>

# Check kubelet logs
sudo journalctl -u kubelet -n 100
```

**Step 3: Check Security Groups**
```bash
# Verify security group allows required ports
aws ec2 describe-security-groups \
  --group-ids <security-group-id> \
  --query 'SecurityGroups[0].IpPermissions'
```

Required ports:
- 443 (HTTPS)
- 10250 (kubelet)
- 10255 (kubelet read-only)

**Step 4: Wait for Node Initialization**

Nodes may take 5-10 minutes to initialize. Wait and check again:
```bash
# Wait for nodes to be ready
kubectl wait --for=condition=Ready node --all --timeout=600s
```

## Kubernetes Deployment Issues

### Issue: "Pods stuck in Pending state"

**Symptoms:**
- `kubectl get pods` shows pods in Pending state
- Pods don't transition to Running
- No error messages in pod events

**Root Causes:**
1. Insufficient cluster resources (CPU/memory)
2. Node selector doesn't match any nodes
3. Pod affinity/anti-affinity rules prevent scheduling
4. PersistentVolume not available

**Solutions:**

**Step 1: Check Pod Events**
```bash
kubectl describe pod <pod-name> -n cloudtolocalllm
```

Look for events like:
- "Insufficient cpu"
- "Insufficient memory"
- "No nodes match the pod's node selector"

**Step 2: Check Node Resources**
```bash
# Check node capacity
kubectl describe nodes

# Check resource requests/limits
kubectl describe pod <pod-name> -n cloudtolocalllm
```

**Step 3: Scale Cluster if Needed**
```bash
# Increase node count
aws eks update-nodegroup-config \
  --cluster-name cloudtolocalllm-eks \
  --nodegroup-name cloudtolocalllm-nodes \
  --scaling-config minSize=1,maxSize=10,desiredSize=3
```

**Step 4: Adjust Pod Resources**
```bash
# Edit deployment to reduce resource requests
kubectl edit deployment web-app -n cloudtolocalllm

# Change resources section:
# resources:
#   requests:
#     cpu: 50m        # Reduce from 100m
#     memory: 128Mi   # Reduce from 256Mi
```

### Issue: "ImagePullBackOff" or "ErrImagePull"

**Symptoms:**
- Pods fail to start with ImagePullBackOff error
- Cannot pull Docker image from Docker Hub
- Error: "Failed to pull image"

**Root Causes:**
1. Docker Hub credentials not configured
2. Image doesn't exist in Docker Hub
3. Image tag is incorrect
4. Docker Hub rate limiting

**Solutions:**

**Step 1: Verify Docker Hub Credentials**
```bash
# Check if secret exists
kubectl get secrets -n cloudtolocalllm | grep dockerhub

# Verify secret content
kubectl get secret dockerhub-secret -n cloudtolocalllm -o yaml
```

**Step 2: Verify Image Exists**
```bash
# Check Docker Hub
docker pull cloudtolocalllm/cloudtolocalllm-web:latest

# Or use Docker Hub API
curl https://hub.docker.com/v2/repositories/cloudtolocalllm/cloudtolocalllm-web/tags/
```

**Step 3: Check Image Tag in Deployment**
```bash
# Get deployment image
kubectl get deployment web-app -n cloudtolocalllm \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Step 4: Recreate Secret if Needed**
```bash
# Delete old secret
kubectl delete secret dockerhub-secret -n cloudtolocalllm

# Create new secret
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=$DOCKERHUB_USERNAME \
  --docker-password=$DOCKERHUB_TOKEN \
  --docker-email=your-email@example.com \
  -n cloudtolocalllm

# Restart pods to use new secret
kubectl rollout restart deployment web-app -n cloudtolocalllm
```

### Issue: "CrashLoopBackOff" or "Pod keeps restarting"

**Symptoms:**
- Pod starts but crashes immediately
- Pod restarts repeatedly
- Application logs show errors

**Root Causes:**
1. Application startup error
2. Missing environment variables
3. Database connection failure
4. Configuration error

**Solutions:**

**Step 1: Check Pod Logs**
```bash
# Get recent logs
kubectl logs <pod-name> -n cloudtolocalllm

# Get logs from previous container (if crashed)
kubectl logs <pod-name> -n cloudtolocalllm --previous

# Stream logs in real-time
kubectl logs -f <pod-name> -n cloudtolocalllm
```

**Step 2: Check Pod Events**
```bash
kubectl describe pod <pod-name> -n cloudtolocalllm
```

**Step 3: Verify Environment Variables**
```bash
# Check ConfigMap
kubectl get configmap app-config -n cloudtolocalllm -o yaml

# Check Secrets
kubectl get secret app-secrets -n cloudtolocalllm -o yaml

# Check pod environment
kubectl exec <pod-name> -n cloudtolocalllm -- env
```

**Step 4: Test Database Connection**
```bash
# Connect to pod
kubectl exec -it <pod-name> -n cloudtolocalllm -- /bin/bash

# Test database connection
psql -h postgres-service -U postgres -d cloudtolocalllm
```

## Networking and DNS Issues

### Issue: "Service not accessible" or "Connection refused"

**Symptoms:**
- Cannot connect to service from outside cluster
- Service IP is not accessible
- Connection times out

**Root Causes:**
1. Service not created or misconfigured
2. Ingress not configured
3. Security group blocks traffic
4. Load balancer not ready

**Solutions:**

**Step 1: Verify Service Exists**
```bash
# List services
kubectl get services -n cloudtolocalllm

# Get service details
kubectl describe service web-service -n cloudtolocalllm
```

**Step 2: Verify Ingress Configuration**
```bash
# List ingress
kubectl get ingress -n cloudtolocalllm

# Get ingress details
kubectl describe ingress main-ingress -n cloudtolocalllm
```

**Step 3: Check Load Balancer Status**
```bash
# Get load balancer details
kubectl get svc -n cloudtolocalllm ingress-nlb -o yaml

# Check if load balancer has external IP
kubectl get svc -n cloudtolocalllm ingress-nlb \
  -o jsonpath='{.status.loadBalancer.ingress[0]}'
```

**Step 4: Verify Security Groups**
```bash
# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <security-group-id> \
  --query 'SecurityGroups[0].IpPermissions'
```

### Issue: "DNS resolution fails" or "Cannot resolve domain"

**Symptoms:**
- `nslookup cloudtolocalllm.online` fails
- DNS returns wrong IP address
- DNS resolution times out

**Root Causes:**
1. DNS records not updated
2. DNS propagation not complete
3. Cloudflare DNS misconfigured
4. Load balancer IP changed

**Solutions:**

**Step 1: Check DNS Records**
```bash
# Query DNS
nslookup cloudtolocalllm.online
dig cloudtolocalllm.online

# Check Cloudflare DNS records
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json"
```

**Step 2: Get Current Load Balancer IP**
```bash
# Get NLB DNS name
NLB_DNS=$(kubectl get svc -n cloudtolocalllm ingress-nlb \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Get IP address
dig +short $NLB_DNS
```

**Step 3: Update DNS Records**
```bash
# Update Cloudflare DNS record
curl -X PUT "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"cloudtolocalllm.online\",\"content\":\"$NLB_IP\",\"ttl\":3600}"
```

**Step 4: Wait for DNS Propagation**
```bash
# DNS may take up to 48 hours to propagate
# Check propagation status
watch -n 5 'nslookup cloudtolocalllm.online'
```

## SSL/TLS Certificate Issues

### Issue: "SSL certificate error" or "Certificate not trusted"

**Symptoms:**
- Browser shows SSL certificate warning
- `curl -I https://cloudtolocalllm.online` shows certificate error
- Certificate validation fails

**Root Causes:**
1. SSL certificate not installed
2. Certificate expired
3. Certificate domain mismatch
4. Cloudflare SSL not configured

**Solutions:**

**Step 1: Check Certificate Status**
```bash
# Check certificate expiration
curl -I https://cloudtolocalllm.online 2>&1 | grep -i certificate

# Get certificate details
openssl s_client -connect cloudtolocalllm.online:443 -showcerts
```

**Step 2: Verify Cloudflare SSL Configuration**
```bash
# Check Cloudflare SSL settings
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/settings/ssl" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json"
```

**Step 3: Enable Cloudflare SSL**
```bash
# Set SSL to Full (Strict)
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/{zone_id}/settings/ssl" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"full"}'

# Enable Always Use HTTPS
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/{zone_id}/settings/always_use_https" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}'
```

**Step 4: Purge Cloudflare Cache**
```bash
# Purge cache to force certificate update
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}'
```

## Performance and Resource Issues

### Issue: "High CPU usage" or "High memory usage"

**Symptoms:**
- Cluster CPU usage is high
- Pods are being evicted due to memory pressure
- Application performance is degraded

**Root Causes:**
1. Application has memory leak
2. Pod resource limits too low
3. Too many pods on single node
4. Inefficient application code

**Solutions:**

**Step 1: Check Resource Usage**
```bash
# Get node resource usage
kubectl top nodes

# Get pod resource usage
kubectl top pods -n cloudtolocalllm

# Get detailed pod metrics
kubectl describe pod <pod-name> -n cloudtolocalllm
```

**Step 2: Check for Memory Leaks**
```bash
# Monitor memory usage over time
watch -n 5 'kubectl top pods -n cloudtolocalllm'

# Check pod logs for errors
kubectl logs <pod-name> -n cloudtolocalllm | grep -i error
```

**Step 3: Increase Resource Limits**
```bash
# Edit deployment
kubectl edit deployment web-app -n cloudtolocalllm

# Increase resource limits:
# resources:
#   limits:
#     cpu: 1000m      # Increase from 500m
#     memory: 1Gi     # Increase from 512Mi
```

**Step 4: Scale Cluster**
```bash
# Add more nodes
aws eks update-nodegroup-config \
  --cluster-name cloudtolocalllm-eks \
  --nodegroup-name cloudtolocalllm-nodes \
  --scaling-config minSize=1,maxSize=10,desiredSize=3
```

## Monitoring and Logging Issues

### Issue: "No logs in CloudWatch" or "Logs not appearing"

**Symptoms:**
- CloudWatch log groups are empty
- Application logs not visible
- Cannot troubleshoot issues

**Root Causes:**
1. CloudWatch Container Insights not enabled
2. IAM role doesn't have CloudWatch permissions
3. Application not writing logs to stdout
4. Log group not created

**Solutions:**

**Step 1: Verify CloudWatch Container Insights**
```bash
# Check if Container Insights is enabled
aws eks describe-cluster --name cloudtolocalllm-eks \
  --query 'cluster.logging.clusterLogging'
```

**Step 2: Enable Container Insights**
```bash
# Enable Container Insights
aws eks update-cluster-config \
  --name cloudtolocalllm-eks \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

**Step 3: Check IAM Permissions**
```bash
# Verify node IAM role has CloudWatch permissions
aws iam list-attached-role-policies --role-name eks-node-instance-role
```

**Step 4: Check Application Logging**
```bash
# Verify application writes to stdout
kubectl logs <pod-name> -n cloudtolocalllm

# If no logs, check application configuration
kubectl exec <pod-name> -n cloudtolocalllm -- cat /etc/app/config.yaml
```

## GitHub Actions Workflow Issues

### Issue: "Workflow fails with 'kubectl not found'"

**Symptoms:**
- GitHub Actions workflow fails
- Error: "kubectl: command not found"
- Deployment step fails

**Root Causes:**
1. kubectl not installed in workflow
2. kubeconfig not configured
3. AWS credentials not configured

**Solutions:**

**Step 1: Install kubectl in Workflow**
```yaml
- name: Install kubectl
  uses: azure/setup-kubectl@v3
  with:
    version: 'v1.30.0'
```

**Step 2: Configure kubeconfig**
```yaml
- name: Configure kubeconfig
  run: |
    aws eks update-kubeconfig \
      --name cloudtolocalllm-eks \
      --region us-east-1
```

**Step 3: Verify AWS Credentials**
```yaml
- name: Verify AWS credentials
  run: |
    aws sts get-caller-identity
    aws eks list-clusters
```

### Issue: "Workflow fails with 'Docker image push failed'"

**Symptoms:**
- GitHub Actions workflow fails at Docker push step
- Error: "Failed to push image to Docker Hub"
- Authentication error

**Root Causes:**
1. Docker Hub credentials not configured
2. Docker Hub token expired
3. Rate limiting from Docker Hub
4. Network connectivity issue

**Solutions:**

**Step 1: Verify Docker Hub Credentials**
```bash
# Check GitHub Secrets
gh secret list | grep DOCKERHUB

# Verify credentials are correct
docker login -u $DOCKERHUB_USERNAME -p $DOCKERHUB_TOKEN
```

**Step 2: Update Docker Hub Token**
```bash
# Generate new token in Docker Hub
# https://hub.docker.com/settings/security

# Update GitHub Secret
gh secret set DOCKERHUB_TOKEN --body "new-token"
```

**Step 3: Check Docker Hub Rate Limits**
```bash
# Check rate limit status
curl -H "Authorization: Bearer $DOCKERHUB_TOKEN" \
  https://hub.docker.com/v2/
```

**Step 4: Retry Workflow**
```bash
# Manually retry workflow
gh run rerun <run-id>
```

## Getting Help

If you encounter issues not covered in this guide:

1. **Check CloudTrail Logs**
   ```bash
   aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=cloudtolocalllm-eks
   ```

2. **Check CloudFormation Events**
   ```bash
   aws cloudformation describe-stack-events --stack-name cloudtolocalllm-eks
   ```

3. **Check Kubernetes Events**
   ```bash
   kubectl get events -n cloudtolocalllm --sort-by='.lastTimestamp'
   ```

4. **Enable Debug Logging**
   ```bash
   # Enable kubectl verbose logging
   kubectl -v=8 get pods -n cloudtolocalllm
   ```

5. **Contact Support**
   - AWS Support: https://console.aws.amazon.com/support/
   - Kubernetes Community: https://kubernetes.io/community/
   - GitHub Support: https://support.github.com/

