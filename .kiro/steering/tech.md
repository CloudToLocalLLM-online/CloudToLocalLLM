# CloudToLocalLLM Technology Stack

## Primary Technologies

### Frontend & Desktop Application
- **Flutter 3.8+**: Cross-platform UI framework (Web, Linux, Windows, macOS)
- **Dart SDK**: >=3.8.0 <4.0.0
- **Material Design**: UI component system with light/dark theme support

### Backend Services
- **Node.js 18+**: Server-side runtime for API backend and streaming proxies
- **Express.js**: Web framework for REST APIs and middleware
- **WebSocket (ws)**: Real-time bidirectional communication
- **Docker**: Container orchestration and microservices deployment

### Authentication & Security
- **Auth0**: Identity and access management platform
- **JWT**: JSON Web Tokens for secure authentication
- **CORS**: Cross-origin resource sharing configuration
- **Helmet**: Security middleware for Express applications

## Key Dependencies

### Flutter/Dart Dependencies
- **go_router**: Navigation and routing (^16.0.0)
- **provider**: State management (^6.1.5)
- **http/dio**: HTTP client libraries for API communication
- **web_socket_channel**: WebSocket support for streaming
- **tray_manager**: Native system tray integration (^0.5.0)
- **window_manager**: Window management for desktop apps
- **flutter_secure_storage_x**: Secure local data storage
- **connectivity_plus**: Network connectivity monitoring

### Node.js Dependencies
- **express**: Web application framework (^4.18.2)
- **ws**: WebSocket library (^8.14.2)
- **dockerode**: Docker API client for container management
- **winston**: Logging framework
- **jsonwebtoken**: JWT handling
- **uuid**: Unique identifier generation

## Build System & Tools

### Flutter Build Commands
```bash
# Web build with release optimization
flutter build web --release

# Desktop builds
flutter build linux --release
flutter build windows --release

# Development with hot reload
flutter run -d chrome  # Web development
flutter run -d linux   # Linux development
```

### Docker Operations
```bash
# Multi-container deployment
docker-compose up -d

# Build specific services
docker build -t cloudtolocalllm-nginx -f Dockerfile.nginx .
docker build -f config/docker/Dockerfile.api-backend .

# Container health checks
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Development Scripts
```bash
# Complete deployment with verification
./scripts/deploy/complete_deployment.sh

# Build unified packages
./scripts/build_unified_package.sh

# Version management
./scripts/version_manager.sh

# Flutter build with timestamp injection
./scripts/flutter_build_with_timestamp.sh web
```

### Package Building
```bash
# Linux packages
./scripts/packaging/build_deb.sh        # Debian packages
./scripts/packaging/build_appimage.sh   # AppImage packages

# Windows (PowerShell)
./scripts/powershell/Create-UnifiedPackages.ps1
```

## Development Environment

### Required Tools
- **Flutter SDK**: 3.8+ with Dart SDK
- **Node.js**: 18+ for backend services
- **Docker**: Container runtime and compose
- **Git**: Version control
- **VS Code**: Recommended IDE with Flutter extensions

### Platform-Specific Requirements
- **Linux**: AppImage tools, Debian packaging tools
- **Windows**: Visual Studio Build Tools, PowerShell 5.1+
- **Web**: Chrome/Chromium for development testing

## Testing & Quality

### Testing Framework
- **Flutter Test**: Unit and widget testing
- **Integration Test**: End-to-end testing
- **Playwright**: Web application E2E testing
- **Jest**: Node.js unit testing

### Code Quality
- **flutter_lints**: Dart/Flutter linting rules
- **ESLint**: JavaScript/Node.js code quality
- **Prettier**: Code formatting for JavaScript
- **analysis_options.yaml**: Dart static analysis configuration

### Quality Commands
```bash
# Flutter analysis
flutter analyze

# Dart formatting
dart format .

# Node.js linting
npm run lint

# Run tests
flutter test
npm test
```

## Deployment Architecture

### Container Services
- **nginx-proxy**: SSL termination and request routing
- **flutter-app**: Web application container
- **api-backend**: Core API and proxy management
- **streaming-proxy**: Ephemeral user-specific proxies
- **certbot**: Automated SSL certificate management

### Infrastructure
- **Docker Compose**: Multi-container orchestration
- **Let's Encrypt**: SSL certificate automation
- **Nginx**: Reverse proxy and static file serving
- **Health Checks**: Container monitoring and auto-restart