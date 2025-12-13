# Technology Stack

## Frontend

- **Flutter SDK**: 3.5+ (Dart 3.5.0+)
- **State Management**: Provider pattern with GetIt dependency injection
- **Routing**: go_router for navigation
- **UI Framework**: Material Design with custom theming
- **Platform Support**: Windows, Linux, Web (macOS in development)
- **Authentication**: Auth0 with OIDC flows (auth provider agnostic)
- **Error Tracking**: Sentry Flutter integration

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
- `auth0_flutter` - Auth0 authentication
- `supabase_flutter` - Optional Supabase integration (auth provider agnostic)
- `flutter_secure_storage` - Secure credential storage
- `sqflite` / `sqflite_common_ffi` - Local database (desktop/web)
- `shared_preferences` - Web-compatible storage
- `window_manager` - Desktop window control
- `tray_manager` - System tray integration
- `dartssh2` - SSH tunneling
- `langchain` / `langchain_ollama` / `langchain_community` - LangChain integration
- `get_it` - Dependency injection
- `dio` - HTTP client with streaming
- `web_socket_channel` - WebSocket support
- `sentry_flutter` - Error tracking and performance monitoring
- `web` - Web interop (replaces deprecated `js` package)
- `app_links` - Deep linking support
- `rxdart` - Reactive extensions for Dart

### Node.js
- `@modelcontextprotocol/sdk` - MCP integration
- `@aws-sdk/client-ce` - AWS Cost Explorer client
- `@aws-sdk/client-cloudwatch` - AWS CloudWatch client
- `@playwright/test` - End-to-end testing
- `zod` - Schema validation
- `jest` - Testing framework
- `fast-check` - Property-based testing
- `supertest` - HTTP testing
- `jsonwebtoken` - JWT token handling
- `dotenv` - Environment configuration

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

### AWS CLI (`aws`)
- Use for AWS resource management and operations
- Authentication, resource queries, deployments
- Prefer `aws` commands over manual AWS console operations
- EKS cluster management, CloudFormation deployments
- Cost monitoring and optimization

### Azure CLI (`az`) - Legacy
- Previously used for Azure resource management
- Being phased out in favor of AWS infrastructure
- Still available for migration tasks

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
- Use `aws` for cloud infrastructure queries and management
- Use Grafana for real-time monitoring and alerting
- Use Playwright to verify deployments and test live applications
- CLI tools provide better automation and reproducibility than manual operations
- Monitor AWS costs using `scripts/aws/cost-monitoring.js`

## Database

- **Desktop**: SQLite via sqflite_common_ffi
- **Web**: IndexedDB via sqflite web implementation
- **Cloud**: PostgreSQL (StatefulSet in Azure AKS)
- **Future Options**: Can be deployed to AWS RDS or any Kubernetes cluster

## Deployment

### Desktop Applications
```powershell
# Build and release desktop apps
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1
```

### Cloud Infrastructure

**Azure AKS Deployment (Current Production):**
```bash
# Azure authentication
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID

# Build and push Docker images to ACR
az acr build --registry imrightguycloudtolocalllm --image web:latest .
az acr build --registry imrightguycloudtolocalllm --image api-backend:latest ./services/api-backend

# Deploy to Azure AKS
az aks get-credentials --resource-group cloudtolocalllm-rg --name cloudtolocalllm-aks
kubectl apply -f k8s/
```

**AWS EKS Deployment (Future Option):**
```bash
# AWS CloudFormation templates available in config/cloudformation/
# OIDC authentication patterns documented
# Can be deployed when AWS migration is desired
```

## Code Style

- Follow standard Dart/Flutter conventions
- Use `dart format .` before committing
- Meaningful variable and function names
- Comments for complex logic
- All new features require tests

## AWS Infrastructure

### EKS Deployment Architecture

- **Cluster**: AWS EKS with Kubernetes 1.30
- **Nodes**: t3.medium instances (cost-optimized for development)
- **Networking**: VPC with private subnets, NAT gateways, Network Load Balancer
- **Security**: OIDC authentication, IAM roles, private node groups
- **Monitoring**: CloudWatch Container Insights, custom metrics

### Infrastructure as Code

**CloudFormation Templates:**
- `config/cloudformation/vpc-networking.yaml` - VPC, subnets, security groups
- `config/cloudformation/iam-roles.yaml` - IAM roles and policies
- `config/cloudformation/eks-cluster.yaml` - EKS cluster and node groups

**Deployment Order:**
1. VPC and networking infrastructure
2. IAM roles and OIDC provider
3. EKS cluster and node groups
4. Kubernetes resources (k8s/ directory)

### Cost Optimization

**Monthly Budget:** $300 (development environment)

**Cost Monitoring:**
```bash
# Generate cost report
node scripts/aws/cost-monitoring.js

# Estimated costs:
# - t3.medium (2 nodes): ~$60/month
# - Network Load Balancer: ~$16/month
# - EBS storage: ~$10/month
# - Data transfer: ~$5/month
# Total: ~$91/month (well within budget)
```

**Cost Controls:**
- Auto-scaling node groups (min: 1, max: 5)
- t3.medium instances (cost-effective)
- Spot instances consideration for non-critical workloads
- Resource requests/limits to prevent over-provisioning

### Security Best Practices

- **OIDC Authentication**: No long-lived AWS credentials in GitHub Actions
- **Private Subnets**: EKS nodes not publicly accessible
- **IAM Roles**: Least privilege access, service-specific roles
- **Network Policies**: Kubernetes network segmentation
- **Encryption**: At-rest and in-transit encryption
- **Secrets Management**: Kubernetes secrets with encryption

### Disaster Recovery

**Backup Strategy:**
```bash
# Database backup
./scripts/aws/backup-postgres.sh

# Database restore
./scripts/aws/restore-postgres.sh
```

**Recovery Procedures:**
- Infrastructure recreation from CloudFormation templates
- Database restoration from automated backups
- Application deployment via GitHub Actions
- DNS failover using Cloudflare

### Migration from Azure

**Status:** In progress - migrating from Azure AKS to AWS EKS

**Migration Steps:**
1. ✅ AWS infrastructure setup (CloudFormation templates)
2. ✅ OIDC provider configuration
3. ✅ GitHub Actions workflow updates
4. 🔄 DNS migration to AWS load balancer
5. ⏳ Azure resource decommissioning

**Rollback Plan:**
- Maintain Azure infrastructure during migration
- DNS-based traffic switching
- Automated rollback procedures