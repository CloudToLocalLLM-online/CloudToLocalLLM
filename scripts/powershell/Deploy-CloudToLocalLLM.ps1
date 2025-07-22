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

# Step 3.5: Local Flutter Desktop Build
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "=== STEP 3.5: LOCAL FLUTTER DESKTOP BUILD ===" -ForegroundColor Yellow

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

    # Build Flutter desktop applications
    Write-Host "Building Flutter desktop applications..."
    if (-not $DryRun) {
        try {
            Invoke-WindowsFlutterCommand -FlutterArgs "pub get" -WorkingDirectory $ProjectRoot
            Write-Host "✓ Flutter dependencies updated"

            # Build Windows desktop application
            Write-Host "Building Windows desktop application..."
            Invoke-WindowsFlutterCommand -FlutterArgs "build windows --release" -WorkingDirectory $ProjectRoot
            Write-Host "✓ Flutter Windows desktop build completed"

            # Verify Windows build output
            $buildWindowsPath = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
            if (Test-Path $buildWindowsPath) {
                $exePath = Join-Path $buildWindowsPath "cloudtolocalllm.exe"
                if (Test-Path $exePath) {
                    Write-Host "✓ Windows executable found: cloudtolocalllm.exe"
                } else {
                    Write-Host "ERROR: Windows executable not found" -ForegroundColor Red
                    exit 1
                }
            } else {
                Write-Host "ERROR: Windows build directory not found" -ForegroundColor Red
                exit 1
            }

            # Build Linux desktop application via WSL (if available)
            Write-Host "Building Linux desktop application via WSL..."
            try {
                if (Test-WSLFlutterInstallation) {
                    Invoke-WSLFlutterCommand -FlutterArgs "build linux --release" -WorkingDirectory $ProjectRoot
                    Write-Host "✓ Flutter Linux desktop build completed"
                } else {
                    Write-Host "⚠️ WSL Flutter not available, skipping Linux build" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "⚠️ Linux build failed, will build on VPS: $($_.Exception.Message)" -ForegroundColor Yellow
            }

        } catch {
            Write-Host "ERROR: Flutter desktop build failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[DRY RUN] Would build Flutter desktop applications"
    }

    # Package desktop applications for distribution
    Write-Host "Packaging desktop applications for distribution..."
    if (-not $DryRun) {
        # Create distribution directory
        $distPath = Join-Path $ProjectRoot "dist"
        if (-not (Test-Path $distPath)) {
            New-Item -ItemType Directory -Path $distPath -Force | Out-Null
        }

        # Package Windows application
        if (Test-Path (Join-Path $ProjectRoot "build\windows\x64\runner\Release\cloudtolocalllm.exe")) {
            Write-Host "Packaging Windows application..."
            $windowsDistPath = Join-Path $distPath "windows"
            if (-not (Test-Path $windowsDistPath)) {
                New-Item -ItemType Directory -Path $windowsDistPath -Force | Out-Null
            }

            # Copy Windows executable and dependencies
            Copy-Item -Path (Join-Path $ProjectRoot "build\windows\x64\runner\Release\*") -Destination $windowsDistPath -Recurse -Force
            Write-Host "✓ Windows application packaged"
        }

        # Create distribution packages
        Write-Host "Creating distribution packages..."
        $currentVersion = & $versionManagerPath get-semantic

        # Create Windows ZIP package
        if (Test-Path (Join-Path $distPath "windows")) {
            $windowsZipPath = Join-Path $distPath "cloudtolocalllm-windows-v$currentVersion.zip"
            Compress-Archive -Path (Join-Path $distPath "windows\*") -DestinationPath $windowsZipPath -Force
            Write-Host "✓ Windows ZIP package created: cloudtolocalllm-windows-v$currentVersion.zip"
        }
    } else {
        Write-Host "[DRY RUN] Would package desktop applications"
    }

    # Commit and push distribution assets
    Write-Host "Committing distribution assets..."
    if (-not $DryRun) {
        git add dist/
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to stage distribution assets" -ForegroundColor Red
            exit 1
        }

        # Check if there are changes to commit
        git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) {
            # There are staged changes, commit them
            $buildCommitMessage = "Build Flutter desktop applications for deployment v$(& $versionManagerPath get-semantic)"
            git commit -m $buildCommitMessage
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Failed to commit distribution assets" -ForegroundColor Red
                exit 1
            }

            git push origin master
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Failed to push distribution assets" -ForegroundColor Red
                exit 1
            }

            Write-Host "✓ Distribution assets committed and pushed"
        } else {
            Write-Host "✓ No new distribution assets to commit"
        }
    } else {
        Write-Host "[DRY RUN] Would commit and push distribution assets"
    }

    Write-Host "✓ Local Flutter desktop build completed successfully"
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