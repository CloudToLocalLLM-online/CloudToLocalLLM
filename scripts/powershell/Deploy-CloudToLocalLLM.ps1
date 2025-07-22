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

# Step 3.5: Local Flutter Web Build
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "=== STEP 3.5: LOCAL FLUTTER WEB BUILD ===" -ForegroundColor Yellow

    # Import build utilities
    $buildUtilsPath = Join-Path $PSScriptRoot "BuildEnvironmentUtilities.ps1"
    if (Test-Path $buildUtilsPath) {
        . $buildUtilsPath
    } else {
        Write-Host "ERROR: BuildEnvironmentUtilities.ps1 not found" -ForegroundColor Red
        exit 1
    }

    # Check if Flutter is available on Windows
    Write-Host "Checking Flutter installation..."
    if (-not (Test-WindowsFlutterInstallation)) {
        Write-Host "ERROR: Flutter not available on Windows" -ForegroundColor Red
        Write-Host "Please install Flutter or use WSL for builds" -ForegroundColor Red
        exit 1
    }

    # Build-time version injection
    Write-Host "Injecting build-time timestamp..."
    $buildInjectorPath = Join-Path $PSScriptRoot "build_time_version_injector.ps1"

    if (-not $DryRun) {
        & $buildInjectorPath inject
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Build-time version injection failed" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[DRY RUN] Would inject build-time timestamp"
    }

    # Build Flutter web application
    Write-Host "Building Flutter web application..."
    if (-not $DryRun) {
        try {
            Invoke-WindowsFlutterCommand -FlutterArgs "pub get" -WorkingDirectory $ProjectRoot
            Write-Host "✓ Flutter dependencies updated"

            Invoke-WindowsFlutterCommand -FlutterArgs "build web --release --no-tree-shake-icons" -WorkingDirectory $ProjectRoot
            Write-Host "✓ Flutter web build completed"

            # Verify build output
            $buildWebPath = Join-Path $ProjectRoot "build\web"
            if (Test-Path $buildWebPath) {
                $indexPath = Join-Path $buildWebPath "index.html"
                if (Test-Path $indexPath) {
                    Write-Host "✓ Build output verified: index.html found"
                } else {
                    Write-Host "ERROR: index.html not found in build output" -ForegroundColor Red
                    exit 1
                }
            } else {
                Write-Host "ERROR: Build directory not found" -ForegroundColor Red
                exit 1
            }
        } catch {
            Write-Host "ERROR: Flutter build failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[DRY RUN] Would build Flutter web application"
    }

    # Commit and push built assets
    Write-Host "Committing built assets..."
    if (-not $DryRun) {
        git add build/web/
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to stage build assets" -ForegroundColor Red
            exit 1
        }

        # Check if there are changes to commit
        git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) {
            # There are staged changes, commit them
            $buildCommitMessage = "Build Flutter web assets for deployment v$(& $versionManagerPath get-semantic)"
            git commit -m $buildCommitMessage
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Failed to commit build assets" -ForegroundColor Red
                exit 1
            }

            git push origin master
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Failed to push build assets" -ForegroundColor Red
                exit 1
            }

            Write-Host "✓ Built assets committed and pushed"
        } else {
            Write-Host "✓ No new build assets to commit"
        }
    } else {
        Write-Host "[DRY RUN] Would commit and push built assets"
    }

    Write-Host "✓ Local Flutter web build completed successfully"
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

# Step 5: Cleanup and Verification
if (-not $SkipBuild -and -not $DryRun) {
    Write-Host ""
    Write-Host "=== STEP 5: BUILD CLEANUP ===" -ForegroundColor Yellow

    # Restore version files to remove build-time timestamps
    Write-Host "Restoring version files..."
    & $buildInjectorPath restore
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Failed to restore version files" -ForegroundColor Yellow
    } else {
        Write-Host "✓ Version files restored"
    }
}

# Step 6: Verification
if (-not $SkipVerification) {
    Write-Host ""
    Write-Host "=== STEP 6: VERIFICATION ===" -ForegroundColor Yellow
    
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