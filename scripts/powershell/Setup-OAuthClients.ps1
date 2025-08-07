# CloudToLocalLLM - OAuth Client Setup Script for Windows
# This PowerShell script creates the necessary OAuth 2.0 client IDs for Google Cloud Identity Platform

[CmdletBinding()]
param(
    [switch]$Interactive,
    [switch]$Force
)

# Configuration
$ProjectId = "cloudtolocalllm-468303"
$FirebaseProjectId = "cloudtolocalllm-auth"
$Region = "us-east4"
$ProjectRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent

Write-Host "=== CloudToLocalLLM OAuth Client Setup ===" -ForegroundColor Cyan
Write-Host "Project ID: $ProjectId" -ForegroundColor Gray
Write-Host "Firebase Project: $FirebaseProjectId" -ForegroundColor Gray
Write-Host ""

# Check prerequisites
function Test-Prerequisites {
    Write-Host "=== Checking Prerequisites ===" -ForegroundColor Yellow
    
    # Check if gcloud is installed
    try {
        $gcloudVersion = & gcloud version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Google Cloud CLI found" -ForegroundColor Green
        } else {
            throw "gcloud not found"
        }
    } catch {
        Write-Host "✗ Google Cloud CLI not found" -ForegroundColor Red
        Write-Host "Please install from: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
        return $false
    }

    # Check authentication
    try {
        $activeAccount = & gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
        if ($activeAccount) {
            Write-Host "✓ Authenticated as: $activeAccount" -ForegroundColor Green
        } else {
            throw "Not authenticated"
        }
    } catch {
        Write-Host "✗ Not authenticated with gcloud" -ForegroundColor Red
        Write-Host "Please run: gcloud auth login" -ForegroundColor Yellow
        return $false
    }
    
    # Set project
    & gcloud config set project $ProjectId 2>$null
    Write-Host "✓ Project set to: $ProjectId" -ForegroundColor Green
    
    return $true
}

# Enable required APIs
function Enable-RequiredAPIs {
    Write-Host "=== Enabling Required APIs ===" -ForegroundColor Yellow
    
    $apis = @(
        "identitytoolkit.googleapis.com",
        "firebase.googleapis.com",
        "iamcredentials.googleapis.com"
    )
    
    foreach ($api in $apis) {
        Write-Host "Enabling $api..." -ForegroundColor Gray
        & gcloud services enable $api --project=$ProjectId 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ $api enabled" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to enable $api" -ForegroundColor Red
        }
    }
}

# Get OAuth client IDs from user
function Get-OAuthClientIds {
    Write-Host "=== OAuth Client Configuration ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To fix the 401 invalid_client error, you need to create OAuth 2.0 Client IDs:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Open Google Cloud Console:" -ForegroundColor White
    Write-Host "   https://console.cloud.google.com/apis/credentials?project=$ProjectId" -ForegroundColor Blue
    Write-Host ""
    Write-Host "2. Click '+ CREATE CREDENTIALS' > 'OAuth client ID'" -ForegroundColor White
    Write-Host ""
    Write-Host "3. For Web Application:" -ForegroundColor White
    Write-Host "   - Application type: Web application" -ForegroundColor Gray
    Write-Host "   - Name: CloudToLocalLLM Web Client" -ForegroundColor Gray
    Write-Host "   - Authorized JavaScript origins:" -ForegroundColor Gray
    Write-Host "     * https://app.cloudtolocalllm.online" -ForegroundColor Gray
    Write-Host "     * https://cloudtolocalllm.online" -ForegroundColor Gray
    Write-Host "     * http://localhost:3000" -ForegroundColor Gray
    Write-Host "   - Authorized redirect URIs:" -ForegroundColor Gray
    Write-Host "     * https://app.cloudtolocalllm.online/callback" -ForegroundColor Gray
    Write-Host "     * http://localhost:3000/callback" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. For Desktop Application:" -ForegroundColor White
    Write-Host "   - Application type: Desktop application" -ForegroundColor Gray
    Write-Host "   - Name: CloudToLocalLLM Desktop Client" -ForegroundColor Gray
    Write-Host ""
    
    # Open browser to help user
    if ($Interactive) {
        $openBrowser = Read-Host "Open Google Cloud Console in browser? (y/n)"
        if ($openBrowser -eq 'y' -or $openBrowser -eq 'Y') {
            Start-Process "https://console.cloud.google.com/apis/credentials?project=$ProjectId"
            Write-Host "Browser opened. Please create the OAuth clients and return here." -ForegroundColor Yellow
            Read-Host "Press Enter when you have created both OAuth clients..."
        }
    }
    
    Write-Host ""
    $webClientId = Read-Host "Enter Web OAuth Client ID"
    $desktopClientId = Read-Host "Enter Desktop OAuth Client ID"
    
    # Validate client IDs
    if (-not $webClientId -or -not $webClientId.EndsWith(".apps.googleusercontent.com")) {
        Write-Host "✗ Invalid Web Client ID format" -ForegroundColor Red
        return $null
    }
    
    if (-not $desktopClientId -or -not $desktopClientId.EndsWith(".apps.googleusercontent.com")) {
        Write-Host "✗ Invalid Desktop Client ID format" -ForegroundColor Red
        return $null
    }
    
    return @{
        WebClientId = $webClientId
        DesktopClientId = $desktopClientId
    }
}

