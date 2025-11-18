# Script to switch wildcard certificate from staging to production
# Run this after verifying staging certificate works correctly

$ErrorActionPreference = "Stop"

Write-Host "🔄 Switching wildcard certificate from staging to production..." -ForegroundColor Cyan

# Update certificate to use production issuer
$certFile = "k8s/certificate-wildcard.yaml"
$certContent = Get-Content $certFile -Raw
$certContent = $certContent -replace 'name: azure-dns-staging', 'name: azure-dns-prod'
$certContent = $certContent -replace '# STAGING: Use staging issuer first to test \(no rate limits\)', '# PRODUCTION: Using production issuer'
$certContent = $certContent -replace '# PRODUCTION: Change to "azure-dns-prod" after testing', '# STAGING: Change to "azure-dns-staging" to test'
Set-Content -Path $certFile -Value $certContent

# Update ingress annotation
$ingressFile = "k8s/ingress-nginx.yaml"
$ingressContent = Get-Content $ingressFile -Raw
$ingressContent = $ingressContent -replace 'cert-manager\.io/cluster-issuer: "azure-dns-staging"', 'cert-manager.io/cluster-issuer: "azure-dns-prod"'
$ingressContent = $ingressContent -replace '# STAGING MODE: Currently using staging issuer to test configuration', '# PRODUCTION MODE: Using production issuer'
Set-Content -Path $ingressFile -Value $ingressContent

# Delete existing certificate to force new production certificate
Write-Host "Deleting existing staging certificate..." -ForegroundColor Yellow
kubectl delete certificate cloudtolocalllm-wildcard -n cloudtolocalllm -ErrorAction SilentlyContinue
kubectl delete secret cloudtolocalllm-wildcard-tls -n cloudtolocalllm -ErrorAction SilentlyContinue

# Apply updated certificate
Write-Host "Applying production certificate configuration..." -ForegroundColor Cyan
kubectl apply -f k8s/certificate-wildcard.yaml
kubectl apply -f k8s/ingress-nginx.yaml

Write-Host ""
Write-Host "✅ Switched to production certificate!" -ForegroundColor Green
Write-Host "   - New production certificate will be provisioned automatically" -ForegroundColor White
Write-Host "   - May take a few minutes for cert-manager to issue the certificate" -ForegroundColor White
Write-Host "   - Check status with: kubectl get certificate cloudtolocalllm-wildcard -n cloudtolocalllm" -ForegroundColor White
Write-Host "   - Check cert-manager logs: kubectl logs -n cert-manager -l app=cert-manager" -ForegroundColor White

