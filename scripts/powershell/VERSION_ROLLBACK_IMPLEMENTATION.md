# Version Rollback Implementation

This document describes the version rollback capabilities implemented in the CloudToLocalLLM deployment workflow as part of task 3.2.

## Overview

The version rollback functionality provides comprehensive Git-based version rollback capabilities, version consistency checking across all files, rollback verification and validation, and error recovery for version management failures.

## Implementation Details

### Core Functions

#### 1. `Backup-VersionState`
Creates a comprehensive backup of the current version state before making any changes.

**Features:**
- Stores current Git commit hash for rollback reference
- Backs up all version-related files (pubspec.yaml, app_config.dart, version.dart, etc.)
- Captures current version and build number information
- Creates timestamped backup for audit trail

**Usage:**
```powershell
$backupSuccess = Backup-VersionState
```

#### 2. `Test-VersionConsistency`
Validates that all version files contain consistent version information.

**Features:**
- Checks version consistency across all version files
- Validates semantic version format
- Compares build numbers across files
- Reports specific inconsistencies found

**Files Checked:**
- `pubspec.yaml`
- `lib/config/app_config.dart`
- `lib/shared/lib/version.dart`
- `lib/shared/pubspec.yaml`
- `assets/version.json`

**Usage:**
```powershell
$isConsistent = Test-VersionConsistency
```

#### 3. `Invoke-VersionRollback`
Performs version rollback using backed up files.

**Features:**
- Restores all version files from backup
- Verifies rollback success with consistency check
- Cleans up backup files after successful rollback
- Falls back to Git-based recovery if file restoration fails

**Usage:**
```powershell
$rollbackSuccess = Invoke-VersionRollback
```

#### 4. `Invoke-GitVersionRecovery`
Git-based version recovery as a fallback mechanism.

**Features:**
- Uses Git to restore version files to previous commit state
- Handles uncommitted changes by stashing
- Provides manual recovery instructions if automated recovery fails
- Verifies recovery with consistency checks

**Usage:**
```powershell
$recoverySuccess = Invoke-GitVersionRecovery
```

#### 5. `Test-VersionRollbackCapability`
Tests whether version rollback functionality is available.

**Features:**
- Checks Git availability and repository status
- Validates version manager script availability
- Warns about uncommitted changes
- Returns capability status

**Usage:**
```powershell
$canRollback = Test-VersionRollbackCapability
```

#### 6. `Update-ProjectVersionWithRollback`
Enhanced version management function with integrated rollback support.

**Features:**
- Creates version backup before making changes
- Validates version consistency before and after updates
- Automatically triggers rollback on failure
- Integrates with existing version_manager.ps1 script

**Usage:**
```powershell
$versionUpdateSuccess = Update-ProjectVersionWithRollback
```

### Integration with Deployment Workflow

#### Automatic Rollback Integration
The `Invoke-AutomaticRollback` function has been enhanced to include version rollback:

1. **Local Version Rollback**: Restores local version files to previous state
2. **VPS Deployment Rollback**: Rolls back VPS deployment using Git
3. **Verification**: Verifies both local and VPS rollback success
4. **Cleanup**: Removes backup files after successful rollback

#### Error Recovery
Comprehensive error recovery with detailed manual instructions:

- **Local Recovery**: Git commands to restore version files
- **VPS Recovery**: SSH commands to restore VPS deployment
- **Verification**: Commands to verify system state after recovery

## Usage Examples

### Basic Version Rollback Test
```powershell
# Test rollback capability
if (Test-VersionRollbackCapability) {
    Write-Host "Version rollback is available"
} else {
    Write-Host "Version rollback is not available"
}
```

### Manual Version Rollback
```powershell
# Create backup
if (Backup-VersionState) {
    # Attempt version update
    if (-not (Update-ProjectVersionWithRollback)) {
        # Rollback on failure
        Invoke-VersionRollback
    }
}
```

### Version Consistency Check
```powershell
# Check if all version files are consistent
if (Test-VersionConsistency) {
    Write-Host "All version files are consistent"
} else {
    Write-Host "Version inconsistencies detected"
}
```

## Error Handling

### Rollback Failure Recovery
If automatic rollback fails, the system provides detailed manual recovery instructions:

1. **Local Version Recovery:**
   ```bash
   git checkout HEAD -- pubspec.yaml lib/config/app_config.dart lib/shared/lib/version.dart lib/shared/pubspec.yaml assets/version.json
   ```

2. **VPS Recovery:**
   ```bash
   ssh user@vps
   cd /opt/cloudtolocalllm
   git reset --hard HEAD~1
   ./scripts/deploy/complete_deployment.sh
   ./scripts/deploy/verify_deployment.sh
   ```

### Version Consistency Issues
When version inconsistencies are detected:
- Specific files and discrepancies are reported
- System prevents deployment until consistency is restored
- Manual correction guidance is provided

## Testing

### Prerequisite Tests
Run the prerequisite test to verify rollback capability:
```powershell
.\scripts\powershell\test-version-rollback-simple.ps1
```

This test verifies:
- Version manager availability
- Git availability and repository status
- Version files existence
- Backup file creation capability

### Integration Testing
The rollback functionality is automatically tested during deployment failures when `AutoRollback` is enabled.

## Configuration

### Deployment Script Parameters
- `AutoRollback`: Enable automatic rollback on deployment failure (default: true)
- `DryRun`: Preview rollback actions without executing them

### Version Files Managed
The rollback system manages these version files:
- `pubspec.yaml` - Main Flutter project version
- `lib/config/app_config.dart` - Application configuration version
- `lib/shared/lib/version.dart` - Shared library version constants
- `lib/shared/pubspec.yaml` - Shared library pubspec version
- `assets/version.json` - Asset version information

## Requirements Compliance

This implementation satisfies the requirements specified in task 3.2:

✅ **Git-based version rollback functionality**
- Implemented with `Invoke-GitVersionRecovery` and Git commit tracking

✅ **Version consistency checking across all files**
- Implemented with `Test-VersionConsistency` function

✅ **Rollback verification and validation**
- Integrated verification in all rollback functions

✅ **Error recovery for version management failures**
- Comprehensive error handling with manual recovery instructions

✅ **Requirements 4.4, 5.4 compliance**
- Automatic version rollback on deployment failure
- Strict verification with rollback on failure

## Maintenance

### Adding New Version Files
To add new version files to the rollback system:

1. Add the file path to the `$versionFiles` array in `Backup-VersionState`
2. Add version consistency checks in `Test-VersionConsistency`
3. Update the documentation

### Troubleshooting
Common issues and solutions:

- **Git not available**: Ensure Git is installed and in PATH
- **Not in Git repository**: Run from project root directory
- **Version inconsistencies**: Run version manager to fix inconsistencies
- **Backup failures**: Check file permissions and disk space

## Security Considerations

- Backup files are created with same permissions as original files
- Git operations use existing repository credentials
- No sensitive information is logged in rollback operations
- Backup files are automatically cleaned up after successful operations