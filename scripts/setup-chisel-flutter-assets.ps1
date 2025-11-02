# PowerShell script to download Chisel binaries for Flutter app
# Downloads Chisel for Windows, macOS, and Linux (amd64 and arm64)

param(
    [string]$ChiselVersion = "1.9.1",
    [string]$AssetsDir = "assets\chisel"
)

# Check if running as admin, if not, restart with elevated privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Script requires administrator privileges for Windows Defender exclusion." -ForegroundColor Yellow
    Write-Host "Restarting with elevated privileges..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -ChiselVersion $ChiselVersion -AssetsDir $AssetsDir" -Verb RunAs -Wait
    exit $LASTEXITCODE
}

$ErrorActionPreference = "Stop"

Write-Host "Downloading Chisel v$ChiselVersion binaries for Flutter app..." -ForegroundColor Green

# Create assets directory
if (!(Test-Path $AssetsDir)) {
    New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null
}

# Add Windows Defender exclusion BEFORE downloading to prevent quarantine
Write-Host ""
Write-Host "Adding Windows Defender exclusions..." -ForegroundColor Green
try {
    # Exclude the assets directory where binaries are stored
    Add-MpPreference -ExclusionPath "$PSScriptRoot\$AssetsDir" -ErrorAction Stop
    Write-Host "  Added exclusion for: $PSScriptRoot\$AssetsDir" -ForegroundColor Green
    
    # Also exclude the app directory where binaries are extracted at runtime
    $appChiselDir = "$env:USERPROFILE\Documents\CloudToLocalLLM\chisel"
    Add-MpPreference -ExclusionPath $appChiselDir -ErrorAction Stop
    Write-Host "  Added exclusion for: $appChiselDir" -ForegroundColor Green
} catch {
    Write-Host "  Failed to add exclusion: $_" -ForegroundColor Yellow
}

# Platforms to download
$platforms = @(
    @{OS="windows"; Arch="amd64"; Ext=".exe"},
    @{OS="windows"; Arch="arm64"; Ext=".exe"},
    @{OS="darwin"; Arch="amd64"; Ext=""},
    @{OS="darwin"; Arch="arm64"; Ext=""},
    @{OS="linux"; Arch="amd64"; Ext=""},
    @{OS="linux"; Arch="arm64"; Ext=""}
)

foreach ($platform in $platforms) {
    $os = $platform.OS
    $arch = $platform.Arch
    $ext = $platform.Ext
    
    if ($os -eq "windows") {
        $file = "chisel_${ChiselVersion}_${os}_${arch}.gz"
        $binary = "chisel.exe"
    } else {
        $file = "chisel_${ChiselVersion}_${os}_${arch}.gz"
        $binary = "chisel"
    }
    
    $url = "https://github.com/jpillora/chisel/releases/download/v${ChiselVersion}/${file}"
    $target = "$AssetsDir\chisel-${os}$($arch -replace 'amd64', '')${ext}"
    
    Write-Host "Downloading ${os}/${arch}..." -ForegroundColor Yellow
    
    try {
        # Download file
        $downloadPath = Join-Path $AssetsDir $file
        Invoke-WebRequest -Uri $url -OutFile $downloadPath -UseBasicParsing
        
        # Extract - all platforms use .gz format
        if (Get-Command 7z -ErrorAction SilentlyContinue) {
            7z e $downloadPath -o"$AssetsDir" -y | Out-Null
        } else {
            # PowerShell can't natively handle .gz, need external tool
            Write-Warning "Cannot extract .gz files without 7zip. Please install 7-zip or extract manually."
            Write-Host "  File downloaded to: $downloadPath" -ForegroundColor Yellow
            continue
        }
        
        $extractedBinary = Join-Path $AssetsDir $binary
        if (Test-Path $extractedBinary) {
            Move-Item -Path $extractedBinary -Destination $target -Force
        }
        Remove-Item $downloadPath -Force
        
        Write-Host "  [OK] $os/$arch -> $target" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] Failed to download $os/$arch : $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Chisel binaries downloaded to $AssetsDir" -ForegroundColor Green
Write-Host "Dont forget to run flutter pub get" -ForegroundColor Yellow
Write-Host "Windows Defender exclusion was added earlier" -ForegroundColor Green

