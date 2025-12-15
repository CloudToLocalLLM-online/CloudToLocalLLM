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

## Key Commands
```bash
# Flutter
flutter pub get && flutter run -d windows
flutter build windows --release

# Node.js  
npm install && npm run dev
```

## CLI Tools Available
- `aws` - AWS resource management
- `gh` - GitHub operations (repos, releases, workflows)
- `grafana` - Monitoring dashboards (GRAFANA_API_KEY required)

## Current Deployment
- **Production**: Azure AKS (deploy.yml workflow)
- **Future**: AWS EKS migration in progress