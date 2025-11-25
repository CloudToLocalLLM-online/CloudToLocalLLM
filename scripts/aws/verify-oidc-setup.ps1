# Verify AWS OIDC Provider Setup (PowerShell)
# This script verifies that the OIDC provider and IAM role are correctly configured

param(
    [string]$AwsAccountId = "422017356244",
    [string]$OidcProviderUrl = "token.actions.githubusercontent.com",
    [string]$RoleName = "github-actions-role"
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "AWS OIDC Provider Verification" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$allChecks = $true

# Check 1: OIDC Provider exists
Write-Host "Check 1: OIDC Provider exists" -ForegroundColor Yellow
try {
    $oidcProviders = aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?Arn=='arn:aws:iam::$($AwsAccountId):oidc-provider/$OidcProviderUrl'].Arn" --output text
    
    if ($oidcProviders) {
        Write-Host "✓ OIDC Provider found: $oidcProviders" -ForegroundColor Green
    }
    else {
        Write-Host "✗ OIDC Provider not found" -ForegroundColor Red
        $allChecks = $false
    }
}
catch {
    Write-Host "✗ Error checking OIDC Provider: $_" -ForegroundColor Red
    $allChecks = $false
}

Write-Host ""

# Check 2: OIDC Provider configuration
Write-Host "Check 2: OIDC Provider configuration" -ForegroundColor Yellow
try {
    $oidcProviderArn = "arn:aws:iam::$($AwsAccountId):oidc-provider/$OidcProviderUrl"
    $providerDetails = aws iam get-open-id-connect-provider --open-id-connect-provider-arn $oidcProviderArn | ConvertFrom-Json
    
    Write-Host "  URL: $($providerDetails.Url)" -ForegroundColor Green
    Write-Host "  Client IDs: $($providerDetails.ClientIDList -join ', ')" -ForegroundColor Green
    Write-Host "  Thumbprints: $($providerDetails.ThumbprintList -join ', ')" -ForegroundColor Green
    Write-Host "✓ OIDC Provider configuration verified" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error getting OIDC Provider details: $_" -ForegroundColor Red
    $allChecks = $false
}

Write-Host ""

# Check 3: IAM Role exists
Write-Host "Check 3: IAM Role exists" -ForegroundColor Yellow
try {
    $role = aws iam get-role --role-name $RoleName | ConvertFrom-Json
    Write-Host "✓ IAM Role found: $($role.Role.RoleName)" -ForegroundColor Green
    Write-Host "  ARN: $($role.Role.Arn)" -ForegroundColor Green
    Write-Host "  Created: $($role.Role.CreateDate)" -ForegroundColor Green
}
catch {
    Write-Host "✗ IAM Role not found: $_" -ForegroundColor Red
    $allChecks = $false
}

Write-Host ""

# Check 4: Trust policy is correct
Write-Host "Check 4: Trust policy configuration" -ForegroundColor Yellow
try {
    $role = aws iam get-role --role-name $RoleName | ConvertFrom-Json
    $trustPolicy = $role.Role.AssumeRolePolicyDocument
    
    # Check for OIDC provider in trust policy
    if ($trustPolicy | ConvertTo-Json | Select-String "token.actions.githubusercontent.com") {
        Write-Host "✓ Trust policy includes GitHub OIDC provider" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Trust policy does not include GitHub OIDC provider" -ForegroundColor Red
        $allChecks = $false
    }
    
    # Check for correct audience
    if ($trustPolicy | ConvertTo-Json | Select-String "sts.amazonaws.com") {
        Write-Host "✓ Trust policy includes correct audience (sts.amazonaws.com)" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Trust policy does not include correct audience" -ForegroundColor Red
        $allChecks = $false
    }
    
    # Display trust policy
    Write-Host ""
    Write-Host "  Trust Policy:" -ForegroundColor Cyan
    $trustPolicy | ConvertTo-Json -Depth 10 | ForEach-Object { Write-Host "    $_" }
}
catch {
    Write-Host "✗ Error checking trust policy: $_" -ForegroundColor Red
    $allChecks = $false
}

Write-Host ""

# Check 5: Required policies are attached
Write-Host "Check 5: Required policies attached" -ForegroundColor Yellow
try {
    $attachedPolicies = aws iam list-attached-role-policies --role-name $RoleName | ConvertFrom-Json
    
    $requiredPolicies = @(
        "AmazonEKSFullAccess",
        "AmazonEC2FullAccess",
        "AmazonECRFullAccess",
        "CloudWatchFullAccess",
        "IAMFullAccess"
    )
    
    $allPoliciesAttached = $true
    foreach ($policy in $requiredPolicies) {
        $found = $attachedPolicies.AttachedPolicies | Where-Object { $_.PolicyName -eq $policy }
        if ($found) {
            Write-Host "  ✓ $policy" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ $policy (NOT ATTACHED)" -ForegroundColor Red
            $allPoliciesAttached = $false
        }
    }
    
    if ($allPoliciesAttached) {
        Write-Host "✓ All required policies are attached" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Some required policies are missing" -ForegroundColor Red
        $allChecks = $false
    }
}
catch {
    Write-Host "✗ Error checking attached policies: $_" -ForegroundColor Red
    $allChecks = $false
}

Write-Host ""

# Check 6: Role can be assumed (basic check)
Write-Host "Check 6: Role configuration for assumption" -ForegroundColor Yellow
try {
    $role = aws iam get-role --role-name $RoleName | ConvertFrom-Json
    $maxSessionDuration = $role.Role.MaxSessionDuration
    
    Write-Host "  Max Session Duration: $maxSessionDuration seconds (~$([math]::Round($maxSessionDuration / 3600)) hours)" -ForegroundColor Green
    
    if ($maxSessionDuration -ge 3600) {
        Write-Host "✓ Role has sufficient session duration" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Role session duration is less than 1 hour" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Error checking role configuration: $_" -ForegroundColor Red
    $allChecks = $false
}

Write-Host ""

# Check 7: GitHub Actions workflow configuration
Write-Host "Check 7: GitHub Actions workflow configuration" -ForegroundColor Yellow
$workflowPath = ".github/workflows/deploy-aws-eks.yml"
if (Test-Path $workflowPath) {
    $workflowContent = Get-Content $workflowPath -Raw
    
    if ($workflowContent -match "aws-actions/configure-aws-credentials") {
        Write-Host "✓ Workflow includes AWS credentials configuration" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Workflow does not include AWS credentials configuration" -ForegroundColor Yellow
    }
    
    if ($workflowContent -match "id-token: write") {
        Write-Host "✓ Workflow includes id-token permission" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Workflow does not include id-token permission" -ForegroundColor Yellow
    }
}
else {
    Write-Host "⚠ Workflow file not found at $workflowPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan

if ($allChecks) {
    Write-Host "✓ All checks passed! OIDC setup is complete." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Create GitHub Actions workflow at .github/workflows/deploy-aws-eks.yml" -ForegroundColor White
    Write-Host "2. Add AWS credentials configuration step to workflow" -ForegroundColor White
    Write-Host "3. Test the workflow by pushing code to main branch" -ForegroundColor White
}
else {
    Write-Host "✗ Some checks failed. Please review the errors above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure AWS CLI is configured with correct credentials" -ForegroundColor White
    Write-Host "2. Verify AWS account ID is correct: $AwsAccountId" -ForegroundColor White
    Write-Host "3. Check IAM permissions for OIDC provider and role management" -ForegroundColor White
    Write-Host "4. Review AWS_OIDC_SETUP_GUIDE.md for detailed instructions" -ForegroundColor White
}

Write-Host ""
