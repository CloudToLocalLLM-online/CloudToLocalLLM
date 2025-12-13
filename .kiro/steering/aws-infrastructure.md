# Platform Infrastructure Guidelines

## CRITICAL PLATFORM CONTEXT

### Current Production Infrastructure: Azure AKS

**CloudToLocalLLM is currently running on Azure AKS in production**:
- **Resource Group**: `cloudtolocalllm-rg`
- **Cluster**: `cloudtolocalllm-aks`
- **Registry**: Azure Container Registry (ACR) `imrightguycloudtolocalllm`
- **Status**: Active production deployment

### Provider Agnostic Design

**CloudToLocalLLM is designed to be provider agnostic**:
- Can run on Azure AKS, AWS EKS, Google GKE, or any Kubernetes cluster
- Uses standard Kubernetes manifests in `k8s/` directory
- Container registry can be ACR, ECR, Docker Hub, or any OCI-compatible registry
- Authentication providers are configurable (Auth0, Supabase, etc.)

### Development Environment Context

**Current development environment**: Windows with PowerShell
- **Shell**: PowerShell (cmd)
- **Platform**: Windows (win32)
- **Script Execution**: 
  - Use PowerShell for Windows-native scripts
  - Use WSL for bash scripts when needed
  - **Cannot make bash scripts executable directly in PowerShell**
  - Use `wsl chmod +x script.sh` if bash script execution is needed

## AWS Infrastructure (Future Option)

CloudToLocalLLM CAN be deployed to AWS EKS as an alternative to Azure AKS. This document outlines the AWS deployment option for teams who prefer AWS infrastructure.

## Infrastructure Architecture

### AWS EKS Cluster

- **Cluster Name**: cloudtolocalllm-eks
- **Kubernetes Version**: 1.30
- **Region**: us-east-1
- **Node Groups**: Auto-scaling with t3.medium instances
- **Networking**: Private subnets with NAT gateways

### CloudFormation Stack Dependencies

1. **VPC Stack** (`cloudtolocalllm-vpc`)
   - VPC with CIDR 10.0.0.0/16
   - 3 private subnets for EKS nodes
   - 2 public subnets for NAT gateways
   - Internet Gateway and NAT gateways
   - Security groups for cluster and nodes

2. **IAM Stack** (`cloudtolocalllm-iam`)
   - EKS Service Role
   - Node Instance Role
   - GitHub Actions OIDC Role
   - Pod Execution Role (IRSA)

3. **EKS Stack** (`cloudtolocalllm-eks`)
   - EKS cluster with logging enabled
   - Managed node group with auto-scaling
   - Network Load Balancer
   - CloudWatch alarms

## Security Best Practices

### OIDC Authentication

- **No Long-lived Credentials**: GitHub Actions uses OIDC to obtain temporary AWS credentials
- **Least Privilege**: IAM roles have minimal required permissions
- **Branch Restrictions**: OIDC trust policy restricts access to specific branches
- **Audit Trail**: All OIDC authentications logged in CloudTrail

### Network Security

- **Private Node Groups**: EKS nodes in private subnets (not publicly accessible)
- **Security Groups**: Restrictive ingress/egress rules
- **Network Policies**: Kubernetes-level traffic segmentation
- **VPC Flow Logs**: Network traffic monitoring

### Data Protection

- **Encryption at Rest**: EBS volumes encrypted with AWS KMS
- **Encryption in Transit**: TLS for all communications
- **Secrets Management**: Kubernetes secrets with envelope encryption
- **Database Encryption**: PostgreSQL with encryption enabled

## Cost Management

### Budget Constraints

- **Monthly Budget**: $300 for development environment
- **Target Cost**: ~$91/month for basic setup
- **Cost Monitoring**: Automated reports via `scripts/aws/cost-monitoring.js`

### Cost Optimization Strategies

- **Instance Types**: t3.medium for cost-effectiveness
- **Auto-scaling**: Dynamic capacity adjustment
- **Resource Limits**: Prevent over-provisioning
- **Spot Instances**: Consider for non-critical workloads
- **Reserved Instances**: For predictable workloads

### Cost Breakdown

```
Estimated Monthly Costs:
- EC2 Instances (2x t3.medium): $60.48
- Network Load Balancer: $16.56
- EBS Storage (100GB): $10.00
- Data Transfer (250GB): $5.00
- CloudWatch Logs (10GB): $5.00
Total: ~$97/month
```

## Deployment Patterns

