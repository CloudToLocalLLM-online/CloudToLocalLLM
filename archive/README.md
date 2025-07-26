# CloudToLocalLLM Archive Directory

This directory contains archived files that have been moved from the repository root during the comprehensive repository cleanup performed on 2025-07-26.

## 📁 Directory Structure

```
archive/
├── backups/                    # Backup files (.backup, .build-backup)
├── deprecated/                 # Deprecated functionality
├── temp-files/                # Temporary files and artifacts
├── development-artifacts/      # IDE files and development tools
└── README.md                  # This documentation
```

## 📋 Archived Files

### Backup Files (`backups/`)
- `pubspec.yaml.backup` - Backup of main pubspec.yaml
- `pubspec.yaml.build-backup` - Build-time backup of pubspec.yaml
- `version.json.backup` - Backup of version configuration
- `version.json.build-backup` - Build-time backup of version configuration

### Development Artifacts (`development-artifacts/`)
- `augment_memory.json` - Augment AI memory file
- `cloudtolocalllm.iml` - IntelliJ IDEA module file

## 🔄 File Movements

### Documentation Reorganization
The following documentation files were moved from root to organized `docs/` subdirectories:

**Moved to `docs/summaries/`:**
- `CODE_QUALITY_REVIEW_SUMMARY.md`
- `CORS_FIX_IMPLEMENTATION_SUMMARY.md`
- `DEPLOYMENT_RESTORATION_SUMMARY.md`
- `IMPLEMENTATION_SUMMARY.md`
- `LOGIN_LOOP_FIX_SUMMARY.md`
- `ONBOARDING_SUMMARY.md`
- `PLAYWRIGHT_TEST_SETUP_SUMMARY.md`

**Moved to `docs/checklists/`:**
- `DEPLOYMENT_CHECKLIST.md`
- `LOGIN_LOOP_FIX_DEPLOYMENT_CHECKLIST.md`

**Moved to `docs/implementation-notes/`:**
- `DEPLOYMENT_SCRIPT_FIXES.md`
- `GIT_BASH_WORKFLOW_UPDATE.md`
- `MANUAL_VERSION_INCREMENT_CHANGES.md`
- `README_VISUAL_ENHANCEMENT_COMPLETE.md`

**Moved to `docs/`:**
- `README_DOCKER.md`

### Configuration File Reorganization
**Moved to `config/docker/`:**
- `Dockerfile.build`
- `Dockerfile.dev`
- `Dockerfile.nginx`

**Moved to `config/`:**
- `browsertools-mcp-config.json`
- `devtools_options.yaml`

### Script Reorganization
**Moved to `scripts/powershell/`:**
- `fix_ssh_config.ps1`
- `run-auth-loop-test.ps1`

## 🔗 Updated References

The following files were updated to reflect the new file locations:

1. **`build.sh`** - Updated Dockerfile.build reference
2. **`docker-compose.yml`** - Updated Dockerfile.nginx reference
3. **`docs/summaries/ONBOARDING_SUMMARY.md`** - Updated relative paths to root files
4. **`docs/FEATURES/FIRST_TIME_SETUP_WIZARD.md`** - Verified CONTRIBUTING.md reference

## 📚 Files Kept in Root

The following important files were intentionally kept in the repository root:

- `README.md` - Main project documentation
- `CONTRIBUTING.md` - Contribution guidelines (referenced by multiple files)
- `CHANGELOG.md` - Version history
- `LICENSE` - Project license
- `pubspec.yaml` - Flutter project configuration
- `docker-compose.yml` - Main Docker Compose configuration
- `build.sh` - Main build script

## 🎯 Benefits of Reorganization

1. **Cleaner Root Directory** - Essential files are immediately visible
2. **Better Organization** - Related files are grouped logically
3. **Improved Navigation** - Easier to find specific types of documentation
4. **Professional Structure** - Follows industry best practices
5. **Preserved History** - All moves used `git mv` to maintain version history

## 🔄 Restoration

If any archived files need to be restored, they can be moved back using:

```bash
# Example: Restore a backup file
git mv archive/backups/filename.backup ./

# Example: Restore a development artifact
mv archive/development-artifacts/filename ./
```

## 📞 Support

If you need to access any archived files or have questions about the reorganization:

1. Check this README for file locations
2. Use `git log --follow` to trace file history
3. Refer to the commit history for the reorganization changes

---

**Archive Date**: 2025-07-26  
**Reorganization Scope**: Repository root cleanup and professional structure implementation  
**Files Preserved**: All files maintained with git history where applicable
