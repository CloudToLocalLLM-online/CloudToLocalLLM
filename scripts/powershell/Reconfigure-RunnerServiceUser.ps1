# Reconfigure GitHub Actions Runner Service to Run as User Account
# This fixes issues with downloads and permissions when runner runs as SYSTEM

param(
    [Parameter(Mandatory=$false)]
    [string]$RunnerPath = "C:\actions-runner",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = $env:USERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$Password = ""
)

# Require Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'"
    exit 1
}

Write-Host "=== GitHub Actions Runner Service Reconfiguration ===" -ForegroundColor Cyan
Write-Host ""

# Check if runner directory exists
if (-not (Test-Path $RunnerPath)) {
    Write-Error "Runner directory not found: $RunnerPath"
    Write-Host "Please specify the correct path with -RunnerPath parameter"
    exit 1
}

Set-Location $RunnerPath

# Check if svc.exe exists
if (-not (Test-Path ".\svc.exe")) {
    Write-Error "svc.exe not found in $RunnerPath. Is this a valid runner installation?"
    exit 1
}

Write-Host "Current runner path: $RunnerPath" -ForegroundColor Yellow
Write-Host "Target username: $Username" -ForegroundColor Yellow
Write-Host ""

# Check current service status
Write-Host "Checking current service status..." -ForegroundColor Cyan
$services = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue
if ($services) {
    foreach ($service in $services) {
        Write-Host "Found service: $($service.Name)" -ForegroundColor Green
        Write-Host "  Status: $($service.Status)" -ForegroundColor Gray
        Write-Host "  Display Name: $($service.DisplayName)" -ForegroundColor Gray
        
        # Get service account
        $wmiService = Get-WmiObject Win32_Service -Filter "Name='$($service.Name)'"
        Write-Host "  Running as: $($wmiService.StartName)" -ForegroundColor $(if ($wmiService.StartName -eq "LocalSystem") { "Red" } else { "Green" })
        Write-Host ""
    }
} else {
    Write-Warning "No GitHub Actions runner services found"
}

# Stop and uninstall service
Write-Host "Stopping and uninstalling current service..." -ForegroundColor Cyan
try {
    .\svc.exe stop
    Start-Sleep -Seconds 2
    .\svc.exe uninstall
    Write-Host "Service uninstalled successfully" -ForegroundColor Green
} catch {
    Write-Warning "Error during uninstall (may already be uninstalled): $($_.Exception.Message)"
}

Write-Host ""

# Install service with user account
Write-Host "Installing service to run as user: $Username" -ForegroundColor Cyan

if ([string]::IsNullOrEmpty($Password)) {
    Write-Host "No password provided. Installing without password (will prompt if needed)..." -ForegroundColor Yellow
    $installArgs = @(
        "install",
        "--username", $Username
    )
} else {
    Write-Host "Installing with provided credentials..." -ForegroundColor Yellow
    $installArgs = @(
        "install",
        "--username", $Username,
        "--password", $Password
    )
}

try {
    & .\svc.exe $installArgs
    Write-Host "Service installed successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to install service: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "You may need to manually install using:" -ForegroundColor Yellow
    Write-Host "  .\svc.exe install --username $Username" -ForegroundColor White
    exit 1
}

Write-Host ""

# Start service
Write-Host "Starting service..." -ForegroundColor Cyan
try {
    .\svc.exe start
    Start-Sleep -Seconds 2
    
    $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($service -and $service.Status -eq "Running") {
        Write-Host "Service started successfully" -ForegroundColor Green
    } else {
        Write-Warning "Service may not have started. Check status manually."
    }
} catch {
    Write-Warning "Error starting service: $($_.Exception.Message)"
    Write-Host "You may need to start it manually: .\svc.exe start" -ForegroundColor Yellow
}

Write-Host ""

# Verify new configuration
Write-Host "Verifying service configuration..." -ForegroundColor Cyan
$services = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue
if ($services) {
    foreach ($service in $services) {
        $wmiService = Get-WmiObject Win32_Service -Filter "Name='$($service.Name)'"
        Write-Host "Service: $($service.Name)" -ForegroundColor Green
        Write-Host "  Status: $($service.Status)" -ForegroundColor Gray
        Write-Host "  Running as: $($wmiService.StartName)" -ForegroundColor $(if ($wmiService.StartName -eq $Username) { "Green" } else { "Yellow" })
        
        if ($wmiService.StartName -eq $Username) {
            Write-Host "  ✓ Service is configured to run as your user account" -ForegroundColor Green
        } else {
            Write-Warning "  ⚠ Service is still running as: $($wmiService.StartName)"
            Write-Host "  You may need to configure it manually through Services (services.msc)" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "=== Reconfiguration Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Check GitHub Actions to verify the runner is online" -ForegroundColor White
Write-Host "2. Run a test workflow to verify downloads work" -ForegroundColor White
Write-Host "3. If issues persist, check Windows Firewall settings" -ForegroundColor White

