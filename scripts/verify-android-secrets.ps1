# Verify Android Signing Secrets in GitHub
# This script verifies that all required Android signing secrets are configured
# in the GitHub repository and accessible to workflows.
#
# Usage: .\scripts\verify-android-secrets.ps1

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Android Signing Secrets Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check if a command exists
function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Check GitHub CLI
if (-not (Test-Command "gh")) {
    Write-Host "ERROR: GitHub CLI (gh) not found." -ForegroundColor Red
    Write-Host "Install with: choco install gh" -ForegroundColor Yellow
    exit 1
}

# Check GitHub authentication
$ghAuthStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: GitHub CLI not authenticated." -ForegroundColor Red
    Write-Host "Authenticate with: gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ GitHub CLI authenticated" -ForegroundColor Green
Write-Host ""

# Get repository information
$repoInfo = gh repo view --json nameWithOwner -q .nameWithOwner 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get repository information" -ForegroundColor Red
    exit 1
}

Write-Host "Repository: $repoInfo" -ForegroundColor Cyan
Write-Host ""

# List all secrets
Write-Host "Fetching repository secrets..." -ForegroundColor Yellow
$secretsList = gh secret list 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to list secrets" -ForegroundColor Red
    Write-Host $secretsList -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All configured secrets:" -ForegroundColor Cyan
Write-Host $secretsList
Write-Host ""

# Check required Android secrets
$requiredSecrets = @(
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_PASSWORD",
    "ANDROID_KEY_ALIAS"
)

Write-Host "Verifying required Android signing secrets..." -ForegroundColor Yellow
Write-Host ""

$allSecretsPresent = $true
$secretsStatus = @{}

foreach ($secretName in $requiredSecrets) {
    if ($secretsList -match $secretName) {
        Write-Host "  ✓ $secretName" -ForegroundColor Green
        $secretsStatus[$secretName] = $true
        
        # Extract timestamp if available
        $timestampPattern = "$secretName\s+(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)"
        if ($secretsList -match $timestampPattern) {
            if ($matches -and $matches.Count -gt 1) {
                $timestamp = $matches[1]
                Write-Host "    Updated: $timestamp" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "  ✗ $secretName - MISSING" -ForegroundColor Red
        $secretsStatus[$secretName] = $false
        $allSecretsPresent = $false
    }
}

Write-Host ""

# Check workflow file references
Write-Host "Verifying workflow file references..." -ForegroundColor Yellow
Write-Host ""

$workflowFile = ".github/workflows/build-release.yml"

if (-not (Test-Path $workflowFile)) {
    Write-Host "  ⚠ Workflow file not found: $workflowFile" -ForegroundColor Yellow
} else {
    $workflowContent = Get-Content $workflowFile -Raw
    
    $workflowReferencesCorrect = $true
    
    foreach ($secretName in $requiredSecrets) {
        $secretRef = "secrets.$secretName"
        
        if ($workflowContent -match [regex]::Escape($secretRef)) {
            Write-Host "  ✓ $secretRef referenced in workflow" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $secretRef NOT referenced in workflow" -ForegroundColor Red
            $workflowReferencesCorrect = $false
        }
    }
    
    Write-Host ""
    
    if ($workflowReferencesCorrect) {
        Write-Host "  ✓ All secrets are referenced in workflow" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Some secrets are not referenced in workflow" -ForegroundColor Yellow
    }
}

Write-Host ""

# Check local keystore file
Write-Host "Verifying local keystore file..." -ForegroundColor Yellow
Write-Host ""

$keystorePath = "android/release-keystore.jks"

if (Test-Path $keystorePath) {
    $keystoreInfo = Get-Item $keystorePath
    Write-Host "  ✓ Keystore file exists" -ForegroundColor Green
    Write-Host "    Location: $keystorePath" -ForegroundColor DarkGray
    Write-Host "    Size: $($keystoreInfo.Length) bytes" -ForegroundColor DarkGray
    Write-Host "    Modified: $($keystoreInfo.LastWriteTime)" -ForegroundColor DarkGray
    
    # Verify keystore is in .gitignore
    if (Test-Path ".gitignore") {
        $gitignoreContent = Get-Content ".gitignore" -Raw
        if ($gitignoreContent -match "release-keystore\.jks" -or $gitignoreContent -match "\*\.jks") {
            Write-Host "  ✓ Keystore is in .gitignore" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Keystore may not be in .gitignore" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  ⚠ Keystore file not found locally: $keystorePath" -ForegroundColor Yellow
    Write-Host "    This is OK if you only need CI/CD builds" -ForegroundColor DarkGray
}

Write-Host ""

# Check key.properties template
Write-Host "Verifying key.properties template..." -ForegroundColor Yellow
Write-Host ""

$keyPropertiesTemplate = "android/key.properties.template"

if (Test-Path $keyPropertiesTemplate) {
    Write-Host "  ✓ key.properties.template exists" -ForegroundColor Green
} else {
    Write-Host "  ⚠ key.properties.template not found" -ForegroundColor Yellow
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($allSecretsPresent) {
    Write-Host "✓ All required secrets are configured" -ForegroundColor Green
    Write-Host ""
    Write-Host "Status: READY FOR CI/CD BUILDS" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Test Android build locally (optional):" -ForegroundColor White
    Write-Host "     flutter build apk --release" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  2. Test Android build in CI/CD:" -ForegroundColor White
    Write-Host "     git tag v4.5.0-android-test" -ForegroundColor DarkGray
    Write-Host "     git push origin v4.5.0-android-test" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  3. Or manually trigger workflow:" -ForegroundColor White
    Write-Host "     GitHub Actions → Build Desktop Apps → Run workflow" -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Host "✗ Some required secrets are missing" -ForegroundColor Red
    Write-Host ""
    Write-Host "Status: NOT READY" -ForegroundColor Red
    Write-Host ""
    Write-Host "Action required:" -ForegroundColor Yellow
    Write-Host "  Run: .\scripts\setup-android-signing.ps1" -ForegroundColor White
    Write-Host ""
}

# Additional checks
Write-Host "Additional Information:" -ForegroundColor Cyan
Write-Host ""

# Check if Android platform is enabled in workflow
if (Test-Path $workflowFile) {
    $workflowContent = Get-Content $workflowFile -Raw
    
    if ($workflowContent -match "platform:\s*android") {
        Write-Host "  ✓ Android platform is enabled in workflow matrix" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Android platform may not be enabled in workflow matrix" -ForegroundColor Yellow
        Write-Host "    Check .github/workflows/build-release.yml" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "For more information, see: docs/ANDROID_BUILD_GUIDE.md" -ForegroundColor Cyan
Write-Host ""
