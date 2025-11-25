# CloudFormation Templates for AWS EKS Deployment

This directory contains CloudFormation templates for deploying CloudToLocalLLM on AWS EKS.

## Templates

### 1. vpc-networking.yaml

Creates the VPC and networking infrastructure for the EKS cluster.

**Resources:**
- VPC with CIDR block 10.0.0.0/16
- 2 Public subnets for NAT gateways and load balancers
- 3 Private subnets for EKS nodes
- Internet Gateway for public internet access
- 2 NAT Gateways for private subnet outbound access
- Route tables for public and private subnets
- Security groups for EKS cluster and nodes

**Parameters:**
- `VPCCidr`: CIDR block for VPC (default: 10.0.0.0/16)
- `PrivateSubnet1Cidr`: CIDR for private subnet 1 (default: 10.0.1.0/24)
- `PrivateSubnet2Cidr`: CIDR for private subnet 2 (default: 10.0.2.0/24)
- `PrivateSubnet3Cidr`: CIDR for private subnet 3 (default: 10.0.3.0/24)
- `PublicSubnet1Cidr`: CIDR for public subnet 1 (default: 10.0.101.0/24)
- `PublicSubnet2Cidr`: CIDR for public subnet 2 (default: 10.0.102.0/24)

**Outputs:**
- VPC ID
- Private subnet IDs
- Public subnet IDs
- Security group IDs

### 2. iam-roles.yaml

Creates IAM roles and policies for EKS cluster, nodes, GitHub Actions, and pods.

**Resources:**
- EKS Service Role with required permissions
- Node Instance Role with worker node permissions
- Node Instance Profile for EC2 instances
- GitHub Actions OIDC Role for CI/CD authentication
- GitHub Actions policies for EKS deployment
- Pod Execution Role for IRSA (IAM Roles for Service Accounts)
- CloudWatch Logs Role for cluster logging

**Parameters:**
- `GitHubOIDCProviderArn`: ARN of GitHub OIDC provider
- `GitHubRepository`: GitHub repository in format owner/repo

**Outputs:**
- EKS Service Role ARN
- Node Instance Role ARN
- GitHub Actions Role ARN
- Pod Execution Role ARN
- CloudWatch Logs Role ARN

### 3. eks-cluster.yaml

Creates the EKS cluster, node group, and load balancer.

**Resources:**
- EKS Cluster with specified Kubernetes version
- Node Group with auto-scaling configuration
- CloudWatch Log Group for cluster logs
- Network Load Balancer for ingress traffic
- Target groups for HTTP and HTTPS
- Listeners for HTTP and HTTPS traffic
- CloudWatch alarms for cluster health monitoring

**Parameters:**
- `ClusterName`: Name of the EKS cluster (default: cloudtolocalllm-eks)
- `KubernetesVersion`: Kubernetes version (default: 1.30)
- `NodeInstanceType`: EC2 instance type (default: t3.medium)
- `DesiredNodeCount`: Desired number of nodes (default: 2)
- `MinNodeCount`: Minimum number of nodes (default: 1)
- `MaxNodeCount`: Maximum number of nodes (default: 5)
- `EKSServiceRoleArn`: ARN of EKS Service Role
- `NodeInstanceRoleArn`: ARN of Node Instance Role
- `VPCId`: VPC ID for the cluster
- `PrivateSubnetIds`: List of private subnet IDs
- `NodeSecurityGroupId`: Security group ID for nodes

**Outputs:**
- Cluster Name
- Cluster ARN
- Cluster Endpoint
- Node Group ID
- Load Balancer DNS Name
- Load Balancer ARN
- Target Group ARNs
- CloudWatch Log Group Name

## Deployment Order

1. Deploy `vpc-networking.yaml` first
2. Deploy `iam-roles.yaml` second
3. Deploy `eks-cluster.yaml` last

This order ensures all dependencies are created before resources that depend on them.

## Quick Start

```bash
# Deploy VPC
aws cloudformation create-stack \
  --stack-name cloudtolocalllm-vpc \
  --template-body file://vpc-networking.yaml \
  --region us-east-1

# Deploy IAM
aws cloudformation create-stack \
  --stack-name cloudtolocalllm-iam \
  --template-body file://iam-roles.yaml \
  --region us-east-1 \
  --capabilities CAPABILITY_NAMED_IAM

# Deploy EKS (after getting outputs from previous stacks)
aws cloudformation create-stack \
  --stack-name cloudtolocalllm-eks \
  --template-body file://eks-cluster.yaml \
  --region us-east-1 \
  --parameters \
    ParameterKey=EKSServiceRoleArn,ParameterValue=<from-iam-stack> \
    ParameterKey=NodeInstanceRoleArn,ParameterValue=<from-iam-stack> \
    ParameterKey=VPCId,ParameterValue=<from-vpc-stack> \
    ParameterKey=PrivateSubnetIds,ParameterValue=<from-vpc-stack> \
    ParameterKey=NodeSecurityGroupId,ParameterValue=<from-vpc-stack>
```

## Features

### High Availability
- Multi-AZ deployment with subnets in 3 availability zones
- NAT gateways in 2 availability zones for redundancy
- Auto-scaling node group for dynamic capacity

### Security
- Private subnets for EKS nodes (not publicly accessible)
- Security groups with least-privilege access
- OIDC authentication for GitHub Actions (no long-lived credentials)
- IAM roles for pod authentication (IRSA)
- Encrypted CloudWatch logs

### Monitoring
- CloudWatch Container Insights integration
- CloudWatch alarms for cluster health
- Cluster logging enabled for API, audit, authenticator, controller manager, and scheduler
- Network Load Balancer health checks

### Cost Optimization
- t3.medium instances for development (cost-effective)
- Auto-scaling to adjust capacity based on demand
- Network Load Balancer for efficient traffic distribution
- Estimated monthly cost: $200-300

## Customization

### Change Instance Type

Update the `NodeInstanceType` parameter:

```bash
aws cloudformation update-stack \
  --stack-name cloudtolocalllm-eks \
  --template-body file://eks-cluster.yaml \
  --region us-east-1 \
  --parameters \
    ParameterKey=NodeInstanceType,ParameterValue=t3.large \
    UsePreviousValue=true
```

### Scale Node Count

Update the `DesiredNodeCount` parameter:

```bash
aws cloudformation update-stack \
  --stack-name cloudtolocalllm-eks \
  --template-body file://eks-cluster.yaml \
  --region us-east-1 \
  --parameters \
    ParameterKey=DesiredNodeCount,ParameterValue=3 \
    UsePreviousValue=true
```

### Change Kubernetes Version

Update the `KubernetesVersion` parameter:

```bash
aws cloudformation update-stack \
  --stack-name cloudtolocalllm-eks \
  --template-body file://eks-cluster.yaml \
  --region us-east-1 \
  --parameters \
    ParameterKey=KubernetesVersion,ParameterValue=1.29 \
    UsePreviousValue=true
```

## Validation

Validate templates before deployment:

```bash
aws cloudformation validate-template \
  --template-body file://vpc-networking.yaml

aws cloudformation validate-template \
  --template-body file://iam-roles.yaml

aws cloudformation validate-template \
  --template-body file://eks-cluster.yaml
```

## Troubleshooting

### Check Stack Status

```bash
aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1
```

### View Stack Events

```bash
aws cloudformation describe-stack-events \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1
```

### Get Stack Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

## References

- [AWS CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/)
- [CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
