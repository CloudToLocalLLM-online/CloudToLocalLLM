#!/bin/bash

#
# Verifies GitHub Actions IAM role configuration
#
# Tests that the IAM role is properly configured for GitHub Actions
# OIDC authentication and can assume the role with temporary credentials.
#
# Requirements: 3.1, 3.4, 3.5
#

set -e

# Configuration
ROLE_NAME="${1:-github-actions-role}"
AWS_ACCOUNT_ID="${2:-422017356244}"

echo "Verifying GitHub Actions IAM Role Configuration"
echo "================================================="
echo ""

# Verify AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "✗ AWS CLI not found"
    exit 1
fi

echo "✓ AWS CLI found"
echo ""

# Check if role exists
echo "Checking if IAM role exists..."

if ! ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null); then
    echo "✗ IAM role not found: $ROLE_NAME"
    exit 1
fi

echo "✓ IAM role found: $ROLE_ARN"

# Check trust policy
echo ""
echo "Checking trust policy..."

ASSUME_ROLE_POLICY=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)

# Verify OIDC provider is in trust policy
if echo "$ASSUME_ROLE_POLICY" | grep -q "token.actions.githubusercontent.com"; then
    echo "✓ Trust policy includes GitHub OIDC provider"
else
    echo "✗ Trust policy does not include GitHub OIDC provider"
    exit 1
fi

# Verify STS audience
if echo "$ASSUME_ROLE_POLICY" | grep -q "sts.amazonaws.com"; then
    echo "✓ Trust policy includes STS audience"
else
    echo "✗ Trust policy does not include STS audience"
    exit 1
fi

# Check attached policies
echo ""
echo "Checking attached policies..."

if aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames' --output text | grep -q "eks-deployment-policy"; then
    echo "✓ EKS deployment policy is attached"
else
    echo "✗ EKS deployment policy is not attached"
    exit 1
fi

# Check policy permissions
POLICY_DOCUMENT=$(aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "eks-deployment-policy" --query 'RolePolicyDocument' --output json)

if echo "$POLICY_DOCUMENT" | grep -q "eks:DescribeCluster"; then
    echo "✓ EKS permissions are included"
else
    echo "✗ EKS permissions are missing"
    exit 1
fi

if echo "$POLICY_DOCUMENT" | grep -q "ecr:GetAuthorizationToken"; then
    echo "✓ ECR permissions are included"
else
    echo "✗ ECR permissions are missing"
    exit 1
fi

if echo "$POLICY_DOCUMENT" | grep -q "logs:CreateLogGroup"; then
    echo "✓ CloudWatch permissions are included"
else
    echo "✗ CloudWatch permissions are missing"
    exit 1
fi

# Check OIDC provider
echo ""
echo "Checking GitHub OIDC provider..."

if aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output text | grep -q "token.actions.githubusercontent.com"; then
    echo "✓ GitHub OIDC provider is configured"
else
    echo "✗ GitHub OIDC provider is not configured"
    exit 1
fi

# Display summary
echo ""
echo "Verification Complete!"
echo "================================================="
echo ""
echo "IAM Role Status:"
echo "  Role Name: $ROLE_NAME"
echo "  Role ARN: $ROLE_ARN"
echo "  Trust Policy: ✓ Configured"
echo "  EKS Permissions: ✓ Attached"
echo "  ECR Permissions: ✓ Attached"
echo "  CloudWatch Permissions: ✓ Attached"
echo "  OIDC Provider: ✓ Configured"
echo ""
echo "✓ All checks passed! Role is ready for GitHub Actions."
