# CloudToLocalLLM Documentation

Welcome to the CloudToLocalLLM documentation! This directory contains comprehensive guides for users, developers, and system administrators.

## 📚 Documentation Structure

### 📦 **Installation & Setup**
- **[Installation Overview](INSTALLATION/README.md)** - Choose your platform and installation method
- **[Linux Installation](INSTALLATION/LINUX.md)** - Ubuntu, Debian, Arch, and other distributions
- **[Windows Installation](INSTALLATION/WINDOWS.md)** - Windows 10/11 desktop application
- **[macOS Installation](INSTALLATION/MACOS.md)** - Coming soon (development preview available)
- **** - Getting started after installation

### 👥 **User Guides**
- **[User Guide](USER_DOCUMENTATION/USER_GUIDE.md)** - How to use CloudToLocalLLM
- **[Features Guide](USER_DOCUMENTATION/FEATURES_GUIDE.md)** - Detailed feature explanations
- **[Troubleshooting Guide](USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md)** - Common issues and solutions
- **[Setup FAQ](USER_DOCUMENTATION/SETUP_TROUBLESHOOTING_FAQ.md)** - Frequently asked questions

### 🏗️ Architecture Documentation
- **[System Architecture](ARCHITECTURE/SYSTEM_ARCHITECTURE.md)** - Overall system design
- **[Secure Tunnel & Web Interface Design](ARCHITECTURE/SECURE_TUNNEL_WEB_INTERFACE_DESIGN.md)** - Comprehensive design specification for core infrastructure components
- **[Tunnel System](ARCHITECTURE/TUNNEL_SYSTEM.md)** - Secure tunnel management
- **[System Tray Implementation](ARCHITECTURE/UNIFIED_FLUTTER_NATIVE_SYSTEM_TRAY.md)** - Desktop integration details
- **[Unified Flutter Web](ARCHITECTURE/UNIFIED_FLUTTER_WEB.md)** - Web platform architecture
- **[Architecture Codemap](ARCHITECTURE/architecture-codemap.md)** - Code organization and structure
- **[Chisel Integration Plan](ARCHITECTURE/CHISEL_INTEGRATION_PLAN.md)** - Chisel tunnel integration
- **[LangChain Integration Plan](ARCHITECTURE/LANGCHAIN_INTEGRATION_PLAN.md)** - AI framework integration
- **[Tunnel Feature Analysis](ARCHITECTURE/TUNNEL_FEATURE_ANALYSIS.md)** - Tunnel system capabilities
- **[Third Party Tunnel Evaluation](ARCHITECTURE/THIRD_PARTY_TUNNEL_EVALUATION.md)** - Alternative tunnel solutions

### 🔗 Tunnel Integration
- **[Tunnel System](ARCHITECTURE/TUNNEL_SYSTEM.md)** - Secure tunnel management with Cloudflare
  - Platform abstraction patterns
  - Supabase Auth JWT validation integration
  - Cross-platform compatibility
  - Troubleshooting and support

### 🚀 **Deployment & Operations**
- **[Provider Infrastructure Guide](DEPLOYMENT/PROVIDER_INFRASTRUCTURE_GUIDE.md)** - Multi-cloud deployment options and current status
- **[Deployment Overview](DEPLOYMENT/DEPLOYMENT_OVERVIEW.md)** - All deployment options and strategies
- **[Complete Deployment Workflow](DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)** - End-to-end deployment process
- **[Strict Deployment Policy](DEPLOYMENT/STRICT_DEPLOYMENT_POLICY.md)** - Zero-tolerance quality standards
- **[Auth0 Migration Guide](DEPLOYMENT/AUTH0_MIGRATION_GUIDE.md)** - Authentication system migration
- **[Docker Deployment](DEPLOYMENT/DOCKER_DEPLOYMENT.md)** - Container-based deployment
- **[Self-Hosting Guide](OPERATIONS/SELF_HOSTING.md)** - Deploy your own instance
- **[Infrastructure Guide](OPERATIONS/INFRASTRUCTURE.md)** - Server requirements and setup
- **[Disaster Recovery Strategy](OPERATIONS/DISASTER_RECOVERY_STRATEGY.md)** - Business continuity planning
- **[AWS Operations](OPERATIONS/aws/README.md)** - AWS infrastructure and deployment
- **[Kubernetes Operations](OPERATIONS/kubernetes/README.md)** - Kubernetes deployment and management
- **[CI/CD Operations](OPERATIONS/cicd/README.md)** - CI/CD pipelines and workflows

