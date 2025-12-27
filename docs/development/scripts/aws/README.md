# AWS Setup Scripts

This directory contains PowerShell and Bash scripts for setting up AWS infrastructure for CloudToLocalLLM EKS deployment.

## Scripts

### 1. setup-oidc-provider.ps1 (Windows)

Sets up AWS OIDC provider and IAM role for GitHub Actions authentication.

**Usage:**
```powershell
.\setup-oidc-provider.ps1 `
  -AwsAccountId "422017356244" `
  -GitHubRepo "cloudtolocalllm/cloudtolocalllm" `
  -OidcProviderUrl "token.actions.githubusercontent.com" `
  -OidcAudience "sts.amazonaws.com" `
  -AwsRegion "us-east-1"
```

**Parameters:**
- `AwsAccountId`: AWS Account ID (default: 422017356244)
- `GitHubRepo`: GitHub repository in format `owner/repo` (default: cloudtolocalllm/cloudtolocalllm)
- `OidcProviderUrl`: OIDC provider URL (default: token.actions.githubusercontent.com)
- `OidcAudience`: OIDC audience (default: sts.amazonaws.com)
- `AwsRegion`: AWS region (default: us-east-1)

**What it does:**
1. Creates OIDC provider in AWS (if not exists)
2. Creates IAM role for GitHub Actions (if not exists)
3. Attaches required policies to the role
4. Verifies OIDC provider configuration
5. Outputs role ARN for use in GitHub Actions

**Output:**
- OIDC Provider ARN
- IAM Role ARN
- Configuration saved to `oidc-config.json`

### 2. setup-oidc-provider.sh (Linux/macOS)

Bash version of the OIDC provider setup script.

**Usage:**
```bash
chmod +x setup-oidc-provider.sh
./setup-oidc-provider.sh
```

**What it does:**
- Same as PowerShell version but for Unix-like systems

### 3. verify-oidc-setup.ps1 (Windows)

Verifies that the OIDC provider and IAM role are correctly configured.

**Usage:**
```powershell
.\verify-oidc-setup.ps1 `
  -AwsAccountId "422017356244" `
  -OidcProviderUrl "token.actions.githubusercontent.com" `
  -RoleName "github-actions-role"
```

**Checks:**
1. OIDC Provider exists
2. OIDC Provider configuration (URL, client IDs, thumbprints)
3. IAM Role exists
4. Trust policy is correct
5. Required policies are attached
6. Role can be assumed
7. GitHub Actions workflow configuration

**Output:**
- ✓ for passed checks
- ✗ for failed checks
- ⚠ for warnings

### 4. cost-monitoring.js (Node.js)

Monitors AWS EKS cluster costs and generates optimization reports.

**Usage:**
```bash
# Generate cost report
node scripts/aws/cost-monitoring.js

# Output: JSON report with cost breakdown and recommendations
```

**What it does:**
1. Calculates estimated monthly costs based on cluster configuration
2. Generates detailed cost breakdown by service
3. Provides cost optimization recommendations
4. Exports reports to JSON files
5. Creates CloudWatch dashboards for cost tracking
6. Configures monthly cost alerts

**Cost Estimates Included:**
- t3.small: $30.72/month per instance
- t3.micro: $7.68/month per instance
- Network Load Balancer: $16.56/month
- EBS Storage: $10/month (100GB estimate)
- Data Transfer: $5/month (250GB estimate)
- CloudWatch Logs: $5/month (10GB estimate)

