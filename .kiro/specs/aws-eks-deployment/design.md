# AWS EKS CI/CD Deployment - Design Document

## Overview

This design document outlines the architecture for deploying CloudToLocalLLM on AWS EKS with GitHub Actions CI/CD. The system maintains Kubernetes portability while leveraging AWS services for cost efficiency and reliability. The deployment uses OIDC for secure GitHub Actions authentication, Docker Hub for container images, and Cloudflare for DNS/SSL management.

**Key Design Principles:**
- **Portability**: All infrastructure defined in Kubernetes manifests (deployable anywhere)
- **Cost Optimization**: Development cluster uses t3.medium instances with 2 nodes
- **Security**: OIDC authentication, IAM roles for pods, encrypted secrets
- **Reliability**: Health checks, automatic rollbacks, sequential deployments
- **Simplicity**: Minimal AWS-specific dependencies, focus on Kubernetes

## Architecture

### High-Level Deployment Flow

```
Developer Push to GitHub
    ↓
GitHub Actions Workflow Triggered
    ↓
OIDC Token Exchange (GitHub → AWS)
    ↓
Build Docker Images
    ↓
Push to Docker Hub
    ↓
Update Kubernetes Manifests
    ↓
Deploy to AWS EKS Cluster
    ↓
Health Checks & Verification
    ↓
Update Cloudflare DNS (if needed)
    ↓
Deployment Complete
```

### AWS Infrastructure Components

```
AWS Account (422017356244)
├── EKS Cluster (cloudtolocalllm-eks)
│   ├── Control Plane (managed by AWS)
│   ├── Node Group (2x t3.medium instances)
│   ├── VPC & Subnets (private)
│   ├── Security Groups
│   └── IAM Roles for Pods (IRSA)
├── Load Balancer (Network Load Balancer)
├── CloudWatch (logs & metrics)
└── IAM Roles & Policies
    ├── GitHub OIDC Provider
    ├── EKS Service Role
    └── Node Instance Role
```

### Kubernetes Architecture

```
EKS Cluster
├── Namespace: cloudtolocalllm
│   ├── Deployment: web-app
│   ├── Deployment: api-backend
│   ├── StatefulSet: postgres
│   ├── Service: web-service
│   ├── Service: api-service
│   ├── Service: postgres-service
│   ├── Ingress: main-ingress
│   ├── ConfigMap: app-config
│   ├── Secret: app-secrets
│   └── NetworkPolicy: traffic-rules
├── Namespace: monitoring
│   ├── Deployment: prometheus
│   ├── Deployment: grafana
│   └── Deployment: loki
└── Namespace: kube-system
    └── (AWS-managed system components)
```

## Components and Interfaces

### 1. GitHub Actions Workflow

**File**: `.github/workflows/deploy-aws-eks.yml`

**Responsibilities:**
- Authenticate to AWS using OIDC
- Build Docker images
- Push images to Docker Hub
- Deploy to EKS cluster
- Verify deployment health
- Rollback on failure

**Inputs:**
- Git commit SHA
- Repository code
- Secrets (Docker Hub credentials)

**Outputs:**
- Deployed application
- Deployment status
- Error logs (if failed)

### 2. AWS EKS Cluster

**Responsibilities:**
- Run Kubernetes workloads
- Manage networking and load balancing
- Provide persistent storage
- Monitor cluster health

**Configuration:**
- Cluster name: `cloudtolocalllm-eks`
- Region: `us-east-1` (default, can be changed)
- Node group: 2x t3.medium instances
- Kubernetes version: Latest stable (1.28+)

### 3. OIDC Provider Integration

**Responsibilities:**
- Exchange GitHub tokens for AWS credentials
- Provide temporary credentials to GitHub Actions
- Enforce least-privilege access

