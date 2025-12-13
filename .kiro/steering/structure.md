# Project Structure

## Root Directory Organization

```
CloudToLocalLLM/
├── lib/                    # Flutter application source code
├── services/               # Backend microservices (Node.js)
├── scripts/                # Build, deployment, and utility scripts
├── docs/                   # Comprehensive documentation
├── test/                   # Flutter tests
├── k8s/                    # Kubernetes deployment manifests
├── config/                 # Configuration files and templates
├── web/                    # Web-specific assets and config
├── windows/                # Windows platform-specific code
├── linux/                  # Linux platform-specific code
└── android/                # Android platform code (legacy)
```

## Flutter Application (`lib/`)

```
lib/
├── main.dart               # Application entry point
├── bootstrap/              # App initialization and bootstrapping
├── components/             # Reusable UI components
├── config/                 # App configuration (router, theme, etc.)
├── di/                     # Dependency injection setup (get_it)
├── models/                 # Data models and DTOs
├── screens/                # Full-screen views
├── services/               # Business logic and state management
├── shared/                 # Shared utilities and constants
├── utils/                  # Helper functions and utilities
└── widgets/                # Reusable widget components
```

### Key Service Patterns

Services in `lib/services/` follow these patterns:
- Extend `ChangeNotifier` for state management
- Registered in `di/locator.dart` using get_it
- Provided to widget tree via Provider in `main.dart`
- Core services (AuthService) always available
- Authenticated services registered after login

### Platform-Specific Code

- Use conditional imports with stubs for platform-specific features
- Pattern: `import 'file.dart' if (dart.library.html) 'file_web.dart' if (dart.library.io) 'file_stub.dart'`
- Examples: `web_js_interop.dart`, `window_listener_widget.dart`

## Backend Services (`services/`)

```
services/
├── api-backend/            # Main API server (Express.js)
│   ├── Dockerfile.prod     # Production Docker image
│   └── src/                # API source code
└── streaming-proxy/        # WebSocket streaming proxy
    └── src/                # Proxy source code
```

## Scripts (`scripts/`)

```
scripts/
├── powershell/             # Windows PowerShell scripts
│   └── Deploy-CloudToLocalLLM.ps1  # Main deployment script
├── aws/                    # AWS infrastructure scripts
│   ├── setup-oidc-provider.ps1     # OIDC provider setup
│   ├── setup-oidc-provider.sh      # OIDC provider setup (Linux)
│   ├── verify-oidc-setup.ps1       # OIDC verification
│   ├── cost-monitoring.js          # AWS cost monitoring
│   ├── backup-postgres.sh          # Database backup
│   ├── restore-postgres.sh         # Database restore
│   └── README.md                   # AWS setup documentation
├── deploy/                 # Deployment automation
├── setup/                  # Environment setup scripts
├── tests/                  # Test automation scripts
└── release/                # Release management scripts
```

## Documentation (`docs/`)

```
docs/
├── ARCHITECTURE/           # System design and architecture docs
├── DEPLOYMENT/             # Deployment guides and workflows
├── DEVELOPMENT/            # Developer guides and onboarding
├── INSTALLATION/           # Platform-specific installation guides
├── OPERATIONS/             # Operations and infrastructure guides
├── USER_DOCUMENTATION/     # End-user guides and tutorials
└── RELEASE/                # Release notes and changelogs
```

## Kubernetes (`k8s/`)

```
k8s/
├── namespace.yaml          # Kubernetes namespace
├── configmap.yaml          # Configuration data
├── secrets.yaml.template   # Secrets template
├── web-deployment.yaml     # Web app deployment
├── api-backend-deployment.yaml  # API deployment
├── postgres-statefulset.yaml    # Database
├── ingress-nginx.yaml      # Ingress controller
└── cert-manager.yaml       # SSL certificate management
```

## Configuration (`config/`)

```
config/
├── docker/                 # Dockerfiles for various services
├── kubernetes/             # Additional K8s configs
├── cloudformation/         # AWS CloudFormation templates
│   ├── vpc-networking.yaml # VPC and networking infrastructure
│   ├── iam-roles.yaml      # IAM roles and policies
│   ├── eks-cluster.yaml    # EKS cluster and node groups
│   └── README.md           # CloudFormation documentation
├── nginx/                  # Nginx configurations
├── mcp/                    # Model Context Protocol configs
└── *.template              # Environment templates
```

## Architecture Patterns

### Dependency Injection
- Services registered in `lib/di/locator.dart`
- Use `get_it` for service location
- Singleton pattern for most services

### State Management
- Provider pattern for reactive state
- ChangeNotifier for service state
- Context.watch/read for consuming state

### Routing
- Declarative routing with go_router
- Route guards for authentication
- Deep linking support for OAuth callbacks

