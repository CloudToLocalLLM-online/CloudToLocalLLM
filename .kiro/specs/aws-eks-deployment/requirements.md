# AWS EKS CI/CD Deployment - Requirements Document

## Introduction

This feature enables CloudToLocalLLM to deploy on AWS EKS (Elastic Kubernetes Service) instead of Azure AKS, providing a portable, cost-optimized Kubernetes deployment. The system maintains all existing functionality while leveraging AWS services for improved cost efficiency and feature parity. The deployment uses GitHub Actions for CI/CD, OIDC for secure authentication, and keeps Docker Hub as the container registry. Cloudflare remains the DNS and SSL provider.

## Glossary

- **EKS**: Amazon Elastic Kubernetes Service - managed Kubernetes service on AWS
- **OIDC**: OpenID Connect - secure authentication method without storing long-lived credentials
- **IAM**: AWS Identity and Access Management - service for managing AWS credentials and permissions
- **ECR**: Amazon Elastic Container Registry - AWS container image registry
- **Route53**: AWS DNS service
- **CloudFront**: AWS content delivery network
- **Spot Instances**: AWS EC2 instances available at discounted rates (up to 70% cheaper)
- **t3.medium**: AWS EC2 instance type suitable for development workloads
- **GitHub Actions**: CI/CD platform integrated with GitHub repositories
- **Docker Hub**: Container registry for storing and distributing Docker images
- **Cloudflare**: DNS and SSL/TLS provider
- **Kubernetes**: Container orchestration platform
- **StatefulSet**: Kubernetes resource for managing stateful applications like databases
- **Deployment**: Kubernetes resource for managing stateless applications
- **Service**: Kubernetes resource for exposing applications
- **Ingress**: Kubernetes resource for managing external HTTP/HTTPS access
- **Namespace**: Kubernetes logical partition for organizing resources
- **ConfigMap**: Kubernetes resource for storing configuration data
- **Secret**: Kubernetes resource for storing sensitive data

## Requirements

### Requirement 1

**User Story:** As a DevOps engineer, I want to deploy CloudToLocalLLM on AWS EKS, so that I can leverage AWS services while maintaining Kubernetes portability.

#### Acceptance Criteria

1. WHEN the CI/CD pipeline is triggered, THE system SHALL authenticate to AWS using OIDC without storing long-lived credentials
2. WHEN deploying to AWS EKS, THE system SHALL create or update all necessary Kubernetes resources (Deployments, Services, ConfigMaps, Secrets, Ingress)
3. WHEN the deployment completes, THE system SHALL verify that all pods are running and healthy
4. WHEN the application is deployed, THE system SHALL be accessible via the existing Cloudflare domains (cloudtolocalllm.online, app.cloudtolocalllm.online, api.cloudtolocalllm.online)
5. WHEN the deployment fails, THE system SHALL provide clear error messages and rollback to the previous stable version

### Requirement 2

**User Story:** As a cost-conscious developer, I want the AWS EKS deployment to be optimized for development costs, so that I can run a feature-complete development environment affordably.

#### Acceptance Criteria

1. WHEN the EKS cluster is created, THE system SHALL use t3.medium instances for cost efficiency
2. WHEN the cluster is running, THE system SHALL use a minimum of 2 nodes for development (not 3 for production)
3. WHEN pods are scheduled, THE system SHALL use resource requests and limits to prevent over-provisioning
4. WHEN the cluster is idle, THE system SHALL allow automatic scaling down to reduce costs
5. WHEN monitoring the cluster, THE system SHALL track and report monthly AWS costs

### Requirement 3

**User Story:** As a deployment engineer, I want GitHub Actions to securely authenticate to AWS, so that I can deploy without managing long-lived credentials.

#### Acceptance Criteria

1. WHEN GitHub Actions runs, THE system SHALL use OIDC to obtain temporary AWS credentials
2. WHEN the workflow executes, THE system SHALL not store or expose AWS access keys or secret keys
3. WHEN the deployment completes, THE system SHALL automatically revoke temporary credentials
4. WHEN a new workflow runs, THE system SHALL obtain fresh credentials with minimal permissions (least privilege)
5. WHEN credentials are needed, THE system SHALL use AWS STS (Security Token Service) to generate temporary tokens

### Requirement 4

**User Story:** As a platform engineer, I want to migrate from Azure AKS to AWS EKS, so that I can consolidate infrastructure on a single cloud provider.