**Configuration:**
- Provider: `token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- Subject: `repo:cloudtolocalllm/cloudtolocalllm:ref:refs/heads/main`

### 4. Docker Hub Integration

**Responsibilities:**
- Store container images
- Provide image pull capability
- Version images with tags

**Images:**
- `cloudtolocalllm/cloudtolocalllm-web:latest`
- `cloudtolocalllm/cloudtolocalllm-web:{commit-sha}`
- `cloudtolocalllm/cloudtolocalllm-api:latest`
- `cloudtolocalllm/cloudtolocalllm-api:{commit-sha}`

### 5. Cloudflare DNS & SSL

**Responsibilities:**
- Manage DNS records
- Provide SSL/TLS certificates
- Route traffic to AWS load balancer

**Domains:**
- `cloudtolocalllm.online` → AWS NLB
- `app.cloudtolocalllm.online` → AWS NLB
- `api.cloudtolocalllm.online` → AWS NLB

## Data Models

### Kubernetes Manifest Structure

```yaml
# Deployment Example
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: cloudtolocalllm
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-app
        image: cloudtolocalllm/cloudtolocalllm-web:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        env:
        - name: API_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: api-url
        - name: AUTH0_DOMAIN
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: auth0-domain
```

### AWS IAM Role for OIDC

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::422017356244:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:cloudtolocalllm/cloudtolocalllm:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

### GitHub Actions Workflow Structure

```yaml
name: Deploy to AWS EKS
on:
  push:
    branches: [main]
    paths:
      - 'lib/**'
      - 'services/**'
      - 'k8s/**'
      - '.github/workflows/deploy-aws-eks.yml'

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v3
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::422017356244:role/github-actions-role
          aws-region: us-east-1
      - name: Build and push Docker images
        # Build and push logic
      - name: Deploy to EKS
        # Deployment logic
      - name: Verify deployment
        # Health check logic
