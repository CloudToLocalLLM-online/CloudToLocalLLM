# Implementation Plan

- [x] 1. Update build workflow to use GitHub-hosted Windows runner
  - Replace `runs-on: [self-hosted, windows]` with `runs-on: windows-latest`
  - Remove dependency on pre-installed tools
  - Add matrix strategy structure (Windows only initially)
  - Update workflow file `.github/workflows/build-release.yml`
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

- [x] 2. Add automated Flutter SDK installation
  - Add `subosito/flutter-action@v2` step to workflow
  - Configure Flutter version 3.24.0 (or from environment variable)
  - Enable caching for Flutter SDK and pub dependencies
  - Verify Flutter installation with `flutter doctor`
  - _Requirements: 2.1, 3.1, 3.2, 3.4_

- [x] 3. Add automated Inno Setup installation for Windows
  - Add step to install Inno Setup via Chocolatey
  - Add fallback to Winget if Chocolatey fails
  - Detect Inno Setup installation path and set environment variable
  - Verify Inno Setup is accessible before build
  - _Requirements: 2.2, 2.6, 7.2_

- [x] 4. Implement dependency verification step
  - Create verification step that checks Flutter, Inno Setup, and Git
  - Add clear error messages for missing dependencies
  - Fail fast if any required dependency is missing
  - Log all dependency versions for debugging
  - _Requirements: 2.6, 2.7, 7.1, 7.2, 7.5_

- [x] 5. Update caching configuration for GitHub-hosted runners
  - Update cache paths for Windows runner (use `${{ runner.temp }}` instead of hardcoded paths)
  - Add cache for Chocolatey packages
  - Implement cache key based on `pubspec.lock` hash
  - Add cache restore-keys for fallback
  - _Requirements: 3.1, 3.2, 3.3, 3.5_

- [x] 6. Test Windows build on GitHub-hosted runner
  - Trigger workflow manually with workflow_dispatch
  - Verify all dependencies install correctly
  - Verify Flutter build completes successfully
  - Verify installer and portable packages are created
  - Verify checksums are generated correctly
  - Compare artifacts with previous self-hosted builds
  - _Requirements: 1.3, 1.4, 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 7. Update release creation to handle matrix artifacts
  - Modify artifact download step to handle matrix outputs
  - Update release notes generation for multi-platform support (Windows only initially)
  - Ensure all Windows artifacts are included in release
  - Verify release creation works with new workflow structure
  - _Requirements: 4.4, 4.5, 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 8. Add comprehensive logging and error handling
  - Add detailed logging for each build step
  - Implement clear error messages for common failures
  - Add step summaries for GitHub Actions UI
  - Log build times for performance monitoring
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 10.1, 10.2_

- [x] 9. Update documentation for new build process
  - Update README with GitHub-hosted runner informationa
  - Document how to trigger builds manually
  - Add troubleshooting section for common issues
  - Document cost savings (free for public repos)
  - Update CI/CD documentation
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 10. Add Linux build to matrix and implement Flatpak packaging
  - Add Linux platform to build matrix configuration
  - Install Flatpak build tools (flatpak-builder, Freedesktop SDK)
  - Verify Flatpak manifest file exists and is valid
  - Implement Flatpak build steps in workflow
  - Create Flatpak bundle for distribution
  - Generate SHA256 checksum for Flatpak package
  - _Requirements: 1.2, 2.3, 4.3, 11.1, 11.2, 12.1, 12.3, 12.5, 12.7_

- [x] 11. Implement .deb package creation for Linux
  - Install .deb packaging tools (dpkg-dev, fakeroot, lintian)
  - Create DEBIAN control files with proper metadata
  - Structure .deb package with correct directory layout
  - Build .deb package with dpkg-deb
  - Validate .deb package with lintian
  - Generate SHA256 checksum for .deb package
  - _Requirements: 1.2, 2.3, 4.4, 12.2, 12.4, 12.6, 12.7_