# Update configuration file
function Update-Configuration {
    param(
        [string]$WebClientId,
        [string]$DesktopClientId
    )
    
    Write-Host "=== Updating Configuration ===" -ForegroundColor Yellow
    
    $configFile = Join-Path $ProjectRoot "lib\config\app_config.dart"
    
    if (-not (Test-Path $configFile)) {
        Write-Host "✗ Configuration file not found: $configFile" -ForegroundColor Red
        return $false
    }
    
    try {
        $content = Get-Content $configFile -Raw
        
        # Replace the client IDs
        $content = $content -replace "googleClientIdWeb = '[^']*'", "googleClientIdWeb = '$WebClientId'"
        $content = $content -replace "googleClientIdDesktop = '[^']*'", "googleClientIdDesktop = '$DesktopClientId'"
        
        # Write back to file
        Set-Content -Path $configFile -Value $content -NoNewline
        
        Write-Host "✓ Configuration updated successfully!" -ForegroundColor Green
        Write-Host "  Web Client ID: $WebClientId" -ForegroundColor Gray
        Write-Host "  Desktop Client ID: $DesktopClientId" -ForegroundColor Gray
        
        return $true
    } catch {
        Write-Host "✗ Failed to update configuration: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Test OAuth configuration
function Test-OAuthConfiguration {
    Write-Host "=== Testing Configuration ===" -ForegroundColor Yellow
    
    $configFile = Join-Path $ProjectRoot "lib\config\app_config.dart"
    $content = Get-Content $configFile -Raw
    
    if ($content -match "googleClientIdWeb = '([^']+)'") {
        $webId = $matches[1]
        if ($webId -ne "YOUR_ACTUAL_CLIENT_ID_HERE.apps.googleusercontent.com") {
            Write-Host "✓ Web Client ID configured" -ForegroundColor Green
        } else {
            Write-Host "✗ Web Client ID still using placeholder" -ForegroundColor Red
            return $false
        }
    }
    
    if ($content -match "googleClientIdDesktop = '([^']+)'") {
        $desktopId = $matches[1]
        if ($desktopId -ne "YOUR_ACTUAL_CLIENT_ID_HERE.apps.googleusercontent.com") {
            Write-Host "✓ Desktop Client ID configured" -ForegroundColor Green
        } else {
            Write-Host "✗ Desktop Client ID still using placeholder" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

# Main execution
function Main {
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    Enable-RequiredAPIs
    
    $clientIds = Get-OAuthClientIds
    if (-not $clientIds) {
        Write-Host "✗ Failed to get valid OAuth client IDs" -ForegroundColor Red
        exit 1
    }
    
    if (-not (Update-Configuration -WebClientId $clientIds.WebClientId -DesktopClientId $clientIds.DesktopClientId)) {
        exit 1
    }
    
    if (Test-OAuthConfiguration) {
        Write-Host ""
        Write-Host "=== Setup Complete ===" -ForegroundColor Green
        Write-Host "✓ OAuth client IDs configured successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Rebuild your Flutter application:" -ForegroundColor White
        Write-Host "   flutter clean && flutter pub get" -ForegroundColor Gray
        Write-Host "2. Test the authentication flow" -ForegroundColor White
        Write-Host "3. If issues persist, verify OAuth consent screen is configured" -ForegroundColor White
        Write-Host ""
        Write-Host "The 401 invalid_client error should now be resolved!" -ForegroundColor Green
    } else {
        Write-Host "✗ Configuration test failed" -ForegroundColor Red
        exit 1
    }
}

# Run main function
Main