### Authentication Flow
1. User initiates login → Auth0 OAuth flow
2. Callback handled by `/callback` route
3. JWT tokens stored in flutter_secure_storage
4. Authenticated services registered in DI container
5. Provider tree rebuilt with authenticated services

### Service Initialization
1. Bootstrap phase loads core services
2. AuthService checks for existing session
3. Session bootstrap completes
4. Router initialized with auth state
5. Authenticated services loaded on demand

## Testing Structure

```
test/
├── unit/                   # Unit tests for services/models
├── widgets/                # Widget tests
├── integration/            # Integration tests
├── e2e/                    # End-to-end tests (Playwright)
└── flutter_test_config.dart  # Test configuration
```

## Build Artifacts

- `build/` - Flutter build output (gitignored)
- `dist/` - Distribution packages (gitignored)
- `.dart_tool/` - Dart tooling cache (gitignored)
- `node_modules/` - Node.js dependencies (gitignored)

## CI/CD Pipeline (`.github/workflows/`)

```
.github/workflows/
├── build-release.yml       # Desktop app builds & GitHub releases
├── build-images.yml        # Docker image builds for cloud services
├── deploy-aks.yml          # Azure AKS deployment automation
├── bootstrap-secrets.yml   # Secrets management
└── README.md               # CI/CD documentation
```

### Build & Release Pipeline (`build-release.yml`)

**Triggers:**
- Push to tags matching `v*` pattern
- Manual workflow dispatch

**Jobs:**
1. **version-info**: Extracts version from `pubspec.yaml`, generates build number
2. **build-desktop**: Builds Windows desktop app (self-hosted runner)
   - Creates installer (.exe) using Inno Setup
   - Creates portable package (.zip)
   - Generates SHA256 checksums
3. **create-release**: Creates GitHub release with artifacts

**Outputs:**
- Windows installer: `CloudToLocalLLM-Windows-{version}-Setup.exe`
- Portable package: `cloudtolocalllm-{version}-portable.zip`
- SHA256 checksums for verification

### Cloud Deployment Pipeline (`deploy-eks.yml`)

**Triggers:**
- Push to `main` branch (paths: `k8s/`, `services/`, `config/`, `lib/`, `web/`)
- Manual workflow dispatch

**Jobs:**
1. **deploy**: 
   - Authenticates to AWS using OIDC (no long-lived credentials)
   - Builds and pushes Docker images to Docker Hub
   - Updates EKS deployments with new images
   - Purges Cloudflare cache
   - Waits for rollout completion
2. **dns-validation**:
   - Gets load balancer IP from EKS
   - Configures Cloudflare DNS records
   - Enables SSL/TLS (Full mode)
   - Enables Always Use HTTPS

**Deployed Services:**
- Web app: `cloudtolocalllm/cloudtolocalllm-web:latest`
- API backend: `cloudtolocalllm/cloudtolocalllm-api:latest`

**Domains:**
- https://cloudtolocalllm.online
- https://app.cloudtolocalllm.online
- https://api.cloudtolocalllm.online
- https://auth.cloudtolocalllm.online

### Legacy Azure Deployment Pipeline (`deploy-aks.yml`)

**Status:** Being migrated to AWS EKS
- Previously deployed to Azure AKS
- Will be decommissioned after AWS migration

### Docker Image Pipeline (`build-images.yml`)

**Triggers:**
- Push/PR to Dockerfiles or source code

**Outputs:**
- Builds and validates Docker images
- Pushes to Docker Hub with commit SHA tags
- Validates Kubernetes manifests

### Required Secrets

**Docker Hub:**
- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token

**AWS:**
- `AWS_ACCOUNT_ID` - AWS account ID
- `AWS_REGION` - AWS region (us-east-1)
- GitHub OIDC authentication (no long-lived credentials stored)

**Azure (Legacy):**
- `AZURE_CREDENTIALS` - Service principal credentials (JSON)
- `AZURE_CLIENT_ID` - Azure client ID
- `AZURE_TENANT_ID` - Azure tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID

**Cloudflare:**
- `CLOUDFLARE_API_TOKEN` - Cloudflare API token for DNS/SSL

### CI/CD Best Practices

- Desktop builds run on self-hosted Windows runner
- Cloud deployments use Azure-hosted runners
- All builds generate SHA256 checksums
- Automated DNS and SSL configuration via Cloudflare API
- Rollout verification before marking deployment complete
- Cache purging for immediate updates

## Version Management

- Version defined in `pubspec.yaml` (format: `X.Y.Z+buildNumber`)
- Synchronized with `package.json` for backend services
- Build number format: `YYYYMMDDHHmm` (UTC timestamp)
- Automated version bumping via scripts
- Git tags created automatically: `v{version}`
- GitHub releases created with build artifacts
