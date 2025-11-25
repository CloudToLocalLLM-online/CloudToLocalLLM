# CI/CD Integration Guide

## Overview

The CI/CD pipeline is now fully integrated with AWS OIDC authentication. This guide explains how the pipeline works and how to use it.

## Architecture

```
GitHub Repository
    ↓
GitHub Actions Workflow
    ↓
OIDC Token Exchange
    ↓
AWS STS (Security Token Service)
    ↓
Temporary AWS Credentials
    ↓
AWS Services (EKS, ECR, CloudWatch)
    ↓
Application Deployment
```

## Workflows

### 1. Deploy to AWS EKS Workflow

**File**: `.github/workflows/deploy-aws-eks.yml`

**Triggers**:
- Push to `main` branch (with code changes)
- Manual workflow dispatch

**Steps**:

1. **Checkout Code**
   - Clones the repository

2. **Configure AWS Credentials**
   - Uses OIDC to obtain temporary AWS credentials
   - No long-lived credentials stored

3. **Verify AWS Credentials**
   - Confirms AWS account access
   - Lists available EKS clusters

4. **Set up Docker Buildx**
   - Prepares Docker for multi-platform builds

5. **Log in to Docker Hub**
   - Uses Docker Hub credentials from GitHub Secrets

6. **Build and Push Web App Image**
   - Builds Docker image for web application
   - Tags with `latest` and commit SHA
   - Pushes to Docker Hub

7. **Build and Push API Backend Image**
   - Builds Docker image for API backend
   - Tags with `latest` and commit SHA
   - Pushes to Docker Hub

8. **Update kubeconfig**
   - Configures kubectl to access EKS cluster

9. **Verify Cluster Connectivity**
   - Confirms connection to EKS cluster
   - Lists cluster nodes

10. **Create Namespace**
    - Creates Kubernetes namespace if not exists

11. **Update Kubernetes Manifests**
    - Updates deployment images with new tags

12. **Wait for Rollout**
    - Waits for deployments to complete
    - Verifies all pods are running

13. **Verify Deployment Health**
    - Checks pod status
    - Checks service status
    - Checks ingress status

14. **Get Load Balancer Endpoint**
    - Retrieves load balancer IP/hostname

15. **Verify Application Accessibility**
    - Tests application health endpoint
    - Confirms application is accessible

16. **Deployment Successful**
    - Logs deployment summary

17. **Rollback on Failure**
    - Automatically rolls back on failure
    - Restores previous version

### 2. Test OIDC Authentication Workflow

**File**: `.github/workflows/test-oidc-auth.yml`

**Triggers**:
- Manual workflow dispatch
- Weekly schedule (Sunday at midnight UTC)

**Tests**:

1. **Get Caller Identity**
   - Verifies OIDC authentication
   - Confirms AWS account access

2. **List EKS Clusters**
   - Tests EKS permissions

3. **List ECR Repositories**
   - Tests ECR permissions

4. **Check IAM Role Permissions**
   - Tests EKS describe-cluster permission
   - Tests EC2 describe-instances permission
   - Tests ECR describe-repositories permission
   - Tests CloudWatch list-metrics permission

5. **Verify Token Expiration**
   - Confirms temporary credentials are used

6. **Check CloudTrail Logging**
   - Verifies OIDC events are logged

## Environment Variables

### Deploy Workflow
```yaml
AWS_REGION: us-east-1
EKS_CLUSTER_NAME: cloudtolocalllm-eks
DOCKER_REGISTRY: cloudtolocalllm
NAMESPACE: cloudtolocalllm
```

## Required Secrets

### Docker Hub Credentials
- `DOCKERHUB_USERNAME`: Docker Hub username
- `DOCKERHUB_TOKEN`: Docker Hub access token

### AWS Credentials (Not Required)
- AWS credentials are obtained via OIDC
- No long-lived credentials needed in GitHub Secrets

## How to Use

### 1. Test OIDC Authentication

```bash
# Manually trigger the test workflow
gh workflow run test-oidc-auth.yml

# Check the workflow run
gh run list --workflow=test-oidc-auth.yml

# View workflow details
gh run view <RUN_ID>

# View workflow logs
gh run view <RUN_ID> --log
```

### 2. Deploy to AWS EKS

```bash
# Push code to main branch
git push origin main

# Or manually trigger the workflow
gh workflow run deploy-aws-eks.yml

# Check the workflow run
gh run list --workflow=deploy-aws-eks.yml

# View workflow details
gh run view <RUN_ID>

# View workflow logs
gh run view <RUN_ID> --log
```

### 3. Monitor Deployments

