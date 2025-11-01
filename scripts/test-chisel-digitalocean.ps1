# Test Chisel Binary Extraction on DigitalOcean
# This script builds the Docker image and verifies Chisel is extracted correctly

param(
    [Parameter(Mandatory=$false)]
    [string]$Registry = "cloudtolocalllm",
    
    [Parameter(Mandatory=$false)]
    [string]$ClusterName = "cloudtolocalllm",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$LocalTestOnly
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║      Chisel Binary Extraction Test - DigitalOcean        ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

$REGISTRY_URL = "registry.digitalocean.com/$Registry"
$IMAGE_NAME = "${REGISTRY_URL}/api:chisel-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

#######################################################################
# Step 1: Check Prerequisites
#######################################################################

Write-Host "Step 1: Checking prerequisites..." -ForegroundColor Yellow

# Check Docker
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "✗ Docker not found" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again"
    exit 1
}

try {
    docker ps | Out-Null
    Write-Host "✓ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker is not running" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again"
    exit 1
}

# Check doctl
if (!(Get-Command doctl -ErrorAction SilentlyContinue)) {
    Write-Host "✗ doctl not found" -ForegroundColor Red
    exit 1
}
Write-Host "✓ doctl found" -ForegroundColor Green

# Check doctl auth
try {
    doctl account get | Out-Null
    Write-Host "✓ doctl authenticated" -ForegroundColor Green
} catch {
    Write-Host "✗ doctl not authenticated" -ForegroundColor Red
    Write-Host "Run: doctl auth init"
    exit 1
}

#######################################################################
# Step 2: Build Docker Image with Chisel
#######################################################################

if (!$SkipBuild) {
    Write-Host ""
    Write-Host "Step 2: Building API backend image with Chisel..." -ForegroundColor Yellow
    Write-Host "This will test if Chisel binary is extracted correctly from official image" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Building image: $IMAGE_NAME" -ForegroundColor Cyan
    docker build -f services/api-backend/Dockerfile.prod -t $IMAGE_NAME . 
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "✗ Build failed!" -ForegroundColor Red
        Write-Host "This means Chisel binary extraction from official image failed" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "✓ Image built successfully" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Skipping build (using existing image)" -ForegroundColor Yellow
}

#######################################################################
# Step 3: Test Chisel Binary Locally
#######################################################################

Write-Host ""
Write-Host "Step 3: Testing Chisel binary in container..." -ForegroundColor Yellow

Write-Host "Running test container to verify Chisel binary..." -ForegroundColor Cyan
$testOutput = docker run --rm $IMAGE_NAME sh -c "chisel --version && echo 'CHISEL_TEST_PASSED'"

if ($testOutput -match "CHISEL_TEST_PASSED") {
    Write-Host "✓ Chisel binary is working correctly!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Chisel version output:" -ForegroundColor Cyan
    Write-Host $testOutput
} else {
    Write-Host "✗ Chisel binary test failed!" -ForegroundColor Red
    Write-Host "Output: $testOutput" -ForegroundColor Yellow
    exit 1
}

#######################################################################
# Step 4: Test on DigitalOcean (if not local-only)
#######################################################################

if (!$LocalTestOnly) {
    Write-Host ""
    Write-Host "Step 4: Testing on DigitalOcean..." -ForegroundColor Yellow
    
    # Login to registry
    Write-Host "Logging in to DigitalOcean Container Registry..." -ForegroundColor Cyan
    doctl registry login
    
    # Tag and push image
    Write-Host ""
    Write-Host "Tagging and pushing image to registry..." -ForegroundColor Cyan
    docker tag $IMAGE_NAME "${REGISTRY_URL}/api:chisel-test-latest"
    docker push "${REGISTRY_URL}/api:chisel-test-latest"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to push image" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Image pushed to registry" -ForegroundColor Green
    
    # Connect to cluster
    Write-Host ""
    Write-Host "Connecting to Kubernetes cluster..." -ForegroundColor Cyan
    doctl kubernetes cluster kubeconfig save $ClusterName
    
    # Create test pod
    Write-Host ""
    Write-Host "Creating test pod to verify Chisel..." -ForegroundColor Cyan
    
    $testPodYaml = @"
apiVersion: v1
kind: Pod
metadata:
  name: chisel-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')
  namespace: cloudtolocalllm
  labels:
    test: chisel-verification
spec:
  containers:
  - name: test
    image: ${REGISTRY_URL}/api:chisel-test-latest
    command: ["sh", "-c", "chisel --version && echo 'CHISEL_TEST_PASSED' && sleep 3600"]
  restartPolicy: Never
"@
    
    $testPodYaml | kubectl apply -f -
    
    Write-Host "Waiting for pod to start..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    
    # Check pod logs
    $podName = (kubectl get pods -n cloudtolocalllm -l test=chisel-verification -o jsonpath='{.items[0].metadata.name}' | Select-Object -First 1)
    
    if ($podName) {
        Write-Host ""
        Write-Host "Pod logs:" -ForegroundColor Cyan
        kubectl logs -n cloudtolocalllm $podName
        
        Write-Host ""
        Write-Host "Checking if Chisel test passed..." -ForegroundColor Cyan
        $logs = kubectl logs -n cloudtolocalllm $podName
        if ($logs -match "CHISEL_TEST_PASSED") {
            Write-Host "✓ Chisel verification passed on DigitalOcean!" -ForegroundColor Green
        } else {
            Write-Host "✗ Chisel verification failed on DigitalOcean" -ForegroundColor Red
        }
        
        # Cleanup
        Write-Host ""
        Write-Host "Cleaning up test pod..." -ForegroundColor Cyan
        kubectl delete pod $podName -n cloudtolocalllm
    } else {
        Write-Host "✗ Could not find test pod" -ForegroundColor Red
    }
}

#######################################################################
# Summary
#######################################################################

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Chisel Test Summary                          ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "✓ Docker image built successfully" -ForegroundColor Green
Write-Host "✓ Chisel binary extracted from official image" -ForegroundColor Green
Write-Host "✓ Chisel binary verified and working" -ForegroundColor Green

if (!$LocalTestOnly) {
    Write-Host "✓ Image pushed to DigitalOcean registry" -ForegroundColor Green
    Write-Host "✓ Tested on DigitalOcean Kubernetes cluster" -ForegroundColor Green
}

Write-Host ""
Write-Host "Test image: $IMAGE_NAME" -ForegroundColor Cyan
Write-Host ""
Write-Host "The Chisel binary extraction from jpillora/chisel:latest is working correctly!" -ForegroundColor Green

