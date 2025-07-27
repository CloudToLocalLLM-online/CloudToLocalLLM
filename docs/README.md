# CloudToLocalLLM Documentation

Welcome to the CloudToLocalLLM documentation! This directory contains comprehensive guides for users, developers, and system administrators.

## 📚 Documentation Structure

### 📦 **Installation & Setup**
- **[Installation Overview](INSTALLATION/README.md)** - Choose your platform and installation method
- **[Linux Installation](INSTALLATION/LINUX.md)** - Ubuntu, Debian, Arch, and other distributions
- **[Windows Installation](INSTALLATION/WINDOWS.md)** - Windows 10/11 desktop application
- **[macOS Installation](INSTALLATION/MACOS.md)** - Coming soon (development preview available)
- **[First Time Setup](USER_DOCUMENTATION/FIRST_TIME_SETUP.md)** - Getting started after installation

### 👥 **User Guides**
- **[User Guide](USER_DOCUMENTATION/USER_GUIDE.md)** - How to use CloudToLocalLLM
- **[Features Guide](USER_DOCUMENTATION/FEATURES_GUIDE.md)** - Detailed feature explanations
- **[Troubleshooting Guide](USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md)** - Common issues and solutions
- **[Setup FAQ](USER_DOCUMENTATION/SETUP_TROUBLESHOOTING_FAQ.md)** - Frequently asked questions

### 🏗️ Architecture Documentation
- **[System Architecture](ARCHITECTURE/SYSTEM_ARCHITECTURE.md)** - Overall system design
- **[Simplified Tunnel Architecture](ARCHITECTURE/SIMPLIFIED_TUNNEL_ARCHITECTURE.md)** - New streamlined tunnel system
- **[Streaming Proxy Architecture](ARCHITECTURE/STREAMING_PROXY_ARCHITECTURE.md)** - Multi-tenant proxy system
- **[Multi-Container Architecture](ARCHITECTURE/MULTI_CONTAINER_ARCHITECTURE.md)** - Container orchestration
- **[System Tray Implementation](ARCHITECTURE/UNIFIED_FLUTTER_NATIVE_SYSTEM_TRAY.md)** - Desktop integration details
- **[Unified Flutter Web](ARCHITECTURE/UNIFIED_FLUTTER_WEB.md)** - Web platform architecture

### 🔗 Tunnel Integration
- **[Zrok Tunnel System](ARCHITECTURE/TUNNEL_ARCHITECTURE.md)** - Secure tunnel management with zrok
  - Automatic fallback hierarchy
  - Platform abstraction patterns
  - Auth0 JWT validation integration
  - Cross-platform compatibility
  - Troubleshooting and support

### 🚀 **Deployment & Operations**
- **[Deployment Overview](DEPLOYMENT/DEPLOYMENT_OVERVIEW.md)** - All deployment options and strategies
- **[Scripts Overview](DEPLOYMENT/SCRIPTS_OVERVIEW.md)** - Comprehensive guide to deployment scripts
- **[Complete Deployment Workflow](DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)** - End-to-end deployment process
- **[Strict Deployment Policy](DEPLOYMENT/STRICT_DEPLOYMENT_POLICY.md)** - Zero-tolerance quality standards
- **[Self-Hosting Guide](OPERATIONS/SELF_HOSTING.md)** - Deploy your own instance
- **[Infrastructure Guide](OPERATIONS/INFRASTRUCTURE_GUIDE.md)** - Server requirements and setup
- **[Versioning Strategy](DEPLOYMENT/VERSIONING_STRATEGY.md)** - Version management approach

### 👨‍💻 **Development**
- **[Developer Onboarding](DEVELOPMENT/DEVELOPER_ONBOARDING.md)** - Get started with development
- **[Development Workflow](DEVELOPMENT/DEVELOPMENT_WORKFLOW.md)** - Development tools and automation
- **[Building Guide](DEVELOPMENT/BUILDING_GUIDE.md)** - Build applications for all platforms
- **[API Documentation](DEVELOPMENT/API_DOCUMENTATION.md)** - Technical API reference
- **[Contribution Guidelines](../CONTRIBUTING.md)** - How to contribute to the project

