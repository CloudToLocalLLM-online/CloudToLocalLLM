#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CloudToLocalLLM Deployment Script with Integrated Testing (PowerShell)

.DESCRIPTION
    Enhanced deployment workflow with comprehensive test execution for Windows/PowerShell environments.
    This script runs the complete test suite before deployment and provides detailed reporting.

.PARAMETER Force
    Skip safety prompts and proceed automatically

.PARAMETER Verbose
    Enable verbose output

.PARAMETER SkipTests
    Skip all test execution

.PARAMETER SkipFlutterTests
    Skip Flutter tests only

.PARAMETER SkipNodejsTests
    Skip Node.js tests only

.PARAMETER SkipPowerShellTests
    Skip PowerShell tests only

.PARAMETER IncludeE2ETests
    Include E2E tests (slower)

.PARAMETER DryRun
    Show what would be done without executing

.PARAMETER ContinueOnTestFailure
    Continue deployment even if tests fail

.EXAMPLE
    .\Deploy-WithTests.ps1
    Run all tests then deploy

.EXAMPLE
    .\Deploy-WithTests.ps1 -SkipTests
    Deploy without running tests

.EXAMPLE
    .\Deploy-WithTests.ps1 -IncludeE2ETests
    Run all tests including E2E

.EXAMPLE
    .\Deploy-WithTests.ps1 -DryRun
    Show deployment plan without executing

.NOTES
    This script integrates with the CloudToLocalLLM CI/CD pipeline and provides
    comprehensive test execution before deployment.
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$DetailedOutput,
    [switch]$SkipTests,
    [switch]$SkipFlutterTests,
    [switch]$SkipNodejsTests,
    [switch]$SkipPowerShellTests,
    [switch]$IncludeE2ETests,
    [switch]$DryRun,
    [switch]$ContinueOnTestFailure
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script metadata
$ScriptVersion = "1.0.0"
$ScriptName = "CloudToLocalLLM Test-Integrated Deployment"

# Configuration
$ProjectDir = Get-Location
$ScriptsDir = Join-Path $ProjectDir "scripts\deploy"
$TestDir = Join-Path $ProjectDir "test"

# Test configuration
$RunFlutterTests = -not $SkipFlutterTests
$RunNodejsTests = -not $SkipNodejsTests
$RunPowerShellTests = -not $SkipPowerShellTests
$RunE2ETests = $IncludeE2ETests
$FailOnTestFailure = -not $ContinueOnTestFailure

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-DetailedOutput {
    param([string]$Message)
    if ($DetailedOutput) {
        Write-Host "[VERBOSE] $Message" -ForegroundColor Cyan
    }
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking deployment prerequisites..."
    
    # Check if we're in the right directory
    if (-not (Test-Path "pubspec.yaml")) {
        Write-Error "Not in CloudToLocalLLM project directory"
        exit 1
    }
    
    # Check for required tools
    $missingTools = @()
    
    if ($RunFlutterTests -and -not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        $missingTools += "flutter"
    }
    
    if ($RunNodejsTests -and -not (Get-Command npm -ErrorAction SilentlyContinue)) {
        $missingTools += "npm"
    }
    
    if ($RunPowerShellTests -and -not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        # PowerShell is available since we're running in it
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($missingTools -join ', ')"
        Write-Info "Install missing tools or use -SkipTests to bypass"
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
}

# Run Flutter tests
function Invoke-FlutterTests {
    if (-not $RunFlutterTests) {
        Write-Info "Skipping Flutter tests"
        return $true
    }
    
    Write-Info "Running Flutter tests..."
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would run: flutter test"
        return $true
    }
    
    try {
        # Get dependencies
        Write-DetailedOutput "Getting Flutter dependencies..."
        flutter pub get

        # Run static analysis
        Write-DetailedOutput "Running Flutter analyze..."
        flutter analyze --fatal-infos --fatal-warnings

        # Run tests
        Write-DetailedOutput "Running Flutter unit tests..."
        flutter test

        # Test build
        Write-DetailedOutput "Testing Flutter build..."
        flutter build web --release
        
        Write-Success "Flutter tests passed"
        return $true
    }
    catch {
        Write-Error "Flutter tests failed: $_"
        return $false
    }
}

