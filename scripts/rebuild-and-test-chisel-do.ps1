# Rebuild API image with Chisel and test on DigitalOcean
# This script builds a new image with Chisel, pushes it, and tests it

param(
    [Parameter(Mandatory=$false)]
    [string]$Registry = "cloudtolocalllm",
    
    [Parameter(Mandatory=$false)]
    [string]$ClusterName = "cloudtolocalllm",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "cloudtolocalllm",
    
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = "chisel-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║   Rebuild API with Chisel & Test on DigitalOcean         ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

$REGISTRY_URL = "registry.digitalocean.com/$Registry"
$IMAGE_NAME = "${REGISTRY_URL}/api:$ImageTag"
$IMAGE_LATEST = "${REGISTRY_URL}/api:latest"

#######################################################################
# Prerequisites Check
#######################################################################

Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check Docker
try {
    docker ps | Out-Null
    Write-Host "✓ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker is not running" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again"
    exit 1
}

# Check doctl auth
try {
    doctl account get | Out-Null
    Write-Host "✓ doctl authenticated" -ForegroundColor Green
} catch {
    Write-Host "✗ doctl not authenticated" -ForegroundColor Red
    exit 1
}

#######################################################################
# Step 1: Build Docker Image with Chisel
#######################################################################

if (!$SkipBuild) {
    Write-Host ""
    Write-Host "Step 1: Building API image with Chisel..." -ForegroundColor Yellow
    Write-Host "This will extract Chisel binary from official jpillora/chisel:latest image" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Building: $IMAGE_NAME" -ForegroundColor Cyan
    docker build -f services/api-backend/Dockerfile.prod -t $IMAGE_NAME -t $IMAGE_LATEST .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "✗ Build failed!" -ForegroundColor Red
        Write-Host "Check the build output above for errors" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "✓ Image built successfully" -ForegroundColor Green
    
    # Test Chisel locally
    Write-Host ""
    Write-Host "Testing Chisel binary in image..." -ForegroundColor Cyan
    $testOutput = docker run --rm $IMAGE_NAME sh -c "chisel --version"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Chisel works in image!" -ForegroundColor Green
        Write-Host "Chisel version: $testOutput" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Chisel test failed!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "Skipping build (using existing image)" -ForegroundColor Yellow
}

#######################################################################
# Step 2: Push to DigitalOcean Registry
#######################################################################

Write-Host ""
Write-Host "Step 2: Pushing image to DigitalOcean registry..." -ForegroundColor Yellow

Write-Host "Logging in to registry..." -ForegroundColor Cyan
doctl registry login

Write-Host ""
Write-Host "Pushing $IMAGE_NAME..." -ForegroundColor Cyan
docker push $IMAGE_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to push image" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Image pushed to registry" -ForegroundColor Green

if ($IMAGE_NAME -ne $IMAGE_LATEST) {
    Write-Host ""
    Write-Host "Pushing as latest..." -ForegroundColor Cyan
    docker push $IMAGE_LATEST
    Write-Host "✓ Latest tag pushed" -ForegroundColor Green
}

#######################################################################
# Step 3: Connect to Cluster
#######################################################################

Write-Host ""
Write-Host "Step 3: Connecting to Kubernetes cluster..." -ForegroundColor Yellow

doctl kubernetes cluster kubeconfig save $ClusterName
Write-Host "✓ Connected to cluster" -ForegroundColor Green

#######################################################################
# Step 4: Update Deployment
#######################################################################

Write-Host ""
Write-Host "Step 4: Updating deployment to use new image..." -ForegroundColor Yellow

# Get current deployment
Write-Host "Current deployment image:" -ForegroundColor Cyan
$currentImage = kubectl get deployment api-backend -n $Namespace -o jsonpath='{.spec.template.spec.containers[0].image}'
Write-Host $currentImage

Write-Host ""
Write-Host "Updating to: $IMAGE_NAME" -ForegroundColor Cyan
kubectl set image deployment/api-backend -n $Namespace api-backend=$IMAGE_NAME

Write-Host "✓ Deployment updated" -ForegroundColor Green

Write-Host ""
Write-Host "Waiting for rollout..." -ForegroundColor Cyan
kubectl rollout status deployment/api-backend -n $Namespace --timeout=300s

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Rollout complete" -ForegroundColor Green
} else {
    Write-Host "⚠ Rollout may have issues, continuing with test..." -ForegroundColor Yellow
}

#######################################################################
# Step 5: Test Chisel in New Pod
#######################################################################

Write-Host ""
Write-Host "Step 5: Testing Chisel in new pod..." -ForegroundColor Yellow

# Wait a moment for new pod
Start-Sleep -Seconds 10

# Get new pod name
$newPod = kubectl get pods -n $Namespace -l app=api-backend -o jsonpath='{.items[0].metadata.name}'
Write-Host "Testing pod: $newPod" -ForegroundColor Cyan

Write-Host ""
Write-Host "Checking Chisel binary..." -ForegroundColor Cyan
$chiselCheck = kubectl exec -n $Namespace $newPod -- sh -c "ls -lh /usr/local/bin/chisel && file /usr/local/bin/chisel" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Chisel binary found!" -ForegroundColor Green
    Write-Host $chiselCheck
} else {
    Write-Host "✗ Chisel binary not found!" -ForegroundColor Red
    Write-Host $chiselCheck
    exit 1
}

Write-Host ""
Write-Host "Testing Chisel version..." -ForegroundColor Cyan
$chiselVersion = kubectl exec -n $Namespace $newPod -- chisel --version 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Chisel is working!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Chisel version:" -ForegroundColor Cyan
    Write-Host $chiselVersion
} else {
    Write-Host "✗ Chisel version check failed!" -ForegroundColor Red
    Write-Host $chiselVersion
    exit 1
}

#######################################################################
# Summary
#######################################################################

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Chisel Verification Complete                 ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "✓ Image built with Chisel binary extraction" -ForegroundColor Green
Write-Host "✓ Image pushed to DigitalOcean registry" -ForegroundColor Green
Write-Host "✓ Deployment updated with new image" -ForegroundColor Green
Write-Host "✓ Chisel binary verified in running pod" -ForegroundColor Green
Write-Host ""
Write-Host "Image: $IMAGE_NAME" -ForegroundColor Cyan
Write-Host "Pod: $newPod" -ForegroundColor Cyan
Write-Host ""
Write-Host "The Chisel binary extraction from jpillora/chisel:latest" -ForegroundColor Cyan
Write-Host "is working correctly on DigitalOcean Kubernetes!" -ForegroundColor Cyan
Write-Host ""

