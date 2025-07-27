# CloudToLocalLLM Deployment Overview

This document provides a comprehensive overview of deployment options and strategies for CloudToLocalLLM.

## 📋 Table of Contents

- [Deployment Options](#deployment-options)
- [Multi-Container Architecture](#multi-container-architecture)
- [Deployment Scripts](#deployment-scripts)
- [Quality Standards](#quality-standards)
- [Versioning Strategy](#versioning-strategy)
- [Related Documentation](#related-documentation)

---

## Deployment Options

### 🚀 Multi-Container Deployment (Recommended)

Deploy the full CloudToLocalLLM stack to your own Virtual Private Server (VPS) using Docker Compose with **strict quality standards**.

```bash
# Automated deployment with zero-tolerance quality verification
# Use --force flag for fully automatic execution without prompts
cd /path/to/CloudToLocalLLM
./scripts/deploy/complete_deployment.sh --force
```

**Benefits:**
- Scalable and secure environment for multiple users
- Automated SSL certificate management
- Isolated services prevent cascading failures
- Enhanced network policies and container isolation

**Requirements:**
- VPS with Docker and Docker Compose
- Domain name with DNS configuration
- Minimum 2GB RAM, 20GB storage

### 🏠 Self-Hosting Options

For detailed self-hosting instructions, see:
- [Self-Hosting Guide](../OPERATIONS/SELF_HOSTING.md)
- [Infrastructure Guide](../OPERATIONS/INFRASTRUCTURE_GUIDE.md)

### ⚠️ Legacy Single Container (Deprecated)

The legacy single-container deployment is deprecated and no longer supported. Please migrate to the multi-container architecture.

---

## Multi-Container Architecture

CloudToLocalLLM features a modern multi-container architecture that provides:

### 🏗️ **Architecture Benefits**
- **Scalability**: Easily handle multiple users and connections
- **Resilience**: Isolated services prevent cascading failures
- **Maintainability**: Clear separation of concerns simplifies development and updates
- **Security**: Enhanced network policies and container isolation

### 🔧 **Key Containers**
- `nginx-proxy`: SSL termination and request routing
- `flutter-app`: The unified Flutter web application (UI, chat, marketing pages)
- `api-backend`: Core API, authentication, and streaming proxy management
- `streaming-proxy` (ephemeral): Lightweight proxies for user-to-local-LLM communication
- `certbot`: Automated SSL certificate management

For detailed information, see [System Architecture](../ARCHITECTURE/SYSTEM_ARCHITECTURE.md).

---

## Deployment Scripts

### 🎯 **Primary Deployment Scripts**

#### `scripts/deploy/complete_deployment.sh` (RECOMMENDED)
Fully automated deployment with strict quality verification and zero-tolerance policy.

```bash
# Basic deployment
./scripts/deploy/complete_deployment.sh --force

# With verbose output
./scripts/deploy/complete_deployment.sh --force --verbose

# Dry run (preview only)
./scripts/deploy/complete_deployment.sh --dry-run
```

#### `scripts/deploy/update_and_deploy.sh`
Deploys the multi-container architecture to a VPS.

#### `scripts/deploy/verify_deployment.sh`
Strict verification script that enforces zero warnings/errors policy.

### 🔧 **Supporting Scripts**

#### `scripts/version_manager.sh`
Manages project version numbers across different files.

```bash
# Increment version
./scripts/version_manager.sh increment minor

# Set specific version
./scripts/version_manager.sh set 3.13.0

# Get current version
./scripts/version_manager.sh get
```

#### `scripts/deploy/complete_automated_deployment.sh`
Orchestrates a full deployment workflow including versioning, building, and distributing.

For a complete list of scripts, see [scripts/README.md](../../scripts/README.md).

---

## Quality Standards

### 🎯 Strict Deployment Policy

CloudToLocalLLM enforces a **zero-tolerance deployment policy** for production:

- ✅ **Success**: Zero warnings AND zero errors required
- ❌ **Failure**: Any warning condition triggers automatic rollback
- 🔄 **Rollback**: Immediate restoration of previous version on any issue
- 🏆 **Quality**: Only perfect deployments reach production

### 📊 **Success Criteria**
- Perfect HTTP 200 responses (no redirects)
- Valid SSL certificates mandatory
- Clean container logs (no errors)
- Optimal system resources (<90% usage)
- Fully functional application health checks

See [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md) for complete details.

---

## Versioning Strategy

CloudToLocalLLM uses a granular build numbering system:

- **Format**: `v<major>.<minor>.<patch>+<build>` (e.g., `v3.13.0+202507262156`)
- **`major.minor.patch`**: Semantic versioning for core application
- **`build`**: Incremental build number based on timestamp (YYYYMMDDHHMM)

This allows for precise tracking of releases and development builds.

For detailed information, see [Versioning Strategy](VERSIONING_STRATEGY.md).

---

## Related Documentation

### 📚 **Deployment Guides**
- [Complete Deployment Workflow](COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md)
- [VPS Quality Gates Specification](VPS_QUALITY_GATES_SPECIFICATION.md)
- [Deployment Testing Guide](DEPLOYMENT_TESTING_GUIDE.md)

### 🔧 **Operations**
- [Self-Hosting Guide](../OPERATIONS/SELF_HOSTING.md)
- [Infrastructure Guide](../OPERATIONS/INFRASTRUCTURE_GUIDE.md)
- [Tunnel Troubleshooting](../OPERATIONS/TUNNEL_TROUBLESHOOTING.md)

### 🏗️ **Architecture**
- [System Architecture](../ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
- [Multi-Container Architecture](../ARCHITECTURE/MULTI_CONTAINER_ARCHITECTURE.md)
- [Streaming Proxy Architecture](../ARCHITECTURE/STREAMING_PROXY_ARCHITECTURE.md)

### 👨‍💻 **Development**
- [Developer Onboarding](../DEVELOPMENT/DEVELOPER_ONBOARDING.md)
- [API Documentation](../DEVELOPMENT/API_DOCUMENTATION.md)

---

*For questions about deployment, please see our [troubleshooting guide](deployment-troubleshooting.md) or [open an issue](https://github.com/imrightguy/CloudToLocalLLM/issues).*
