# AWS OIDC Provider Setup Guide

This guide walks through setting up AWS OIDC (OpenID Connect) provider to enable GitHub Actions to authenticate to AWS without storing long-lived credentials.

## Overview

OIDC allows GitHub Actions to exchange GitHub tokens for temporary AWS credentials using a trust relationship. This is more secure than storing AWS access keys in GitHub Secrets.

**Benefits:**
- No long-lived credentials stored in GitHub
- Automatic credential rotation
- Least-privilege access through IAM roles
- Audit trail of all deployments
- Compliance with security best practices

## Prerequisites

- AWS Account (ID: 422017356244)
- AWS CLI installed and configured with appropriate credentials
- PowerShell 5.0+ (for Windows) or Bash (for Linux/macOS)
- GitHub repository with Actions enabled
- Appropriate IAM permissions to create OIDC providers and IAM roles

## Setup Steps

### Step 1: Run the Setup Script

#### On Windows (PowerShell):

```powershell
# Navigate to the scripts directory
cd scripts/aws

# Run the setup script
.\setup-oidc-provider.ps1 -AwsAccountId "422017356244" -GitHubRepo "cloudtolocalllm/cloudtolocalllm"
```

#### On Linux/macOS (Bash):

```bash
# Navigate to the scripts directory
cd scripts/aws

# Make the script executable
chmod +x setup-oidc-provider.sh

# Run the setup script
./setup-oidc-provider.sh
```

### Step 2: Verify OIDC Provider Creation

The script will output:
- OIDC Provider ARN
- IAM Role ARN
- Attached policies

Example output:
```
OIDC Provider ARN: arn:aws:iam::422017356244:oidc-provider/token.actions.githubusercontent.com
IAM Role ARN: arn:aws:iam::422017356244:role/github-actions-role
```

### Step 3: Configure GitHub Actions Workflow

Add the following to your GitHub Actions workflow (`.github/workflows/deploy-aws-eks.yml`):

```yaml
name: Deploy to AWS EKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # Required for OIDC token
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::422017356244:role/github-actions-role
          aws-region: us-east-1
      
      - name: Verify AWS credentials
        run: |
          aws sts get-caller-identity
          aws eks list-clusters
      
      # Additional deployment steps...
```

### Step 4: Test OIDC Authentication

Create a test workflow to verify OIDC authentication works:

```yaml
name: Test OIDC Authentication

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::422017356244:role/github-actions-role
          aws-region: us-east-1
      
      - name: Get caller identity
        run: aws sts get-caller-identity
      
      - name: List EKS clusters
        run: aws eks list-clusters
      
      - name: List ECR repositories
        run: aws ecr describe-repositories
```

## OIDC Configuration Details

### Trust Relationship

The IAM role trusts the GitHub OIDC provider with the following conditions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::422017356244:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:cloudtolocalllm/cloudtolocalllm:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

**Key Points:**
- `Federated`: Points to the GitHub OIDC provider
- `aud` (Audience): Must be `sts.amazonaws.com`
- `sub` (Subject): Restricts to specific repository and branch
  - `repo:cloudtolocalllm/cloudtolocalllm` - Repository
  - `ref:refs/heads/main` - Main branch only

### Attached Policies

The IAM role has the following policies attached:

1. **AmazonEKSFullAccess** - Full access to EKS operations
2. **AmazonEC2FullAccess** - Full access to EC2 (for node management)
3. **AmazonECRFullAccess** - Full access to ECR (for image management)
4. **CloudWatchFullAccess** - Full access to CloudWatch (for monitoring)
5. **IAMFullAccess** - Full access to IAM (for pod roles)

**Note:** These are broad permissions for development. In production, consider using more restrictive policies.

## Verification

### Verify OIDC Provider

```bash
# List OIDC providers
aws iam list-open-id-connect-providers

# Get OIDC provider details
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::422017356244:oidc-provider/token.actions.githubusercontent.com
```

### Verify IAM Role

```bash
# Get role details
aws iam get-role --role-name github-actions-role

# List attached policies
aws iam list-attached-role-policies --role-name github-actions-role

# Get trust policy
aws iam get-role --role-name github-actions-role --query 'Role.AssumeRolePolicyDocument'
```

### Test Role Assumption

```bash
# Assume the role (requires valid OIDC token from GitHub)
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::422017356244:role/github-actions-role \
  --role-session-name github-actions-session \
  --web-identity-token <GITHUB_OIDC_TOKEN>
```

## Troubleshooting

### Issue: "InvalidParameterException: Invalid thumbprint"

**Solution:** The OIDC provider thumbprint may have changed. Update it:

```bash
# Get the current thumbprint
openssl s_client -servername token.actions.githubusercontent.com \
  -connect token.actions.githubusercontent.com:443 2>/dev/null | \
  openssl x509 -fingerprint -noout | sed 's/://g' | awk '{print $NF}'

# Update the OIDC provider
aws iam update-open-id-connect-provider-thumbprint \
  --open-id-connect-provider-arn arn:aws:iam::422017356244:oidc-provider/token.actions.githubusercontent.com \
  --thumbprint-list <NEW_THUMBPRINT>
```

### Issue: "AccessDenied: User is not authorized to perform: iam:CreateOpenIDConnectProvider"

**Solution:** Ensure your AWS credentials have IAM permissions. Contact your AWS administrator.

### Issue: GitHub Actions workflow fails with "AssumeRoleUnauthorizedOperation"

**Solution:** Verify the trust policy includes the correct repository and branch:

```bash
# Check the trust policy
aws iam get-role --role-name github-actions-role \
  --query 'Role.AssumeRolePolicyDocument'
```

Ensure the `sub` condition matches your repository and branch.

### Issue: "The provided web identity token is invalid"

**Solution:** This typically means the OIDC token from GitHub is invalid or expired. Ensure:
1. The workflow has `id-token: write` permission
2. The OIDC provider is correctly configured
3. The trust policy is correct

## Security Best Practices

1. **Restrict by Branch:** Only allow deployments from specific branches (e.g., `main`)
2. **Restrict by Environment:** Use GitHub environment protection rules
3. **Least Privilege:** Use more restrictive IAM policies in production
4. **Audit Logging:** Enable CloudTrail to audit all OIDC-based deployments
5. **Regular Review:** Periodically review and update OIDC configuration

## Additional Resources

- [GitHub Actions: About security hardening with OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS: Using OpenID Connect identity providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- [AWS: Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#configuring-the-oidc-trust-with-aws)

## Next Steps

1. Run the setup script to create the OIDC provider and IAM role
2. Update your GitHub Actions workflow with the role ARN
3. Test the OIDC authentication with a test workflow
4. Monitor CloudTrail for OIDC-based deployments
5. Proceed to Task 2: Create AWS IAM Role for GitHub Actions (if not already done)