**Example Output:**
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "clusterName": "cloudtolocalllm-eks",
  "costAnalysis": {
    "estimatedMonthlyCost": 60.48,
    "breakdown": {
      "t3.small": {
        "cost": 30.72,
        "description": "2x t3.small EC2 instance"
      },
      "network-load-balancer": {
        "cost": 16.56,
        "description": "Network Load Balancer"
      }
    },
    "budget": 300,
    "budgetUtilization": "20.16%",
    "withinBudget": true
  },
  "recommendations": []
}
```

**Key Functions:**
- `calculateEstimatedMonthlyCost(config)` - Calculate monthly costs
- `generateCostOptimizationReport(config, estimatedCost)` - Generate reports
- `generateRecommendations(config, estimatedCost)` - Get optimization tips
- `exportCostReport(report, outputPath)` - Export to JSON
- `createCostDashboard()` - Create CloudWatch dashboard
- `configureCostAlerts(monthlyBudget)` - Set up cost alerts
- `getCostAndUsageData(startDate, endDate)` - Fetch AWS cost data

**Budget Constraints:**
- Monthly budget: $300
- Development cluster: 2-3 nodes
- Instance types: t3.small or t3.micro only

## Prerequisites

### Windows
- PowerShell 5.0 or later
- AWS CLI installed and configured
- Appropriate IAM permissions

### Linux/macOS
- Bash 4.0 or later
- AWS CLI installed and configured
- OpenSSL installed
- Appropriate IAM permissions

## Installation

### AWS CLI Installation

**Windows (using Chocolatey):**
```powershell
choco install awscli
```

**Windows (using MSI installer):**
Download from: https://aws.amazon.com/cli/

**Linux/macOS (using Homebrew):**
```bash
brew install awscli
```

**Linux (using pip):**
```bash
pip install awscli
```

### AWS CLI Configuration

```bash
aws configure
```

Enter your AWS credentials:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: us-east-1
- Default output format: json

## Quick Start

### Step 1: Set up OIDC Provider

**Windows:**
```powershell
cd scripts/aws
.\setup-oidc-provider.ps1
```

**Linux/macOS:**
```bash
cd scripts/aws
chmod +x setup-oidc-provider.sh
./setup-oidc-provider.sh
```

### Step 2: Verify Setup

**Windows:**
```powershell
.\verify-oidc-setup.ps1
```

### Step 3: Update GitHub Actions Workflow

Copy the role ARN from the setup output and add it to your GitHub Actions workflow:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: arn:aws:iam::422017356244:role/github-actions-role
    aws-region: us-east-1
```

### Step 4: Test OIDC Authentication

Push a test workflow or manually trigger the test workflow:

```bash
gh workflow run test-oidc-auth.yml
```

### Step 5: Monitor Cluster Costs

Generate a cost report to track AWS spending:

```bash
# Generate cost report
node scripts/aws/cost-monitoring.js

# Reports are saved to docs/cost-report-*.json
ls -lh docs/cost-report-*.json
```

## Troubleshooting

### Issue: "InvalidParameterException: Invalid thumbprint"

**Solution:** Update the OIDC provider thumbprint:

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

### Issue: "AccessDenied: User is not authorized"

**Solution:** Ensure your AWS credentials have the following permissions:
- `iam:CreateOpenIDConnectProvider`
- `iam:CreateRole`
- `iam:AttachRolePolicy`
- `iam:GetRole`
- `iam:GetOpenIDConnectProvider`

### Issue: GitHub Actions workflow fails with "AssumeRoleUnauthorizedOperation"

**Solution:** Verify the trust policy includes the correct repository and branch:

```bash
aws iam get-role --role-name github-actions-role \
  --query 'Role.AssumeRolePolicyDocument'
```

Ensure the `sub` condition matches your repository and branch.

## Configuration Files

### oidc-config.json

Generated by `setup-oidc-provider.ps1`, contains:
- AWS Account ID
- GitHub Repository
- OIDC Provider URL
- OIDC Provider ARN
- IAM Role Name
- IAM Role ARN
- AWS Region
- Setup Date

## Security Considerations

1. **Restrict by Branch:** Only allow deployments from specific branches
2. **Restrict by Environment:** Use GitHub environment protection rules
3. **Least Privilege:** Use more restrictive IAM policies in production
4. **Audit Logging:** Enable CloudTrail to audit all OIDC-based deployments
5. **Regular Review:** Periodically review and update OIDC configuration

## Additional Resources

- [AWS OIDC Setup Guide](../../docs/AWS_OIDC_SETUP_GUIDE.md)
- [GitHub Actions: About security hardening with OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS: Using OpenID Connect identity providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the AWS OIDC Setup Guide
3. Check AWS CloudTrail logs for detailed error information
4. Contact AWS support if needed

## Next Steps

After setting up OIDC:
1. Verify the setup using `verify-oidc-setup.ps1`
2. Update GitHub Actions workflows with the role ARN
3. Test OIDC authentication with a test workflow
4. Monitor CloudTrail for OIDC-based deployments
5. Proceed to Task 2: Create AWS IAM Role for GitHub Actions
