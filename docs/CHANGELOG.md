# Changelog

All notable changes to CloudToLocalLLM will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.3.0] - 2025-11-06

### Added
- New features and enhancements

## [4.1.4] - 2025-11-01



### Fixed
- Bug fixes and improvements


## [4.1.1] - 2025-08-07



### Fixed
- Bug fixes and improvements


## [4.1.0] - 2025-08-07



### Added
- New features and enhancements


## [4.0.86] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.85] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.84] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.83] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.82] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.81] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.80] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.79] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.78] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.77] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.76] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.75] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.74] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.73] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.72] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.71] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.70] - 2025-08-05



### Technical
- Build and deployment updates


## [4.0.70] - 2025-08-05



### Fixed
- Bug fixes and improvements


## [4.0.69] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.68] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.67] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.66] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.65] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.64] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.63] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.62] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.61] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.60] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.59] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.58] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.57] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.56] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.55] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.54] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.53] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.52] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.51] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.50] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.49] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.48] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.47] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.46] - 2025-08-04



### Fixed
- Bug fixes and improvements


## [4.0.45] - 2025-08-03

### Fixed
- Bug fixes and improvements

## [4.0.44] - 2025-08-03



### Fixed
- Bug fixes and improvements


## [4.0.43] - 2025-08-03



### Fixed
- Bug fixes and improvements


## [4.0.35] - 2025-08-02



### Fixed
- Bug fixes and improvements


## [4.0.32] - 2025-08-01



### Fixed
- Bug fixes and improvements


## [Unreleased] - 2025-01-13

### Changed - Deployment Script Consolidation and Cleanup
- **CONSOLIDATED: Enhanced complete_deployment.sh** - Merged functionality from multiple deployment scripts
  - Integrated six-phase deployment structure from complete_automated_deployment.sh
  - Added enhanced argument parsing: --verbose, --dry-run, --force, --skip-backup, --interactive
  - Merged build-time timestamp injection integration for automated version management
  - Enhanced network connectivity checks with latency monitoring and fallback handling
  - Improved error handling with comprehensive recovery mechanisms and detailed logging
  - Added dry-run simulation mode for safe testing without making actual changes
  - Preserved zero-tolerance quality gates and strict verification standards
  - Maintained automated execution without interactive prompts (user preference)

- **ARCHIVED: Duplicate deployment scripts** - Moved to scripts/archive/ with migration documentation
  - complete_automated_deployment.sh â†’ Functionality merged into complete_deployment.sh
  - deploy_to_vps.sh â†’ Functionality available in consolidated scripts
  - build_and_package.sh â†’ Functionality available in scripts/packaging/build_deb.sh

### Removed - AUR Support (Temporary)
- **AUR support is temporarily removed** as of v3.10.3. See [AUR Status](DEPLOYMENT/AUR_STATUS.md) for details.

### Fixed - Documentation and Cross-References
- **Updated script references** across all documentation files
  - README.md: Updated script listings and usage examples
  - scripts/README.md: Accurate deployment script inventory
  - scripts/update_documentation.sh: Corrected script references
  - Dockerfile.build: Updated to use scripts/packaging/build_deb.sh
  - All deployment workflow documentation updated for consolidated scripts

