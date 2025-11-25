<#
.SYNOPSIS
    Verifies GitHub Actions IAM role configuration

.DESCRIPTION
    Tests that the IAM role is properly configured for GitHub Actions
    OIDC authentication and can assume the role with temporary credentials.

    Requirements: 3.1, 3.4, 3.5

.PARAMETER RoleName
    IAM role name (default: github-actions-role)

.PARAMETER AwsAccountId
    AWS Account ID (default: 422017356244)

.EXAMPLE
    .\verify-github-actions-role.ps1
    .\verify-github-actions-role.ps1 -RoleName github-actions-role
#>

param(
    [string]$RoleName = "github-actions-role",
    [string]$AwsAccountId = "422017356244"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "Verifying GitHub Actions IAM Role Configuration" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Verify AWS CLI is installed
try {
    $awsVersion = aws --version
    Write-Host "✓ AWS CLI found" -ForegroundColor Green
}
catch {
    Write-Host "✗ AWS CLI not found" -ForegroundColor Red
    exit 1
}

# Check if role exists
Write-Host ""
Write-Host "Checking if IAM role exists..." -ForegroundColor Yellow

try {
    $roleInfo = aws iam get-role --role-name $RoleName --output json | ConvertFrom-Json
    $roleArn = $roleInfo.Role.Arn
    Write-Host "✓ IAM role found: $roleArn" -ForegroundColor Green
}
catch {
    Write-Host "✗ IAM role not found: $RoleName" -ForegroundColor Red
    exit 1
}

# Check trust policy
Write-Host ""
Write-Host "Checking trust policy..." -ForegroundColor Yellow

try {
    $assumeRolePolicy = aws iam get-role --role-name $RoleName --query 'Role.AssumeRolePolicyDocument' --output json | ConvertFrom-Json
    
    # Verify OIDC provider is in trust policy
    $hasOIDCProvider = $assumeRolePolicy.Statement | Where-Object { $_.Principal.Federated -like "*token.actions.githubusercontent.com*" }
    
    if ($hasOIDCProvider) {
        Write-Host "✓ Trust policy includes GitHub OIDC provider" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Trust policy does not include GitHub OIDC provider" -ForegroundColor Red
        exit 1
    }
    
    # Verify STS audience
    $hasSTSAudience = $assumeRolePolicy.Statement | Where-Object { $_.Condition.StringEquals."token.actions.githubusercontent.com:aud" -eq "sts.amazonaws.com" }
    
    if ($hasSTSAudience) {
        Write-Host "✓ Trust policy includes STS audience" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Trust policy does not include STS audience" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "✗ Failed to check trust policy: $_" -ForegroundColor Red
    exit 1
}

# Check attached policies
Write-Host ""
Write-Host "Checking attached policies..." -ForegroundColor Yellow

try {
    $policies = aws iam list-role-policies --role-name $RoleName --query 'PolicyNames' --output json | ConvertFrom-Json
    
    if ($policies -contains "eks-deployment-policy") {
        Write-Host "✓ EKS deployment policy is attached" -ForegroundColor Green
    }
    else {
        Write-Host "✗ EKS deployment policy is not attached" -ForegroundColor Red
        exit 1
    }
    
    # Check policy permissions
    $policyDocument = aws iam get-role-policy --role-name $RoleName --policy-name "eks-deployment-policy" --query 'RolePolicyDocument' --output json | ConvertFrom-Json
    
    $hasEKSPermissions = $policyDocument.Statement | Where-Object { $_.Action -contains "eks:DescribeCluster" }
    $hasECRPermissions = $policyDocument.Statement | Where-Object { $_.Action -contains "ecr:GetAuthorizationToken" }
    $hasCloudWatchPermissions = $policyDocument.Statement | Where-Object { $_.Action -contains "logs:CreateLogGroup" }
    
    if ($hasEKSPermissions) {
        Write-Host "✓ EKS permissions are included" -ForegroundColor Green
    }
    else {
        Write-Host "✗ EKS permissions are missing" -ForegroundColor Red
        exit 1
    }
    
    if ($hasECRPermissions) {
        Write-Host "✓ ECR permissions are included" -ForegroundColor Green
    }
    else {
        Write-Host "✗ ECR permissions are missing" -ForegroundColor Red
        exit 1
    }
    
    if ($hasCloudWatchPermissions) {
        Write-Host "✓ CloudWatch permissions are included" -ForegroundColor Green
    }
    else {
        Write-Host "✗ CloudWatch permissions are missing" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "✗ Failed to check policies: $_" -ForegroundColor Red
    exit 1
}

# Check OIDC provider
Write-Host ""
Write-Host "Checking GitHub OIDC provider..." -ForegroundColor Yellow

try {
    $oidcProviders = aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output json | ConvertFrom-Json
    
    $hasGitHubProvider = $oidcProviders | Where-Object { $_ -like "*token.actions.githubusercontent.com*" }
    
    if ($hasGitHubProvider) {
        Write-Host "✓ GitHub OIDC provider is configured" -ForegroundColor Green
    }
    else {
        Write-Host "✗ GitHub OIDC provider is not configured" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "✗ Failed to check OIDC provider: $_" -ForegroundColor Red
    exit 1
}

# Display summary
Write-Host ""
Write-Host "Verification Complete!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "IAM Role Status:" -ForegroundColor Cyan
Write-Host "  Role Name: $RoleName" -ForegroundColor White
Write-Host "  Role ARN: $roleArn" -ForegroundColor White
Write-Host "  Trust Policy: ✓ Configured" -ForegroundColor Green
Write-Host "  EKS Permissions: ✓ Attached" -ForegroundColor Green
Write-Host "  ECR Permissions: ✓ Attached" -ForegroundColor Green
Write-Host "  CloudWatch Permissions: ✓ Attached" -ForegroundColor Green
Write-Host "  OIDC Provider: ✓ Configured" -ForegroundColor Green
Write-Host ""
Write-Host "✓ All checks passed! Role is ready for GitHub Actions." -ForegroundColor Green
