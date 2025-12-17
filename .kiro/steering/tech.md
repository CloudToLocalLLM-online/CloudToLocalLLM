# Technology Stack

## Frontend
- **Flutter SDK**: 3.5+ (Dart 3.5.0+)
- **State Management**: Provider + GetIt DI
- **Routing**: go_router with auth guards
- **Platform Support**: Windows, Linux, Web
- **Authentication**: Auth0 OAuth2 + JWT

## Backend
- **Runtime**: Node.js with Express.js
- **WebSocket**: web_socket_channel for real-time
- **Database**: SQLite (desktop), IndexedDB (web), PostgreSQL (cloud)

## Key Commands (Native WSL/Ubuntu)
```bash
# Flutter
flutter pub get
flutter run -d linux   # Primary development target
flutter run -d chrome  # Web development

# Node.js
npm install && npm run dev
```

## Platform-Specific Tools
- **WSL (Ubuntu 24.04)**: Primary development environment.
- **PowerShell**: Used *only* for Windows-native packaging and releases (see `scripts/powershell/`).

## CLI Tools Available
- `aws` - AWS resource management
- `gh` - GitHub operations (repos, releases, workflows)
- `grafana` - Monitoring dashboards (GRAFANA_API_KEY required)
- `sentry-cli` - Error monitoring and release tracking
- `auth0` - Authentication management

## Infrastructure
- **Production**: Azure AKS (managed via `deploy.yml`)
- **Local Dev**: WSL2 with native Linux SDKs. Ollama (host) accessed via `localhost`.