```bash
# List all workflow runs
gh run list

# List runs for specific workflow
gh run list --workflow=deploy-aws-eks.yml

# View specific run
gh run view <RUN_ID>

# View run logs
gh run view <RUN_ID> --log

# Watch run in real-time
gh run watch <RUN_ID>
```

## Workflow Status

### Success
- All steps complete successfully
- Application is deployed and accessible
- Health checks pass

### Failure
- Automatic rollback to previous version
- Error logs available in workflow run
- Application remains accessible with previous version

## Troubleshooting

### Workflow fails with "AssumeRoleUnauthorizedOperation"

**Cause**: OIDC token exchange failed

**Solution**:
1. Verify GitHub Actions permissions include `id-token: write`
2. Check trust policy includes correct repository and branch
3. Verify AWS credentials are configured correctly

**Check**:
```bash
aws iam get-role --role-name github-actions-role \
  --query 'Role.AssumeRolePolicyDocument'
```

### Workflow fails with "Docker image push failed"

**Cause**: Docker Hub credentials are invalid or missing

**Solution**:
1. Verify Docker Hub credentials in GitHub Secrets
2. Check Docker Hub repository exists
3. Verify Docker Hub token has push permissions

**Check**:
```bash
# Test Docker Hub login
docker login -u <USERNAME> -p <TOKEN>
```

### Workflow fails with "EKS cluster not found"

**Cause**: EKS cluster doesn't exist or is in different region

**Solution**:
1. Verify EKS cluster exists in AWS
2. Check cluster name matches `cloudtolocalllm-eks`
3. Verify AWS region is `us-east-1`

**Check**:
```bash
aws eks list-clusters --region us-east-1
aws eks describe-cluster --name cloudtolocalllm-eks --region us-east-1
```

### Workflow fails with "Kubernetes namespace not found"

**Cause**: Kubernetes namespace doesn't exist

**Solution**:
1. Workflow automatically creates namespace
2. If manual creation needed:
```bash
kubectl create namespace cloudtolocalllm
```

### Workflow fails with "Pod failed health checks"

**Cause**: Application pod is not healthy

**Solution**:
1. Check pod logs:
```bash
kubectl logs -n cloudtolocalllm <POD_NAME>
```

2. Check pod events:
```bash
kubectl describe pod -n cloudtolocalllm <POD_NAME>
```

3. Check pod status:
```bash
kubectl get pods -n cloudtolocalllm
```

## Security

### OIDC Authentication
- ✓ No long-lived credentials stored in GitHub Secrets
- ✓ Automatic credential rotation on each workflow run
- ✓ Credentials expire after 1 hour
- ✓ All deployments logged in CloudTrail

### Branch Protection
- ✓ Deployments only from main branch
- ✓ Trust policy restricts to main branch
- ✓ Additional branch protection rules recommended

### Least Privilege
- ✓ IAM role has specific permissions
- ✓ No overly broad permissions
- ✓ Policies can be further restricted if needed

## Monitoring

### CloudWatch Logs
```bash
# View application logs
aws logs tail /aws/eks/cloudtolocalllm-eks --follow

# View specific pod logs
kubectl logs -n cloudtolocalllm <POD_NAME> --follow
```

### CloudTrail Events
```bash
# View OIDC-based deployments
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --region us-east-1
```

### GitHub Actions
```bash
# View workflow runs
gh run list --workflow=deploy-aws-eks.yml

# View workflow logs
gh run view <RUN_ID> --log
```

## Best Practices

1. **Always Test First**
   - Run test workflow before deploying
   - Verify OIDC authentication works

2. **Monitor Deployments**
   - Check workflow logs
   - Monitor application health
   - Review CloudTrail events

3. **Use Branch Protection**
   - Require pull request reviews
   - Require status checks to pass
   - Restrict who can push to main

4. **Keep Secrets Secure**
   - Rotate Docker Hub tokens regularly
   - Use GitHub Secrets for sensitive data
   - Never commit credentials to repository

5. **Document Changes**
   - Update deployment documentation
   - Document any manual changes
   - Keep runbooks up to date

## Files

- `.github/workflows/deploy-aws-eks.yml` - Main deployment workflow
- `.github/workflows/test-oidc-auth.yml` - OIDC test workflow
- `docs/CI_CD_QUICK_REFERENCE.md` - Quick reference guide
- `docs/AWS_OIDC_SETUP_GUIDE.md` - Detailed setup guide
- `docs/AWS_INFRASTRUCTURE_SETUP_COMPLETE.md` - Setup completion summary

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Actions: About security hardening with OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS: Using OpenID Connect identity providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Support

For issues or questions:
1. Check workflow logs in GitHub Actions
2. Review CloudTrail events in AWS
3. Check application logs in CloudWatch
4. Contact AWS support if needed
