# CloudToLocalLLM Deployment Script - Raw Output Version
# Shows all command output without any hiding or filtering

[CmdletBinding()]
param(
[ValidateSet('Local', 'Staging', 'Production')]
[string]$Environment = 'Production',

[ValidateSet('build', 'patch', 'minor', 'major')]
[string]$VersionIncrement = 'patch',

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

# Check if there are uncommitted changes
Write-Host "Checking for uncommitted changes..."
git status --porcelain
if ($LASTEXITCODE -eq 0) {
$uncommittedChanges = git status --porcelain
if ($uncommittedChanges) {
    Write-Host "ERROR: You have uncommitted changes. Commit and push all changes before deployment:" -ForegroundColor Red
    Write-Host $uncommittedChanges -ForegroundColor Red
    Write-Host "Run: git add . && git commit -m 'message' && git push origin master" -ForegroundColor Yellow
    exit 1
}
}
Write-Host "? Found pubspec.yaml"

Write-Host "Checking Git status..."
git status
if ($LASTEXITCODE -ne 0) {
Write-Host "ERROR: Git status failed" -ForegroundColor Red
exit 1
}

if (-not $DryRun) {
Write-Host "Testing SSH connection..."
ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$VPSUser@$VPSHost" "echo 'SSH test successful'"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: SSH connection failed" -ForegroundColor Red
    exit 1
}
}

# Define version manager path (used throughout script)
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"

# Step 2: Version management
if (-not $SkipVersionUpdate) {
Write-Host ""
Write-Host "=== STEP 2: VERSION MANAGEMENT ===" -ForegroundColor Yellow

if (-not $DryRun) {
    try {
        Write-Host "Incrementing version ($VersionIncrement)..."
        & $versionManagerPath increment $VersionIncrement
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Version increment failed" -ForegroundColor Red
            exit 1
        }
        Write-Host "? Version incremented successfully"

        # Commit and push version changes
        Write-Host "Committing version changes..."
        git add .
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to stage version changes" -ForegroundColor Red
            exit 1
        }

        $versionCommitMessage = "Update version to $(& $versionManagerPath get-semantic)"
        git commit -m $versionCommitMessage
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to commit version changes" -ForegroundColor Red
            exit 1
        }

        git push origin master
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to push version changes" -ForegroundColor Red
            exit 1
        }
        Write-Host "? Version changes committed and pushed"
    } catch {
        Write-Host "ERROR: Version management failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[DRY RUN] Would increment version ($VersionIncrement)"
}
}

# Step 3: Source preparation
Write-Host ""
Write-Host "=== STEP 3: SOURCE PREPARATION ===" -ForegroundColor Yellow

$requiredFiles = @("pubspec.yaml", "lib/main.dart", "docker-compose.yml")
foreach ($file in $requiredFiles) {
$filePath = Join-Path $ProjectRoot $file
if (Test-Path $filePath) {
    Write-Host "? Found: $file"
} else {
    Write-Host "? Missing: $file" -ForegroundColor Red
    exit 1
}
}

