# CloudToLocalLLM Kiro Hook Integration Test Script
# Tests the integration between Kiro hooks and the deployment workflow
#
# Version: 1.0.0
# Author: CloudToLocalLLM Development Team
# Last Updated: 2025-07-18
#
# This script implements part of task 12 from the automated deployment workflow specification:
# - Test Kiro hook integration and execution
# - Requirements: 2.1, 2.2, 2.3, 2.4

<#
.SYNOPSIS
    Tests Kiro hook integration with the CloudToLocalLLM deployment workflow.

.DESCRIPTION
    This script tests the integration between Kiro hooks and the CloudToLocalLLM
    deployment workflow, ensuring that hooks can properly trigger deployments.

.PARAMETER CreateHook
    Create a test hook if it doesn't exist

.PARAMETER TestHookExecution
    Simulate hook execution (doesn't actually deploy)

.PARAMETER Verbose
    Enable verbose logging output

.EXAMPLE
    .\Test-KiroHookIntegration.ps1 -CreateHook
    Create a test hook and validate its configuration

.EXAMPLE
    .\Test-KiroHookIntegration.ps1 -TestHookExecution
    Test hook execution simulation

.NOTES
    This script is designed to test Kiro hook integration without actually
    performing a deployment. It validates hook configuration and simulates
    hook execution to ensure proper integration.
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Create a test hook if it doesn't exist")]
    [switch]$CreateHook,

    [Parameter(HelpMessage = "Simulate hook execution")]
    [switch]$TestHookExecution,

    [Parameter(HelpMessage = "Display help information")]
    [switch]$Help
)

# Script configuration
$Script:ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$Script:DeployScriptPath = Join-Path $PSScriptRoot "Deploy-CloudToLocalLLM.ps1"
$Script:HookDir = Join-Path $Script:ProjectRoot ".kiro/hooks"
$Script:LogsDir = Join-Path $Script:ProjectRoot "logs"
$Script:TestLogFile = Join-Path $Script:LogsDir "hook_execution_$(Get-Date -Format 'yyyyMMdd').log"

# Ensure logs directory exists
if (-not (Test-Path $Script:LogsDir)) {
    New-Item -ItemType Directory -Path $Script:LogsDir -Force | Out-Null
}

# Initialize test log file
"CloudToLocalLLM Kiro Hook Integration Test Log - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $Script:TestLogFile -Encoding utf8
"=" * 80 | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append

# Logging functions
function Write-TestLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level,
        
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Add to log file
    $logMessage | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    
    # Output with appropriate formatting and colors
    switch ($Level) {
        'Info' { 
            Write-Host $Message -ForegroundColor White
        }
        'Success' { 
            Write-Host $Message -ForegroundColor Green
        }
        'Warning' { 
            Write-Host $Message -ForegroundColor Yellow
        }
        'Error' { 
            Write-Host $Message -ForegroundColor Red
        }
    }
}

# Verify hook directory exists
function Test-HookDirectoryExists {
    if (-not (Test-Path $Script:HookDir)) {
        Write-TestLog -Level Warning -Message "Kiro hooks directory not found at: $Script:HookDir"
        
        if ($CreateHook) {
            New-Item -ItemType Directory -Path $Script:HookDir -Force | Out-Null
            Write-TestLog -Level Success -Message "Created Kiro hooks directory: $Script:HookDir"
            return $true
        }
        
        return $false
    }
    
    Write-TestLog -Level Success -Message "Kiro hooks directory exists: $Script:HookDir"
    return $true
}

# Create a test hook configuration
function New-TestHook {
    if (-not (Test-HookDirectoryExists)) {
        return $false
    }
    
    $hookFilePath = Join-Path $Script:HookDir "deploy-to-staging.json"
    
    $hookContent = @{
        name = "Deploy to Staging"
        description = "Deploy CloudToLocalLLM to staging environment"
        trigger = "manual"
        command = "powershell"
        args = @("-ExecutionPolicy", "Bypass", "-File", "scripts/powershell/Deploy-CloudToLocalLLM.ps1", "-Environment", "Staging", "-Force", "-KiroHookMode")
        workingDirectory = "."
        timeout = 1800
    } | ConvertTo-Json -Depth 3
    
    Set-Content -Path $hookFilePath -Value $hookContent -Encoding UTF8
    
    Write-TestLog -Level Success -Message "Created test Kiro hook configuration: $hookFilePath"
    return $true
}

