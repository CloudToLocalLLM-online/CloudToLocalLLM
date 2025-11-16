# Technology Stack

## Frontend

- **Flutter SDK**: 3.8+ (Dart 3.9.0+)
- **State Management**: Provider pattern
- **Routing**: go_router for navigation
- **UI Framework**: Material Design with custom theming
- **Platform Support**: Windows, Linux, Web (macOS in development)

## Backend Services

- **Runtime**: Node.js with ES modules
- **API Framework**: Express.js
- **WebSocket**: web_socket_channel for real-time communication
- **HTTP Client**: dio for enhanced streaming support

## Key Dependencies

### Flutter/Dart
- `provider` - State management
- `go_router` - Declarative routing
- `jwt_decoder` - Auth0 token handling
- `flutter_secure_storage_x` - Secure credential storage
- `sqflite` / `sqflite_common_ffi` - Local database (desktop/web)
- `shared_preferences` - Web-compatible storage
- `window_manager` - Desktop window control
- `tray_manager` - System tray integration
- `dartssh2` - SSH tunneling
- `langchain` / `langchain_ollama` - LangChain integration
- `get_it` - Dependency injection
- `dio` - HTTP client with streaming
- `web_socket_channel` - WebSocket support

### Node.js
- `@modelcontextprotocol/sdk` - MCP integration
- `zod` - Schema validation
- `jest` - Testing framework

## Build System

### Flutter Commands
```bash
# Install dependencies
flutter pub get

# Run desktop app
flutter run -d windows
flutter run -d linux

# Run web app
flutter run -d chrome

# Build release
flutter build windows --release
flutter build linux --release
flutter build web --release

# Run tests
flutter test

# Format code
dart format .
```

### Node.js Commands
```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Run production server
npm start

# Run tests
npm test
```

## Development Tools

- **Version Management**: Automated scripts in `scripts/powershell/` and `scripts/`
- **Deployment**: PowerShell scripts for desktop builds, Kubernetes for cloud
- **Testing**: Flutter test framework, Jest for Node.js, Playwright for e2e
- **CI/CD**: GitHub Actions workflows

## Monitoring & Observability

- **Grafana**: Dashboards and visualization (Admin API key configured)
- **Prometheus**: Metrics collection and time-series database
- **Loki**: Log aggregation and querying
- **Jaeger**: Distributed tracing (optional)
- **Custom Metrics**: ServerMetricsCollector for application-specific metrics

## Available CLI Tools

The development environment has the following CLI tools available:

### Azure CLI (`az`)
- Use for Azure resource management and operations
- Authentication, resource queries, deployments
- Prefer `az` commands over manual Azure portal operations

### GitHub CLI (`gh`)
- Use for GitHub operations (repos, issues, PRs, releases)
- Authentication, repository management, workflow operations
- Prefer `gh` commands over manual GitHub web interface operations

### Grafana CLI (`grafana`)
- Use for Grafana dashboard and datasource management
- Query metrics and alerts programmatically
- Admin API key: Set via `GRAFANA_API_KEY` environment variable
- Configured in Docker MCP toolkit for automated access
- Use for monitoring system health and performance

### Playwright Browser Testing (MCP Tool)
- Playwright MCP server is configured and available via `@executeautomation/playwright-mcp-server`
- Use to test live deployed applications after CI/CD deployment
- Primary test URL: https://app.cloudtolocalllm.online
- Supports Chromium, Firefox, and WebKit browsers
- Use for end-to-end testing, UI validation, and deployment verification

**Setup (if needed):**
```powershell
# Install MCP server globally
npm install -g @executeautomation/playwright-mcp-server

# Install Playwright browsers for the MCP server
cd C:\Users\rightguy\AppData\Roaming\npm\node_modules\@executeautomation\playwright-mcp-server
npx playwright install chromium
```

**Common Playwright Operations:**
- `playwright_navigate` - Navigate to URLs
- `playwright_screenshot` - Capture page screenshots
- `playwright_click` - Click elements
- `playwright_fill` - Fill form inputs
- `playwright_evaluate` - Execute JavaScript
- `playwright_get_visible_text` - Extract page text
- `playwright_get_visible_html` - Get page HTML

**Testing Workflow:**
1. Navigate to the deployed application
2. Take screenshots for visual verification
3. Interact with UI elements (click, fill forms)
4. Verify functionality and user flows
5. Close browser when done

**Best Practices:**
- Use CLI tools for automation and scripting tasks
- Leverage `gh` for release management and GitHub Actions
- Use `az` for cloud infrastructure queries and management
- Use Grafana for real-time monitoring and alerting
- Use Playwright to verify deployments and test live applications
- CLI tools provide better automation and reproducibility than manual operations

## Database

- **Desktop**: SQLite via sqflite_common_ffi
- **Web**: IndexedDB via sqflite web implementation
- **Cloud**: PostgreSQL (StatefulSet in Kubernetes)

## Deployment

### Desktop Applications
```powershell
# Build and release desktop apps
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1
```

### Cloud Infrastructure
```bash
# Build Docker images
docker build -f config/docker/Dockerfile.web -t registry/app-web:latest .
docker build -f services/api-backend/Dockerfile.prod -t registry/app-api:latest .

# Deploy to Kubernetes
kubectl apply -f k8s/
```

## Code Style

- Follow standard Dart/Flutter conventions
- Use `dart format .` before committing
- Meaningful variable and function names
- Comments for complex logic
- All new features require tests
