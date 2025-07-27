# CloudToLocalLLM Deployment Scripts Overview

This document provides a comprehensive overview of all deployment-related scripts in the CloudToLocalLLM project.

## 📋 Table of Contents

- [Primary Deployment Scripts](#primary-deployment-scripts)
- [Version Management Scripts](#version-management-scripts)
- [Verification Scripts](#verification-scripts)
- [Platform-Specific Scripts](#platform-specific-scripts)
- [Utility Scripts](#utility-scripts)
- [Script Usage Examples](#script-usage-examples)

---

## Primary Deployment Scripts

### 🚀 `scripts/deploy/complete_deployment.sh` (RECOMMENDED)

**Purpose**: Fully automated deployment with strict quality verification and zero-tolerance policy.

**Features**:
- Automated deployment with zero-tolerance quality verification
- Automatic rollback on any warnings or errors
- Comprehensive health checks and validation
- SSL certificate verification
- Container health monitoring

**Usage**:
```bash
# Basic deployment
./scripts/deploy/complete_deployment.sh --force

# With verbose output
./scripts/deploy/complete_deployment.sh --force --verbose

# Dry run (preview only)
./scripts/deploy/complete_deployment.sh --dry-run
```

### 🔄 `scripts/deploy/update_and_deploy.sh`

**Purpose**: Deploys the multi-container architecture to a VPS.

**Features**:
- Multi-container Docker Compose deployment
- Automated container orchestration
- Service health verification
- Basic rollback capabilities

### 🔍 `scripts/deploy/verify_deployment.sh`

**Purpose**: Strict verification script that enforces zero warnings/errors policy.

**Features**:
- Comprehensive deployment verification
- Zero-tolerance quality gates
- SSL certificate validation
- Performance benchmarks
- Security header validation

**Usage**:
```bash
# Basic verification
./scripts/deploy/verify_deployment.sh

# Strict mode (warnings count as failures)
./scripts/deploy/verify_deployment.sh --strict

# Custom timeout
./scripts/deploy/verify_deployment.sh --timeout 60
```

### 🎯 `scripts/deploy/complete_automated_deployment.sh`

**Purpose**: Orchestrates a full deployment workflow including versioning, building, and distributing.

**Features**:
- End-to-end deployment automation
- Version management integration
- Build process orchestration
- Distribution and packaging

---

## Version Management Scripts

### 📊 `scripts/version_manager.sh`

**Purpose**: Manages project version numbers across different files.

**Features**:
- Semantic version management
- Build number generation (timestamp-based)
- Multi-file version synchronization
- Version validation

**Usage**:
```bash
# Get current version
./scripts/version_manager.sh get

# Increment version types
./scripts/version_manager.sh increment major    # 3.12.1 → 4.0.0
./scripts/version_manager.sh increment minor    # 3.12.1 → 3.13.0
./scripts/version_manager.sh increment patch    # 3.12.1 → 3.12.2
./scripts/version_manager.sh increment build    # Keep version, new build number

# Set specific version
./scripts/version_manager.sh set 3.13.0

# Validate version format
./scripts/version_manager.sh validate
```

### 🏷️ `scripts/powershell/version_manager.ps1`

**Purpose**: PowerShell version of the version manager for Windows environments.

**Features**:
- Windows-compatible version management
- PowerShell-native implementation
- Same functionality as bash version
- Integration with Windows deployment workflows

---

## Verification Scripts

### ✅ Quality Gate Scripts

#### `scripts/deploy/verify_deployment.sh`
- Comprehensive deployment verification
- Zero-tolerance quality gates
- Automated rollback triggers

#### `scripts/powershell/Deploy-CloudToLocalLLM.ps1`
- Windows PowerShell deployment orchestration
- Integrated quality verification
- Cross-platform deployment support

---

## Platform-Specific Scripts

### 🐧 Linux Scripts

#### `scripts/build_unified_package.sh`
**Purpose**: Builds and packages the unified Flutter application for static download distribution.

**Process**:
1. Builds the Flutter application in release mode
2. Copies necessary assets and libraries
3. Creates a distributable archive (e.g., `.tar.gz`)

**Usage**:
```bash
./scripts/build_unified_package.sh
```
Output will be in the `dist/` directory.

#### `scripts/packaging/build_deb.sh`
**Purpose**: Creates DEB packages for Debian/Ubuntu systems.

**Features**:
- Native package management integration
- Automatic dependency handling
- System service integration
- Desktop environment integration

#### `scripts/packaging/build_appimage.sh`
**Purpose**: Creates portable AppImage packages for Linux.

**Features**:
- Portable, no-installation-needed package
- Universal Linux compatibility
- Self-contained application bundle

### 🪟 Windows Scripts

#### `scripts/powershell/Deploy-CloudToLocalLLM.ps1`
**Purpose**: Windows PowerShell deployment orchestration.

**Features**:
- Native Windows deployment
- PowerShell-based automation
- Integration with Windows services
- Cross-platform compatibility

---

## Utility Scripts

### 🔧 Build Scripts

#### `scripts/build/`
Directory containing various build automation scripts:
- Component building scripts
- Asset compilation scripts
- Platform-specific build tools

#### `scripts/packaging/`
Directory containing packaging scripts for different platforms:
- DEB package creation
- AppImage generation
- Windows installer creation

#### `scripts/release/`
Directory containing release management scripts:
- Release preparation
- Asset generation
- Distribution automation

---

## Script Usage Examples

### 🚀 Complete Deployment Workflow

```bash
# 1. Update version
./scripts/version_manager.sh increment minor

# 2. Deploy with verification
./scripts/deploy/complete_deployment.sh --force

# 3. Verify deployment
./scripts/deploy/verify_deployment.sh --strict
```

### 🔄 Development Deployment

```bash
# Quick development deployment
./scripts/deploy/update_and_deploy.sh

# Verify basic functionality
./scripts/deploy/verify_deployment.sh
```

### 📦 Package Creation

```bash
# Create Linux packages
./scripts/packaging/build_deb.sh
./scripts/packaging/build_appimage.sh

# Create unified package
./scripts/build_unified_package.sh
```

### 🔍 Verification Only

```bash
# Basic verification
./scripts/deploy/verify_deployment.sh

# Strict verification (warnings = failures)
./scripts/deploy/verify_deployment.sh --strict

# Custom timeout
./scripts/deploy/verify_deployment.sh --timeout 120
```

---

## Script Dependencies

### 📋 Required Tools

**For Deployment Scripts**:
- Docker and Docker Compose
- SSH access to target server
- Git (for version management)
- curl (for verification)

**For Build Scripts**:
- Flutter SDK
- Platform-specific build tools
- Packaging utilities (dpkg, AppImageTool, etc.)

**For Version Management**:
- Git
- sed/awk (Linux/macOS)
- PowerShell (Windows)

---

## Related Documentation

- [Complete Deployment Workflow](COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md)
- [Versioning Strategy](VERSIONING_STRATEGY.md)
- [Main Scripts README](../../scripts/README.md)

---

*For detailed information about any specific script, see the respective README files in each directory or the script's built-in help (`--help` flag).*
