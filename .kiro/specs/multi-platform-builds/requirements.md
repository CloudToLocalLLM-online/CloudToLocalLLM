# Requirements Document

## Introduction

This document specifies the requirements for implementing a comprehensive multi-platform build system using GitHub-hosted runners for the CloudToLocalLLM desktop application. The system will support building for Windows, Linux, and Android platforms using GitHub's free runner infrastructure for public repositories. This approach eliminates infrastructure costs, reduces maintenance overhead, and provides consistent, reproducible builds across all platforms.

## Glossary

- **GitHub-Hosted Runner**: Virtual machines managed by GitHub Actions that execute workflow jobs at no cost for public repositories
- **Build Matrix**: GitHub Actions feature that allows running the same job across multiple configurations (OS, versions, etc.)
- **Build Workflow**: The `.github/workflows/build-release.yml` file that orchestrates desktop application builds
- **Flutter Build**: The process of compiling Flutter source code into native platform executables
- **Inno Setup**: Windows installer creation tool used to package the Windows application
- **Flatpak**: Universal Linux package format that runs on all major Linux distributions with sandboxing
- **.deb Package**: Debian package format for native integration on Debian/Ubuntu-based systems
- **APK**: Android Package file format for distributing Android applications
- **Build Artifacts**: Compiled binaries, installers, and checksums produced by the build process
- **Release Assets**: Files attached to GitHub releases for user download
- **Build Cache**: Stored dependencies and build outputs to speed up subsequent builds
- **Chocolatey**: Windows package manager used to install build dependencies
- **Winget**: Microsoft's official Windows package manager for installing applications

## Requirements

### Requirement 1

**User Story:** As a developer, I want all platform builds to run on GitHub-hosted runners, so that I have zero infrastructure costs and minimal maintenance overhead.

#### Acceptance Criteria

1. THE Build Workflow SHALL use `windows-latest` GitHub-hosted runners for Windows builds
2. THE Build Workflow SHALL use `ubuntu-latest` GitHub-hosted runners for Linux builds
3. THE Build Workflow SHALL use `ubuntu-latest` GitHub-hosted runners for Android builds
4. THE Build Workflow SHALL install all required build dependencies on each runner
5. THE Build Workflow SHALL complete successfully on GitHub-hosted infrastructure
6. THE Build Workflow SHALL produce identical build artifacts to the current self-hosted process

### Requirement 2

**User Story:** As a developer, I want all build dependencies automatically installed on runners, so that builds are reproducible and don't require manual setup.

#### Acceptance Criteria

1. THE Build Workflow SHALL install Flutter SDK at the specified version using the subosito/flutter-action
2. THE Windows build SHALL install Inno Setup using Chocolatey or Winget package manager
3. THE Linux build SHALL install Flatpak build tools (flatpak-builder) and .deb packaging tools (dpkg-dev)
4. THE Android build SHALL install Android SDK and NDK at specified versions
5. THE Build Workflow SHALL verify all dependencies are installed before starting each platform build
6. WHEN dependencies are missing, THE Build Workflow SHALL fail with clear error messages indicating which dependency is missing

### Requirement 3

**User Story:** As a developer, I want the build process to be fast and efficient, so that I can iterate quickly on releases.

#### Acceptance Criteria

1. THE Build Workflow SHALL cache Flutter pub dependencies between builds
2. THE Build Workflow SHALL cache Dart tool outputs between builds
3. THE Build Workflow SHALL cache platform-specific build tools (Inno Setup, Android SDK)
4. THE Build Workflow SHALL restore cached dependencies before running `flutter pub get`
5. WHEN cache is available, THE Build Workflow SHALL complete at least 30% faster than without cache
6. THE Build Workflow SHALL use cache keys based on `pubspec.lock` hash and platform to ensure cache validity

### Requirement 4

**User Story:** As a release manager, I want the build workflow to create platform-specific packages, so that users have appropriate installation options for each platform.

#### Acceptance Criteria

1. THE Windows build SHALL create an installer (.exe) using Inno Setup
2. THE Windows build SHALL create a portable ZIP package
3. THE Linux build SHALL create a Flatpak package
4. THE Linux build SHALL create a .deb package
5. THE Android build SHALL create an APK file
6. THE Build Workflow SHALL generate SHA256 checksums for all packages
7. THE Build Workflow SHALL upload all artifacts to the GitHub release
8. WHEN the build completes, THE Build Workflow SHALL verify all expected artifacts exist before creating the release

### Requirement 5

**User Story:** As a user downloading the application, I want to verify the integrity of downloaded files, so that I can ensure they haven't been tampered with.

#### Acceptance Criteria

1. THE Build Workflow SHALL generate SHA256 checksums for all release artifacts
2. THE Build Workflow SHALL store checksums in separate `.sha256` files
3. THE Build Workflow SHALL include checksums in the release assets
4. THE Checksum files SHALL follow the format: `<hash>  <filename>`
5. THE Build Workflow SHALL verify checksums are generated before uploading to release

