# CloudToLocalLLM Technology Stack

## Primary Framework
- **Flutter 3.8+**: Cross-platform UI framework for desktop, web, and mobile
- **Dart SDK 3.8+**: Programming language
- **Material Design**: UI component system

## Key Dependencies
### Authentication & Security
- `flutter_appauth`: OAuth/OIDC authentication
- `flutter_secure_storage_x`: Secure local storage
- `cryptography`, `pointycastle`: End-to-end encryption
- `crypto`: Cryptographic utilities

### Networking & Communication
- `http`, `dio`: HTTP client libraries
- `web_socket_channel`: WebSocket support for real-time communication
- `stream_channel`: Stream-based communication
- `connectivity_plus`: Network connectivity monitoring

### AI & LangChain Integration
- `langchain`: LangChain framework integration
- `langchain_ollama`: Ollama provider for LangChain
- `langchain_community`: Community LangChain tools

### System Integration
- `window_manager`: Desktop window management
- `tray_manager`: System tray integration
- `package_info_plus`: App information access
- `url_launcher`: External URL handling

### State Management & Navigation
- `provider`: State management
- `go_router`: Declarative routing
- `rxdart`: Reactive programming extensions

### Storage & Data
- `sqflite`: SQLite database
- `shared_preferences`: Simple key-value storage
- `path_provider`: File system path access

## Backend Services
- **Node.js API Backend**: Express-based API server (port 8080)
- **Nginx**: Web server and reverse proxy
- **Docker**: Containerization platform
- **Postfix**: Email server for notifications

## Build System & Tools
### Flutter Commands
```bash
# Get dependencies
flutter pub get

# Build for different platforms
flutter build web --release
flutter build linux --release
flutter build windows --release
flutter build apk --release

# Development
flutter run
flutter test
flutter analyze
```

### Custom Build Scripts
```bash
# Unified package builder
./scripts/build_unified_package.sh

# Flutter build with timestamp injection
./scripts/flutter_build_with_timestamp.sh [web|linux|android|all]

# Version management
./scripts/version_manager.sh [get|increment]

# Build time version injection
./scripts/build_time_version_injector.sh inject
```

### Docker Commands
```bash
# Start all services
docker-compose up -d

# Build and deploy
docker-compose build
docker-compose up --build

# View logs
docker-compose logs -f [service-name]
```

## Testing
- **Flutter Test**: Unit and widget testing
- **Integration Test**: Flutter integration testing
- **Playwright**: End-to-end testing (Node.js)
- **PowerShell Scripts**: Windows-specific testing

### Test Commands
```bash
# Flutter tests
flutter test

# E2E tests
npm test
npm run test:tunnel-all

# Specific test suites
npm run test:auth
npm run test:tunnel-diagnosis
```

## Development Environment
- **IDE**: VS Code, Android Studio, or IntelliJ IDEA
- **Flutter Doctor**: `flutter doctor` for environment validation
- **Platform Requirements**:
  - Linux: GTK development libraries
  - Windows: Visual Studio with C++ tools
  - Web: Chrome for debugging
  - Android: Android SDK and emulator

## Code Quality
- **flutter_lints**: Dart/Flutter linting rules
- **analysis_options.yaml**: Static analysis configuration
- **Automated formatting**: `dart format`
- **Import organization**: Automatic import sorting