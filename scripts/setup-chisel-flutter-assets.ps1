# PowerShell script to download Chisel binaries for Flutter app
# Downloads Chisel for Windows, macOS, and Linux (amd64 and arm64)

param(
    [string]$ChiselVersion = "1.9.1",
    [string]$AssetsDir = "assets\chisel"
)

$ErrorActionPreference = "Stop"

Write-Host "Downloading Chisel v$ChiselVersion binaries for Flutter app..." -ForegroundColor Green

# Create assets directory
if (!(Test-Path $AssetsDir)) {
    New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null
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
Write-Host ""
Write-Host "Windows Defender Note:" -ForegroundColor Yellow
Write-Host "  Windows Defender may flag Chisel as potentially unwanted software." -ForegroundColor Yellow
Write-Host "  This is a false positive. The binary is legitimate and open-source." -ForegroundColor Yellow
Write-Host "  To add an exclusion, run as Administrator:" -ForegroundColor Yellow
Write-Host "    Add-MpPreference -ExclusionPath '$PSScriptRoot\$AssetsDir'" -ForegroundColor Cyan