### 🔧 Operations Documentation
- **[Infrastructure Guide](OPERATIONS/INFRASTRUCTURE_GUIDE.md)** - Infrastructure management
- **[Self-Hosting Guide](OPERATIONS/SELF_HOSTING.md)** - Self-hosting instructions

### 📋 **Additional Resources**
- **[Release Notes](RELEASE/RELEASE_NOTES.md)** - Version history and changes
- **[Legal Documentation](LEGAL/)** - Privacy policy and terms of service
- **[LangChain Integration](LANGCHAIN_INTEGRATION_PLAN.md)** - Advanced AI capabilities

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

See our [Contribution Guidelines](../CONTRIBUTING.md) for detailed information on contributing.

## 📖 Quick Navigation

### **🆕 New Users**
1. **[Choose Installation Method](INSTALLATION/README.md)** - Pick your platform
2. **[Install CloudToLocalLLM](INSTALLATION/)** - Follow platform-specific guide
3. **[First Time Setup](USER_DOCUMENTATION/FIRST_TIME_SETUP.md)** - Configure your installation
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
5. **[Contribution Guidelines](../CONTRIBUTING.md)** - How to contribute

### **🔧 System Administrators**
1. **[Deployment Overview](DEPLOYMENT/DEPLOYMENT_OVERVIEW.md)** - Understand deployment options
2. **[Scripts Overview](DEPLOYMENT/SCRIPTS_OVERVIEW.md)** - Learn about automation scripts
3. **[Strict Deployment Policy](DEPLOYMENT/STRICT_DEPLOYMENT_POLICY.md)** - Quality standards
4. **[Infrastructure Guide](OPERATIONS/INFRASTRUCTURE_GUIDE.md)** - Server management
5. Check [Troubleshooting](USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md) if issues arise

### For Developers
1. Review [System Architecture](ARCHITECTURE/SYSTEM_ARCHITECTURE.md)
2. Understand [Streaming Proxy Architecture](ARCHITECTURE/STREAMING_PROXY_ARCHITECTURE.md)
3. Learn about tunnel management and platform abstraction patterns
4. Follow [Developer Onboarding](DEVELOPMENT/DEVELOPER_ONBOARDING.md)
5. Reference [API Documentation](DEVELOPMENT/API_DOCUMENTATION.md)

### For System Administrators
1. Study [Infrastructure Guide](OPERATIONS/INFRASTRUCTURE_GUIDE.md)
2. Review [Deployment Workflow](DEPLOYMENT/COMPLETE_DEPLOYMENT_WORKFLOW.md)
3. Configure [Environment Separation](DEPLOYMENT/ENVIRONMENT_SEPARATION_GUIDE.md)
4. Set up monitoring and maintenance procedures

## 🆘 Getting Help

### Common Issues
- **Installation Problems**: Check [Installation Guide](USER_DOCUMENTATION/INSTALLATION_GUIDE.md)
- **Connection Issues**: See [Troubleshooting Guide](USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md)
- **Tunnel Problems**: Review connection fallback hierarchy and zrok configuration
- **Performance Issues**: Monitor connection status and tunnel health

### Support Channels
- **GitHub Issues**: [Report bugs and request features](https://github.com/imrightguy/CloudToLocalLLM/issues)
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

## 🔄 Recent Updates

### 2025-07-12: Documentation Consolidation and Architecture Standardization
- Updated all documentation to reflect current version 3.10.3
- Consolidated duplicate installation guides into single authoritative guide
- Standardized architecture terminology to "Unified Flutter-Native Architecture"
- Updated AUR status to "temporarily decommissioned with reintegration planned"
- Removed outdated version-specific deployment guides
- Fixed cross-references and improved navigation structure

---

*For the most current information, always refer to the official repository and documentation.*
