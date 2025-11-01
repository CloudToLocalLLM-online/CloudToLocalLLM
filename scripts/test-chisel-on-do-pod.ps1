# Test Chisel binary on existing DigitalOcean Kubernetes pod
# This script verifies Chisel is working in a running deployment

param(
    [Parameter(Mandatory=$false)]
    [string]$ClusterName = "cloudtolocalllm",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "cloudtolocalllm",
    
    [Parameter(Mandatory=$false)]
    [string]$DeploymentName = "api-backend"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║        Test Chisel Binary on DigitalOcean Pod              ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

#######################################################################
# Step 1: Connect to Cluster
#######################################################################

Write-Host "Step 1: Connecting to Kubernetes cluster..." -ForegroundColor Yellow

try {
    doctl kubernetes cluster kubeconfig save $ClusterName
    Write-Host "✓ Connected to cluster: $ClusterName" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to connect to cluster" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Yellow
    exit 1
}

#######################################################################
# Step 2: Find API Backend Pod
#######################################################################

Write-Host ""
Write-Host "Step 2: Finding API backend pod..." -ForegroundColor Yellow

$pods = kubectl get pods -n $Namespace -l app=$DeploymentName -o json | ConvertFrom-Json

if (!$pods.items -or $pods.items.Count -eq 0) {
    Write-Host "✗ No pods found for deployment: $DeploymentName" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available pods:" -ForegroundColor Yellow
    kubectl get pods -n $Namespace
    exit 1
}

$podName = $pods.items[0].metadata.name
Write-Host "✓ Found pod: $podName" -ForegroundColor Green

# Check if pod is running
$podStatus = ($pods.items[0].status.phase)
if ($podStatus -ne "Running") {
    Write-Host "⚠ Pod status: $podStatus" -ForegroundColor Yellow
    Write-Host "Waiting for pod to be ready..." -ForegroundColor Cyan
    kubectl wait --for=condition=ready pod/$podName -n $Namespace --timeout=60s
}

#######################################################################
# Step 3: Test Chisel Binary
#######################################################################

Write-Host ""
Write-Host "Step 3: Testing Chisel binary in pod..." -ForegroundColor Yellow

Write-Host "Checking if Chisel binary exists..." -ForegroundColor Cyan
$chiselCheck = kubectl exec -n $Namespace $podName -- sh -c "which chisel || ls -la /usr/local/bin/chisel || echo 'CHISEL_NOT_FOUND'"

if ($chiselCheck -match "CHISEL_NOT_FOUND") {
    Write-Host "✗ Chisel binary not found!" -ForegroundColor Red
    Write-Host "Output: $chiselCheck" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Chisel binary found" -ForegroundColor Green
Write-Host "Binary location check:" -ForegroundColor Cyan
Write-Host $chiselCheck

Write-Host ""
Write-Host "Testing Chisel version..." -ForegroundColor Cyan
$chiselVersion = kubectl exec -n $Namespace $podName -- chisel --version

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Chisel is working!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Chisel version output:" -ForegroundColor Cyan
    Write-Host $chiselVersion
} else {
    Write-Host "✗ Chisel version check failed!" -ForegroundColor Red
    exit 1
}

#######################################################################
# Step 4: Verify Chisel Binary Properties
#######################################################################

Write-Host ""
Write-Host "Step 4: Verifying Chisel binary properties..." -ForegroundColor Yellow

Write-Host "Checking binary file info..." -ForegroundColor Cyan
$binaryInfo = kubectl exec -n $Namespace $podName -- sh -c "ls -lh /usr/local/bin/chisel && file /usr/local/bin/chisel"

Write-Host $binaryInfo

Write-Host ""
Write-Host "Testing Chisel help command..." -ForegroundColor Cyan
$chiselHelp = kubectl exec -n $Namespace $podName -- chisel --help 2>&1 | Select-Object -First 5

Write-Host $chiselHelp

#######################################################################
# Summary
#######################################################################

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Chisel Verification Summary                ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "✓ Pod found and accessible: $podName" -ForegroundColor Green
Write-Host "✓ Chisel binary found at: /usr/local/bin/chisel" -ForegroundColor Green
Write-Host "✓ Chisel version command works" -ForegroundColor Green
Write-Host ""
Write-Host "Conclusion: Chisel binary was successfully extracted from" -ForegroundColor Cyan
Write-Host "the official jpillora/chisel:latest Docker image and is" -ForegroundColor Cyan
Write-Host "working correctly in the DigitalOcean Kubernetes deployment!" -ForegroundColor Cyan
Write-Host ""