```


## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: OIDC Authentication Succeeds

*For any* GitHub Actions workflow run, when the workflow attempts to authenticate to AWS using OIDC, the authentication SHALL succeed and provide temporary AWS credentials without storing long-lived secrets.

**Validates: Requirements 3.1, 3.2, 3.3**

### Property 2: Deployment Idempotency

*For any* Kubernetes manifest applied to the EKS cluster, applying the same manifest multiple times SHALL result in the same final state (idempotent operation).

**Validates: Requirements 1.2, 6.3**

### Property 3: Image Tag Consistency

*For any* Docker image built and pushed to Docker Hub, the image tag SHALL match the commit SHA, and subsequent deployments SHALL pull the correct image version.

**Validates: Requirements 5.1, 5.2**

### Property 4: Health Check Verification

*For any* deployment to the EKS cluster, after the deployment completes, all pods SHALL be in a "Running" state and pass readiness checks before the deployment is marked as successful.

**Validates: Requirements 1.3, 10.2**

### Property 5: Rollback on Failure

*For any* failed deployment, the system SHALL automatically rollback to the previous stable version, and the application SHALL remain accessible during the rollback.

**Validates: Requirements 1.5, 10.3**

### Property 6: DNS Resolution Consistency

*For any* deployed application, DNS queries to the Cloudflare-managed domains SHALL resolve to the AWS Network Load Balancer IP address.

**Validates: Requirements 1.4, 4.3**

### Property 7: Resource Isolation

*For any* pod running in the EKS cluster, the pod SHALL only have access to resources defined in its namespace and allowed by network policies.

**Validates: Requirements 8.2, 8.4**

### Property 8: Secret Encryption

*For any* secret stored in the Kubernetes cluster, the secret SHALL be encrypted at rest and only accessible to authorized pods.

**Validates: Requirements 8.3, 8.5**

### Property 9: Cost Optimization

*For any* development cluster, the total monthly AWS costs SHALL not exceed $300, achieved through t3.medium instances and 2-node configuration.

**Validates: Requirements 2.1, 2.2, 2.4**

### Property 10: Deployment Sequencing

*For any* multiple code pushes, deployments SHALL be processed sequentially (not concurrently) to prevent race conditions and ensure consistent state.

**Validates: Requirements 5.5, 10.4**

## Error Handling

### Deployment Failures

**Scenario**: Docker image build fails
- **Detection**: GitHub Actions workflow step fails
- **Response**: Workflow stops, error logged, developer notified
- **Recovery**: Developer fixes code and pushes again

**Scenario**: EKS cluster unreachable
- **Detection**: kubectl commands timeout
- **Response**: Workflow retries 3 times with exponential backoff
- **Recovery**: If still failing, alert DevOps team

**Scenario**: Pod fails health checks
- **Detection**: Readiness probe fails after 30 seconds
- **Response**: Deployment marked as failed, automatic rollback triggered
- **Recovery**: Previous version restored, developer investigates logs

**Scenario**: Insufficient cluster resources
- **Detection**: Pod pending due to resource constraints
- **Response**: Deployment fails, error message indicates resource issue
- **Recovery**: Scale cluster or reduce resource requests

### Network Failures

**Scenario**: Docker Hub push fails
- **Detection**: Push command returns error
- **Response**: Retry up to 3 times
- **Recovery**: If persistent, alert developer

**Scenario**: Cloudflare DNS update fails
- **Detection**: DNS query returns old IP
- **Response**: Retry DNS update
- **Recovery**: Manual DNS update if needed

### Security Failures

**Scenario**: OIDC token exchange fails
- **Detection**: AWS credentials not obtained
- **Response**: Workflow fails, security alert triggered
- **Recovery**: Check OIDC provider configuration, verify GitHub Actions permissions

**Scenario**: Unauthorized pod access to secrets
- **Detection**: Pod attempts to read secret outside its namespace
- **Response**: Access denied, event logged
- **Recovery**: Verify RBAC policies and pod service account

## Testing Strategy

### Unit Testing

Unit tests verify specific components in isolation:

1. **Kubernetes Manifest Validation**
   - Validate YAML syntax
   - Verify required fields present
   - Check resource limits and requests
   - Validate image references

2. **GitHub Actions Workflow Validation**
   - Verify workflow syntax
   - Check step dependencies
   - Validate environment variables
   - Test conditional logic

3. **AWS IAM Policy Validation**
   - Verify policy syntax
   - Check permissions are least-privilege
   - Validate resource ARNs

### Property-Based Testing

Property-based tests verify universal properties across many inputs:

1. **OIDC Authentication Property Test**
   - Generate random GitHub Actions runs
   - Verify OIDC token exchange succeeds
   - Verify credentials are temporary
   - Verify credentials expire

2. **Deployment Idempotency Property Test**
   - Generate random Kubernetes manifests
   - Apply manifest multiple times
   - Verify final state is identical
   - Verify no resources are duplicated

3. **Image Tag Consistency Property Test**
   - Generate random commit SHAs
   - Build and push images
   - Verify image tags match commit SHA
   - Verify image can be pulled

4. **Health Check Verification Property Test**
   - Deploy application to test cluster
   - Verify all pods reach Running state
   - Verify readiness probes pass
   - Verify liveness probes pass

5. **Rollback on Failure Property Test**
   - Deploy version A
   - Deploy version B (with intentional failure)
   - Verify automatic rollback to version A
   - Verify application remains accessible

6. **DNS Resolution Consistency Property Test**
   - Query Cloudflare DNS for each domain
   - Verify resolution to AWS NLB IP
   - Verify consistency across multiple queries
   - Verify TTL is respected

7. **Resource Isolation Property Test**
   - Deploy pods in different namespaces
   - Attempt cross-namespace communication
   - Verify network policies block unauthorized access
   - Verify authorized communication succeeds

8. **Secret Encryption Property Test**
   - Create secrets in cluster
   - Verify secrets are encrypted at rest
   - Verify unauthorized pods cannot access secrets
   - Verify authorized pods can access secrets

9. **Cost Optimization Property Test**
   - Monitor cluster for 1 month
   - Verify monthly costs ≤ $300
   - Verify t3.medium instances are used
   - Verify 2-node configuration maintained

10. **Deployment Sequencing Property Test**
    - Trigger multiple deployments rapidly
    - Verify deployments are queued
    - Verify deployments execute sequentially
    - Verify no race conditions occur

### Integration Testing

Integration tests verify components work together:

1. **End-to-End Deployment Test**
   - Push code to GitHub
   - Verify GitHub Actions workflow triggers
   - Verify Docker images build and push
   - Verify EKS deployment succeeds
   - Verify application is accessible
   - Verify Cloudflare DNS resolves correctly

2. **Failure Recovery Test**
   - Deploy version A
   - Simulate pod failure
   - Verify automatic restart
   - Verify application remains accessible

3. **Scaling Test**
   - Deploy application
   - Increase load
   - Verify cluster auto-scales
   - Verify performance remains acceptable

### Testing Framework

- **Kubernetes Manifest Validation**: `kubeval`, `kube-score`
- **GitHub Actions Workflow Validation**: `actionlint`
- **AWS IAM Policy Validation**: `IAM Policy Simulator`
- **Property-Based Testing**: `fast-check` (JavaScript), `hypothesis` (Python)
- **Integration Testing**: `kubectl`, `docker`, AWS CLI
- **Monitoring**: CloudWatch, Prometheus, Grafana

### Test Configuration

- **Minimum iterations**: 100 per property-based test
- **Test environment**: Separate AWS account or namespace
- **Test data**: Generated randomly to cover edge cases
- **Test execution**: Automated in GitHub Actions
- **Test reporting**: Detailed logs and metrics