- [x] 12. Test Linux builds on GitHub-hosted runner
  - Trigger workflow manually to test Linux build
  - Verify Flatpak and .deb packages are created
  - Test Flatpak installation on Ubuntu, Fedora, Arch
  - Test .deb installation on Ubuntu and Debian
  - Verify desktop integration files are included
  - Verify checksums are generated correctly
  - _Requirements: 4.3, 4.4, 4.5, 12.1, 12.2, 12.3, 12.4, 12.7_

- [x] 13. Add Android build to matrix and implement multi-architecture APKs
  - Add Android platform to build matrix configuration
  - Install Java 17 and Android SDK/NDK
  - Configure Android signing with release keystore
  - Implement APK build with --split-per-abi flag
  - Verify all architecture APKs are created (ARM64, ARMv7, x86_64)
  - Generate SHA256 checksums for all APKs
  - _Requirements: 1.3, 2.4, 4.5, 11.1, 11.2, 13.1, 13.2, 13.3, 13.4, 13.5_

- [x] 14. Update release creation for all platforms
  - Update artifact download to collect Windows, Linux, and Android artifacts
  - Update release notes template with all platform instructions
  - Implement artifact verification before release creation
  - Verify all expected artifacts exist (installers, packages, APKs, checksums)
  - Test release creation with all platforms
  - _Requirements: 4.6, 4.7, 4.8, 9.1, 9.2, 9.3, 9.4, 9.5, 11.3, 11.4_

- [x] 15. Implement comprehensive caching for all platforms
  - Add Flutter pub dependencies cache with pubspec.lock-based keys
  - Add Dart tool cache for build outputs
  - Add Flatpak build cache for Linux (via flatpak-builder cache)
  - Add Gradle cache for Android
  - Verify cache hit rates and performance improvements
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 16. Add workflow triggers and concurrency controls
  - Configure tag-based triggers (v* pattern)
  - Add workflow_dispatch for manual triggering
  - Implement concurrency controls to prevent duplicate builds
  - Configure release creation only for tag triggers
  - Test sequential queueing of simultaneous tag pushes
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 17. Configure Android signing secrets in GitHub repository





  - Generate Android release keystore (if not already created)
  - Convert keystore to base64 format
  - Add `ANDROID_KEYSTORE_BASE64` secret to GitHub repository
  - Add `ANDROID_KEYSTORE_PASSWORD` secret to GitHub repository
  - Add `ANDROID_KEY_PASSWORD` secret to GitHub repository
  - Add `ANDROID_KEY_ALIAS` secret to GitHub repository
  - Verify secrets are accessible in workflow
  - _Requirements: 13.4, 13.5_

- [x] 18. Test complete multi-platform build end-to-end





  - Trigger workflow with tag push (e.g., v4.5.0-test)
  - Verify all three platforms build in parallel
  - Verify Windows artifacts (installer, portable, checksums)
  - Verify Linux artifacts (Flatpak, .deb, checksums)
  - Verify Android artifacts (3 APKs, checksums)
  - Verify release is created with all artifacts
  - Verify release notes include all platforms
  - Test artifact downloads and installations
  - _Requirements: 4.5, 4.6, 4.7, 4.8, 11.3, 11.4, 13.1, 13.2, 13.3_

- [x] 19. Update documentation for complete multi-platform workflow





  - Update .github/workflows/README.md with complete workflow overview
  - Ensure LINUX_BUILD_GUIDE.md is complete and accurate
  - Ensure ANDROID_BUILD_GUIDE.md includes secret setup instructions
  - Update BUILD_TROUBLESHOOTING.md with Android-specific issues
  - Add workflow diagram showing all three platforms
  - Document expected build times for each platform
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ]* 20. Create integration tests for build workflow
  - Write test workflow that validates all platform builds
  - Test dependency installation steps for each platform
  - Test artifact creation and upload for all platforms
  - Test release creation process with all artifacts
  - Test partial platform failure scenarios
  - _Requirements: All requirements_

- [ ]* 21. Performance benchmarking and optimization
  - Measure build times with and without cache for each platform
  - Verify 30%+ speed improvement with caching
  - Measure parallel build efficiency
  - Identify and optimize slow steps
  - Document performance metrics
  - _Requirements: 3.4, 3.5, 10.1, 11.2_
