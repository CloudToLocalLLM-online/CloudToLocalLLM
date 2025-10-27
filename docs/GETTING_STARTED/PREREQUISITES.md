# Prerequisites

Before getting started with CloudToLocalLLM, ensure your development environment meets these requirements.

## Required Software

### Core Requirements
- **Flutter SDK 3.8+**
  - Required for building the cross-platform UI
  - Download from [flutter.dev](https://flutter.dev)

- **Node.js 16/18+**
  - Required for the backend server
  - Download from [nodejs.org](https://nodejs.org)

### Optional Components
- **Ollama**
  - Required for local AI model support
  - Follow installation at [ollama.ai](https://ollama.ai)

## Development Tools

### Required Tools
- **Git**
  - Version control system
  - Required for development workflow

- **VS Code** (recommended)
  - Primary development environment
  - Required extensions:
    - Flutter
    - Dart
    - ESLint
    - Prettier

### Optional Tools
- **Docker** and **Docker Compose**
  - Required for container-based development
  - Recommended for consistent environments

- **PowerShell 7+** (Windows)
  - Required for Windows development scripts
  - Available from Microsoft Store or PowerShell website

## System Requirements

### Minimum Specifications
- **CPU**: 4 cores
- **RAM**: 8GB
- **Storage**: 10GB free space
- **OS**: Windows 10/11, macOS 10.15+, or Linux

### Recommended Specifications
- **CPU**: 8+ cores
- **RAM**: 16GB
- **Storage**: 20GB+ free space (SSD recommended)
- **GPU**: Dedicated GPU for local AI model acceleration

## Network Requirements

### Development
- Internet connection for dependency downloads
- Local ports available:
  - 3000 (backend API)
  - 8080 (development server)

### Production
- HTTPS certificates (for production deployment)
- Domain name (optional, for production deployment)

## Next Steps
- [Installation Guide](INSTALLATION.md)
- [Quick Start Guide](QUICKSTART.md)
- [Development Setup](../DEVELOPMENT/README.md)