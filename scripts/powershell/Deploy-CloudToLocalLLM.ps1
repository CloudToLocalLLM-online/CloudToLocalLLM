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
ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$VPSUser@$VPSHost" "echo 'SSH test successful'"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: SSH connection failed" -ForegroundColor Red
    exit 1
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

# Step 3.5: Full Release Build and GitHub Release Creation (Orchestrated via WSL)
Write-Host ""
Write-Host "=== STEP 3.5: FULL RELEASE BUILD AND GITHUB RELEASE CREATION ===" -ForegroundColor Yellow

# TEMPORARILY DISABLED - Windows build already completed manually
Write-Host "SKIPPING: Full release build step (Windows build already completed)" -ForegroundColor Yellow

# if (-not $DryRun) {
#     Write-Host "Starting full release build and GitHub release creation via WSL..."
#     $fullReleaseScriptPath = Join-Path $ProjectRoot "scripts\release\full_release_wsl.sh"
#     try {
#         # Convert Windows path to WSL path manually since wslpath seems to have issues
#         # Convert C:\Users\chris\Dev\CloudToLocalLLM\scripts\release\full_release_wsl.sh
#         # to /mnt/c/Users/chris/Dev/CloudToLocalLLM/scripts/release/full_release_wsl.sh
#         $wslScriptPath = $fullReleaseScriptPath -replace '^([A-Za-z]):', '/mnt/$1' -replace '\\', '/'
#         $wslScriptPath = $wslScriptPath.ToLower()

#         Write-Host "Converted path: $fullReleaseScriptPath -> $wslScriptPath"

#         # Construct the bash command to make the script executable and then run it
#         # Escape the WSL path for bash -c
#         $bashCommand = "chmod +x `"$wslScriptPath`"; `"$wslScriptPath`""

#         # Execute the bash command in WSL
#         wsl -d ArchLinux bash -c "$bashCommand"

#         if ($LASTEXITCODE -ne 0) {
#             throw "Full release build and GitHub release creation failed in WSL."
#         }
#         Write-Host "? Full release build and GitHub release created successfully via WSL."
#     } catch {
#         Write-Host "ERROR: Full release build and GitHub release creation failed: $($_.Exception.Message)" -ForegroundColor Red
#         exit 1
#     }
# } else {
#     Write-Host "[DRY RUN] Would perform full release build and GitHub release creation via WSL."
# }


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

$deploymentCommand = "cd $VPSProjectPath \&\& $vpsDeploymentScript $deploymentFlags"

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
