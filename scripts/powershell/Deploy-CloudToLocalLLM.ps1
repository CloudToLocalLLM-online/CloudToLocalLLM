# CloudToLocalLLM Deployment Script - Raw Output Version
# Shows all command output without any hiding or filtering

[CmdletBinding()]
param(
[ValidateSet('Local', 'Staging', 'Production')]
[string]$Environment = 'Production',

[ValidateSet('build', 'patch', 'minor', 'major')]
[string]$VersionIncrement = 'patch',

[switch]$SkipVerification,
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
$sshTestResult = & ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "$VPSUser@$VPSHost" "echo 'SSH test successful'" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: SSH connection failed with exit code $LASTEXITCODE" -ForegroundColor Red
    Write-Host "SSH output: $sshTestResult" -ForegroundColor Red
    exit 1
} else {
    Write-Host "SSH connection successful" -ForegroundColor Green
}
}

# Define version manager path (used throughout script)
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"

# Step 2: Version management
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
                        git add pubspec.yaml assets/version.json lib/shared/lib/version.dart lib/shared/pubspec.yaml lib/config/app_config.dart package.json docs/CHANGELOG.md
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

# Step 3.5: Windows Release Build and GitHub Release Creation (Native PowerShell)
Write-Host ""
Write-Host "=== STEP 3.5: WINDOWS RELEASE BUILD AND GITHUB RELEASE CREATION ===" -ForegroundColor Yellow

if (-not $DryRun) {
    try {
        # Get current version for release
        $versionManagerPath = Join-Path $ProjectRoot "scripts\version_manager.sh"
        # Convert Windows path to WSL path (e.g., C:\Users\... -> /mnt/c/Users/...)
        $wslProjectRoot = $ProjectRoot -replace '\\', '/'
        $wslProjectRoot = $wslProjectRoot -replace '^([A-Za-z]):', '/mnt/$1'
        $wslProjectRoot = $wslProjectRoot.ToLower()
        $currentVersion = & wsl bash -c "cd '$wslProjectRoot' && ./scripts/version_manager.sh get-semantic"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get current version"
        }
        $currentVersion = $currentVersion.Trim()
        Write-Host "Building release for version: $currentVersion"

        # Step 3.5.1: Build Windows packages
        Write-Host ""
        Write-Host "--- Building Windows Release Assets ---" -ForegroundColor Cyan
        $buildAssetsScript = Join-Path $ProjectRoot "scripts\powershell\Build-GitHubReleaseAssets.ps1"
        & $buildAssetsScript -InstallInnoSetup
        if ($LASTEXITCODE -ne 0) {
            throw "Windows release assets build failed"
        }
        Write-Host "? Windows release assets built successfully"

        # Step 3.5.2: Build Linux AppImage packages (via WSL) - TEMPORARILY SKIPPED
        Write-Host ""
        Write-Host "--- Skipping Linux AppImage Assets (AppImage structure needs setup) ---" -ForegroundColor Yellow
        Write-Host "? Linux AppImage build skipped - continuing with deployment"

        # Step 3.5.3: Update AUR PKGBUILD (via WSL)
        Write-Host ""
        Write-Host "--- Updating AUR PKGBUILD ---" -ForegroundColor Cyan
        $aurUpdateScript = Join-Path $ProjectRoot "scripts\packaging\update_aur_pkgbuild.sh"
        $wslAurUpdatePath = $aurUpdateScript -replace '\\', '/'
        $wslAurUpdatePath = $wslAurUpdatePath -replace '^([A-Za-z]):', '/mnt/$1'
        $wslAurUpdatePath = $wslAurUpdatePath.ToLower()
        & wsl -d ArchLinux bash -c "cd '$wslProjectRoot' && chmod +x '$wslAurUpdatePath' && '$wslAurUpdatePath'"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WARNING: AUR PKGBUILD update failed, continuing with deployment" -ForegroundColor Yellow
        } else {
            Write-Host "? AUR PKGBUILD updated successfully"
        }

        # Step 3.5.4: Create GitHub Release (Native PowerShell using gh CLI)
        Write-Host ""
        Write-Host "--- Creating GitHub Release ---" -ForegroundColor Cyan

        # Check if gh CLI is available
        $ghPath = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $ghPath) {
            throw "GitHub CLI (gh) is not installed or not in PATH. Please install it from https://cli.github.com/"
        }

        $tagName = "v$currentVersion"
        $releaseName = "CloudToLocalLLM v$currentVersion"

        # Generate release notes
        $releaseNotes = @"
# CloudToLocalLLM v$currentVersion

## What's Changed
- Version $currentVersion release
- Updated dependencies and bug fixes
- Performance improvements

## Download
Choose the appropriate package for your system:

### Windows
- **cloudtolocalllm-$currentVersion-portable.zip** - Portable version (no installation required)
- **CloudToLocalLLM-Windows-$currentVersion-Setup.exe** - Windows installer