# Verify hook configurations
function Test-HookConfigurations {
    if (-not (Test-HookDirectoryExists)) {
        return $false
    }
    
    $hookFiles = Get-ChildItem -Path $Script:HookDir -Filter "*.json" -ErrorAction SilentlyContinue
    
    if ($hookFiles.Count -eq 0) {
        Write-TestLog -Level Warning -Message "No hook configurations found in $Script:HookDir"
        
        if ($CreateHook) {
            return New-TestHook
        }
        
        return $false
    }
    
    Write-TestLog -Level Info -Message "Found $($hookFiles.Count) hook configuration(s)"
    
    $validHooks = 0
    $deploymentHooks = 0
    
    foreach ($hookFile in $hookFiles) {
        try {
            $hookContent = Get-Content -Path $hookFile.FullName -Raw | ConvertFrom-Json
            
            # Check if it's a valid hook configuration
            if ($hookContent.name -and $hookContent.command) {
                $validHooks++
                
                # Check if it's a deployment hook
                if ($hookContent.command -eq "powershell" -and 
                    $hookContent.args -and 
                    ($hookContent.args -join " ") -match "Deploy-CloudToLocalLLM") {
                    $deploymentHooks++
                    Write-TestLog -Level Success -Message "Valid deployment hook found: $($hookFile.Name)"
                    
                    # Display hook details
                    Write-TestLog -Level Info -Message "  Name: $($hookContent.name)"
                    Write-TestLog -Level Info -Message "  Description: $($hookContent.description)"
                    Write-TestLog -Level Info -Message "  Trigger: $($hookContent.trigger)"
                    Write-TestLog -Level Info -Message "  Timeout: $($hookContent.timeout) seconds"
                }
            } else {
                Write-TestLog -Level Warning -Message "Invalid hook configuration: $($hookFile.Name)"
            }
        } catch {
            Write-TestLog -Level Error -Message "Failed to parse hook configuration $($hookFile.Name): $($_.Exception.Message)"
        }
    }
    
    Write-TestLog -Level Info -Message "Valid hooks: $validHooks, Deployment hooks: $deploymentHooks"
    
    if ($deploymentHooks -eq 0 -and $CreateHook) {
        return New-TestHook
    }
    
    return ($deploymentHooks -gt 0)
}

# Simulate hook execution
function Test-HookExecution {
    if (-not (Test-Path $Script:DeployScriptPath)) {
        Write-TestLog -Level Error -Message "Deployment script not found at: $Script:DeployScriptPath"
        return $false
    }
    
    Write-TestLog -Level Info -Message "Simulating Kiro hook execution..."
    
    try {
        # Simulate hook execution with KiroHookMode and DryRun
        $output = & $Script:DeployScriptPath -KiroHookMode -DryRun -Environment Staging
        
        # Check for Kiro-specific output format
        if ($output -match "\[INFO\]" -and $output -match "\[SUCCESS\]") {
            Write-TestLog -Level Success -Message "Hook execution simulation successful"
            Write-TestLog -Level Info -Message "Hook output format verified"
            return $true
        } else {
            Write-TestLog -Level Error -Message "Hook execution output format not as expected"
            return $false
        }
    } catch {
        Write-TestLog -Level Error -Message "Hook execution simulation failed: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
if ($Help) {
    Write-Host "CloudToLocalLLM Kiro Hook Integration Test Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Tests the integration between Kiro hooks and the CloudToLocalLLM deployment workflow."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\Test-KiroHookIntegration.ps1 [Options]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -CreateHook         Create a test hook if it doesn't exist"
    Write-Host "  -TestHookExecution  Simulate hook execution (doesn't actually deploy)"
    Write-Host "  -Verbose            Enable verbose logging"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\Test-KiroHookIntegration.ps1 -CreateHook         # Create and validate test hook"
    Write-Host "  .\Test-KiroHookIntegration.ps1 -TestHookExecution  # Test hook execution"
    Write-Host ""
    exit 0
}

try {
    Write-Host "=== CloudToLocalLLM Kiro Hook Integration Test ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""
    
    # Test hook directory and configurations
    $hooksValid = Test-HookConfigurations
    
    # Test hook execution if requested
    if ($TestHookExecution) {
        $executionValid = Test-HookExecution
    } else {
        $executionValid = $true
        Write-TestLog -Level Info -Message "Hook execution test skipped (use -TestHookExecution to test)"
    }
    
    # Generate summary
    Write-Host ""
    Write-Host "=== Test Summary ===" -ForegroundColor Cyan
    
    if ($hooksValid) {
        Write-Host "✓ Hook configurations: VALID" -ForegroundColor Green
    } else {
        Write-Host "✗ Hook configurations: INVALID" -ForegroundColor Red
    }
    
    if ($TestHookExecution) {
        if ($executionValid) {
            Write-Host "✓ Hook execution: SUCCESSFUL" -ForegroundColor Green
        } else {
            Write-Host "✗ Hook execution: FAILED" -ForegroundColor Red
        }
    } else {
        Write-Host "- Hook execution: NOT TESTED" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Log file: $Script:TestLogFile"
    
    # Exit with appropriate code
    if ($hooksValid -and $executionValid) {
        Write-Host "All tests completed successfully!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Some tests failed. See log for details." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    "FATAL ERROR: $($_.Exception.Message)" | Out-File -FilePath $Script:TestLogFile -Encoding utf8 -Append
    exit 1
}