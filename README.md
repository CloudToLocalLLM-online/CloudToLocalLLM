# CloudToLocalLLM

Your Personal AI Powerhouse

[![Version](https://img.shields.io/badge/version-4.3.0-blue.svg)](https://github.com/imrightguy/CloudToLocalLLM/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.8+-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20Web-lightgrey.svg)](https://github.com/imrightguy/CloudToLocalLLM)

**Website: [https://cloudtolocalllm.online](https://cloudtolocalllm.online)**
**Web App: [https://app.cloudtolocalllm.online](https://app.cloudtolocalllm.online)**

## Overview

CloudToLocalLLM is a revolutionary Flutter-based application that bridges the gap between cloud-based AI services and local AI models. It provides a seamless, secure, and efficient way to interact with various AI models while maintaining complete control over your data and privacy.

### Key Features

- **Hybrid AI Architecture**: Seamlessly switch between cloud-based and local AI models
- **Privacy-First Design**: Keep sensitive data local while leveraging cloud AI when needed
- **Cross-Platform Support**: Available on Windows, Linux, and Web platforms
- **Secure Authentication**: Auth0 OAuth2 authentication with encrypted token storage
- **Real-Time Communication**: WebSocket-based tunneling for instant AI responses
- **Model Flexibility**: Support for OpenAI, Anthropic, and local Ollama models
- **User-Friendly Interface**: Intuitive Flutter-based UI with responsive design

## Quick Start

### Prerequisites

- **Flutter SDK** (3.8 or higher)
- **Node.js** (for development and testing)
- **Git** (for version control)
- **Ollama** (optional, for local AI models)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/imrightguy/CloudToLocalLLM.git
   cd CloudToLocalLLM
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   npm install
   ```

3. **Run the application:**
   ```bash
   # For desktop (Windows/Linux)
   flutter run -d windows
   flutter run -d linux

   # For web
   flutter run -d chrome
   ```

## Architecture

CloudToLocalLLM employs a sophisticated architecture that combines the best of both worlds:

### Cloud Integration
- **Auth0 Authentication**: Secure OAuth2 authentication via Auth0
- **API Gateway**: Centralized API management and routing
- **WebSocket Tunneling**: Real-time communication between client and cloud services
- **Load Balancing**: Intelligent distribution of requests across multiple AI providers

### Local AI Support
- **Ollama Integration**: Direct integration with local Ollama models
- **Model Management**: Easy installation and switching between local models
- **Privacy Protection**: All local processing stays on your device
- **Offline Capability**: Continue working even without internet connection

### Security Features
- **End-to-End Encryption**: All communications are encrypted
- **Token Management**: Secure storage and automatic refresh of authentication tokens
- **Data Isolation**: Clear separation between local and cloud data
- **Audit Logging**: Comprehensive logging for security monitoring

## Development

### Development Environment Setup

#### Windows Development
```powershell
# Run the automated setup script
.\scripts\powershell\Setup-WindowsDevelopmentEnvironment.ps1

# Or install manually:
choco install flutter nodejs git docker-desktop
```

#### Linux Development
```bash
# Install Flutter
sudo snap install flutter --classic

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install other dependencies
sudo apt-get install git docker.io
```

### Version Management

CloudToLocalLLM uses automated version management with documentation updates:

```powershell
# Windows
.\scripts\powershell\version_manager.ps1 increment patch

# Linux
./scripts/version_manager.sh increment patch
```

### Testing

```bash
# Run Flutter tests
flutter test

# Run e2e tests
npm test

# Run specific test suites
npm run test:auth
npm run test:tunnel
```

### Building

#### Local Development Builds

```bash
# Build for Windows
flutter build windows --release

# Build for Linux
flutter build linux --release

# Build for Web
flutter build web --release
```

#### Automated Builds (GitHub Actions)

CloudToLocalLLM uses **GitHub-hosted runners** for automated desktop builds, providing:
- ✅ **Zero infrastructure costs** (free for public repositories)
- ✅ **Automated dependency installation** (Flutter, Inno Setup, etc.)
- ✅ **Consistent, reproducible builds** across all platforms
- ✅ **Parallel builds** for faster release cycles

**Triggering Builds:**

1. **Automatic (Tag Push):**
   ```bash
   # Create and push a version tag
   git tag v4.5.0
   git push origin v4.5.0
   ```

2. **Manual (Workflow Dispatch):**
   - Go to GitHub Actions → "Build Desktop Apps & Create Release"
   - Click "Run workflow"
   - Select branch and build type
   - Click "Run workflow"

**Build Process:**
- Runs on `windows-latest` GitHub-hosted runner
- Installs Flutter SDK 3.32.8 automatically
- Installs Inno Setup via Chocolatey/Winget
- Creates Windows installer (.exe) and portable package (.zip)
- Generates SHA256 checksums for all artifacts
- Creates GitHub release with all packages

**Build Artifacts:**
- `CloudToLocalLLM-Windows-{version}-Setup.exe` - Windows installer
- `cloudtolocalllm-{version}-portable.zip` - Portable package
- Corresponding `.sha256` checksum files

For troubleshooting build issues, see [Build Troubleshooting Guide](docs/BUILD_TROUBLESHOOTING.md).
### Security

CloudToLocalLLM uses Auth0 for user authentication and deploys to Kubernetes (managed or self-hosted) for infrastructure security and scalability. Kubernetes secrets are managed securely through kubectl and your container registry.


## Deployment

CloudToLocalLLM uses a comprehensive CI/CD pipeline that separates desktop builds from cloud infrastructure deployment.

### 🖥️ Desktop Application Builds

Desktop builds run automatically on **GitHub-hosted runners** (free for public repos):

**Automated Builds (Recommended):**
```bash
# Create and push a version tag to trigger automated build
git tag v4.5.0
git push origin v4.5.0
```

**Manual Trigger:**
- Go to GitHub Actions → "Build Desktop Apps & Create Release"
- Click "Run workflow" → Select options → Run

**Build Infrastructure:**
- **Runner:** `windows-latest` (GitHub-hosted, free)
- **Cost:** $0/month (free for public repositories)
- **Dependencies:** Automatically installed (Flutter, Inno Setup)
- **Build Time:** ~15-20 minutes
- **Artifacts:** Windows installer (.exe) and portable package (.zip)

**What it does:**
- Builds Windows desktop application on GitHub infrastructure
- Installs all dependencies automatically (no manual setup)
- Creates installer and portable packages
- Generates SHA256 checksums for security verification
- Creates GitHub release with all artifacts

**Legacy Local Build Script:**
```powershell
# For local testing only (not recommended for releases)
.\scripts\powershell\Deploy-CloudToLocalLLM.ps1
```

### ☁️ Cloud Infrastructure Deployment

CloudToLocalLLM is deployed to **Kubernetes** using Dockerfiles and Kubernetes manifests. Works with:
- **Managed Kubernetes**: DigitalOcean (DOKS), Google GKE, AWS EKS, Azure AKS
- **Self-Hosted Kubernetes**: On-premises or your own infrastructure (ideal for businesses)

**Deployment Process:**
1. Build Docker images using Dockerfiles
2. Push images to container registry (any registry: Docker Hub, DigitalOcean, self-hosted, etc.)
3. Deploy to Kubernetes cluster using `kubectl apply -f k8s/`

```bash
# Build and push images (example with Docker Hub)
docker build -f config/docker/Dockerfile.web -t your-registry/cloudtolocalllm-web:latest .
docker build -f services/api-backend/Dockerfile.prod -t your-registry/cloudtolocalllm-api:latest .
docker push your-registry/cloudtolocalllm-web:latest
docker push your-registry/cloudtolocalllm-api:latest

# Deploy to Kubernetes (works with any cluster)
kubectl apply -f k8s/
```

**What's Deployed:**
- Web application (Flutter web app)
- API backend (Node.js Express)
- PostgreSQL database (StatefulSet)
- Ingress controller with SSL certificates (cert-manager)

### 📋 Deployment Overview

| Component | Technology | Location |
|---------|--------|--------|
| Desktop builds | GitHub Actions (hosted runners) | `.github/workflows/build-release.yml` |
| Cloud deployment | Kubernetes (managed or self-hosted) | `k8s/` directory |
| Container builds | Dockerfiles | `config/docker/`, `services/api-backend/` |

### 📚 Documentation

**Build & Release:**
- **[Build Troubleshooting Guide](docs/BUILD_TROUBLESHOOTING.md)** - Fix common build issues
- **[CI/CD Setup Guide](docs/CICD_SETUP_GUIDE.md)** - Complete CI/CD configuration

**Cloud Deployment:**
- **[Kubernetes Quick Start](docs/KUBERNETES_QUICKSTART.md)** - Kubernetes deployment example (DigitalOcean)
- **[Kubernetes README](k8s/README.md)** - Complete Kubernetes deployment guide (works with any cluster)
- **[Complete Deployment Workflow](docs/DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)** - Step-by-step deployment guide
- **[Deployment Overview](docs/DEPLOYMENT/DEPLOYMENT_OVERVIEW.md)** - All deployment options (managed or self-hosted)
- **[Cloud Run OIDC/WIF Guide](config/cloudrun/OIDC_WIF_SETUP.md)** - Keyless GitHub Actions deployment setup

**Development:**
- **[MCP Development Workflow](docs/MCP_DEVELOPMENT_WORKFLOW.md)** - Guidelines for model-driven development

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```env
# API Configuration
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key

# Server Configuration
SERVER_HOST=localhost
SERVER_PORT=3000

# Database Configuration
DATABASE_URL=your_database_url

# OAuth Configuration
OAUTH_CLIENT_ID=your_client_id
OAUTH_CLIENT_SECRET=your_client_secret
```

### Local AI Models

To use local AI models with Ollama:

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Download models
ollama pull llama3.2:1b
ollama pull codellama:7b
ollama pull mistral:7b
```

## API Documentation

### Authentication Endpoints

- `POST /auth/login` - Initiate OAuth login
- `POST /auth/callback` - Handle OAuth callback
- `POST /auth/refresh` - Refresh authentication token
- `POST /auth/logout` - Logout and invalidate tokens

### AI Model Endpoints

- `POST /api/chat` - Send chat message to AI model
- `GET /api/models` - List available AI models
- `POST /api/models/switch` - Switch active AI model
- `GET /api/models/status` - Get model status and health

### WebSocket Events

- `connection` - Establish WebSocket connection
- `message` - Send/receive chat messages
- `model_switch` - Switch AI model in real-time
- `status_update` - Receive status updates

### Admin Center API (Backend)

The Admin Center provides secure administrative endpoints and a comprehensive UI for managing users, subscriptions, and payments.

**Available Endpoints:**

- `GET /api/admin/users` - List users with pagination and filtering
- `GET /api/admin/users/:userId` - Get detailed user profile
- `PATCH /api/admin/users/:userId` - Update user subscription tier
- `POST /api/admin/users/:userId/suspend` - Suspend user account
- `POST /api/admin/users/:userId/reactivate` - Reactivate suspended account

**Features:**
- Role-based access control (Super Admin, Support Admin, Finance Admin)
- Comprehensive audit logging for all administrative actions
- Automatic prorated charge calculation for subscription changes
- Session invalidation on account suspension
- PostgreSQL database with migration system

**Documentation:**
- [Admin API Reference](docs/API/ADMIN_API.md)
- [Admin Center Requirements](.kiro/specs/admin-center/requirements.md)
- [Admin Center Design](.kiro/specs/admin-center/design.md)
- [Database Setup Guide](services/api-backend/database/QUICKSTART.md)

**Quick Setup:**
```bash
# Apply database migration
node services/api-backend/database/migrations/run-migration.js up 001

# Apply seed data (development only)
node services/api-backend/database/seeds/run-seed.js apply 001
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Add tests**
5. **Submit a pull request**

### Code Style

- Follow Flutter/Dart conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Ensure all tests pass

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: [https://docs.cloudtolocalllm.online](https://docs.cloudtolocalllm.online)
- **Issues**: [GitHub Issues](https://github.com/imrightguy/CloudToLocalLLM/issues)
- **Discussions**: [GitHub Discussions](https://github.com/imrightguy/CloudToLocalLLM/discussions)
- **Email**: support@cloudtolocalllm.online

## Acknowledgments

- **Flutter Team** for the amazing cross-platform framework
- **Ollama** for local AI model support
- **OpenAI** and **Anthropic** for cloud AI services
- **Community Contributors** for their valuable contributions

---

**Made with ❤️ by the CloudToLocalLLM Team**

Triggering a new build to test the Cloud Build trigger.

<!-- trigger build -->
