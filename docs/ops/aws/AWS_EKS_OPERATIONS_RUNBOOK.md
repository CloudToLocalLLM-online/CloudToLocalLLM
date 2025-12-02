# AWS EKS Operations Runbook

This runbook provides step-by-step procedures for common operational tasks on the AWS EKS cluster running CloudToLocalLLM.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Deployment Operations](#deployment-operations)
3. [Scaling Operations](#scaling-operations)
4. [Cost Monitoring](#cost-monitoring)
5. [Backup and Recovery](#backup-and-recovery)
6. [Monitoring and Alerting](#monitoring-and-alerting)
7. [Maintenance Operations](#maintenance-operations)
8. [Emergency Procedures](#emergency-procedures)

## Daily Operations

### Check Cluster Health

**Frequency:** Daily (or as needed)

**Steps:**

1. **Check Cluster Status**
   ```bash
   aws eks describe-cluster --name cloudtolocalllm-eks \
     --query 'cluster.status'
   ```
   Expected output: `ACTIVE`

2. **Check Node Status**
   ```bash
   kubectl get nodes
   ```
   Expected output: All nodes in `Ready` state

3. **Check Pod Status**
   ```bash
   kubectl get pods -n cloudtolocalllm
   ```
   Expected output: All pods in `Running` state

4. **Check Service Status**
   ```bash
   kubectl get services -n cloudtolocalllm
   ```
   Expected output: All services have external IPs/DNS names

5. **Check Resource Usage**
   ```bash
   kubectl top nodes
   kubectl top pods -n cloudtolocalllm
   ```
   Expected output: CPU and memory usage within limits

**Troubleshooting:**
- If any component is not healthy, refer to the [Troubleshooting Guide](AWS_EKS_TROUBLESHOOTING_GUIDE.md)

### Monitor Application Logs

**Frequency:** Daily or as needed

**Steps:**

1. **View Recent Logs**
   ```bash
   kubectl logs -n cloudtolocalllm deployment/web-app --tail=100
   kubectl logs -n cloudtolocalllm deployment/api-backend --tail=100
   ```

2. **Stream Live Logs**
   ```bash
   kubectl logs -f -n cloudtolocalllm deployment/web-app
   ```

3. **Check for Errors**
   ```bash
   kubectl logs -n cloudtolocalllm deployment/web-app | grep -i error
   ```

4. **View CloudWatch Logs**
   ```bash
   aws logs tail /aws/eks/cloudtolocalllm-eks/cluster --follow
   ```

### Check DNS Resolution

**Frequency:** Daily

**Steps:**

1. **Verify DNS Records**
   ```bash
   nslookup cloudtolocalllm.online
   nslookup app.cloudtolocalllm.online
   nslookup api.cloudtolocalllm.online
   ```

2. **Verify SSL Certificates**
   ```bash
   curl -I https://cloudtolocalllm.online
   curl -I https://app.cloudtolocalllm.online
   curl -I https://api.cloudtolocalllm.online
   ```

3. **Check Certificate Expiration**
   ```bash
   openssl s_client -connect cloudtolocalllm.online:443 -showcerts | \
     grep -A 1 "Not After"
   ```

## Deployment Operations

### Deploy New Version

**Frequency:** As needed (typically multiple times per day)

**Steps:**

1. **Trigger GitHub Actions Workflow**
   ```bash
   # Option 1: Push code to main branch
   git push origin main

   # Option 2: Manually trigger workflow
   gh workflow run deploy-aws-eks.yml
   ```

2. **Monitor Deployment**
   ```bash
   # Watch workflow progress
   gh run list --workflow=deploy-aws-eks.yml
   gh run view <run-id>

   # Watch pod rollout
   kubectl rollout status deployment/web-app -n cloudtolocalllm
   kubectl rollout status deployment/api-backend -n cloudtolocalllm
   ```

3. **Verify Deployment**
   ```bash
   # Check pod status
   kubectl get pods -n cloudtolocalllm

   # Check pod logs for errors
   kubectl logs -n cloudtolocalllm deployment/web-app --tail=50
   kubectl logs -n cloudtolocalllm deployment/api-backend --tail=50

   # Test application
   curl https://app.cloudtolocalllm.online
   curl https://api.cloudtolocalllm.online
   ```

4. **Rollback if Needed**
   ```bash
   # Rollback to previous version
   kubectl rollout undo deployment/web-app -n cloudtolocalllm
   kubectl rollout undo deployment/api-backend -n cloudtolocalllm

   # Verify rollback
   kubectl rollout status deployment/web-app -n cloudtolocalllm
   ```

### Update Deployment Configuration

**Frequency:** As needed

**Steps:**

1. **Update ConfigMap**
   ```bash
   # Edit ConfigMap
   kubectl edit configmap app-config -n cloudtolocalllm

   # Or update from file
   kubectl apply -f k8s/configmap.yaml -n cloudtolocalllm

   # Restart pods to apply changes
   kubectl rollout restart deployment/web-app -n cloudtolocalllm
   kubectl rollout restart deployment/api-backend -n cloudtolocalllm
   ```

2. **Update Secrets**
   ```bash
   # Delete old secret
   kubectl delete secret app-secrets -n cloudtolocalllm

   # Create new secret
   kubectl create secret generic app-secrets \
     --from-literal=supabase-auth-domain=$JWT_ISSUER_DOMAIN \
     --from-literal=supabase-auth-client-id=$JWT_CLIENT_ID \
     --from-literal=supabase-auth-client-secret=$JWT_CLIENT_SECRET \
     -n cloudtolocalllm

   # Restart pods to apply changes
   kubectl rollout restart deployment/web-app -n cloudtolocalllm
   kubectl rollout restart deployment/api-backend -n cloudtolocalllm
   ```

3. **Verify Changes**
   ```bash
   # Check pod environment
   kubectl exec <pod-name> -n cloudtolocalllm -- env | grep JWT

   # Check application logs
   kubectl logs -n cloudtolocalllm deployment/web-app --tail=50
   ```

### Update Kubernetes Manifests

**Frequency:** As needed

**Steps:**

1. **Update Manifest Files**
   ```bash
   # Edit manifest
   vim k8s/web-deployment.yaml

   # Apply changes
   kubectl apply -f k8s/web-deployment.yaml -n cloudtolocalllm
   ```

2. **Verify Changes**
   ```bash
   # Check deployment status
   kubectl get deployment web-app -n cloudtolocalllm -o yaml

   # Check pod status
   kubectl get pods -n cloudtolocalllm

   # Check rollout status
   kubectl rollout status deployment/web-app -n cloudtolocalllm
   ```

3. **Rollback if Needed**
   ```bash
   # Rollback to previous version
   kubectl rollout undo deployment/web-app -n cloudtolocalllm

   # Verify rollback
   kubectl rollout status deployment/web-app -n cloudtolocalllm
   ```

## Scaling Operations

### Scale Deployment Replicas

**Frequency:** As needed (typically during traffic spikes)

**Steps:**

1. **Manual Scaling**
   ```bash
   # Scale deployment
   kubectl scale deployment web-app --replicas=3 -n cloudtolocalllm
   kubectl scale deployment api-backend --replicas=3 -n cloudtolocalllm

   # Verify scaling
   kubectl get pods -n cloudtolocalllm
   ```

2. **Automatic Scaling (HPA)**
   ```bash
   # Create HPA if not exists
   kubectl autoscale deployment web-app \
     --min=2 --max=10 \
     --cpu-percent=80 \
     -n cloudtolocalllm

   # Check HPA status
   kubectl get hpa -n cloudtolocalllm
   kubectl describe hpa web-app -n cloudtolocalllm
   ```

3. **Monitor Scaling**
   ```bash
   # Watch pod scaling
   watch -n 5 'kubectl get pods -n cloudtolocalllm'

   # Check HPA metrics
   kubectl get hpa -n cloudtolocalllm --watch
   ```

### Scale Cluster Nodes

**Frequency:** As needed (typically during sustained high traffic)

**Steps:**

1. **Check Current Node Count**
   ```bash
   kubectl get nodes
   aws eks describe-nodegroup \
     --cluster-name cloudtolocalllm-eks \
     --nodegroup-name cloudtolocalllm-nodes \
     --query 'nodegroup.scalingConfig'
   ```

2. **Scale Node Group**
   ```bash
   # Increase node count
   aws eks update-nodegroup-config \
     --cluster-name cloudtolocalllm-eks \
     --nodegroup-name cloudtolocalllm-nodes \
     --scaling-config minSize=1,maxSize=10,desiredSize=3
   ```

3. **Monitor Node Scaling**
   ```bash
   # Watch nodes being added
   watch -n 10 'kubectl get nodes'

   # Check node status
   kubectl describe nodes
   ```

4. **Verify Pods Scheduled**
   ```bash
   # Check if pending pods are now scheduled
   kubectl get pods -n cloudtolocalllm
   ```

### Scale Down Cluster

**Frequency:** During off-hours or low traffic periods

**Steps:**

1. **Scale Down Node Group**
   ```bash
   # Decrease node count
   aws eks update-nodegroup-config \
     --cluster-name cloudtolocalllm-eks \
     --nodegroup-name cloudtolocalllm-nodes \
     --scaling-config minSize=1,maxSize=10,desiredSize=2
   ```

2. **Monitor Node Removal**
   ```bash
   # Watch nodes being removed
   watch -n 10 'kubectl get nodes'

   # Check pod eviction
   kubectl get events -n cloudtolocalllm
   ```

3. **Verify Application Health**
   ```bash
   # Check pod status
   kubectl get pods -n cloudtolocalllm

   # Check application logs
   kubectl logs -n cloudtolocalllm deployment/web-app --tail=50
   ```

## Cost Monitoring

### Generate Cost Report

**Frequency:** Weekly or as needed

**Steps:**

1. **Run Cost Monitoring Script**
   ```bash
   # Generate cost report
   node scripts/aws/cost-monitoring.js

   # Output: Cost report with breakdown and recommendations
   ```

2. **Review Cost Report**
   ```json
   {
     "timestamp": "2024-01-15T10:30:00Z",
     "clusterName": "cloudtolocalllm-eks",
     "costAnalysis": {
       "estimatedMonthlyCost": 60.48,
       "breakdown": {
         "t3.small": {
           "cost": 30.72,
           "description": "2x t3.small EC2 instance"
         },
         "network-load-balancer": {
           "cost": 16.56,
           "description": "Network Load Balancer"
         },
         "ebs-storage": {
           "cost": 10,
           "description": "EBS storage (100GB estimate)"
         },
         "data-transfer": {
           "cost": 5,
           "description": "Data transfer out (250GB estimate)"
         },
         "cloudwatch-logs": {
           "cost": 5,
           "description": "CloudWatch logs (10GB estimate)"
         }
       },
       "budget": 300,
       "budgetUtilization": "20.16%",
       "withinBudget": true
     },
     "recommendations": []
   }
   ```

3. **Export Report**
   ```bash
   # Reports are automatically saved to docs/cost-report-*.json
   ls -lh docs/cost-report-*.json
   ```

### Monitor Actual AWS Costs

**Frequency:** Daily or as needed

**Steps:**

1. **Check AWS Billing Dashboard**
   ```bash
   # Get estimated charges
   aws ce get-cost-and-usage \
     --time-period Start=$(date -d '1 month ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
     --granularity MONTHLY \
     --metrics "UnblendedCost" \
     --group-by Type=DIMENSION,Key=SERVICE
   ```

2. **View Cost Explorer**
   - Navigate to AWS Console → Billing → Cost Explorer
   - Filter by service (EC2, ELB, CloudWatch, etc.)
   - Compare actual vs. estimated costs

3. **Set Up Cost Alerts**
   ```bash
   # Create monthly cost alert
   aws cloudwatch put-metric-alarm \
     --alarm-name cloudtolocalllm-monthly-cost-alert \
     --alarm-description "Alert when monthly costs exceed $300" \
     --metric-name EstimatedCharges \
     --namespace AWS/Billing \
     --statistic Maximum \
     --period 86400 \
     --threshold 300 \
     --comparison-operator GreaterThanThreshold \
     --evaluation-periods 1
   ```

### Optimize Cluster Costs

**Frequency:** Monthly or as needed

**Steps:**

1. **Review Cost Recommendations**
   ```bash
   # Check recommendations from cost report
   node scripts/aws/cost-monitoring.js | grep -A 10 "recommendations"
   ```

2. **Implement Cost Optimizations**
   - **Reduce Instance Type**: Switch from t3.small to t3.micro if possible
   - **Reduce Node Count**: Scale down to 2 nodes during off-hours
   - **Disable Unused Services**: Disable storage, data transfer, or logging if not needed
   - **Use Reserved Instances**: Purchase 1-year or 3-year reserved instances for 30-50% savings

3. **Example: Scale Down to t3.micro**
   ```bash
   # Update node group to use t3.micro
   aws eks update-nodegroup-config \
     --cluster-name cloudtolocalllm-eks \
     --nodegroup-name cloudtolocalllm-nodes \
     --scaling-config minSize=2,maxSize=3,desiredSize=2

   # Estimated savings: ~$23/month per node
   ```

4. **Verify Cost Reduction**
   ```bash
   # Re-run cost monitoring to see new estimates
   node scripts/aws/cost-monitoring.js
   ```

### Track Cost Trends

**Frequency:** Monthly

**Steps:**

1. **Compare Month-over-Month Costs**
   ```bash
   # Get previous month costs
   aws ce get-cost-and-usage \
     --time-period Start=$(date -d '2 months ago' +%Y-%m-%d),End=$(date -d '1 month ago' +%Y-%m-%d) \
     --granularity MONTHLY \
     --metrics "UnblendedCost"

   # Get current month costs
   aws ce get-cost-and-usage \
     --time-period Start=$(date -d '1 month ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
     --granularity MONTHLY \
     --metrics "UnblendedCost"
   ```

2. **Identify Cost Drivers**
   ```bash
   # Get costs by service
   aws ce get-cost-and-usage \
     --time-period Start=$(date -d '1 month ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
     --granularity MONTHLY \
     --metrics "UnblendedCost" \
     --group-by Type=DIMENSION,Key=SERVICE
   ```

3. **Document Findings**
   - Record monthly costs in a spreadsheet
   - Track cost trends over time
   - Identify anomalies or unexpected increases

## Backup and Recovery

### Backup PostgreSQL Database

**Frequency:** Daily (automated) or as needed

**Steps:**

1. **Create Backup**
   ```bash
   # Create backup
   kubectl exec -n cloudtolocalllm postgres-0 -- \
     pg_dump -U postgres cloudtolocalllm > backup-$(date +%Y%m%d-%H%M%S).sql

   # Verify backup
   ls -lh backup-*.sql
   ```

2. **Upload to S3**
   ```bash
   # Upload backup
   aws s3 cp backup-*.sql s3://cloudtolocalllm-backups/

   # Verify upload
   aws s3 ls s3://cloudtolocalllm-backups/
   ```

3. **Verify Backup Integrity**
   ```bash
   # Check backup file size
   ls -lh backup-*.sql

   # Check backup content
   head -20 backup-*.sql
   ```

### Restore PostgreSQL Database

**Frequency:** As needed (disaster recovery)

**Steps:**

1. **Download Backup from S3**
   ```bash
   # List available backups
   aws s3 ls s3://cloudtolocalllm-backups/

   # Download backup
   aws s3 cp s3://cloudtolocalllm-backups/backup-20240101-120000.sql .
   ```

2. **Restore Database**
   ```bash
   # Connect to PostgreSQL pod
   kubectl exec -it -n cloudtolocalllm postgres-0 -- /bin/bash

   # Restore database
   psql -U postgres < backup-20240101-120000.sql
   ```

3. **Verify Restoration**
   ```bash
   # Connect to database
   kubectl exec -it -n cloudtolocalllm postgres-0 -- \
     psql -U postgres -d cloudtolocalllm

   # Check tables
   \dt

   # Check data
   SELECT COUNT(*) FROM users;
   ```

### Backup Kubernetes Configuration

**Frequency:** Before major changes

**Steps:**

1. **Backup Manifests**
   ```bash
   # Backup all manifests
   kubectl get all -n cloudtolocalllm -o yaml > k8s-backup-$(date +%Y%m%d-%H%M%S).yaml

   # Backup specific resources
   kubectl get deployment -n cloudtolocalllm -o yaml > deployments-backup.yaml
   kubectl get configmap -n cloudtolocalllm -o yaml > configmaps-backup.yaml
   kubectl get secret -n cloudtolocalllm -o yaml > secrets-backup.yaml
   ```

2. **Upload to Git**
   ```bash
   # Commit backups to Git
   git add k8s-backup-*.yaml
   git commit -m "Backup Kubernetes configuration"
   git push origin main
   ```

## Monitoring and Alerting

### Check CloudWatch Metrics

**Frequency:** Daily or as needed

**Steps:**

1. **View Cluster Metrics**
   ```bash
   # Get CPU usage
   aws cloudwatch get-metric-statistics \
     --namespace ContainerInsights \
     --metric-name ClusterNode_cpu_utilization \
     --dimensions Name=ClusterName,Value=cloudtolocalllm-eks \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Average

   # Get memory usage
   aws cloudwatch get-metric-statistics \
     --namespace ContainerInsights \
     --metric-name ClusterNode_memory_utilization \
     --dimensions Name=ClusterName,Value=cloudtolocalllm-eks \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Average
   ```

2. **View Pod Metrics**
   ```bash
   # Get pod CPU usage
   kubectl top pods -n cloudtolocalllm

   # Get pod memory usage
   kubectl top pods -n cloudtolocalllm --containers
   ```

3. **View CloudWatch Dashboards**
   ```bash
   # List dashboards
   aws cloudwatch list-dashboards

   # Get dashboard details
   aws cloudwatch get-dashboard --dashboard-name cloudtolocalllm-eks
   ```

### Create CloudWatch Alarms

**Frequency:** During setup or as needed

**Steps:**

1. **Create CPU Alarm**
   ```bash
   aws cloudwatch put-metric-alarm \
     --alarm-name cloudtolocalllm-high-cpu \
     --alarm-description "Alert when cluster CPU is high" \
     --metric-name ClusterNode_cpu_utilization \
     --namespace ContainerInsights \
     --statistic Average \
     --period 300 \
     --threshold 80 \
     --comparison-operator GreaterThanThreshold \
     --evaluation-periods 2 \
     --alarm-actions arn:aws:sns:us-east-1:422017356244:cloudtolocalllm-alerts
   ```

2. **Create Memory Alarm**
   ```bash
   aws cloudwatch put-metric-alarm \
     --alarm-name cloudtolocalllm-high-memory \
     --alarm-description "Alert when cluster memory is high" \
     --metric-name ClusterNode_memory_utilization \
     --namespace ContainerInsights \
     --statistic Average \
     --period 300 \
     --threshold 80 \
     --comparison-operator GreaterThanThreshold \
     --evaluation-periods 2 \
     --alarm-actions arn:aws:sns:us-east-1:422017356244:cloudtolocalllm-alerts
   ```

3. **Verify Alarms**
   ```bash
   # List alarms
   aws cloudwatch describe-alarms

   # Get alarm details
   aws cloudwatch describe-alarms --alarm-names cloudtolocalllm-high-cpu
   ```

## Maintenance Operations

### Update Kubernetes Version

**Frequency:** Quarterly or as needed

**Steps:**

1. **Check Current Version**
   ```bash
   kubectl version --short
   aws eks describe-cluster --name cloudtolocalllm-eks \
     --query 'cluster.version'
   ```

2. **Update Cluster**
   ```bash
   # Update cluster control plane
   aws eks update-cluster-version \
     --name cloudtolocalllm-eks \
     --kubernetes-version 1.31
   ```

3. **Monitor Update**
   ```bash
   # Check update status
   aws eks describe-cluster --name cloudtolocalllm-eks \
     --query 'cluster.status'

   # Wait for update to complete (may take 30-60 minutes)
   ```

4. **Update Node Group**
   ```bash
   # Update node group
   aws eks update-nodegroup-version \
     --cluster-name cloudtolocalllm-eks \
     --nodegroup-name cloudtolocalllm-nodes \
     --kubernetes-version 1.31
   ```

5. **Verify Update**
   ```bash
   # Check node versions
   kubectl get nodes -o wide

   # Check pod status
   kubectl get pods -n cloudtolocalllm
   ```

### Update Node AMI

**Frequency:** Monthly or as needed

**Steps:**

1. **Check Current AMI**
   ```bash
   aws eks describe-nodegroup \
     --cluster-name cloudtolocalllm-eks \
     --nodegroup-name cloudtolocalllm-nodes \
     --query 'nodegroup.amiType'
   ```

2. **Update Node Group**
   ```bash
   # Update node group with latest AMI
   aws eks update-nodegroup-version \
     --cluster-name cloudtolocalllm-eks \
     --nodegroup-name cloudtolocalllm-nodes
   ```

3. **Monitor Update**
   ```bash
   # Watch nodes being replaced
   watch -n 10 'kubectl get nodes'

   # Check pod status
   kubectl get pods -n cloudtolocalllm
   ```

### Clean Up Old Resources

**Frequency:** Monthly

**Steps:**

1. **Delete Old Pods**
   ```bash
   # Delete completed pods
   kubectl delete pods --field-selector status.phase=Succeeded -n cloudtolocalllm
   kubectl delete pods --field-selector status.phase=Failed -n cloudtolocalllm
   ```

2. **Clean Up Old Images**
   ```bash
   # List old images
   docker images | grep cloudtolocalllm

   # Delete old images (keep last 5)
   docker rmi $(docker images --format "{{.ID}}" | tail -n +6)
   ```

3. **Clean Up Old Backups**
   ```bash
   # List old backups
   aws s3 ls s3://cloudtolocalllm-backups/

   # Delete backups older than 30 days
   aws s3 rm s3://cloudtolocalllm-backups/ --recursive \
     --exclude "*" --include "backup-*" \
     --older-than 30
   ```

## Emergency Procedures

### Cluster Failure Recovery

**Frequency:** As needed (emergency)

**Steps:**

1. **Assess Situation**
   ```bash
   # Check cluster status
   aws eks describe-cluster --name cloudtolocalllm-eks

   # Check node status
   kubectl get nodes

   # Check pod status
   kubectl get pods -n cloudtolocalllm
   ```

2. **Restart Cluster**
   ```bash
   # Restart all pods
   kubectl rollout restart deployment -n cloudtolocalllm

   # Wait for pods to restart
   kubectl rollout status deployment/web-app -n cloudtolocalllm
   ```

3. **Restore from Backup**
   ```bash
   # If data is corrupted, restore from backup
   # See "Restore PostgreSQL Database" section above
   ```

### Pod Crash Recovery

**Frequency:** As needed (emergency)

**Steps:**

1. **Identify Crashed Pod**
   ```bash
   # Get pod status
   kubectl get pods -n cloudtolocalllm

   # Get pod logs
   kubectl logs <pod-name> -n cloudtolocalllm --previous
   ```

2. **Restart Pod**
   ```bash
   # Delete pod to force restart
   kubectl delete pod <pod-name> -n cloudtolocalllm

   # Verify pod restarted
   kubectl get pods -n cloudtolocalllm
   ```

3. **Investigate Root Cause**
   ```bash
   # Check pod events
   kubectl describe pod <pod-name> -n cloudtolocalllm

   # Check application logs
   kubectl logs <pod-name> -n cloudtolocalllm
   ```

### Database Connection Failure

**Frequency:** As needed (emergency)

**Steps:**

1. **Check Database Pod**
   ```bash
   # Get database pod status
   kubectl get pods -n cloudtolocalllm | grep postgres

   # Check database logs
   kubectl logs -n cloudtolocalllm postgres-0
   ```

2. **Restart Database**
   ```bash
   # Delete database pod to force restart
   kubectl delete pod postgres-0 -n cloudtolocalllm

   # Wait for pod to restart
   kubectl wait --for=condition=Ready pod/postgres-0 -n cloudtolocalllm --timeout=300s
   ```

3. **Verify Database Connection**
   ```bash
   # Test database connection
   kubectl exec -it -n cloudtolocalllm postgres-0 -- \
     psql -U postgres -d cloudtolocalllm -c "SELECT 1"
   ```

4. **Restore from Backup if Needed**
   ```bash
   # If database is corrupted, restore from backup
   # See "Restore PostgreSQL Database" section above
   ```

### Network Connectivity Failure

**Frequency:** As needed (emergency)

**Steps:**

1. **Check Network Connectivity**
   ```bash
   # Test DNS resolution
   kubectl exec -it -n cloudtolocalllm <pod-name> -- nslookup cloudtolocalllm.online

   # Test network connectivity
   kubectl exec -it -n cloudtolocalllm <pod-name> -- ping 8.8.8.8
   ```

2. **Check Security Groups**
   ```bash
   # Verify security group rules
   aws ec2 describe-security-groups \
     --filters Name=tag:Name,Values=cloudtolocalllm-* \
     --query 'SecurityGroups[0].IpPermissions'
   ```

3. **Check Network Policies**
   ```bash
   # Get network policies
   kubectl get networkpolicies -n cloudtolocalllm

   # Describe network policy
   kubectl describe networkpolicy <policy-name> -n cloudtolocalllm
   ```

4. **Restart Network Components**
   ```bash
   # Restart CoreDNS
   kubectl rollout restart deployment coredns -n kube-system

   # Restart network policy controller
   kubectl rollout restart deployment aws-vpc-cni -n kube-system
   ```

## Quick Reference

### Common Commands

```bash
# Cluster management
aws eks describe-cluster --name cloudtolocalllm-eks
aws eks list-clusters
kubectl cluster-info

# Node management
kubectl get nodes
kubectl describe nodes
kubectl top nodes

# Pod management
kubectl get pods -n cloudtolocalllm
kubectl describe pod <pod-name> -n cloudtolocalllm
kubectl logs <pod-name> -n cloudtolocalllm
kubectl exec -it <pod-name> -n cloudtolocalllm -- /bin/bash

# Deployment management
kubectl get deployments -n cloudtolocalllm
kubectl describe deployment <deployment-name> -n cloudtolocalllm
kubectl rollout status deployment/<deployment-name> -n cloudtolocalllm
kubectl rollout undo deployment/<deployment-name> -n cloudtolocalllm

# Service management
kubectl get services -n cloudtolocalllm
kubectl describe service <service-name> -n cloudtolocalllm

# Resource management
kubectl top pods -n cloudtolocalllm
kubectl describe resourcequota -n cloudtolocalllm
```

### Useful Aliases

```bash
# Add to ~/.bashrc or ~/.zshrc
alias k='kubectl'
alias kgp='kubectl get pods -n cloudtolocalllm'
alias kgd='kubectl get deployments -n cloudtolocalllm'
alias kgs='kubectl get services -n cloudtolocalllm'
alias kl='kubectl logs -n cloudtolocalllm'
alias kex='kubectl exec -it -n cloudtolocalllm'
alias kdesc='kubectl describe -n cloudtolocalllm'
```

