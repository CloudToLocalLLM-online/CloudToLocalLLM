# CloudToLocalLLM Archived Scripts

**Archive Date**: 2025-01-13  
**Archive Reason**: Deployment script consolidation and cleanup  
**Retention Period**: 30 days (until 2025-02-13)

## 📋 Archived Scripts

### Deployment Scripts

#### `complete_automated_deployment.sh`
- **Original Location**: `scripts/deploy/complete_automated_deployment.sh`
- **Archive Reason**: Functionality merged into `scripts/deploy/complete_deployment.sh`
- **Key Features Preserved**:
  - Six-phase deployment structure
  - Enhanced argument parsing (--verbose, --dry-run, --force)
  - Build-time timestamp injection integration
  - Enhanced network connectivity checks
  - Comprehensive error handling with recovery
  - Multi-platform build capabilities
  - Dry-run simulation mode
- **Migration Status**: ✅ All features successfully merged
- **Replacement**: Use `scripts/deploy/complete_deployment.sh` with new enhanced options

#### `deploy_to_vps.sh`
- **Original Location**: `scripts/deploy/deploy_to_vps.sh`
- **Archive Reason**: Functionality covered by main deployment scripts
- **Key Features**: Basic VPS deployment, Docker container management
- **Migration Status**: ✅ Functionality available in consolidated scripts
- **Replacement**: Use `scripts/deploy/complete_deployment.sh` or `scripts/deploy/update_and_deploy.sh`

### Build Scripts

#### `build_and_package.sh`
- **Original Location**: `build_and_package.sh` (root directory)
- **Archive Reason**: Duplicate functionality with `scripts/packaging/build_deb.sh`
- **Key Features**: Debian package creation, lintian validation
- **Migration Status**: ✅ All features already available in scripts/packaging/build_deb.sh
- **Replacement**: Use `scripts/packaging/build_deb.sh`

### VPS Deployment Scripts (Deprecated - Migrated to Kubernetes)

#### `Deploy-CloudToLocalLLM.ps1`
- **Original Location**: `scripts/deploy/Deploy-CloudToLocalLLM.ps1`
- **Archive Reason**: VPS deployment deprecated in favor of Kubernetes deployment
- **Key Features**: Complete VPS deployment orchestration, version management, GitHub releases
- **Migration Status**: ✅ Replaced by Kubernetes deployment workflow
- **Replacement**: Use Kubernetes deployment (`kubectl apply -f k8s/`)

#### `BuildEnvironmentUtilities.ps1`
- **Original Location**: `scripts/deploy/BuildEnvironmentUtilities.ps1`
- **Archive Reason**: VPS-specific build utilities no longer needed
- **Key Features**: PowerShell build environment utilities for VPS deployment
- **Migration Status**: ✅ Functionality replaced by Kubernetes CI/CD pipeline
- **Replacement**: Use GitHub Actions workflows for automated builds

#### `sync_versions.sh`
- **Original Location**: `scripts/deploy/sync_versions.sh`
- **Archive Reason**: Version synchronization for VPS deployment
- **Key Features**: Cross-component version synchronization
- **Migration Status**: ✅ Replaced by automated versioning in CI/CD
- **Replacement**: Version management handled by GitHub Actions

#### `verify_deployment.sh`
- **Original Location**: `scripts/deploy/verify_deployment.sh`
- **Archive Reason**: VPS deployment verification
- **Key Features**: Post-deployment health checks and validation
- **Migration Status**: ✅ Replaced by Kubernetes health checks and monitoring
- **Replacement**: Use `kubectl get pods` and Kubernetes monitoring

#### `version_manager.ps1`
- **Original Location**: `scripts/deploy/version_manager.ps1`
- **Archive Reason**: PowerShell version management for VPS deployments
- **Key Features**: Version incrementing and management
- **Migration Status**: ✅ Replaced by automated versioning in CI/CD
- **Replacement**: Version management handled by GitHub Actions

## 🔄 Migration Guide

### For Users of `complete_automated_deployment.sh`

**Old Usage:**
```bash
./scripts/deploy/complete_automated_deployment.sh --verbose --dry-run
```

**New Usage:**
```bash
./scripts/deploy/complete_deployment.sh --verbose --dry-run
```

**Enhanced Options Available:**
- `--verbose, -v` - Enable verbose logging
- `--dry-run, -d` - Simulate deployment without changes
- `--force, -f` - Force deployment bypassing some safety checks
- `--skip-backup` - Skip backup creation
- `--interactive, -i` - Enable interactive mode

### For Users of `deploy_to_vps.sh`

**Old Usage:**
```bash
./scripts/deploy/deploy_to_vps.sh
```

**New Usage (Full Deployment):**
```bash
./scripts/deploy/complete_deployment.sh
```

**New Usage (Lightweight VPS-only):**
```bash
./scripts/deploy/update_and_deploy.sh
```

### For Users of `build_and_package.sh`

**Old Usage:**
```bash
./build_and_package.sh
```

**New Usage:**
```bash
./scripts/packaging/build_deb.sh
```

## 🛡️ Recovery Instructions

If you need to restore any archived script temporarily:

1. **Copy from archive:**
   ```bash
   cp scripts/archive/[script_name] scripts/deploy/
   # or
   cp scripts/archive/build_and_package.sh ./
   ```

2. **Make executable:**
   ```bash
   chmod +x scripts/deploy/[script_name]
   # or
   chmod +x build_and_package.sh
   ```

3. **Test functionality:**
   ```bash
   ./scripts/deploy/[script_name] --help
   ```

## 📊 Consolidation Benefits

### Reduced Complexity
- **Before**: 4 overlapping deployment scripts
- **After**: 2 focused deployment scripts (`complete_deployment.sh`, `update_and_deploy.sh`)

### Enhanced Functionality
- All best features from multiple scripts combined
- Consistent argument parsing across all scripts
- Improved error handling and logging
- Better dry-run and verbose capabilities

### Improved Maintenance
- Single source of truth for deployment logic
- Reduced code duplication
- Easier testing and validation
- Clearer documentation and usage

## 🗑️ Permanent Deletion Schedule

**Automatic Deletion Date**: 2025-02-13 (30 days from archive)

**Before Deletion:**
- Verify no references to archived scripts in documentation
- Confirm all functionality is available in replacement scripts
- Check for any user dependencies on archived scripts

**Manual Deletion Command (after 30 days):**
```bash
rm -rf scripts/archive/
```

## 🔗 Related Documentation

- [Deployment Workflow Guide](../../docs/DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Script Consolidation Audit Report](../../docs/DEPLOYMENT/SCRIPT_CONSOLIDATION_AUDIT.md)
- [Current Deployment Scripts](../deploy/README.md)
- [Package Building Scripts](../packaging/README.md)

## 📞 Support

If you encounter issues with the consolidated scripts or need help migrating from archived scripts:

1. **Check Migration Guide** above for direct replacements
2. **Review Enhanced Options** in the new consolidated scripts
3. **Test with Dry-Run** mode first: `--dry-run`
4. **Use Verbose Mode** for debugging: `--verbose`
5. **Temporarily Restore** archived script if needed (see Recovery Instructions)

---

**Note**: This archive is part of the CloudToLocalLLM v3.10.3 deployment script consolidation effort. All archived functionality has been preserved and enhanced in the replacement scripts.