#### Acceptance Criteria

1. WHEN the migration begins, THE system SHALL preserve all existing Kubernetes manifests and configurations
2. WHEN deploying to AWS, THE system SHALL use the same container images from Docker Hub
3. WHEN the new cluster is ready, THE system SHALL update DNS records to point to the AWS load balancer
4. WHEN the migration completes, THE system SHALL decommission the Azure AKS cluster
5. WHEN the deployment is verified, THE system SHALL confirm all services are accessible and functional

### Requirement 5

**User Story:** As a developer, I want the CI/CD pipeline to automatically build and push images to Docker Hub, so that I can deploy the latest code without manual steps.

#### Acceptance Criteria

1. WHEN code is pushed to the repository, THE system SHALL build Docker images for web and API services
2. WHEN the build completes, THE system SHALL push images to Docker Hub with appropriate tags (commit SHA, version)
3. WHEN the image is pushed, THE system SHALL trigger the EKS deployment with the new image
4. WHEN the deployment fails, THE system SHALL retain the previous working image and alert the developer
5. WHEN multiple commits occur, THE system SHALL queue deployments and process them sequentially

### Requirement 6

**User Story:** As a system administrator, I want to manage AWS resources through Infrastructure as Code, so that I can version control and reproduce the infrastructure.

#### Acceptance Criteria

1. WHEN the infrastructure is defined, THE system SHALL use Kubernetes manifests (YAML) for all deployments
2. WHEN the cluster is created, THE system SHALL use AWS CloudFormation or Terraform for EKS cluster provisioning
3. WHEN resources are updated, THE system SHALL apply changes through version-controlled configuration files
4. WHEN the infrastructure changes, THE system SHALL maintain a clear audit trail of modifications
5. WHEN disaster recovery is needed, THE system SHALL be able to recreate the entire infrastructure from code

### Requirement 7

**User Story:** As a monitoring engineer, I want to observe the AWS EKS cluster health and performance, so that I can detect and resolve issues quickly.

#### Acceptance Criteria

1. WHEN the cluster is running, THE system SHALL collect metrics from all pods and nodes
2. WHEN monitoring the cluster, THE system SHALL track CPU, memory, disk, and network usage
3. WHEN alerts are triggered, THE system SHALL notify the team of critical issues
4. WHEN logs are generated, THE system SHALL aggregate and store them for analysis
5. WHEN performance degrades, THE system SHALL provide visibility into the root cause

### Requirement 8

**User Story:** As a security engineer, I want the AWS EKS deployment to follow security best practices, so that I can protect the application and data.

#### Acceptance Criteria

1. WHEN the cluster is created, THE system SHALL use private subnets for nodes (not publicly accessible)
2. WHEN pods communicate, THE system SHALL use network policies to restrict traffic
3. WHEN secrets are stored, THE system SHALL encrypt them at rest using AWS KMS or Kubernetes encryption
4. WHEN the application runs, THE system SHALL use IAM roles for pod authentication (IRSA - IAM Roles for Service Accounts)
5. WHEN the cluster is accessed, THE system SHALL require authentication and authorization through AWS IAM

### Requirement 9

**User Story:** As a DevOps engineer, I want to manage environment-specific configurations, so that I can deploy to different environments (development, staging, production) with appropriate settings.

#### Acceptance Criteria

1. WHEN deploying to development, THE system SHALL use development-specific configurations (smaller resources, fewer replicas)
2. WHEN deploying to production, THE system SHALL use production-specific configurations (larger resources, more replicas, higher availability)
3. WHEN configurations change, THE system SHALL apply them without redeploying the entire application
4. WHEN secrets are needed, THE system SHALL store them securely and inject them at runtime
5. WHEN environments are isolated, THE system SHALL prevent accidental cross-environment deployments

### Requirement 10

**User Story:** As a developer, I want the deployment process to be fast and reliable, so that I can iterate quickly and confidently.

#### Acceptance Criteria

1. WHEN code is pushed, THE system SHALL complete the build and deployment within 10 minutes
2. WHEN the deployment starts, THE system SHALL perform health checks before marking it as successful
3. WHEN a deployment fails, THE system SHALL automatically rollback to the previous version
4. WHEN multiple deployments occur, THE system SHALL prevent concurrent deployments to the same cluster
5. WHEN the deployment completes, THE system SHALL provide clear feedback on success or failure
