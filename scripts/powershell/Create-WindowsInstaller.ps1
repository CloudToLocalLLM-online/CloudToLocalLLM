# CloudToLocalLLM Windows Installer Creation Script
# Creates Windows installer using Inno Setup

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [string]$InstallerScript = "build-tools\installers\windows\Basic.iss",
    [string]$OutputDir = "dist\windows",
    [switch]$InstallInnoSetup,
    [switch]$Verbose
)

# Import utility functions
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$ProjectRoot = Split-Path $ScriptDir -Parent | Split-Path -Parent

# Logging functions
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Test for Inno Setup installation
function Test-InnoSetup {
    $possiblePaths = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 5\ISCC.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-LogInfo "Found Inno Setup at: $path"
            return $path
        }
    }
    
    # Check PATH
    try {
        $isccPath = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
        if ($isccPath) {
            Write-LogInfo "Found Inno Setup in PATH: $($isccPath.Source)"
            return $isccPath.Source
        }
    } catch {
        # Ignore
    }
    
    return $null
}

# Install Inno Setup automatically
function Install-InnoSetup {
    Write-LogInfo "Installing Inno Setup..."
    
    try {
        # Download and install Inno Setup
        $downloadUrl = "https://jrsoftware.org/download.php/is.exe"
        $tempFile = Join-Path $env:TEMP "innosetup.exe"
        
        Write-LogInfo "Downloading Inno Setup..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
        
        Write-LogInfo "Installing Inno Setup (silent installation)..."
        Start-Process -FilePath $tempFile -ArgumentList "/SILENT" -Wait
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        # Test installation
        $innoPath = Test-InnoSetup
        if ($innoPath) {
            Write-LogSuccess "Inno Setup installed successfully"
            return $innoPath
        } else {
            throw "Inno Setup installation verification failed"
        }
    }
    catch {
        Write-LogError "Failed to install Inno Setup: $($_.Exception.Message)"
        throw
    }
}

# Create output directory if it doesn't exist
function New-DirectoryIfNotExists {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-LogInfo "Created directory: $Path"
    }
}

# Main installer creation function
function New-WindowsInstaller {
    Write-LogInfo "Creating Windows installer for version $Version..."
    
    # Check for Inno Setup
    $innoPath = Test-InnoSetup
    if (-not $innoPath) {
        if ($InstallInnoSetup) {
            $innoPath = Install-InnoSetup
        } else {
            Write-LogWarning "Inno Setup not found. Use -InstallInnoSetup to install it automatically."
            Write-LogError "Cannot create Windows installer without Inno Setup."
            exit 1
        }
    }
    
    # Resolve paths
    $installerScriptPath = Join-Path $ProjectRoot $InstallerScript
    $outputDirPath = Join-Path $ProjectRoot $OutputDir
    
    # Verify installer script exists
    if (-not (Test-Path $installerScriptPath)) {
        Write-LogError "Installer script not found at: $installerScriptPath"
        exit 1
    }
    
    # Create output directory
    New-DirectoryIfNotExists -Path $outputDirPath
    
    # Verify Windows build exists
    $windowsBuildDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
    $mainExecutable = Join-Path $windowsBuildDir "cloudtolocalllm.exe"
    
    if (-not (Test-Path $mainExecutable)) {
        Write-LogWarning "Windows executable not found at: $mainExecutable"
        Write-LogWarning "You may need to run 'flutter build windows --release' first"
    }
    
    try {
        Write-LogInfo "Compiling installer with Inno Setup..."
        Write-LogInfo "Script: $installerScriptPath"
        Write-LogInfo "Output: $outputDirPath"
        
        $installerArgs = @(
            "`"$installerScriptPath`"",
            "/DMyAppVersion=$Version",
            "/O`"$outputDirPath`""
        )
        
        if ($Verbose) {
            Write-LogInfo "Inno Setup command: $innoPath $($installerArgs -join ' ')"
        }
        
        $process = Start-Process -FilePath $innoPath -ArgumentList $installerArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -ne 0) {
            throw "Inno Setup compilation failed with exit code: $($process.ExitCode)"
        }
        
        # Find the created installer
        $installerName = "CloudToLocalLLM-Windows-$Version-Setup.exe"
        $installerPath = Join-Path $outputDirPath $installerName
        
        if (Test-Path $installerPath) {
            # Generate checksum
            $hash = Get-FileHash -Path $installerPath -Algorithm SHA256
            $checksum = $hash.Hash.ToLower()
            "$checksum  $installerName" | Set-Content -Path "$installerPath.sha256" -Encoding UTF8
            
            Write-LogSuccess "Windows installer created successfully!"
            Write-LogInfo "Installer: $installerPath"
            Write-LogInfo "Checksum: $checksum"
            Write-LogInfo "Size: $([math]::Round((Get-Item $installerPath).Length/1MB,2)) MB"
            
            return $installerPath
        } else {
            throw "Installer file not found after compilation: $installerPath"
        }
    }
    catch {
        Write-LogError "Failed to create Windows installer: $($_.Exception.Message)"
        exit 1
    }
}

# Main execution
try {
    Write-LogInfo "CloudToLocalLLM Windows Installer Creation Script"
    Write-LogInfo "Version: $Version"
    Write-LogInfo "Project Root: $ProjectRoot"
    
    $installerPath = New-WindowsInstaller
    
    Write-LogSuccess "Windows installer creation completed successfully!"
    exit 0
}
catch {
    Write-LogError "Script execution failed: $($_.Exception.Message)"
    exit 1
}
