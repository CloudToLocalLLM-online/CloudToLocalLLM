# Reconfigure GitHub Actions Runner Service to Run as User Account using sc.exe
# Run this script as Administrator

param(
    [Parameter(Mandatory=$false)]
    [string]$Username = $env:USERNAME
)

# Require Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'"
    exit 1
}

Write-Host "=== GitHub Actions Runner Service Reconfiguration ===" -ForegroundColor Cyan
Write-Host ""

# Find the runner service
$services = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue
if (-not $services) {
    Write-Error "No GitHub Actions runner services found"
    exit 1
}

foreach ($service in $services) {
    $serviceName = $service.Name
    Write-Host "Processing service: $serviceName" -ForegroundColor Yellow
    
    # Get current service configuration
    $wmiService = Get-WmiObject Win32_Service -Filter "Name='$serviceName'"
    Write-Host "  Current status: $($service.Status)" -ForegroundColor Gray
    Write-Host "  Currently running as: $($wmiService.StartName)" -ForegroundColor $(if ($wmiService.StartName -like "*$Username*") { 'Green' } else { 'Yellow' })
    Write-Host ""
    
    # Stop the service
    Write-Host "Stopping service..." -ForegroundColor Cyan
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    
    # Get user's full account name
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $userDomain = $currentUser.Name.Split('\')[0]
    $accountName = if ($Username.Contains('\')) { $Username } else { "$env:COMPUTERNAME\$Username" }
    
    Write-Host "Configuring service to run as: $accountName" -ForegroundColor Cyan
    
    # Configure service to run as user account using sc.exe
    Write-Host "Setting service account..." -ForegroundColor Yellow
    $result = & sc.exe config $serviceName obj= "$accountName" password= ""
    
    if ($LASTEXITCODE -ne 0 -and $result -match "success") {
        Write-Warning "Service configuration may require a password. You'll be prompted when starting."
        Write-Host "Setting service to prompt for credentials..." -ForegroundColor Yellow
        # Remove password requirement - service will prompt at start
        & sc.exe config $serviceName obj= "$accountName"
    }
    
    Write-Host ""
    
    # Start the service
    Write-Host "Starting service..." -ForegroundColor Cyan
    Start-Service -Name $serviceName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    
    # Verify configuration
    Write-Host "Verifying configuration..." -ForegroundColor Cyan
    $service = Get-Service -Name $serviceName
    $wmiService = Get-WmiObject Win32_Service -Filter "Name='$serviceName'"
    
    Write-Host ""
    Write-Host "=== Service Configuration Result ===" -ForegroundColor Cyan
    Write-Host "Service: $($service.DisplayName)" -ForegroundColor Green
    Write-Host "  Status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' })
    Write-Host "  Running as: $($wmiService.StartName)" -ForegroundColor $(if ($wmiService.StartName -like "*$Username*") { 'Green' } else { 'Yellow' })
    
    if ($wmiService.StartName -like "*$Username*") {
        Write-Host ""
        Write-Host "✓ Successfully configured to run as user account!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Warning "Service may still be configured as different account"
        Write-Host "If the service won't start, you may need to set it manually:" -ForegroundColor Yellow
        Write-Host "  1. Open services.msc" -ForegroundColor White
        Write-Host "  2. Find '$($service.DisplayName)'" -ForegroundColor White
        Write-Host "  3. Right-click → Properties → Log On tab" -ForegroundColor White
        Write-Host "  4. Select 'This account' and enter: $accountName" -ForegroundColor White
        Write-Host "  5. Enter your password" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "=== Complete ===" -ForegroundColor Cyan
Write-Host "Check GitHub Actions to verify the runner is online." -ForegroundColor Yellow

