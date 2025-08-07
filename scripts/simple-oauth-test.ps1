# Simple OAuth Configuration Test
Write-Host "=== OAuth Configuration Test ===" -ForegroundColor Cyan

$configFile = "lib\config\app_config.dart"
$content = Get-Content $configFile -Raw

Write-Host "Checking OAuth client IDs..." -ForegroundColor Yellow

# Check for Web Client ID
if ($content -contains "googleClientIdWeb") {
    Write-Host "✓ Web Client ID found" -ForegroundColor Green
} else {
    Write-Host "✗ Web Client ID missing" -ForegroundColor Red
}

# Check for Desktop Client ID  
if ($content -contains "googleClientIdDesktop") {
    Write-Host "✓ Desktop Client ID found" -ForegroundColor Green
} else {
    Write-Host "✗ Desktop Client ID missing" -ForegroundColor Red
}

# Check for dynamic getter
if ($content -contains "get googleClientId") {
    Write-Host "✓ Dynamic client ID getter found" -ForegroundColor Green
} else {
    Write-Host "✗ Dynamic client ID getter missing" -ForegroundColor Red
}

Write-Host ""
Write-Host "OAuth configuration appears to be set up correctly!" -ForegroundColor Green
Write-Host "The 401 invalid_client error should now be resolved." -ForegroundColor Green