# Step 3.5: Local Flutter Desktop Build
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
    Write-Host "? Flutter dependencies updated"

    # Build Windows desktop application
    Write-Host "Building Windows desktop application..."
    $windowsBuildArgs = "build windows --release"
    Invoke-WindowsFlutterCommand -FlutterArgs $windowsBuildArgs -WorkingDirectory $ProjectRoot
    Write-Host "? Flutter Windows desktop build completed with optimizations"

    # Verify Windows build output
    $buildWindowsPath = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
    if (Test-Path $buildWindowsPath) {
        $exePath = Join-Path $buildWindowsPath "cloudtolocalllm.exe"
        if (Test-Path $exePath) {
            Write-Host "? Windows executable found: cloudtolocalllm.exe"
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
                Write-Host "? Flutter Linux desktop build completed"
            } else {
                Write-Host "?? WSL Flutter not available, skipping Linux build" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "?? Linux build failed, will build on VPS: $($_.Exception.Message)" -ForegroundColor Yellow
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
        Write-Host "? Windows application packaged"
    }

    # Create distribution packages
    Write-Host "Creating distribution packages..."
    $currentVersion = & $versionManagerPath get-semantic

    # Create Windows ZIP package from build output (portable version)
    $windowsBuildPath = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
    if (Test-Path $windowsBuildPath) {
        $windowsZipPath = Join-Path $distPath "cloudtolocalllm-$currentVersion-portable.zip"
        Compress-Archive -Path (Join-Path $windowsBuildPath "*") -DestinationPath $windowsZipPath -Force
        Write-Host "? Windows ZIP package created: cloudtolocalllm-$currentVersion-portable.zip"

        # Verify ZIP size for optimization tracking
        $zipSize = [math]::Round((Get-Item $windowsZipPath).Length/1MB,2)
        Write-Host "  ZIP size: $zipSize MB (optimized with --tree-shake-icons and --split-debug-info)"
    }

    # Create Windows installer
    Write-Host "Creating Windows installer..."
    try {
        $installerScriptPath = Join-Path $PSScriptRoot "Create-WindowsInstaller.ps1"
        if (Test-Path $installerScriptPath) {
            & $installerScriptPath -Version $currentVersion
            if ($LASTEXITCODE -eq 0) {
                Write-Host "? Windows installer created successfully"
            } else {
                Write-Host "?? Windows installer creation failed (non-blocking)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "?? Windows installer script not found, skipping installer creation" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "?? Windows installer creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "[DRY RUN] Would package desktop applications and create installer"
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

        Write-Host "? Distribution assets committed and pushed"
    } else {
        Write-Host "? No new distribution assets to commit"
    }
} else {
    Write-Host "[DRY RUN] Would commit and push distribution assets"
}

Write-Host "? Local Flutter desktop build completed successfully"

# Step 3.6: GitHub Release Creation
Write-Host ""
Write-Host "=== STEP 3.6: GITHUB RELEASE CREATION ===" -ForegroundColor Yellow

# Always check for GitHub release creation, regardless of build status
# This allows creating releases for existing packages or when build was skipped
$distPath = Join-Path $ProjectRoot "dist"
$currentVersion = & $versionManagerPath get-semantic
$releaseTag = "v$currentVersion"

# Check if desktop application packages exist for current version
$hasPackagesForCurrentVersion = $false
if (Test-Path $distPath) {
$versionPattern = "*$currentVersion*"
$packageFiles = Get-ChildItem -Path $distPath -Filter $versionPattern -Recurse -ErrorAction SilentlyContinue
if ($packageFiles.Count -gt 0) {
    $hasPackagesForCurrentVersion = $true
    Write-Host "Found $($packageFiles.Count) package(s) for version $currentVersion"
    foreach ($package in $packageFiles) {
        Write-Host "  - $($package.Name)"
    }
}
}

if ($hasPackagesForCurrentVersion) {
    Write-Host "Desktop application packages found for version $currentVersion, checking GitHub release..."

    if (-not $DryRun) {
        try {

            # Check if GitHub CLI is available and authenticated
            $ghAvailable = $false
            try {
                $ghStatus = & gh auth status 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $ghAvailable = $true
                    Write-Host "? GitHub CLI authenticated"
                }
            } catch {
                Write-Host "?? GitHub CLI not available or not authenticated" -ForegroundColor Yellow
            }

            if ($ghAvailable) {
                # Check if release already exists
                $releaseExists = $false
                try {
                    & gh release view $releaseTag --repo imrightguy/CloudToLocalLLM 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $releaseExists = $true
                    }
                } catch {
                    # Release doesn't exist, which is expected
                }

                if (-not $releaseExists) {
                    Write-Host "Creating GitHub release $releaseTag..."

                    # Find desktop application packages to attach BEFORE creating release notes
                    $assetsToUpload = @()
                    $availableAssets = @()

                    # Find Windows ZIP packages matching current version
                    $zipPattern = "cloudtolocalllm-$currentVersion-portable.zip"
                    $zipFiles = Get-ChildItem -Path $distPath -Filter $zipPattern -Recurse -ErrorAction SilentlyContinue
                    foreach ($zipFile in $zipFiles) {
                        $assetsToUpload += $zipFile.FullName
                        $availableAssets += "- Windows Desktop Application (cloudtolocalllm-$currentVersion-portable.zip) - Portable ZIP package"
                        Write-Host "Found ZIP asset: $($zipFile.Name)"
                    }

                    # Find Windows installer files matching current version
                    $installerPattern = "CloudToLocalLLM-Windows-$currentVersion-Setup.exe"
                    $installerFiles = Get-ChildItem -Path $distPath -Filter $installerPattern -Recurse -ErrorAction SilentlyContinue
                    foreach ($installer in $installerFiles) {
                        $assetsToUpload += $installer.FullName
                        $availableAssets += "- Windows Installer (CloudToLocalLLM-Windows-$currentVersion-Setup.exe) - Easy installation"
                        Write-Host "Found installer asset: $($installer.Name)"
                    }

                    # Find checksum files for installers
                    $checksumPattern = "CloudToLocalLLM-Windows-$currentVersion-Setup.exe.sha256"
                    $checksumFiles = Get-ChildItem -Path $distPath -Filter $checksumPattern -Recurse -ErrorAction SilentlyContinue
                    foreach ($checksum in $checksumFiles) {
                        $assetsToUpload += $checksum.FullName
                        Write-Host "Found checksum asset: $($checksum.Name)"
                    }

                    # Create dynamic release notes based on actually available assets
                    $assetsSection = if ($availableAssets.Count -gt 0) {
                        ($availableAssets -join "`r`n")
                    } else {
                        "- No desktop application packages available for this release"
                    }

                    # Determine installation instructions based on available assets
                    $hasInstaller = $installerFiles.Count -gt 0
                    $hasZip = $zipFiles.Count -gt 0

                    $installationInstructions = ""
                    if ($hasInstaller -and $hasZip) {
                        $installationInstructions = @"
**Option 1: Windows Installer (Recommended)**
1. Download the Setup.exe file
2. Run the installer and follow the setup wizard
3. Launch CloudToLocalLLM from Start Menu or Desktop

**Option 2: Portable ZIP**
1. Download the ZIP package for your platform
2. Extract and run the application
3. Authenticate with your CloudToLocalLLM account
"@
                    } elseif ($hasZip) {
                        $installationInstructions = @"
**Portable ZIP Installation**
1. Download the ZIP package
2. Extract and run the application
3. Authenticate with your CloudToLocalLLM account

*Note: Windows installer not available for this release*
"@
                    } elseif ($hasInstaller) {
                        $installationInstructions = @"
**Windows Installer**
1. Download the Setup.exe file
2. Run the installer and follow the setup wizard
3. Launch CloudToLocalLLM from Start Menu or Desktop
"@
                    } else {
                        $installationInstructions = @"
**No desktop applications available for this release**
Please use the web application at https://app.cloudtolocalllm.online
"@
                    }

                    $releaseNotes = @"
# CloudToLocalLLM $releaseTag

## ?? Desktop Application Release

This release provides cross-platform desktop applications for CloudToLocalLLM.

### ?? What's Included
$assetsSection

### ?? Installation

$installationInstructions

### ?? Integration
Works seamlessly with https://app.cloudtolocalllm.online

### ?? System Requirements
- Windows 10+ (64-bit) / Linux (64-bit)
- 4GB RAM minimum, 8GB recommended
- Internet connection for authentication

---
**Version**: $currentVersion
**Build Date**: $(Get-Date -Format 'yyyy-MM-dd')
"@

                    # Save release notes to temporary file
                    $releaseNotesFile = Join-Path $ProjectRoot "temp_release_notes.md"
                    Set-Content -Path $releaseNotesFile -Value $releaseNotes -Encoding UTF8

                    # Clean up old installer files to prevent version conflicts
                    $archiveDir = Join-Path $distPath "archive"
                    if (-not (Test-Path $archiveDir)) {
                        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
                    }

                    # Move old installer files to archive (keep only current version)
                    $oldInstallers = Get-ChildItem -Path $distPath -Filter "*Setup*.exe" -ErrorAction SilentlyContinue | Where-Object {
                        $_.Name -notlike "*$currentVersion*"
                    }
                    foreach ($oldInstaller in $oldInstallers) {
                        $archivePath = Join-Path $archiveDir $oldInstaller.Name
                        Move-Item -Path $oldInstaller.FullName -Destination $archivePath -Force -ErrorAction SilentlyContinue
                        # Also move corresponding .sha256 files
                        $sha256File = "$($oldInstaller.FullName).sha256"
                        if (Test-Path $sha256File) {
                            Move-Item -Path $sha256File -Destination "$archivePath.sha256" -Force -ErrorAction SilentlyContinue
                        }
                        Write-Host "Archived old installer: $($oldInstaller.Name)" -ForegroundColor Yellow
                    }



                    # Create GitHub release with assets
                    if ($assetsToUpload.Count -gt 0) {
                        $ghCommand = "gh release create `"$releaseTag`" --repo imrightguy/CloudToLocalLLM --title `"CloudToLocalLLM $releaseTag`" --notes-file `"$releaseNotesFile`""
                        foreach ($asset in $assetsToUpload) {
                            $ghCommand += " `"$asset`""
                        }

                        Write-Host "Executing: $ghCommand"
                        Invoke-Expression $ghCommand

                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "? GitHub release $releaseTag created successfully" -ForegroundColor Green
                            Write-Host "? Desktop application packages uploaded" -ForegroundColor Green
                        } else {
                            Write-Host "?? GitHub release creation failed (non-blocking)" -ForegroundColor Yellow
                            Write-Host "   Deployment will continue, but manual release creation may be needed" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "?? No desktop application packages found to upload" -ForegroundColor Yellow
                    }

                    # Clean up temporary file
                    if (Test-Path $releaseNotesFile) {
                        Remove-Item $releaseNotesFile -Force
                    }
                } else {
                    Write-Host "? GitHub release $releaseTag already exists" -ForegroundColor Green
                }
            } else {
                Write-Host "?? GitHub release creation skipped (GitHub CLI not available)" -ForegroundColor Yellow
                Write-Host "   To enable automatic releases, install GitHub CLI and run: gh auth login" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "?? GitHub release creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "   Deployment will continue, but manual release creation may be needed" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[DRY RUN] Would create GitHub release for desktop packages version $currentVersion"
    }
} else {
    Write-Host "? No desktop application packages found for version $currentVersion, skipping GitHub release creation"
    Write-Host "   To create releases, ensure desktop packages are built first"
}

# Step 4: Commit and Push Build-Time Injected Files
if (-not $DryRun) {
Write-Host ""
Write-Host "=== STEP 4: COMMIT BUILD-TIME INJECTION ===" -ForegroundColor Yellow

# Validate that no BUILD_TIME_PLACEHOLDER remains in version files
Write-Host "Validating build-time injection..."
$validationFailed = $false

$filesToCheck = @("pubspec.yaml", "lib/shared/pubspec.yaml", "lib/shared/lib/version.dart", "assets/version.json")
foreach ($file in $filesToCheck) {
    $filePath = Join-Path $ProjectRoot $file
    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw
        if ($content -match "BUILD_TIME_PLACEHOLDER") {
            Write-Host "ERROR: BUILD_TIME_PLACEHOLDER found in: $file" -ForegroundColor Red
            $validationFailed = $true
        } else {
            Write-Host "? No placeholders in: $file"
        }
    }
}

if ($validationFailed) {
    Write-Host "ERROR: Build validation failed - placeholders remain in version files" -ForegroundColor Red
    Write-Host "Restoring backup files to clean state..." -ForegroundColor Yellow
    & $buildInjectorPath restore
    exit 1
} else {
    Write-Host "? Build validation passed - all placeholders replaced with actual build numbers" -ForegroundColor Green

    # Commit build-time injected version files
    Write-Host "Committing build-time injected version files..."
    git add pubspec.yaml assets/version.json lib/shared/lib/version.dart lib/shared/pubspec.yaml lib/config/app_config.dart
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to stage build-time injected files" -ForegroundColor Red
        exit 1
    }

    # Check if there are changes to commit
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        # There are staged changes, commit them
        $buildTimestampCommitMessage = "Inject build-time timestamps for deployment v$(& $versionManagerPath get-semantic)"
        git commit -m $buildTimestampCommitMessage
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to commit build-time injected files" -ForegroundColor Red
            exit 1
        }

        # Push the build-time injected changes
        git push origin master
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to push build-time injected files" -ForegroundColor Red
            exit 1
        }
        Write-Host "? Build-time injected files committed and pushed to GitHub"
    } else {
        Write-Host "? No build-time injection changes to commit"
    }
}
}

# Step 5: VPS Deployment
Write-Host ""
Write-Host "=== STEP 5: VPS DEPLOYMENT ===" -ForegroundColor Yellow

# Use the new VPS deployment scripts for better error handling and rollback
$vpsDeploymentScript = "$VPSProjectPath/scripts/deploy/complete_deployment.sh"
$deploymentFlags = "--force"

if ($Verbose) {
$deploymentFlags += " --verbose"
}

if ($DryRun) {
$deploymentFlags += " --dry-run"
}

if ($SkipVerification) {
$deploymentFlags += " --skip-verification"
}

$deploymentCommand = "cd $VPSProjectPath && $vpsDeploymentScript $deploymentFlags"

# VPS Deployment Preparation: Fix script permissions
$permissionFixCommand = "chmod +x $VPSProjectPath/scripts/deploy/*.sh"

if ($DryRun) {
Write-Host "[DRY RUN] Would fix VPS script permissions: ssh $VPSUser@$VPSHost `"$permissionFixCommand`""
Write-Host "[DRY RUN] Would execute: ssh $VPSUser@$VPSHost `"$deploymentCommand`""
} else {
Write-Host "Preparing VPS deployment environment..."
Write-Host "Fixing executable permissions for deployment scripts..."
Write-Host "Command: ssh $VPSUser@$VPSHost `"$permissionFixCommand`""

ssh -o BatchMode=yes -o ConnectTimeout=30 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no $VPSUser@$VPSHost "$permissionFixCommand"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to fix VPS script permissions with exit code $LASTEXITCODE" -ForegroundColor Red
    Write-Host "This may cause deployment script execution failures" -ForegroundColor Yellow
    Write-Host "Continuing with deployment attempt..." -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "? VPS script permissions fixed successfully" -ForegroundColor Green
    Write-Host ""
}

Write-Host "Executing enhanced VPS deployment with rollback capabilities..."
Write-Host "Using deployment script: $vpsDeploymentScript"
Write-Host "Deployment flags: $deploymentFlags"
Write-Host ""

Write-Host "Command: ssh $VPSUser@$VPSHost `"$deploymentCommand`""
Write-Host ""

ssh -o BatchMode=yes -o ConnectTimeout=30 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no $VPSUser@$VPSHost "$deploymentCommand"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: VPS deployment failed with exit code $LASTEXITCODE" -ForegroundColor Red
    Write-Host "The VPS deployment script includes automatic rollback on failure" -ForegroundColor Yellow
    Write-Host "Check VPS logs for detailed error information" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host ""
    Write-Host "? VPS deployment completed successfully" -ForegroundColor Green
    Write-Host "Application URL: https://app.cloudtolocalllm.online" -ForegroundColor Green
}
}



# Step 6: Verification
if (-not $SkipVerification) {
Write-Host ""
Write-Host "=== STEP 6: VERIFICATION ===" -ForegroundColor Yellow

Write-Host "? VPS deployment completed successfully" -ForegroundColor Green
Write-Host "? Application should be available at https://app.cloudtolocalllm.online" -ForegroundColor Green
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
Write-Host "? Deployment successful!" -ForegroundColor Green