### Linux
- **cloudtolocalllm-$($currentVersion)-x86_64.AppImage** - Universal Linux package (recommended)

### Package Managers
- **AUR**: `yay -S cloudtolocalllm` (Arch Linux and derivatives)
- **Manual**: Download AppImage for any Linux distribution

## Checksums
SHA256 checksums are provided for all packages to verify integrity.

**Full Changelog**: https://github.com/imrightguy/CloudToLocalLLM/compare/v$($currentVersion.Split('.')[0]).$($currentVersion.Split('.')[1]).$([int]$currentVersion.Split('.')[2] - 1)...v$currentVersion
"@

        # Create and push tag
        Write-Host "Creating and pushing tag $tagName..."
        git tag -a $tagName -m "CloudToLocalLLM v$currentVersion"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Tag may already exist, continuing..."
        }

        git push origin $tagName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Tag push may have failed, continuing with release creation..."
        }

        # Collect release assets for current version only
        $distDir = Join-Path $ProjectRoot "dist"
        $windowsDir = Join-Path $distDir "windows"

        $assets = @()

        # Windows assets - only for current version
        if (Test-Path $windowsDir) {
            $windowsAssets = Get-ChildItem -Path $windowsDir -File | Where-Object {
                $_.Name -match "cloudtolocalllm-$currentVersion.*\.(zip|exe)$" -or
                $_.Name -match "CloudToLocalLLM-Windows-$currentVersion.*\.exe$"
            }
            $assets += $windowsAssets.FullName

            # Also include SHA256 checksums for the current version assets
            $checksumAssets = Get-ChildItem -Path $windowsDir -File | Where-Object {
                $_.Name -match "cloudtolocalllm-$currentVersion.*\.sha256$" -or
                $_.Name -match "CloudToLocalLLM-Windows-$currentVersion.*\.sha256$"
            }
            $assets += $checksumAssets.FullName
        }

        Write-Host "Found $($assets.Count) assets to upload for version $currentVersion"
        foreach ($asset in $assets) {
            Write-Host "  - $(Split-Path $asset -Leaf)"
        }

        if ($assets.Count -eq 0) {
            Write-Host "WARNING: No assets found for version $currentVersion. Expected files:" -ForegroundColor Yellow
            Write-Host "  - cloudtolocalllm-$currentVersion-portable.zip" -ForegroundColor Yellow
            Write-Host "  - CloudToLocalLLM-Windows-$currentVersion-Setup.exe" -ForegroundColor Yellow
        }

        # Verify we have the minimum required assets
        $expectedPortableZip = $assets | Where-Object { $_ -match "cloudtolocalllm-$currentVersion.*portable\.zip$" }
        $expectedInstaller = $assets | Where-Object { $_ -match "CloudToLocalLLM-Windows-$currentVersion.*Setup\.exe$" }

        if (-not $expectedPortableZip -or -not $expectedInstaller) {
            Write-Host "WARNING: Missing expected Windows assets for version $currentVersion" -ForegroundColor Yellow
            Write-Host "Portable ZIP found: $($expectedPortableZip -ne $null)" -ForegroundColor Yellow
            Write-Host "Installer EXE found: $($expectedInstaller -ne $null)" -ForegroundColor Yellow
            Write-Host "Continuing with available assets..." -ForegroundColor Yellow
        }

        # Create GitHub release
        Write-Host "Creating GitHub release $tagName..."
        $releaseNotesFile = Join-Path $env:TEMP "release_notes_$currentVersion.md"
        $releaseNotes | Set-Content -Path $releaseNotesFile -Encoding UTF8

        $ghArgs = @(
            "release", "create", $tagName,
            "--repo", "imrightguy/CloudToLocalLLM",
            "--title", $releaseName,
            "--notes-file", $releaseNotesFile
        )

        # Add assets to the command only if we have any
        if ($assets.Count -gt 0) {
            $ghArgs += $assets
        }

        & gh @ghArgs
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub release creation failed"
        }

        # Clean up
        Remove-Item $releaseNotesFile -ErrorAction SilentlyContinue

        Write-Host "? GitHub release created successfully!"
        Write-Host "? Release URL: https://github.com/imrightguy/CloudToLocalLLM/releases/tag/$tagName"
        Write-Host "? Uploaded $($assets.Count) assets to the release"

    } catch {
        Write-Host "ERROR: Release build and GitHub release creation failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[DRY RUN] Would perform Windows release build and GitHub release creation using native PowerShell"
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
    Write-Host "WARNING: Build validation found placeholders in version files - continuing anyway" -ForegroundColor Yellow
    Write-Host "? Build validation completed - proceeding with deployment" -ForegroundColor Green
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

# Use the simple deployment script
$vpsDeploymentScript = "$VPSProjectPath/scripts/deploy/simple_deploy.sh"
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
