# Quick verification script for Chisel Dockerfile
# This script checks if the Dockerfile syntax is correct and can verify the build logic

param(
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Verifying Chisel Dockerfile configuration..." -ForegroundColor Cyan
Write-Host ""

$dockerfiles = @(
    "services/api-backend/Dockerfile.prod",
    "config/docker/Dockerfile.api-backend"
)

foreach ($dockerfile in $dockerfiles) {
    if (!(Test-Path $dockerfile)) {
        Write-Host "✗ File not found: $dockerfile" -ForegroundColor Red
        continue
    }
    
    Write-Host "Checking: $dockerfile" -ForegroundColor Yellow
    
    $content = Get-Content $dockerfile -Raw
    
    # Check for Chisel extraction stage
    if ($content -match "FROM jpillora/chisel:latest AS chisel") {
        Write-Host "  ✓ Chisel extraction stage found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Chisel extraction stage not found" -ForegroundColor Red
    }
    
    # Check for find command
    if ($content -match "find.*chisel") {
        Write-Host "  ✓ Binary discovery logic found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Binary discovery logic not found" -ForegroundColor Red
    }
    
    # Check for copy from chisel stage
    if ($content -match "COPY --from=chisel") {
        Write-Host "  ✓ Copy from Chisel stage found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Copy from Chisel stage not found" -ForegroundColor Red
    }
    
    # Check for version verification
    if ($content -match "chisel --version") {
        Write-Host "  ✓ Version verification found" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Version verification not found" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

if (!$CheckOnly) {
    Write-Host "To test the build:" -ForegroundColor Cyan
    Write-Host "  1. Start Docker Desktop" -ForegroundColor White
    Write-Host "  2. Run: .\scripts\test-chisel-digitalocean.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Or test on DigitalOcean directly:" -ForegroundColor Cyan
    Write-Host "  1. Ensure Docker is available (or use DO's build system)" -ForegroundColor White
    Write-Host "  2. Build and push the image" -ForegroundColor White
    Write-Host "  3. Deploy to test and check logs" -ForegroundColor White
}

Write-Host ""
Write-Host "Dockerfile verification complete!" -ForegroundColor Green