### Enhanced - Script Organization and Safety
- **Created scripts/archive/** directory with comprehensive migration documentation
  - Detailed migration guide for users of archived scripts
  - Recovery instructions for temporary script restoration if needed
  - 30-day retention policy with automatic cleanup schedule
  - Complete functionality mapping between old and new scripts

## [3.2.0] - 2025-01-27

### Added - Multi-App Architecture with Tunnel Manager
- **NEW: Tunnel Manager v1.0.0** - Independent Flutter desktop application for tunnel management
  - Dedicated connection broker handling local Ollama and cloud services
  - HTTP REST API server on localhost:8765 for external application integration
  - Real-time WebSocket support for status updates
  - Comprehensive health monitoring with configurable intervals (5-300 seconds)
  - Performance metrics collection (latency percentiles, throughput, error rates)
  - Secure authentication token management with Flutter secure storage
  - Material Design 3 GUI for configuration and diagnostics
  - Background service operation with optional minimal GUI
  - Automatic startup integration via systemd user service
  - Connection pooling and request routing optimization
  - Graceful shutdown handling with state persistence

- **Unified Flutter-Native System Tray v2.0.0** - Major upgrade with tunnel integration
  - Real-time tunnel status monitoring with dynamic icons
  - Enhanced menu structure with connection quality indicators
  - Intelligent alert system with configurable thresholds
  - Version compatibility checking across all components
  - Migration support from v1.x with automated upgrade paths
  - Improved IPC communication with HTTP REST API primary and TCP fallback
  - Comprehensive tooltip information with latency and model counts
  - Context-aware menu items based on authentication state

- **Shared Library v3.2.0** - Common utilities and version management
  - Centralized version constants and compatibility checking
  - Cross-component version validation during build process
  - Shared models and services for consistent behavior
  - Build timestamp and Git commit tracking

- **Multi-App Build System** - Comprehensive build pipeline
  - Version consistency validation across all components
  - Unified distribution packaging with launcher scripts
  - Platform-specific build optimization for Linux desktop
  - Automated desktop integration with .desktop entries
  - Build information generation with dependency tracking

### Enhanced
- **Main Application v3.2.0** - Integration with tunnel manager
  - Tunnel manager integration for improved connection reliability
  - Version display in persistent bottom-right corner overlay
  - Enhanced connection status reporting via tunnel API
  - Backward compatibility with existing tray daemon v1.x
  - Improved error handling and graceful degradation

- **Version Management System** - Comprehensive versioning
  - Semantic versioning across all components with compatibility matrix
  - Build timestamp and Git commit hash tracking
  - Version display in all user interfaces with hover tooltips
  - Cross-component dependency validation during builds
  - Migration support for configuration and data formats

- **Documentation Updates** - Complete architecture documentation
  - Tunnel Manager README with API reference and troubleshooting
  - Updated main README with multi-app architecture section
  - Version compatibility matrix and migration guides
  - Deployment documentation with multi-service configuration
  - API reference documentation with OpenAPI specification

### Technical Improvements
- **Architecture Refactoring** - Modular multi-app design
  - Independent application lifecycle management
  - Service isolation to prevent cascade failures
  - Centralized configuration management with hot-reloading
  - Hierarchical service dependency resolution
  - Enhanced error handling with specific error codes

- **Performance Optimization** - System-wide improvements
  - Connection pooling with concurrent request handling
  - Request queuing and routing optimization
  - Memory usage optimization (<50MB per service)
  - CPU usage optimization (<5% idle, <15% active)
  - Latency optimization (<100ms tunnel, <10ms API responses)

- **Security Enhancements** - Comprehensive security model
  - No root privileges required for any component
  - Proper sandboxing and process isolation
  - Secure credential storage with encryption
  - HTTPS-only cloud connections with certificate validation
  - Configurable CORS policies for API server

### Breaking Changes
- **Tray Daemon API v2.0** - Updated IPC protocol
  - New HTTP REST API primary communication method
  - Enhanced status reporting with connection quality metrics
  - Updated menu structure and tooltip format
  - Migration required from v1.x configurations

- **Configuration Format Changes** - Unified configuration
  - New tunnel manager configuration in `~/.cloudtolocalllm/tunnel_config.json`
  - Updated tray daemon configuration format
  - Shared library configuration validation
  - Backward compatibility with automatic migration

### Deployment
- **AUR Package Updates** - Enhanced Linux packaging
  - Multi-app binary distribution with ~125MB unified package
  - Systemd service templates for all components
  - Desktop integration with proper icon installation
  - Version consistency validation in package scripts

- **Build Pipeline** - Automated multi-component builds
  - Cross-component version validation
  - Unified distribution archive creation
  - Checksum generation and integrity verification
  - Platform-specific optimization for Linux x64

### Version Compatibility Matrix
- Main Application v3.2.0 â†” Tunnel Manager v1.0.0 âœ…
- Main Application v3.2.0 â†” Tray Daemon v2.0.0 âœ…
- Main Application v3.2.0 â†” Shared Library v3.2.0 âœ…
- Tunnel Manager v1.0.0 â†” Tray Daemon v2.0.0 âœ…
- Backward compatibility: Main App v3.2.0 â†” Tray Daemon v1.x âš ï¸ (limited)

### Migration Guide
For users upgrading from v3.1.x:
1. Stop existing tray daemon: `pkill cloudtolocalllm-enhanced-tray`
2. Install new multi-app package
3. Run configuration migration: `./cloudtolocalllm-tray --migrate-config`
4. Install system integration: `./install-system-integration.sh`
5. Start services: `systemctl --user start cloudtolocalllm-tunnel.service`

### Known Issues
- Tunnel manager WebSocket connections may require firewall configuration
- System tray icons may not display correctly on some Wayland compositors
- Configuration migration from v1.x requires manual verification

### Future Roadmap
- v1.1.0: Advanced load balancing and plugin system
- v2.0.0: Multi-user support and distributed tunnel management
- Cross-platform support for Windows and macOS

## [3.1.3] - 2025-01-26

### Fixed
- Enhanced tray daemon stability improvements
- Connection broker error handling
- Flutter web build compatibility

### Changed
- Updated dependencies to latest versions
- Improved logging and debugging output

## [3.1.2] - 2025-01-25

### Added
- Enhanced system tray daemon with connection broker
- Universal connection management for local and cloud
- Improved authentication flow

### Fixed
- System tray integration issues on Linux
- Connection stability improvements
- Memory usage optimization

## [3.1.1] - 2025-01-24

### Fixed
- Critical authentication bug fixes
- Improved error handling for connection failures
- UI responsiveness improvements

## [3.1.0] - 2025-01-23

### Added
- System tray integration with independent daemon
- Enhanced connection management
- Improved authentication with Auth0 integration
- Material Design 3 dark theme implementation

### Changed
- Migrated from system_tray package to Python-based daemon
- Improved connection reliability and error handling
- Enhanced UI with modern design patterns

### Fixed
- Connection timeout issues
- Authentication token management
- System tray icon display on various Linux environments

## [3.0.3] - 2025-01-20

### Fixed
- AUR package installation issues
- Binary distribution optimization
- Desktop integration improvements

## [3.0.2] - 2025-01-19

### Added
- AUR package support for Arch Linux
- Improved binary distribution
- Enhanced build scripts

### Fixed
- Package size optimization
- Dependency management improvements

## [3.0.1] - 2025-01-18

### Added
- SourceForge binary distribution
- Enhanced deployment workflow
- Improved documentation

### Fixed
- Build process optimization
- Distribution file management

## [3.0.0] - 2025-01-17

### Added
- Multi-container Docker architecture
- Independent service deployments
- Enhanced security with non-root containers
- Comprehensive documentation structure

### Changed
- Major architecture refactoring
- Improved scalability and maintainability
- Enhanced deployment processes

### Breaking Changes
- Docker configuration format changes
- Service communication protocol updates
- Configuration file structure modifications

---

For more information about each release, visit our [GitHub Releases](https://github.com/imrightguy/CloudToLocalLLM/releases) page.