### 👨‍💻 **Development**
- **[Developer Onboarding](DEVELOPMENT/DEVELOPER_ONBOARDING.md)** - Get started with development
- **[Development Workflow](DEVELOPMENT/DEVELOPMENT_WORKFLOW.md)** - Development tools and automation
- **[Building Guide](DEVELOPMENT/BUILDING_GUIDE.md)** - Build applications for all platforms
- **[API Documentation](DEVELOPMENT/API_DOCUMENTATION.md)** - Technical API reference
- **[Contribution Guidelines](DEVELOPMENT/CONTRIBUTING.md)** - How to contribute to the project
- **** - Android platform development
- **[Linux Build Guide](DEVELOPMENT/LINUX_BUILD_GUIDE.md)** - Linux platform development
- **[Build Scripts](DEVELOPMENT/BUILD_SCRIPTS.md)** - Automated build processes
- **** - Common build issues
- **[MCP Workflow and Rules](DEVELOPMENT/MCP_WORKFLOW_AND_RULES.md)** - Model Context Protocol integration
- **[Gemini Setup](DEVELOPMENT/SETUP-GEMINI.md)** - Google Gemini AI integration
- **[PAT Setup](DEVELOPMENT/SETUP-PAT.md)** - Personal Access Token configuration

### 🔧 **Backend Documentation**
- **[Backend Overview](backend/README.md)** - Overview of backend services
- **[Feature Implementations](backend/features/README.md)** - Detailed feature guides
- **[Backend Operations](backend/ops/README.md)** - Backup, failover, and monitoring

### 📋 **Additional Resources**
- **[API Documentation](API/)** - API reference and tier system
- **[Testing Documentation](TESTING/)** - Testing strategies and guides
- **[Security Documentation](SECURITY/)** - Security policies and audit reports
- **[Release Notes](RELEASE/RELEASE_NOTES.md)** - Version history and changes
- **[Versioning Documentation](VERSIONING/)** - Version management and build processes
- **[Legal Documentation](LEGAL/)** - Privacy policy and terms of service
- **[Audit Reports](audit/)** - Documentation audit and cleanup reports
- **[Archive](archive/README.md)** - Archived documentation and reports

## 📖 Documentation Standards

This documentation follows these principles:
- **User-focused**: Written for the intended audience with clear, actionable guidance
- **Comprehensive**: Covers all aspects of each topic with detailed explanations
- **Up-to-date**: Regularly updated to reflect the latest changes and features
- **Cross-referenced**: Extensive linking between related documentation
- **Searchable**: Well-organized with clear headings and table of contents
- **Platform-aware**: Specific guidance for different operating systems and environments

## 🤝 Contributing to Documentation

We welcome improvements to our documentation! Here's how you can help:

### **📝 Ways to Contribute**
- **Fix typos and errors** - Submit PRs for corrections
- **Add missing information** - Fill gaps in existing documentation
- **Create new guides** - Write documentation for new features
- **Improve clarity** - Make complex topics easier to understand
- **Update screenshots** - Keep visual guides current

### **📋 Documentation Guidelines**
- Follow the existing structure and formatting
- Include table of contents for longer documents
- Add cross-references to related documentation
- Test all instructions before submitting
- Use clear, concise language appropriate for the target audience

See our [Contribution Guidelines](development/CONTRIBUTING.md) for detailed information on contributing.

## 📖 Quick Navigation

### **🆕 New Users**
1. **[Choose Installation Method](INSTALLATION/README.md)** - Pick your platform
2. **[Install CloudToLocalLLM](INSTALLATION/)** - Follow platform-specific guide
3. **** - Configure your installation
4. **[User Guide](USER_DOCUMENTATION/USER_GUIDE.md)** - Learn how to use the application

### **🏠 Self-Hosters**
1. **[System Architecture](ARCHITECTURE/SYSTEM_ARCHITECTURE.md)** - Understand the system design
2. **[Infrastructure Guide](OPERATIONS/INFRASTRUCTURE_GUIDE.md)** - Plan your server setup
3. **[Self-Hosting Guide](OPERATIONS/SELF_HOSTING.md)** - Deploy your own instance
4. **[Deployment Overview](DEPLOYMENT/DEPLOYMENT_OVERVIEW.md)** - Choose deployment strategy