### GitHub Actions Workflow

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: arn:aws:iam::422017356244:role/github-actions-role
    aws-region: us-east-1

- name: Deploy to EKS
  run: |
    aws eks update-kubeconfig --region us-east-1 --name cloudtolocalllm-eks
    kubectl apply -f k8s/
```

### Infrastructure Updates

```bash
# Update CloudFormation stacks
aws cloudformation update-stack \
  --stack-name cloudtolocalllm-eks \
  --template-body file://config/cloudformation/eks-cluster.yaml \
  --parameters ParameterKey=NodeInstanceType,ParameterValue=t3.large

# Verify deployment
kubectl get nodes
kubectl get pods -A
```

## Monitoring and Observability

### CloudWatch Integration

- **Container Insights**: Enabled for cluster monitoring
- **Log Groups**: Separate log groups for different components
- **Alarms**: CPU, memory, and disk usage alerts
- **Dashboards**: Custom dashboards for application metrics

### Grafana Integration

- **Datasources**: CloudWatch, Prometheus, Loki
- **Dashboards**: Infrastructure and application metrics
- **Alerts**: Integration with OnCall for incident management
- **Cost Tracking**: AWS cost and usage dashboards

## Disaster Recovery

### Backup Procedures

```bash
# Database backup
./scripts/aws/backup-postgres.sh

# Backup verification
./scripts/aws/verify-backup.sh
```

### Recovery Procedures

1. **Infrastructure Recovery**:
   - Deploy CloudFormation stacks
   - Verify EKS cluster health
   - Restore network connectivity

2. **Application Recovery**:
   - Deploy Kubernetes resources
   - Restore database from backup
   - Verify application functionality

3. **DNS Recovery**:
   - Update Cloudflare DNS records
   - Verify SSL certificate validity
   - Test end-to-end connectivity

### RTO/RPO Targets

- **Recovery Time Objective (RTO)**: 2 hours
- **Recovery Point Objective (RPO)**: 1 hour
- **Database Backups**: Every 6 hours
- **Infrastructure Snapshots**: Daily

## Migration from Azure

### AWS Deployment Status (Optional)

- 📋 AWS infrastructure templates available
- 📋 OIDC authentication patterns documented
- 📋 GitHub Actions workflow examples provided
- ⚠️ **Current production uses Azure AKS**
- ⚠️ **AWS deployment is an alternative option, not a migration**

### Rollback Plan

1. **DNS Rollback**: Switch Cloudflare records back to Azure
2. **Application Rollback**: Redeploy to Azure AKS if needed
3. **Data Sync**: Ensure database consistency between environments
4. **Monitoring**: Verify all services operational

### Post-Migration Tasks

1. **Azure Cleanup**: Decommission Azure resources
2. **Cost Validation**: Verify AWS costs meet budget targets
3. **Performance Testing**: Validate application performance
4. **Documentation Updates**: Update all references to Azure

## Troubleshooting

### Common Issues

1. **OIDC Authentication Failures**:
   ```bash
   # Verify OIDC provider
   aws iam get-open-id-connect-provider \
     --open-id-connect-provider-arn arn:aws:iam::422017356244:oidc-provider/token.actions.githubusercontent.com
   ```

2. **EKS Node Issues**:
   ```bash
   # Check node status
   kubectl get nodes
   kubectl describe node <node-name>
   ```

3. **Load Balancer Issues**:
   ```bash
   # Check load balancer status
   aws elbv2 describe-load-balancers
   kubectl get svc -A
   ```

### Support Escalation

1. **AWS Support**: Use AWS Support Center for infrastructure issues
2. **GitHub Support**: For GitHub Actions and OIDC issues
3. **Cloudflare Support**: For DNS and SSL issues
4. **Internal Escalation**: Document issues in GitHub Issues

## Best Practices

### Development Workflow

1. **Infrastructure Changes**: Always use CloudFormation templates
2. **Testing**: Test infrastructure changes in development first
3. **Rollback**: Maintain rollback procedures for all changes
4. **Documentation**: Update documentation with all changes

### Security Practices

1. **Least Privilege**: Grant minimal required permissions
2. **Regular Audits**: Review IAM roles and policies monthly
3. **Secrets Rotation**: Rotate secrets and certificates regularly
4. **Compliance**: Follow AWS security best practices

### Cost Management

1. **Regular Reviews**: Monthly cost analysis and optimization
2. **Resource Tagging**: Tag all resources for cost allocation
3. **Alerts**: Set up cost alerts for budget overruns
4. **Optimization**: Regular review of resource utilization