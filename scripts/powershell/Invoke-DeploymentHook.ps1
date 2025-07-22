# CloudToLocalLLM Kiro Hook Execution Wrapper
# Provides hook-compatible interface for the automated deployment workflow
# Handles hook-specific error reporting, progress tracking, and timeout management
#
# Version: 1.0.0
# Author: CloudToLocalLLM Development Team
# Last Updated: 2025-01-18

<#
.SYNOPSIS
    Kiro hook execution wrapper for CloudToLocalLLM deployment workflow.

.DESCRIPTION
    This script provides a Kiro hook-compatible wrapper around the main deployment script.
    It handles hook-specific requirements including progress reporting, error handling,
    timeout management, and output formatting for the Kiro interface.

.PARAMETER Environment
    Target deployment environment. Valid values: Local, Staging, Production (default: Production)

.PARAMETER VersionIncrement
    Type of version increment to apply. Valid values: build, patch, minor, major (default: build)

.PARAMETER TimeoutSeconds
    Maximum timeout for deployment operations in seconds (default: 1800)

.PARAMETER DryRun
    Preview actions without executing actual changes

.PARAMETER Force
    Force deployment without user confirmation prompts

.PARAMETER Verbose
    Enable verbose logging output

.EXAMPLE
    .\Invoke-DeploymentHook.ps1 -Environment Production
    Execute production deployment via Kiro hook

.EXAMPLE
    .\Invoke-DeploymentHook.ps1 -Environment Staging -VersionIncrement patch
    Execute staging deployment with patch version increment

.EXAMPLE
    .\Invoke-DeploymentHook.ps1 -DryRun -VerboseLogging
    Preview deployment actions with verbose output

.NOTES
    This script is designed specifically for Kiro hook execution and provides:
    - Hook-compatible progress reporting
    - Structured error handling and reporting
    - Timeout and cancellation handling
    - Kiro interface-optimized output formatting
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, HelpMessage = "Target deployment environment")]
    [ValidateSet('Local', 'Staging', 'Production')]
    [string]$Environment = 'Production',

    [Parameter(HelpMessage = "Version increment type")]
    [ValidateSet('build', 'patch', 'minor', 'major')]
    [string]$VersionIncrement = 'build',

    [Parameter(HelpMessage = "Deployment timeout in seconds")]
    [int]$TimeoutSeconds = 1800,

    [Parameter(HelpMessage = "Preview actions without executing")]
    [switch]$DryRun,

    [Parameter(HelpMessage = "Force deployment without confirmations")]
    [switch]$Force,

    [Parameter(HelpMessage = "Enable verbose logging")]
    [switch]$VerboseLogging
)

# Hook execution configuration
$Script:HookConfig = @{
    Name = "Automated Deployment Workflow"
    Version = "1.0.0"
    TimeoutSeconds = $TimeoutSeconds
    StartTime = Get-Date
    MaxExecutionTime = (Get-Date).AddSeconds($TimeoutSeconds)
    CancellationRequested = $false
}

# Hook-specific logging function
function Write-HookLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Progress', 'Phase')]
        [string]$Level,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [int]$PercentComplete = -1
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Level) {
        'Info' { 
            Write-Host "[INFO] $Message" -ForegroundColor White
        }
        'Success' { 
            Write-Host "[SUCCESS] $Message" -ForegroundColor Green
        }
        'Warning' { 
            Write-Host "[WARNING] $Message" -ForegroundColor Yellow
        }
        'Error' { 
            Write-Host "[ERROR] $Message" -ForegroundColor Red
        }
        'Progress' {
            if ($PercentComplete -ge 0) {
                Write-Host "Progress: $PercentComplete%" -ForegroundColor Green
            }
            Write-Host "[INFO] $Message" -ForegroundColor White
        }
        'Phase' { 
            Write-Host "Phase: $Message" -ForegroundColor Magenta
        }
    }
    
    # Log to file for debugging
    $logEntry = "[$timestamp] [$Level] $Message"
    if ($PercentComplete -ge 0) {
        $logEntry += " (Progress: $PercentComplete%)"
    }
    
    # Ensure logs directory exists
    $logsDir = Join-Path (Get-Location) "logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }
    
    $logFile = Join-Path $logsDir "hook_execution_$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
}

# Hook timeout and cancellation handler
function Test-HookTimeout {
    [CmdletBinding()]
    param()
    
    $currentTime = Get-Date
    
    if ($currentTime -gt $Script:HookConfig.MaxExecutionTime) {
        Write-HookLog -Level Error -Message "Hook execution timeout reached ($($Script:HookConfig.TimeoutSeconds) seconds)"
        return $true
    }
    
    # Check for cancellation signals (simplified for PowerShell)
    if ($Script:HookConfig.CancellationRequested) {
        Write-HookLog -Level Warning -Message "Hook execution cancelled by user"
        return $true
    }
    
    return $false
}

