# Operations Documentation

This directory contains comprehensive operational guides for CloudToLocalLLM infrastructure management.

## 📚 Contents

### Core Operations
- **[Infrastructure](INFRASTRUCTURE.md)** - Server requirements and infrastructure setup
- **[Self Hosting](SELF_HOSTING.md)** - Deploy your own CloudToLocalLLM instance
- **[Disaster Recovery Strategy](DISASTER_RECOVERY_STRATEGY.md)** - Business continuity and disaster recovery
- **[Cost Monitoring Documentation Update](COST_MONITORING_DOCUMENTATION_UPDATE.md)** - Cost tracking and optimization

### Monitoring & Troubleshooting
- **** - Monitor tunnel system health
- **** - Diagnose and fix tunnel issues
- **[Alert Response Procedures](ALERT_RESPONSE_PROCEDURES.md)** - Incident response procedures
- **[Grafana MCP Tools Usage](GRAFANA_MCP_TOOLS_USAGE.md)** - Monitoring tools and dashboards

### Administrative Operations
- **[Admin Data Flush Guide](ADMIN_DATA_FLUSH_GUIDE.md)** - Data management procedures

### Platform-Specific Operations

#### AWS Operations
- **[AWS EKS Deployment Guide](aws/AWS_EKS_DEPLOYMENT_GUIDE.md)** - Deploy to AWS EKS
- **[AWS EKS Operations Runbook](aws/AWS_EKS_OPERATIONS_RUNBOOK.md)** - Day-to-day AWS operations
- **[AWS EKS Troubleshooting Guide](aws/AWS_EKS_TROUBLESHOOTING_GUIDE.md)** - AWS-specific troubleshooting
- **[AWS Infrastructure Setup Complete](aws/AWS_INFRASTRUCTURE_SETUP_COMPLETE.md)** - Infrastructure setup verification
- **[AWS OIDC Setup Guide](aws/AWS_OIDC_SETUP_GUIDE.md)** - OIDC authentication setup
- **[Cloudflare DNS AWS EKS Setup](aws/CLOUDFLARE_DNS_AWS_EKS_SETUP.md)** - DNS configuration for AWS
- **[CloudFormation Deployment Guide](aws/CLOUDFORMATION_DEPLOYMENT_GUIDE.md)** - Infrastructure as Code deployment

#### Kubernetes Operations
- **[Kubernetes Quickstart](kubernetes/KUBERNETES_QUICKSTART.md)** - Quick Kubernetes deployment
- **[Kubernetes Self-Hosted Guide](kubernetes/KUBERNETES_SELF_HOSTED_GUIDE.md)** - Self-hosted Kubernetes setup

#### CI/CD Operations
- **[CI/CD Integration Guide](cicd/CI_CD_INTEGRATION_GUIDE.md)** - Continuous integration setup
- **[CI/CD Quick Reference](cicd/CI_CD_QUICK_REFERENCE.md)** - Quick CI/CD commands and procedures
- **[CICD Implementation Plan](cicd/CICD_Implementation_Plan.md)** - CI/CD strategy and implementation
- **[CICD Setup Guide](cicd/CICD_SETUP_GUIDE.md)** - Step-by-step CI/CD configuration
- **[Testing and CICD Guide](cicd/TESTING_AND_CICD_GUIDE.md)** - Testing integration with CI/CD

## 🔗 Related Documentation

- **[Deployment Documentation](../DEPLOYMENT/README.md)** - Deployment strategies and procedures
- **[Architecture Documentation](../ARCHITECTURE/README.md)** - System architecture and design
- **[Security Documentation](../SECURITY/README.md)** - Security policies and procedures

## 📖 Operations Overview

### Infrastructure Management
CloudToLocalLLM supports multiple deployment options:
- **AWS EKS** - Primary cloud deployment platform
- **Self-hosted Kubernetes** - On-premises deployment
- **Docker Compose** - Development and small-scale deployment

### Monitoring Stack
- **Grafana** - Dashboards and visualization
- **Prometheus** - Metrics collection
- **Loki** - Log aggregation
- **Sentry** - Error tracking and performance monitoring

### Key Operational Procedures
1. **Health Monitoring** - Continuous system health checks
2. **Incident Response** - Structured incident management
3. **Backup & Recovery** - Data protection and disaster recovery
4. **Cost Optimization** - Resource usage and cost monitoring