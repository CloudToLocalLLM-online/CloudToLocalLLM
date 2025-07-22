# CloudToLocalLLM Deployment Script - Raw Output Version
# Shows all command output without any hiding or filtering

[CmdletBinding()]
param(
    [ValidateSet('Local', 'Staging', 'Production')]
    [string]$Environment = 'Production',
    
    [ValidateSet('build', 'patch', 'minor', 'major')]
    [string]$VersionIncrement = 'build',
    
    [switch]$SkipBuild,
    [switch]$SkipVerification,
    [switch]$SkipVersionUpdate,
    [switch]$Force,
    [switch]$DryRun
)

# Configuration
$VPSHost = "cloudtolocalllm.online"
$VPSUser = "cloudllm"
$VPSProjectPath = "/opt/cloudtolocalllm"
$ProjectRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent

Write-Host "=== CloudToLocalLLM Deployment ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment"
Write-Host "Version Increment: $VersionIncrement"
Write-Host "VPS: $VPSUser@$VPSHost"
Write-Host "Project Root: $ProjectRoot"
Write-Host "Dry Run: $DryRun"
Write-Host ""

# Step 1: Check prerequisites
Write-Host "=== STEP 1: PREREQUISITES ===" -ForegroundColor Yellow

if (-not (Test-Path (Join-Path $ProjectRoot "pubspec.yaml"))) {
    Write-Host "ERROR: pubspec.yaml not found" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Found pubspec.yaml"

Write-Host "Checking Git status..."
git status
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Git status failed" -ForegroundColor Red
    exit 1
}

if (-not $DryRun) {
    Write-Host "Testing SSH connection..."
    ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPSUser@$VPSHost" "echo 'SSH test successful'"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: SSH connection failed" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Version management
if (-not $SkipVersionUpdate) {
    Write-Host ""
    Write-Host "=== STEP 2: VERSION MANAGEMENT ===" -ForegroundColor Yellow
    
    $versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
    
    Write-Host "Getting current version..."
    & $versionManagerPath get-semantic
    
    if (-not $DryRun) {
        Write-Host "Incrementing version ($VersionIncrement)..."
        & $versionManagerPath increment $VersionIncrement
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Version increment failed" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "New version:"
        & $versionManagerPath get-semantic
    }
}

# Step 3: Source preparation
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "=== STEP 3: SOURCE PREPARATION ===" -ForegroundColor Yellow
    
    $requiredFiles = @("pubspec.yaml", "lib/main.dart", "docker-compose.yml", "scripts/deploy/update_and_deploy.sh")
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $ProjectRoot $file
        if (Test-Path $filePath) {
            Write-Host "✓ Found: $file"
        } else {
            Write-Host "✗ Missing: $file" -ForegroundColor Red
            exit 1
        }
    }
}

# Step 4: VPS Deployment
Write-Host ""
Write-Host "=== STEP 4: VPS DEPLOYMENT ===" -ForegroundColor Yellow

$deploymentCommand = "cd $VPSProjectPath && ./scripts/deploy/update_and_deploy.sh --force --verbose"

if ($DryRun) {
    Write-Host "[DRY RUN] Would execute: ssh $VPSUser@$VPSHost `"$deploymentCommand`""
} else {
    Write-Host "Ensuring deployment script has execute permissions..."
    ssh $VPSUser@$VPSHost "chmod +x $VPSProjectPath/scripts/deploy/update_and_deploy.sh"
    
    Write-Host "Executing deployment on VPS..."
    Write-Host "Command: ssh $VPSUser@$VPSHost `"$deploymentCommand`""
    Write-Host ""
    
    ssh $VPSUser@$VPSHost "$deploymentCommand"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: VPS deployment failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
}

# Step 5: Verification
if (-not $SkipVerification) {
    Write-Host ""
    Write-Host "=== STEP 5: VERIFICATION ===" -ForegroundColor Yellow
    
    $verificationCommand = "cd $VPSProjectPath && ./scripts/deploy/verify_deployment.sh"
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Would execute: ssh $VPSUser@$VPSHost `"$verificationCommand`""
    } else {
        Write-Host "Ensuring verification script has execute permissions..."
        ssh $VPSUser@$VPSHost "chmod +x $VPSProjectPath/scripts/deploy/verify_deployment.sh"
        
        Write-Host "Running verification..."
        Write-Host "Command: ssh $VPSUser@$VPSHost `"$verificationCommand`""
        Write-Host ""
        
        ssh $VPSUser@$VPSHost "$verificationCommand"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "ERROR: Verification failed with exit code $LASTEXITCODE" -ForegroundColor Red
            exit 1
        }
    }
}

# Final report
Write-Host ""
Write-Host "=== DEPLOYMENT COMPLETE ===" -ForegroundColor Green
Write-Host "Environment: $Environment"
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
Write-Host ""
Write-Host "Access URLs:"
Write-Host "  - HTTP Homepage: http://cloudtolocalllm.online"
Write-Host "  - HTTP Web App: http://app.cloudtolocalllm.online"
Write-Host "  - HTTPS Homepage: https://cloudtolocalllm.online"
Write-Host "  - HTTPS Web App: https://app.cloudtolocalllm.online"
Write-Host ""
Write-Host "✅ Deployment successful!" -ForegroundColor Green