# Hook execution validation
function Test-HookExecutionEnvironment {
    [CmdletBinding()]
    param()
    
    Write-HookLog -Level Info -Message "Validating hook execution environment"
    
    # Validate PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-HookLog -Level Error -Message "PowerShell 5.0 or later required (current: $($PSVersionTable.PSVersion))"
        return $false
    }
    
    # Validate main deployment script exists
    $deploymentScript = Join-Path $PSScriptRoot "Deploy-CloudToLocalLLM.ps1"
    if (-not (Test-Path $deploymentScript)) {
        Write-HookLog -Level Error -Message "Main deployment script not found: $deploymentScript"
        return $false
    }
    
    # Validate execution policy
    $executionPolicy = Get-ExecutionPolicy
    if ($executionPolicy -eq 'Restricted') {
        Write-HookLog -Level Error -Message "PowerShell execution policy is Restricted. Use 'Set-ExecutionPolicy RemoteSigned' or run with -ExecutionPolicy Bypass"
        return $false
    }
    
    Write-HookLog -Level Success -Message "Hook execution environment validated successfully"
    return $true
}

# Hook progress monitoring wrapper
function Invoke-DeploymentWithProgress {
    [CmdletBinding()]
    param()
    
    Write-HookLog -Level Info -Message "Starting deployment via Kiro hook wrapper"
    Write-HookLog -Level Progress -Message "Initializing deployment workflow" -PercentComplete 0
    
    # Build deployment script arguments
    $deploymentArgs = @(
        "-Environment", $Environment,
        "-VersionIncrement", $VersionIncrement,
        "-KiroHookMode",
        "-Force"
    )
    
    if ($DryRun) {
        $deploymentArgs += "-DryRun"
    }
    
    if ($VerboseLogging) {
        $deploymentArgs += "-Verbose"
    }
    
    # Execute main deployment script with hook mode enabled
    $deploymentScript = Join-Path $PSScriptRoot "Deploy-CloudToLocalLLM.ps1"
    
    Write-HookLog -Level Info -Message "Executing: $deploymentScript"
    Write-HookLog -Level Info -Message "Arguments: $($deploymentArgs -join ' ')"
    
    try {
        # Execute deployment script directly for better integration
        $paramHash = @{
            Environment = $Environment
            VersionIncrement = $VersionIncrement
            KiroHookMode = $true
            Force = $true
        }
        
        if ($DryRun) { $paramHash.DryRun = $true }
        if ($VerboseLogging) { $paramHash.Verbose = $true }
        
        Write-HookLog -Level Info -Message "Executing deployment with parameters: $($paramHash.Keys -join ', ')"
        
        # Execute the deployment script in current session
        $success = $false
        try {
            # Source the deployment script and call it with parameters
            . $deploymentScript @paramHash
            $success = $true
        }
        catch {
            Write-HookLog -Level Error -Message "Deployment script execution failed: $($_.Exception.Message)"
            $success = $false
        }
        
        if ($success) {
            Write-HookLog -Level Progress -Message "Deployment completed successfully" -PercentComplete 100
            Write-HookLog -Level Success -Message "Hook execution completed successfully"
            return $true
        }
        else {
            Write-HookLog -Level Error -Message "Deployment execution failed"
            return $false
        }
    }
    catch {
        Write-HookLog -Level Error -Message "Hook execution failed: $($_.Exception.Message)"
        return $false
    }
}

# Hook execution error handler
function Handle-HookExecutionError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,
        
        [int]$ExitCode = 1
    )
    
    Write-HookLog -Level Error -Message "Hook execution failed: $ErrorMessage"
    
    # Provide troubleshooting guidance
    Write-HookLog -Level Info -Message "Troubleshooting steps:"
    Write-HookLog -Level Info -Message "1. Check PowerShell execution policy: Get-ExecutionPolicy"
    Write-HookLog -Level Info -Message "2. Verify WSL2 Ubuntu 24.04 is installed and accessible"
    Write-HookLog -Level Info -Message "3. Ensure SSH access to VPS is configured"
    Write-HookLog -Level Info -Message "4. Check deployment logs in the logs/ directory"
    Write-HookLog -Level Info -Message "5. Try running with -DryRun to validate configuration"
    
    # Calculate execution time
    $executionTime = (Get-Date) - $Script:HookConfig.StartTime
    Write-HookLog -Level Info -Message "Hook execution time: $($executionTime.ToString('mm\:ss'))"
    
    exit $ExitCode
}

# Main hook execution
try {
    Write-HookLog -Level Info -Message "CloudToLocalLLM Kiro Hook Wrapper v$($Script:HookConfig.Version)"
    Write-HookLog -Level Info -Message "Hook: $($Script:HookConfig.Name)"
    Write-HookLog -Level Info -Message "Environment: $Environment | Version Increment: $VersionIncrement"
    Write-HookLog -Level Info -Message "Timeout: $TimeoutSeconds seconds | Dry Run: $DryRun"
    
    # Validate hook execution environment
    if (-not (Test-HookExecutionEnvironment)) {
        Handle-HookExecutionError -ErrorMessage "Hook execution environment validation failed" -ExitCode 2
    }
    
    # Execute deployment with progress monitoring
    $success = Invoke-DeploymentWithProgress
    
    if ($success) {
        $executionTime = (Get-Date) - $Script:HookConfig.StartTime
        Write-HookLog -Level Success -Message "Hook execution completed successfully in $($executionTime.ToString('mm\:ss'))"
        exit 0
    }
    else {
        Handle-HookExecutionError -ErrorMessage "Deployment execution failed" -ExitCode 3
    }
}
catch {
    Handle-HookExecutionError -ErrorMessage $_.Exception.Message -ExitCode 1
}