### **👨‍💻 Developers**
1. **[Developer Onboarding](DEVELOPMENT/DEVELOPER_ONBOARDING.md)** - Set up development environment
2. **[Development Workflow](DEVELOPMENT/DEVELOPMENT_WORKFLOW.md)** - Learn the development process
3. **[Building Guide](DEVELOPMENT/BUILDING_GUIDE.md)** - Build for different platforms
4. **[API Documentation](DEVELOPMENT/API_DOCUMENTATION.md)** - Technical API reference
5. **[Contribution Guidelines](DEVELOPMENT/CONTRIBUTING.md)** - How to contribute

### **🔧 System Administrators**
1. **[Deployment Overview](DEPLOYMENT/DEPLOYMENT_OVERVIEW.md)** - Understand deployment options
2. **[Kubernetes Operations](OPERATIONS/kubernetes/README.md)** - Kubernetes deployment guide
3. **[Infrastructure Guide](OPERATIONS/INFRASTRUCTURE.md)** - Server management
4. **[AWS Operations](OPERATIONS/aws/README.md)** - AWS infrastructure management
5. **[Backend Operations](backend/ops/README.md)** - Backend maintenance

### For Developers
1. Review [System Architecture](ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
2. Understand [Streaming Proxy Architecture](ARCHITECTURE/STREAMING_PROXY_ARCHITECTURE.md)
3. Learn about tunnel management and platform abstraction patterns
4. Follow [Developer Onboarding](DEVELOPMENT/DEVELOPER_ONBOARDING.md)
5. Reference [API Documentation](DEVELOPMENT/API_DOCUMENTATION.md)

### For System Administrators
1. Study [Infrastructure Guide](OPERATIONS/INFRASTRUCTURE.md)
2. Review [Deployment Workflow](DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)
3. Configure [Environment Separation](DEPLOYMENT/ENVIRONMENT_SEPARATION_GUIDE.md)
4. Set up monitoring and maintenance procedures

## 🆘 Getting Help

### Common Issues
- **Installation Problems**: Check [Installation Guide](INSTALLATION/README.md)
- **Connection Issues**: See [Troubleshooting Guide](USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md)
- **Tunnel Problems**: Review connection fallback hierarchy and tunnel configuration
- **Performance Issues**: Monitor connection status and tunnel health

### Support Channels
- **GitHub Issues**: [Report bugs and request features](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues)
- **Documentation**: Search this documentation for answers
- **Community**: Participate in repository discussions

### Contributing to Documentation
We welcome contributions to improve documentation:
1. **Corrections**: Fix typos, errors, or outdated information
2. **Additions**: Add missing information or new guides
3. **Examples**: Provide real-world usage examples
4. **Translations**: Help translate documentation

## 📊 Documentation Status

| Section | Status | Last Updated |
|---------|--------|--------------|
| User Documentation | ✅ Complete | 2025-07-12 |
| Architecture | ✅ Complete | 2025-07-12 |
| **Unified Flutter-Native** | ✅ **Complete** | 2025-07-12 |
| Deployment | ✅ Complete | 2025-07-12 |
| Development | ✅ Complete | 2025-07-12 |
| Operations | ✅ Complete | 2025-07-12 |
| Backend | ✅ Consolidated | 2025-12-02 |

## 🔄 Recent Updates

### 2025-12-02: Documentation Consolidation
- Consolidated backend documentation from `services/api-backend/` to `docs/backend/`
- Organized operational docs into `docs/ops/` (AWS, Kubernetes, CI/CD)
- Archived older task summaries to `docs/archive/`
- Updated documentation structure for better discoverability

### 2025-07-12: Documentation Consolidation and Architecture Standardization
- Updated all documentation to reflect current version 3.10.3
- Consolidated duplicate installation guides into single authoritative guide
- Standardized architecture terminology to "Unified Flutter-Native Architecture"
- Updated AUR status to "temporarily decommissioned with reintegration planned"
- Removed outdated version-specific deployment guides
- Fixed cross-references and improved navigation structure

---

*For the most current information, always refer to the official repository and documentation.*
