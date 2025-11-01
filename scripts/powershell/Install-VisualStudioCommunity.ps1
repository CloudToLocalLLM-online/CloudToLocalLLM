# Install Visual Studio Community 2022 with C++ Workload for Flutter
# This fixes the Flutter doctor issue for Windows development

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Visual Studio Community 2022 Installer" -ForegroundColor Cyan
Write-Host "For Flutter Windows Development" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$vsInstaller = "$env:TEMP\vs_community.exe"
$vsInstallPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community"

# Check if already installed
if (Test-Path $vsInstallPath) {
    Write-Host "Visual Studio Community 2022 is already installed!" -ForegroundColor Green
    Write-Host "Location: $vsInstallPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Checking if C++ workload is installed..." -ForegroundColor Yellow
    
    # Check for vcxproj support (indicates C++ tools)
    $vcToolsPath = Join-Path $vsInstallPath "VC\Tools\MSVC"
    if (Test-Path $vcToolsPath) {
        Write-Host "✓ C++ build tools found!" -ForegroundColor Green
        Write-Host "Run 'flutter doctor' to verify." -ForegroundColor Cyan
        exit 0
    } else {
        Write-Host " C++ workload not found. Need to add it." -ForegroundColor Yellow
        Write-Host "Please open Visual Studio Installer and add 'Desktop development with C++'" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Downloading Visual Studio Community 2022 installer..." -ForegroundColor Cyan
Write-Host "This may take a few minutes depending on your connection...`n" -ForegroundColor Yellow

try {
    Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_community.exe" -OutFile $vsInstaller -UseBasicParsing
    Write-Host "Download complete!" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to download installer: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Installing Visual Studio Community 2022 with:" -ForegroundColor Cyan
Write-Host "  • Desktop development with C++ workload" -ForegroundColor White
Write-Host "  • Windows 10/11 SDK" -ForegroundColor White
Write-Host "  • CMake tools" -ForegroundColor White
Write-Host ""
Write-Host "This will take 20-30 minutes. The installer window will show progress." -ForegroundColor Yellow
Write-Host ""

# Install with required workloads
$installArgs = @(
    "--quiet",
    "--wait",
    "--add", "Microsoft.VisualStudio.Workload.NativeDesktop",
    "--add", "Microsoft.VisualStudio.Component.Windows10SDK.19041",
    "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "--add", "Microsoft.VisualStudio.Component.VC.CMake.Project",
    "--includeRecommended"
)

Write-Host "Starting installation..." -ForegroundColor Green
Write-Host "You can monitor progress in the Visual Studio Installer window.`n" -ForegroundColor Cyan

$process = Start-Process -FilePath $vsInstaller -ArgumentList $installArgs -PassThru -Wait

if ($process.ExitCode -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Visual Studio Community 2022 has been installed." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Run: flutter doctor" -ForegroundColor White
    Write-Host "2. Verify Visual Studio is now recognized" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "WARNING: Installation returned exit code $($process.ExitCode)" -ForegroundColor Yellow
    Write-Host "The installation may have completed with warnings." -ForegroundColor Yellow
    Write-Host "Please run 'flutter doctor' to verify." -ForegroundColor Cyan
}

# Clean up installer
if (Test-Path $vsInstaller) {
    Remove-Item $vsInstaller -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Press any key to exit..."
try {
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
} catch {
    # If ReadKey fails (e.g., in non-interactive session), just continue
}

