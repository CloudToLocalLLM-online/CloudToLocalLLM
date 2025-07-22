# Test script for version rollback functionality
# This script tests the version rollback capabilities without affecting the actual deployment

[CmdletBinding()]
param(
    [switch]$TestVerbose
)

# Import the deployment script functions
$deploymentScript = Join-Path $PSScriptRoot "Deploy-CloudToLocalLLM.ps1"
if (-not (Test-Path $deploymentScript)) {
    Write-Error "Deploy-CloudToLocalLLM.ps1 not found"
    exit 1
}

# Source the deployment script to get access to functions
. $deploymentScript -DryRun

Write-Host "=== Version Rollback Functionality Test ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Version rollback capability check
Write-Host "Test 1: Testing version rollback capability..." -ForegroundColor Yellow
$rollbackCapable = Test-VersionRollbackCapability
if ($rollbackCapable) {
    Write-Host "✅ Version rollback capability: PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ Version rollback capability: FAILED" -ForegroundColor Red
}
Write-Host ""

# Test 2: Version consistency check
Write-Host "Test 2: Testing version consistency check..." -ForegroundColor Yellow
$consistencyCheck = Test-VersionConsistency
if ($consistencyCheck) {
    Write-Host "✅ Version consistency check: PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ Version consistency check: FAILED" -ForegroundColor Red
}
Write-Host ""

# Test 3: Version backup creation (dry run)
Write-Host "Test 3: Testing version backup creation..." -ForegroundColor Yellow
$backupSuccess = Backup-VersionState
if ($backupSuccess) {
    Write-Host "✅ Version backup creation: PASSED" -ForegroundColor Green
    
    # Display backup information
    if ($Script:VersionBackup) {
        Write-Host "Backup Details:" -ForegroundColor Cyan
        Write-Host "  Git Commit: $($Script:VersionBackup.GitCommit)" -ForegroundColor White
        Write-Host "  Version: $($Script:VersionBackup.SemanticVersion)" -ForegroundColor White
        Write-Host "  Build Number: $($Script:VersionBackup.BuildNumber)" -ForegroundColor White
        Write-Host "  Files Backed Up: $($Script:VersionBackup.Files.Count)" -ForegroundColor White
    }
} else {
    Write-Host "❌ Version backup creation: FAILED" -ForegroundColor Red
}
Write-Host ""

# Test 4: Cleanup test backup files
if ($Script:VersionBackup -and $Script:VersionBackup.Files) {
    Write-Host "Test 4: Cleaning up test backup files..." -ForegroundColor Yellow
    $cleanupCount = 0
    foreach ($fileInfo in $Script:VersionBackup.Files) {
        if (Test-Path $fileInfo.Backup) {
            Remove-Item $fileInfo.Backup -Force -ErrorAction SilentlyContinue
            $cleanupCount++
        }
    }
    Write-Host "✅ Cleaned up $cleanupCount backup files" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
$testResults = @(
    @{ Name = "Rollback Capability"; Result = $rollbackCapable },
    @{ Name = "Version Consistency"; Result = $consistencyCheck },
    @{ Name = "Backup Creation"; Result = $backupSuccess }
)

$passedTests = ($testResults | Where-Object { $_.Result }).Count
$totalTests = $testResults.Count

Write-Host "Tests Passed: $passedTests/$totalTests" -ForegroundColor $(if ($passedTests -eq $totalTests) { 'Green' } else { 'Yellow' })

foreach ($test in $testResults) {
    $status = if ($test.Result) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($test.Result) { 'Green' } else { 'Red' }
    Write-Host "  $($test.Name): $status" -ForegroundColor $color
}

if ($passedTests -eq $totalTests) {
    Write-Host ""
    Write-Host "🎉 All version rollback tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "⚠️  Some tests failed. Check the implementation." -ForegroundColor Yellow
    exit 1
}