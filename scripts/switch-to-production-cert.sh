#!/bin/bash

# Script to switch wildcard certificate from staging to production
# Run this after verifying staging certificate works correctly

set -e

echo "🔄 Switching wildcard certificate from staging to production..."

# Update certificate to use production issuer
sed -i 's/name: azure-dns-staging/name: azure-dns-prod/g' k8s/certificate-wildcard.yaml
sed -i 's/# STAGING: Use staging issuer first to test (no rate limits)/# PRODUCTION: Using production issuer/g' k8s/certificate-wildcard.yaml
sed -i 's/# PRODUCTION: Change to "azure-dns-prod" after testing/# STAGING: Change to "azure-dns-staging" to test/g' k8s/certificate-wildcard.yaml

# Update ingress annotation
sed -i 's/cert-manager.io\/cluster-issuer: "azure-dns-staging"/cert-manager.io\/cluster-issuer: "azure-dns-prod"/g' k8s/ingress-nginx.yaml
sed -i 's/# STAGING MODE: Currently using staging issuer to test configuration/# PRODUCTION MODE: Using production issuer/g' k8s/ingress-nginx.yaml

# Delete existing certificate to force new production certificate
echo "Deleting existing staging certificate..."
kubectl delete certificate cloudtolocalllm-wildcard -n cloudtolocalllm || true
kubectl delete secret cloudtolocalllm-wildcard-tls -n cloudtolocalllm || true

# Apply updated certificate
echo "Applying production certificate configuration..."
kubectl apply -f k8s/certificate-wildcard.yaml
kubectl apply -f k8s/ingress-nginx.yaml

echo ""
echo "✅ Switched to production certificate!"
echo "   - New production certificate will be provisioned automatically"
echo "   - May take a few minutes for cert-manager to issue the certificate"
echo "   - Check status with: kubectl get certificate cloudtolocalllm-wildcard -n cloudtolocalllm"
echo "   - Check cert-manager logs: kubectl logs -n cert-manager -l app=cert-manager"

