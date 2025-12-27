# CloudToLocalLLM Documentation Index

Welcome to the consolidated documentation for CloudToLocalLLM. This repository has been reorganized for clarity, governance, and ease of maintenance.

## 📚 Documentation Categories

### 📦 [Deployment](deployment/)
- [Deployment Overview](deployment/DEPLOYMENT_OVERVIEW.md)
- [Installation Guides](deployment/installation/) (Linux, Windows, macOS)
- [ArgoCD Integration](deployment/ARGOCD_INTEGRATION.md)
- [Docker Deployment](deployment/DOCKER_DEPLOYMENT.md)
- [AKS Setup](deployment/AKS_FIRST_TIME_SETUP.md)

### 🏗️ [Architecture](architecture/)
- [System Architecture](architecture/SYSTEM_ARCHITECTURE.md)
- [Tunnel System](architecture/TUNNEL_SYSTEM.md)
- [Architectural Decisions](architecture/decisions/)
- [Service Architecture](architecture/services/)
- [Tunnel System Architecture](architecture/tunnel/)
- [Unified Flutter Web](architecture/UNIFIED_FLUTTER_WEB.md)

### 👨‍💻 [Development](development/)
- [Contributing Guidelines](development/CONTRIBUTING.md)
- [Agent Context & Operating Manual](development/AGENT_CONTEXT.md)
- [Developer Onboarding](development/DEVELOPER_ONBOARDING.md)
- [MCP Workflow and Rules](development/MCP_WORKFLOW_AND_RULES.md)
- [Testing Strategy](development/testing/TESTING_STRATEGY.md)
- [Versioning Policy](development/versioning/VERSIONING.md)
- [Changelog](development/release/CHANGELOG.md)

### 🔌 [API Reference](api/)
- [Admin Center API](api/ADMIN_API.md)
- [Tunnel Client API](api/TUNNEL_CLIENT_API.md)
- [Tunnel Server API](api/TUNNEL_SERVER_API.md)
- [API Policies](api/policies/) (Versioning, Deprecation, Error Codes)

### ⚙️ [Operations](operations/)
- [Backend Operations](operations/backend/) (Backup, Failover, Monitoring)
- [CI/CD Pipelines](operations/cicd/)
- [AWS EKS Operations](operations/aws/)
- [CloudRun Operations](operations/cloudrun/)
- [Kubernetes Self-Hosted](operations/kubernetes/)
- [Disaster Recovery](operations/DISASTER_RECOVERY_STRATEGY.md)

### ⚖️ [Governance](governance/)
- [Legal](governance/legal/) (Privacy, Terms)
- [Security](governance/security/) (Permissions, Audit Reports)

### 👥 [User Guide](user-guide/)
- [Admin Center User Guide](user-guide/ADMIN_CENTER_USER_GUIDE.md)

### 🗄️ [Archive](archive/)
- [Audit Reports](archive/audit/)
- [Old Reports](archive/reports/)
- [Task Logs](archive/tasks/)

---

## 📖 Documentation Standards
- **Standardized Paths**: All documentation is located in the `docs/` directory with lowercase subdirectories.
- **Cross-Referencing**: Docs are interlinked. Always use relative paths.
- **Agent Governance**: AI Agents follow the guidelines in [AGENT_CONTEXT.md](development/AGENT_CONTEXT.md).

## 🔄 Recent Updates
### 2025-12-27: Repository Consolidation
- Standardized directory structure (lowercase).
- Consolidated Admin API documentation into a single reference.
- Sanitized root directory by moving misplaced documentation and config files.
- Updated governance and contribution guidelines.
