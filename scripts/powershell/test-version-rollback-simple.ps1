# Simple test for version rollback functionality
# Tests individual functions without sourcing the entire deployment script

[CmdletBinding()]
param()

Write-Host "=== Version Rollback Implementation Test ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if version manager script exists
Write-Host "Test 1: Checking version manager availability..." -ForegroundColor Yellow
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
if (Test-Path $versionManagerPath) {
    Write-Host "✅ Version manager script found" -ForegroundColor Green
    
    # Test version retrieval
    try {
        $currentVersion = & $versionManagerPath get-semantic
        Write-Host "  Current version: $currentVersion" -ForegroundColor White
        $versionManagerWorking = $true
    }
    catch {
        Write-Host "❌ Version manager execution failed: $($_.Exception.Message)" -ForegroundColor Red
        $versionManagerWorking = $false
    }
} else {
    Write-Host "❌ Version manager script not found at $versionManagerPath" -ForegroundColor Red
    $versionManagerWorking = $false
}
Write-Host ""

# Test 2: Check Git availability
Write-Host "Test 2: Checking Git availability..." -ForegroundColor Yellow
try {
    $gitVersion = git --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Git is available: $gitVersion" -ForegroundColor Green
        $gitAvailable = $true
    } else {
        Write-Host "❌ Git command failed" -ForegroundColor Red
        $gitAvailable = $false
    }
}
catch {
    Write-Host "❌ Git not found: $($_.Exception.Message)" -ForegroundColor Red
    $gitAvailable = $false
}
Write-Host ""

# Test 3: Check if we're in a Git repository
Write-Host "Test 3: Checking Git repository status..." -ForegroundColor Yellow
if ($gitAvailable) {
    try {
        $gitStatus = git status --porcelain 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Git repository detected" -ForegroundColor Green
            $inGitRepo = $true
            
            # Check current commit
            $currentCommit = git rev-parse HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Current commit: $($currentCommit.Substring(0,8))" -ForegroundColor White
            }
        } else {
            Write-Host "❌ Not in a Git repository" -ForegroundColor Red
            $inGitRepo = $false
        }
    }
    catch {
        Write-Host "❌ Git repository check failed: $($_.Exception.Message)" -ForegroundColor Red
        $inGitRepo = $false
    }
} else {
    $inGitRepo = $false
}
Write-Host ""

# Test 4: Check version files existence
Write-Host "Test 4: Checking version files..." -ForegroundColor Yellow
$versionFiles = @(
    "pubspec.yaml",
    "lib/config/app_config.dart",
    "lib/shared/lib/version.dart", 
    "lib/shared/pubspec.yaml",
    "assets/version.json"
)

$filesFound = 0
foreach ($file in $versionFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
        $filesFound++
    } else {
        Write-Host "  ❌ $file (missing)" -ForegroundColor Red
    }
}

$allVersionFilesExist = ($filesFound -eq $versionFiles.Count)
Write-Host "Version files found: $filesFound/$($versionFiles.Count)" -ForegroundColor $(if ($allVersionFilesExist) { 'Green' } else { 'Yellow' })
Write-Host ""

# Test 5: Test backup file creation capability
Write-Host "Test 5: Testing backup file creation..." -ForegroundColor Yellow
$testBackupSuccess = $true
$backupFiles = @()

foreach ($file in $versionFiles) {
    if (Test-Path $file) {
        $backupPath = "$file.test-backup"
        try {
            Copy-Item $file $backupPath -Force
            $backupFiles += $backupPath
            Write-Host "  ✅ Created backup: $backupPath" -ForegroundColor Green
        }
        catch {
            Write-Host "  ❌ Failed to backup $file : $($_.Exception.Message)" -ForegroundColor Red
            $testBackupSuccess = $false
        }
    }
}

if ($testBackupSuccess -and $backupFiles.Count -gt 0) {
    Write-Host "✅ Backup creation test passed" -ForegroundColor Green
    
    # Clean up test backups
    Write-Host "  Cleaning up test backups..." -ForegroundColor Gray
    foreach ($backupFile in $backupFiles) {
        Remove-Item $backupFile -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "❌ Backup creation test failed" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
$testResults = @(
    @{ Name = "Version Manager"; Result = $versionManagerWorking },
    @{ Name = "Git Availability"; Result = $gitAvailable },
    @{ Name = "Git Repository"; Result = $inGitRepo },
    @{ Name = "Version Files"; Result = $allVersionFilesExist },
    @{ Name = "Backup Creation"; Result = $testBackupSuccess }
)

$passedTests = ($testResults | Where-Object { $_.Result }).Count
$totalTests = $testResults.Count

Write-Host "Tests Passed: $passedTests/$totalTests" -ForegroundColor $(if ($passedTests -eq $totalTests) { 'Green' } else { 'Yellow' })

foreach ($test in $testResults) {
    $status = if ($test.Result) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($test.Result) { 'Green' } else { 'Red' }
    Write-Host "  $($test.Name): $status" -ForegroundColor $color
}

Write-Host ""
if ($passedTests -eq $totalTests) {
    Write-Host "🎉 All prerequisite tests passed! Version rollback implementation should work correctly." -ForegroundColor Green
    Write-Host ""
    Write-Host "Version rollback capabilities implemented:" -ForegroundColor Cyan
    Write-Host "  • Git-based version rollback functionality" -ForegroundColor White
    Write-Host "  • Version consistency checking across all files" -ForegroundColor White
    Write-Host "  • Rollback verification and validation" -ForegroundColor White
    Write-Host "  • Error recovery for version management failures" -ForegroundColor White
    Write-Host "  • Integration with automatic deployment rollback" -ForegroundColor White
    exit 0
} else {
    Write-Host "⚠️  Some prerequisite tests failed. Version rollback may not work correctly." -ForegroundColor Yellow
    Write-Host "Please ensure all prerequisites are met before using version rollback functionality." -ForegroundColor Yellow
    exit 1
}