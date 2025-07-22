# CloudToLocalLLM Project Structure

## Root Directory Organization

### Core Application Code
- **`lib/`** - Flutter application source code (Dart)
  - `components/` - Reusable UI components
  - `config/` - App configuration (theme, router, app_config)
  - `models/` - Data models and DTOs
  - `screens/` - Application screens/pages
  - `services/` - Business logic and API services
  - `shared/` - Shared utilities and constants
  - `widgets/` - Custom widgets
  - `main.dart` - Application entry point

### Backend Services
- **`api-backend/`** - Node.js API server
  - `middleware/` - Express middleware
  - `routes/` - API route handlers
  - `tests/` - Backend unit tests
  - `server.js` - Main server entry point
  - `streaming-proxy-manager.js` - Container orchestration
  - `package.json` - Node.js dependencies

- **`streaming-proxy/`** - Lightweight proxy service
  - `proxy-server.js` - WebSocket proxy implementation
  - `package.json` - Minimal dependencies (ws, winston, jwt)

### Platform-Specific Code
- **`web/`** - Flutter web configuration
  - `index.html` - Web app entry point
  - `manifest.json` - PWA manifest
  - `icons/` - Web app icons

- **`linux/`** - Linux desktop configuration
  - `flutter/` - Flutter Linux build config
  - `runner/` - Linux app runner
  - `icons/` - Linux app icons

- **`windows/`** - Windows desktop configuration
  - `flutter/` - Flutter Windows build config
  - `runner/` - Windows app runner

## Documentation Structure

### Primary Documentation
- **`docs/`** - Comprehensive project documentation
  - `ARCHITECTURE/` - System design and technical architecture
  - `DEPLOYMENT/` - Deployment guides and workflows
  - `DEVELOPMENT/` - Developer guides and contribution info
  - `FEATURES/` - Feature documentation and specifications
  - `OPERATIONS/` - Operational guides and maintenance
  - `USER_DOCUMENTATION/` - End-user guides and tutorials
  - `LEGAL/` - Legal documents and compliance
  - `RELEASE/` - Release notes and changelogs
  - `VERSIONING/` - Version management documentation

### Root Documentation Files
- **`README.md`** - Main project overview and getting started
- **`CONTRIBUTING.md`** - Contribution guidelines
- **`CHANGELOG.md`** - Version history and changes
- **`LICENSE`** - MIT license

## Build and Deployment

### Scripts Directory
- **`scripts/`** - Automation and build scripts
  - `deploy/` - Deployment scripts and workflows
  - `packaging/` - Package building (DEB, AppImage)
  - `powershell/` - Windows-specific PowerShell scripts
  - `release/` - Release management scripts
  - `setup/` - Environment setup scripts
  - `maintenance/` - System maintenance scripts
  - `backup/` - Backup and restore scripts
  - `docker/` - Docker-related utilities
  - `ssl/` - SSL certificate management

### Configuration
- **`config/`** - Platform and service configurations
  - `docker/` - Docker configurations and Dockerfiles
  - `nginx/` - Nginx configuration files
  - `systemd/` - Linux systemd service files
  - `windows/` - Windows-specific configurations
  - `macos/` - macOS-specific configurations

### Build Artifacts
- **`build/`** - Flutter build outputs (generated)
- **`dist/`** - Distribution packages (generated)
- **`node_modules/`** - Node.js dependencies (generated)

## Infrastructure and Deployment

### Docker Configuration
- **`docker-compose.yml`** - Multi-container orchestration
- **`Dockerfile.nginx`** - Nginx container configuration
- **`Dockerfile.build`** - Build container setup
- **`Dockerfile.dev`** - Development container

### Package Building
- **`packaging/`** - Package creation tools
  - `linux/` - Linux package configurations
  - `appimage/` - AppImage build configuration
  - `deb/` - Debian package configuration

### Legacy and Archive
- **`backups/`** - Project backups (timestamped)
- **`MSI/`** - Windows MSI installer (legacy)
- **`PortableZip/`** - Portable ZIP packages

## Testing and Quality

### Test Structure
- **`test/`** - Flutter/Dart tests
  - `integration/` - Integration tests
  - `services/` - Service layer tests
  - `mocks/` - Test mocks and fixtures
  - `widget_test.dart` - Widget tests

- **`tests/`** - E2E and system tests
  - `e2e/` - End-to-end test suites

- **`test-results/`** - Test execution results (generated)
  - `artifacts/` - Test artifacts
  - `screenshots/` - Test screenshots
  - `videos/` - Test recordings

### Quality Configuration
- **`analysis_options.yaml`** - Dart static analysis rules
- **`playwright.config.js`** - E2E testing configuration
- **`.eslintrc.js`** - JavaScript linting rules

## Development Environment

### IDE Configuration
- **`.vscode/`** - VS Code settings and extensions
- **`.idea/`** - IntelliJ/Android Studio configuration

### Version Control
- **`.git/`** - Git repository data
- **`.github/`** - GitHub workflows and templates
- **`.gitignore`** - Git ignore patterns
- **`.gitattributes`** - Git file attributes

### Environment Files
- **`.env.production.template`** - Production environment template
- **`.dockerignore`** - Docker ignore patterns
- **`.metadata`** - Flutter project metadata

## Asset Management

### Static Assets
- **`assets/`** - Application assets
  - `images/` - Image resources
  - `linux/` - Linux-specific assets
  - `version.json` - Version information

### Web Assets
- **`web/favicon.png`** - Web app favicon
- **`web/icons/`** - Progressive Web App icons

## Naming Conventions

### File Naming
- **Dart files**: snake_case (e.g., `auth_service.dart`)
- **JavaScript files**: kebab-case (e.g., `streaming-proxy-manager.js`)
- **Configuration files**: kebab-case (e.g., `docker-compose.yml`)
- **Documentation**: UPPERCASE (e.g., `README.md`, `CONTRIBUTING.md`)

### Directory Structure
- **Service directories**: kebab-case (e.g., `api-backend/`, `streaming-proxy/`)
- **Flutter directories**: snake_case (e.g., `lib/services/`, `lib/widgets/`)
- **Documentation directories**: UPPERCASE (e.g., `ARCHITECTURE/`, `DEPLOYMENT/`)

### Code Organization Patterns
- **Services**: Business logic and external integrations
- **Models**: Data structures and DTOs
- **Widgets**: Reusable UI components
- **Screens**: Full-page UI implementations
- **Config**: Application configuration and constants