### Requirement 6

**User Story:** As a developer, I want the build workflow to handle version management automatically, so that releases are properly tagged and versioned.

#### Acceptance Criteria

1. THE Build Workflow SHALL extract version from `pubspec.yaml` for tagged releases
2. THE Build Workflow SHALL generate build numbers in `YYYYMMDDHHMM` format
3. THE Build Workflow SHALL create git tags in `vX.Y.Z` format for releases
4. THE Build Workflow SHALL name release artifacts with the version number and platform
5. WHEN a version tag already exists, THE Build Workflow SHALL skip tag creation and continue with the release

### Requirement 7

**User Story:** As a developer, I want the build workflow to fail fast with clear error messages, so that I can quickly identify and fix issues.

#### Acceptance Criteria

1. WHEN Flutter installation fails, THE Build Workflow SHALL stop and report the Flutter setup error
2. WHEN dependency installation fails, THE Build Workflow SHALL stop and report which dependency failed
3. WHEN a platform build fails, THE Build Workflow SHALL stop that platform's job and report the compilation error
4. WHEN artifact creation fails, THE Build Workflow SHALL stop and report which artifact failed
5. THE Build Workflow SHALL include detailed logs for each step to aid debugging
6. THE Build Workflow SHALL allow other platform builds to continue if one platform fails

### Requirement 8

**User Story:** As a developer, I want the build workflow to be triggered automatically on version tags, so that releases are created consistently.

#### Acceptance Criteria

1. WHEN a tag matching `v*` pattern is pushed, THE Build Workflow SHALL trigger automatically
2. THE Build Workflow SHALL support manual triggering via workflow_dispatch
3. THE Build Workflow SHALL only create GitHub releases for tag-triggered builds
4. THE Build Workflow SHALL use concurrency controls to prevent duplicate builds
5. WHEN multiple tags are pushed simultaneously, THE Build Workflow SHALL queue builds sequentially

### Requirement 9

**User Story:** As a developer, I want the build workflow to generate comprehensive release notes, so that users understand what changed in each version.

#### Acceptance Criteria

1. THE Build Workflow SHALL generate release notes including version number and changelog
2. THE Build Workflow SHALL include download instructions for each platform (Windows, Linux, Android)
3. THE Build Workflow SHALL include SHA256 checksum information in release notes
4. THE Build Workflow SHALL link to the full changelog on GitHub
5. THE Build Workflow SHALL use the generated release notes when creating the GitHub release

### Requirement 10

**User Story:** As a developer, I want the build workflow to be maintainable and well-documented, so that other contributors can understand and modify it.

#### Acceptance Criteria

1. THE Build Workflow SHALL include comments explaining each major step
2. THE Build Workflow SHALL use descriptive job and step names
3. THE Build Workflow SHALL follow GitHub Actions best practices for security and performance
4. THE Build Workflow SHALL use pinned action versions for reproducibility
5. THE Build Workflow documentation SHALL include setup instructions for all supported platforms

### Requirement 11

**User Story:** As a developer, I want the build workflow to use a matrix strategy, so that platform builds run in parallel and complete faster.

#### Acceptance Criteria

1. THE Build Workflow SHALL use a build matrix to define platform configurations
2. THE Build Workflow SHALL run Windows, Linux, and Android builds in parallel
3. THE Build Workflow SHALL collect artifacts from all platform builds before creating the release
4. THE Build Workflow SHALL wait for all platform builds to complete before creating the release
5. WHEN one platform build fails, THE Build Workflow SHALL still create a release with successful platform artifacts

### Requirement 12

**User Story:** As a Linux user, I want the application packaged for my distribution, so that I can install it using my preferred package format.

#### Acceptance Criteria

1. THE Linux build SHALL create a Flatpak package
2. THE Linux build SHALL create a .deb package
3. THE Flatpak package SHALL be installable on Ubuntu, Fedora, Arch, and other major distributions
4. THE .deb package SHALL be installable on Debian and Ubuntu-based systems
5. THE Flatpak package SHALL follow Flatpak naming conventions (app-id-version.flatpak)
6. THE .deb package SHALL follow Debian naming conventions (package_version_arch.deb)
7. BOTH packages SHALL include desktop integration files (icon, .desktop file, AppStream metadata)

### Requirement 13

**User Story:** As an Android user, I want the application available as an APK, so that I can install it on my Android device.

#### Acceptance Criteria

1. THE Android build SHALL create an APK file
2. THE Android build SHALL target Android API level 21 (Lollipop) or higher
3. THE Android build SHALL support both ARM and x86 architectures
4. THE APK SHALL be signed with a release keystore
5. THE APK SHALL follow Android naming conventions (app-release.apk)