# Run Node.js tests
function Invoke-NodejsTests {
    if (-not $RunNodejsTests) {
        Write-Info "Skipping Node.js tests"
        return $true
    }
    
    Write-Info "Running Node.js tests..."
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would run Node.js tests in services/api-backend"
        return $true
    }
    
    # Check if API backend exists
    $apiBackendPath = Join-Path $ProjectDir "services\api-backend"
    if (-not (Test-Path $apiBackendPath)) {
        Write-Warning "API backend directory not found, skipping Node.js tests"
        return $true
    }
    
    try {
        Push-Location $apiBackendPath
        
        # Install dependencies
        Write-DetailedOutput "Installing Node.js dependencies..."
        npm ci

        # Run linting
        Write-DetailedOutput "Running ESLint..."
        npm run lint

        # Run tests
        Write-DetailedOutput "Running Node.js tests..."
        npm test
        
        Write-Success "Node.js tests passed"
        return $true
    }
    catch {
        Write-Error "Node.js tests failed: $_"
        return $false
    }
    finally {
        Pop-Location
    }
}

# Run PowerShell tests
function Invoke-PowerShellTests {
    if (-not $RunPowerShellTests) {
        Write-Info "Skipping PowerShell tests"
        return $true
    }
    
    Write-Info "Running PowerShell tests..."
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would run PowerShell tests"
        return $true
    }
    
    # Check if PowerShell tests exist
    $testRunnerPath = Join-Path $TestDir "powershell\CI-TestRunner.ps1"
    if (-not (Test-Path $testRunnerPath)) {
        Write-Warning "PowerShell test runner not found, skipping PowerShell tests"
        return $true
    }
    
    try {
        # Run PowerShell tests
        Write-DetailedOutput "Running PowerShell deployment tests..."
        & $testRunnerPath -OutputFormat Minimal -FailFast
        
        Write-Success "PowerShell tests passed"
        return $true
    }
    catch {
        Write-Error "PowerShell tests failed: $_"
        return $false
    }
}

# Run E2E tests
function Invoke-E2ETests {
    if (-not $RunE2ETests) {
        Write-Info "Skipping E2E tests"
        return $true
    }
    
    Write-Info "Running E2E tests..."
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would run Playwright E2E tests"
        return $true
    }
    
    # Check if Playwright is configured
    if (-not (Test-Path "playwright.config.js")) {
        Write-Warning "Playwright config not found, skipping E2E tests"
        return $true
    }
    
    try {
        # Install dependencies and browsers
        Write-DetailedOutput "Installing Playwright dependencies..."
        npm ci
        npx playwright install --with-deps

        # Run E2E tests
        Write-DetailedOutput "Running Playwright E2E tests..."
        npx playwright test test/e2e/ci-health-check.spec.js
        
        Write-Success "E2E tests passed"
        return $true
    }
    catch {
        Write-Error "E2E tests failed: $_"
        return $false
    }
}

# Main execution
function Main {
    Write-Info "Starting $ScriptName v$ScriptVersion"
    
    # Check prerequisites
    Test-Prerequisites
    
    # Run tests if not skipped
    if (-not $SkipTests) {
        Write-Info "Running test suite..."
        
        $testFailures = 0
        
        # Run each test suite
        if (-not (Invoke-FlutterTests)) {
            $testFailures++
        }
        
        if (-not (Invoke-NodejsTests)) {
            $testFailures++
        }
        
        if (-not (Invoke-PowerShellTests)) {
            $testFailures++
        }
        
        if (-not (Invoke-E2ETests)) {
            $testFailures++
        }
        
        # Handle test failures
        if ($testFailures -gt 0) {
            Write-Error "$testFailures test suite(s) failed"
            if ($FailOnTestFailure) {
                Write-Error "Deployment aborted due to test failures"
                exit 1
            } else {
                Write-Warning "Continuing deployment despite test failures"
            }
        } else {
            Write-Success "All tests passed!"
        }
    } else {
        Write-Warning "Skipping all tests as requested"
    }
    
    # Run deployment
    Write-Info "Starting deployment..."
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would execute deployment script"
        Write-Success "Dry run completed successfully"
        exit 0
    }
    
    # Execute the actual deployment
    $deployArgs = @()
    if ($Force) {
        $deployArgs += "--force"
    }
    if ($DetailedOutput) {
        $deployArgs += "--verbose"
    }
    
    try {
        $deployScript = Join-Path $ScriptsDir "complete_deployment.sh"
        if (Test-Path $deployScript) {
            # Use bash to run the shell script
            bash $deployScript @deployArgs
        } else {
            Write-Error "Deployment script not found: $deployScript"
            exit 1
        }
        
        Write-Success "Deployment completed successfully!"
    }
    catch {
        Write-Error "Deployment failed: $_"
        exit 1
    }
}

# Execute main function
Main
