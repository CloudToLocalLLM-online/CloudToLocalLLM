# CloudToLocalLLM Development Workflow

This document outlines the development workflow, tools, and automation available for CloudToLocalLLM development.

## 📋 Table of Contents

- [Development Workflow Overview](#development-workflow-overview)
- [Quick Development Push](#quick-development-push)
- [Automated Development Workflow](#automated-development-workflow)
- [Development Standards](#development-standards)
- [Git Hooks](#git-hooks)
- [Project Structure](#project-structure)
- [Building Applications](#building-applications)

---

## Development Workflow Overview

CloudToLocalLLM includes automated development workflow tools to streamline the development process, enforce quality standards, and automate common tasks.

### 🎯 **Workflow Goals**
- Maintain high code quality standards
- Automate repetitive tasks
- Ensure consistent development practices
- Streamline the commit and push process
- Validate changes before deployment

---

## Quick Development Push

When you've completed development work and documentation, use the quick push script for streamlined commits:

### 🚀 **Basic Usage**

```bash
# Auto-commit and push with generated message
.\push-dev.ps1

# Custom commit message
.\push-dev.ps1 -m "Complete zrok service implementation"

# Preview changes without committing
.\push-dev.ps1 -dry

# Force push (skip validation)
.\push-dev.ps1 -f
```

### 📝 **Features**
- Automatic commit message generation based on changes
- Pre-commit validation and checks
- Dry-run mode for previewing changes
- Force mode for emergency pushes
- Integration with development standards

---

## Automated Development Workflow

For comprehensive development workflow automation, use the complete development workflow script:

### 🔧 **Complete Workflow Script**

```bash
# Complete workflow with validation
.\scripts\powershell\Complete-DevWorkflow.ps1

# Skip static analysis
.\scripts\powershell\Complete-DevWorkflow.ps1 -SkipAnalysis

# Create development release
.\scripts\powershell\Complete-DevWorkflow.ps1 -CreateDevRelease
```

### 🎯 **Workflow Steps**
1. **Code Analysis**: Flutter analyze and PSScriptAnalyzer
2. **Documentation Validation**: Check documentation completeness
3. **Platform Compliance**: Verify platform abstraction patterns
4. **Commit Generation**: Create meaningful commit messages
5. **Quality Gates**: Ensure all standards are met
6. **Optional Release**: Create development releases

---

## Development Standards

The automated workflow enforces the following standards:

### ✅ **Code Quality Standards**
- **Flutter analyze with zero issues**: All Dart code must pass static analysis
- **PSScriptAnalyzer compliance**: PowerShell scripts must meet quality standards
- **Documentation completeness validation**: All features must be documented
- **Platform abstraction pattern compliance**: Cross-platform compatibility
- **Automatic commit message generation**: Based on actual changes made

### 📊 **Quality Metrics**
- Zero warnings in Flutter analyze
- Zero errors in PSScriptAnalyzer
- Complete documentation coverage
- Proper platform abstraction usage
- Meaningful commit messages

### 🔍 **Validation Process**
1. **Static Analysis**: Automated code quality checks
2. **Documentation Review**: Ensure all changes are documented
3. **Platform Compatibility**: Verify cross-platform support
4. **Commit Message Quality**: Generate descriptive commit messages
5. **Pre-push Validation**: Final checks before pushing

---

## Git Hooks

Install Git hooks for automatic push when documentation is complete:

### 🪝 **Installation**

```bash
# Copy post-commit hook
Copy-Item scripts/git-hooks/post-commit .git/hooks/post-commit -Force

# Make executable (Linux/macOS)
chmod +x .git/hooks/post-commit
```

### 🎯 **Hook Features**
- Automatic push when documentation markers are present
- Integration with development workflow
- Conditional execution based on commit content
- Support for development markers and flags

### 📝 **Documentation Markers**
The hooks look for specific markers in commits to trigger automatic actions:
- `[DOCS_COMPLETE]`: Triggers automatic push
- `[DEV_RELEASE]`: Creates development release
- `[SKIP_HOOKS]`: Bypasses hook execution

---

## Project Structure

CloudToLocalLLM follows an organized directory structure for better maintainability and development:

### 🏗️ **Core Directories**

#### **Application Code**
- `services/api-backend/`: Node.js backend for API, Auth0 integration, and streaming proxy management
- `services/streaming-proxy/`: Node.js code for lightweight, ephemeral proxy servers
- `lib/`: Unified Flutter application code (UI, chat, system tray, settings, services)
- `web/`: Entry point and configuration for the Flutter web application
- `assets/`: Static assets for the Flutter application (images, fonts, version info)

#### **Documentation**
- `docs/`: Comprehensive documentation organized by topic
  - `ARCHITECTURE/`: System architecture diagrams and explanations
  - `DEPLOYMENT/`: Deployment guides, strategies, and workflows
  - `OPERATIONS/`: Operational guides, maintenance, and troubleshooting
  - `USER_DOCUMENTATION/`: User-facing guides and FAQs
  - `DEVELOPMENT/`: Developer guides, contribution guidelines

#### **Scripts & Automation**
- `scripts/`: Organized build, deployment, packaging, and utility scripts
  - `build/`: Scripts for building application components
  - `deploy/`: Scripts for deploying to various environments
  - `packaging/`: Scripts for creating distributable packages
  - `release/`: Scripts for managing releases
  - `utils/`: Helper and utility scripts
  - `README.md`: Detailed overview of available scripts

#### **Configuration & Infrastructure**
- `config/`: Configuration files for various platforms and services
- `docker/`: Dockerfiles and related files for building service containers

#### **Development Tools**
- `.vscode/`: VS Code editor configurations, launch settings, recommended extensions
- `analysis_options.yaml`: Dart static analysis settings
- `pubspec.yaml`: Flutter project dependencies and metadata

For detailed information about any component, see the respective README files in each directory.

---

## Building Applications

Instructions for building and packaging client applications for different platforms:

### 🐧 **Linux Development**

#### **General Static Package**
Uses `scripts/build_unified_package.sh`:

```bash
./scripts/build_unified_package.sh
```

**Process**:
1. Builds the Flutter application in release mode
2. Copies necessary assets and libraries
3. Creates a distributable archive (e.g., `.tar.gz`)

Output will be in the `dist/` directory.

#### **Distribution Methods**
**Available Package Formats**:
- **AppImage**: `scripts/packaging/build_appimage.sh` (Recommended)
- **Source Build**: `scripts/build_unified_package.sh`

**Recommended for Linux**:
```bash
# Build AppImage for universal Linux compatibility
./scripts/packaging/build_appimage.sh
```

**AppImage Benefits**:
- Universal Linux compatibility
- No installation required
- Portable application bundle
- Runs on most Linux distributions
- Self-contained with all dependencies

### 🪟 **Windows Development**

#### **Prerequisites**
- Install [Ollama](https://ollama.ai/) for local LLM support
- Ensure Windows 10/11 with latest updates
- Flutter SDK properly configured

#### **Building**
```bash
# Build Windows release
flutter build windows --release
```

#### **Installation Options**
- Download from [releases page](https://github.com/imrightguy/CloudToLocalLLM/releases)
- Build from source using Flutter
- Use development builds for testing

#### **Integration Features**
- System tray integration
- Desktop environment compatibility
- Windows service support

### 🍎 **macOS Development**
**Status**: Planned for future releases

---

## Development Environment Setup

### 📋 **Prerequisites**
- Flutter SDK (3.8+)
- Dart SDK (included with Flutter)
- Git
- Docker (for containerized development)
- Platform-specific tools (Xcode for macOS, Visual Studio for Windows)

### 🔧 **IDE Configuration**
- VS Code with Flutter extension (recommended)
- IntelliJ IDEA with Flutter plugin
- Android Studio with Flutter plugin

### 📝 **Configuration Files**
- `.vscode/`: Pre-configured VS Code settings
- `analysis_options.yaml`: Dart analysis configuration
- `pubspec.yaml`: Project dependencies and metadata

---

## Related Documentation

- [Developer Onboarding](DEVELOPER_ONBOARDING.md)
- [API Documentation](API_DOCUMENTATION.md)
- [Contributing Guidelines](../../CONTRIBUTING.md)
- [System Architecture](../ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
- [Deployment Overview](../DEPLOYMENT/DEPLOYMENT_OVERVIEW.md)

---

*For questions about development workflow, please see our [developer onboarding guide](DEVELOPER_ONBOARDING.md) or [open an issue](https://github.com/imrightguy/CloudToLocalLLM/issues).*
