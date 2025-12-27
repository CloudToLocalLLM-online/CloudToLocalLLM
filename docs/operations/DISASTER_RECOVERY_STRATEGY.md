# AWS EKS Disaster Recovery and Backup Strategy

## Overview

This document outlines the disaster recovery (DR) and backup procedures for CloudToLocalLLM deployed on AWS EKS. The strategy focuses on data protection, recovery time objectives (RTO), and recovery point objectives (RPO) for the development environment.

**Key Principles:**
- **No data migration needed**: Infrastructure can be recreated from code
- **Automated backups**: PostgreSQL backups run on a schedule
- **Point-in-time recovery**: Ability to restore to any point in time
- **Infrastructure as Code**: All infrastructure defined in CloudFormation and Kubernetes manifests
- **Minimal RTO**: Target recovery time of 30 minutes for full infrastructure

## Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO)

### RTO (Recovery Time Objective)

**RTO**: Maximum acceptable downtime before system must be restored

| Component | RTO | Notes |
|-----------|-----|-------|
| EKS Cluster | 30 minutes | Recreate from CloudFormation templates |
| PostgreSQL Database | 15 minutes | Restore from latest backup |
| Application Services | 10 minutes | Redeploy from Docker Hub images |
| DNS/SSL | 5 minutes | Update Cloudflare DNS records |
| **Total System RTO** | **30 minutes** | Full infrastructure recovery |

### RPO (Recovery Point Objective)

**RPO**: Maximum acceptable data loss (time since last backup)

| Component | RPO | Backup Frequency |
|-----------|-----|------------------|
| PostgreSQL Database | 1 hour | Hourly automated backups |
| Application Configuration | Real-time | Version controlled in Git |
| Infrastructure Code | Real-time | Version controlled in Git |
| Docker Images | Real-time | Pushed to Docker Hub on build |

## Backup Strategy

### PostgreSQL Database Backups

#### Backup Types

1. **Full Backups**
   - Complete database dump using `pg_dump`
   - Frequency: Daily at 2 AM UTC
   - Retention: 30 days
   - Size: ~100-500 MB (depending on data)

2. **Incremental Backups**
   - WAL (Write-Ahead Logging) archives
   - Frequency: Continuous
   - Retention: 7 days
   - Enables point-in-time recovery

#### Backup Locations

- **Primary**: AWS S3 bucket `cloudtolocalllm-backups`
- **Secondary**: Local EBS volume (for quick recovery)
- **Encryption**: AES-256 encryption at rest

#### Backup Automation

Backups are automated using:
- Kubernetes CronJob for scheduled backups
- AWS S3 for backup storage
- Automated retention policies

### Infrastructure Backups

#### Infrastructure as Code

All infrastructure is version controlled:

1. **CloudFormation Templates**
   - `config/cloudformation/eks-cluster.yaml`
   - `config/cloudformation/vpc-networking.yaml`
   - `config/cloudformation/iam-roles.yaml`

2. **Kubernetes Manifests**
   - `k8s/namespace.yaml`
   - `k8s/configmap.yaml`
   - `k8s/secrets.yaml.template`
   - `k8s/postgres-statefulset.yaml`
   - `k8s/web-deployment.yaml`
   - `k8s/api-backend-deployment.yaml`
   - `k8s/ingress-aws-nlb.yaml`

3. **GitHub Repository**
   - All code and configuration in Git
   - Automatic backups via GitHub
   - Version history for rollback

### Application Backups

#### Docker Images

- Stored in Docker Hub: `cloudtolocalllm/cloudtolocalllm-web`, `cloudtolocalllm/cloudtolocalllm-api`
- Tagged with commit SHA for traceability
- Retention: All images retained indefinitely

#### Configuration

- Stored in Kubernetes ConfigMaps and Secrets
- Backed up with database backups
- Version controlled in Git

## Disaster Recovery Procedures

### Scenario 1: PostgreSQL Database Failure

**Symptoms:**
- Database pod not responding
- Connection timeouts
- Data corruption detected

**Recovery Steps:**

1. **Identify the issue**
   ```bash
   kubectl logs -n cloudtolocalllm postgres-0
   kubectl describe pod -n cloudtolocalllm postgres-0
   ```

2. **Restore from backup**
   ```bash
   # List available backups
   aws s3 ls s3://cloudtolocalllm-backups/
   
   # Download backup
   aws s3 cp s3://cloudtolocalllm-backups/backup_YYYYMMDD_HHMMSS.sql ./
   
   # Restore to database
   kubectl exec -it -n cloudtolocalllm postgres-0 -- psql -U cloud_admin -d cloudtolocalllm < backup_YYYYMMDD_HHMMSS.sql
   ```

3. **Verify data integrity**
   ```bash
   kubectl exec -it -n cloudtolocalllm postgres-0 -- psql -U cloud_admin -d cloudtolocalllm -c "SELECT COUNT(*) FROM users;"
   ```

4. **Restart application services**
   ```bash
   kubectl rollout restart deployment/web-app -n cloudtolocalllm
   kubectl rollout restart deployment/api-backend -n cloudtolocalllm
   ```

**RTO**: 15 minutes
**RPO**: 1 hour (latest backup)

### Scenario 2: EKS Cluster Failure

**Symptoms:**
- All pods failing
- Cluster nodes not responding
- Network connectivity issues

**Recovery Steps:**

1. **Assess cluster health**
   ```bash
   kubectl get nodes
   kubectl get pods -n cloudtolocalllm
   ```

2. **If cluster is unrecoverable, recreate from CloudFormation**
   ```bash
   # Delete failed cluster
   aws eks delete-cluster --name cloudtolocalllm-eks --region us-east-1
   
   # Wait for deletion (5-10 minutes)
   aws eks describe-cluster --name cloudtolocalllm-eks --region us-east-1
   
   # Recreate cluster from CloudFormation
   aws cloudformation create-stack \
     --stack-name cloudtolocalllm-eks-stack \
     --template-body file://config/cloudformation/eks-cluster.yaml \
     --parameters ParameterKey=ClusterName,ParameterValue=cloudtolocalllm-eks
   ```

3. **Wait for cluster to be ready**
   ```bash
   aws eks describe-cluster --name cloudtolocalllm-eks --region us-east-1 --query 'cluster.status'
   ```

4. **Deploy applications**
   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/secrets.yaml
   kubectl apply -f k8s/postgres-statefulset.yaml
   kubectl apply -f k8s/web-deployment.yaml
   kubectl apply -f k8s/api-backend-deployment.yaml
   kubectl apply -f k8s/ingress-aws-nlb.yaml
   ```

5. **Restore database**
   - Follow "PostgreSQL Database Failure" recovery steps

6. **Update DNS records**
   ```bash
   # Get new load balancer IP
   kubectl get svc -n cloudtolocalllm ingress-nginx-controller
   
   # Update Cloudflare DNS records to point to new IP
   ```

**RTO**: 30 minutes
**RPO**: 1 hour (latest backup)

### Scenario 3: Application Deployment Failure

**Symptoms:**
- Pods in CrashLoopBackOff state
- Application not responding
- Health checks failing

**Recovery Steps:**

1. **Check pod logs**
   ```bash
   kubectl logs -n cloudtolocalllm deployment/web-app --tail=100
   kubectl logs -n cloudtolocalllm deployment/api-backend --tail=100
   ```

2. **Rollback to previous deployment**
   ```bash
   kubectl rollout history deployment/web-app -n cloudtolocalllm
   kubectl rollout undo deployment/web-app -n cloudtolocalllm
   ```

3. **Verify application is running**
   ```bash
   kubectl get pods -n cloudtolocalllm
   kubectl get svc -n cloudtolocalllm
   ```

4. **Check application health**
   ```bash
   curl https://app.cloudtolocalllm.online/health
   curl https://api.cloudtolocalllm.online/health
   ```

**RTO**: 5 minutes
**RPO**: No data loss (application-only failure)

### Scenario 4: Data Corruption

**Symptoms:**
- Inconsistent data in database
- Application errors related to data integrity
- Validation failures

**Recovery Steps:**

1. **Identify corruption**
   ```bash
   kubectl exec -it -n cloudtolocalllm postgres-0 -- psql -U cloud_admin -d cloudtolocalllm -c "SELECT * FROM users WHERE id = <corrupted_id>;"
   ```

2. **Determine point-in-time to restore**
   - Review backup timestamps
   - Choose backup before corruption occurred

3. **Restore from backup**
   ```bash
   # Download backup from before corruption
   aws s3 cp s3://cloudtolocalllm-backups/backup_YYYYMMDD_HHMMSS.sql ./
   
   # Restore database
   kubectl exec -it -n cloudtolocalllm postgres-0 -- psql -U cloud_admin -d cloudtolocalllm < backup_YYYYMMDD_HHMMSS.sql
   ```

4. **Verify data integrity**
   ```bash
   kubectl exec -it -n cloudtolocalllm postgres-0 -- psql -U cloud_admin -d cloudtolocalllm -c "SELECT COUNT(*) FROM users;"
   ```

5. **Restart application services**
   ```bash
   kubectl rollout restart deployment/web-app -n cloudtolocalllm
   kubectl rollout restart deployment/api-backend -n cloudtolocalllm
   ```

**RTO**: 20 minutes
**RPO**: Up to 1 hour (data loss possible)

## Backup Automation

### Kubernetes CronJob for PostgreSQL Backups

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: cloudtolocalllm
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM UTC
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: postgres-backup
          containers:
          - name: postgres-backup
            image: postgres:15
            command:
            - /bin/sh
            - -c
            - |
              BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
              pg_dump -h postgres -U cloud_admin -d cloudtolocalllm > /backups/$BACKUP_FILE
              aws s3 cp /backups/$BACKUP_FILE s3://cloudtolocalllm-backups/
              rm /backups/$BACKUP_FILE
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: cloudtolocalllm-secrets
                  key: postgres-password
            volumeMounts:
            - name: backup-storage
              mountPath: /backups
          volumes:
          - name: backup-storage
            emptyDir: {}
          restartPolicy: OnFailure
```

### AWS S3 Lifecycle Policy

Automatically delete old backups:

```json
{
  "Rules": [
    {
      "Id": "DeleteOldBackups",
      "Status": "Enabled",
      "Prefix": "backup_",
      "Expiration": {
        "Days": 30
      }
    }
  ]
}
```

## Testing Disaster Recovery

### Monthly DR Drill

Perform monthly disaster recovery drills to ensure procedures work:

1. **Database Restore Test**
   - Restore latest backup to test environment
   - Verify data integrity
   - Document any issues

2. **Infrastructure Recreation Test**
   - Recreate EKS cluster from CloudFormation
   - Deploy applications from manifests
   - Verify all services are accessible

3. **Failover Test**
   - Simulate node failure
   - Verify automatic pod rescheduling
   - Verify application remains accessible

### Test Schedule

- **Monthly**: Full DR drill
- **Quarterly**: Full infrastructure recreation test
- **After major changes**: Immediate DR test

## Monitoring and Alerting

### Backup Monitoring

Monitor backup success/failure:

```bash
# Check backup job status
kubectl get cronjob -n cloudtolocalllm postgres-backup
kubectl get jobs -n cloudtolocalllm

# Check backup logs
kubectl logs -n cloudtolocalllm -l job-name=postgres-backup-<timestamp>
```

### Alerts

Configure CloudWatch alarms for:
- Backup job failure
- Backup size anomalies
- S3 storage quota exceeded
- Database replication lag

## Documentation and Runbooks

### Key Documents

1. **This file**: Disaster Recovery Strategy
2. **Backup Automation Scripts**: `scripts/aws/backup-postgres.sh`
3. **Recovery Scripts**: `scripts/aws/restore-postgres.sh`
4. **Infrastructure Templates**: `config/cloudformation/`
5. **Kubernetes Manifests**: `k8s/`

### Runbook Access

All runbooks are stored in:
- GitHub repository (version controlled)
- AWS S3 bucket (backup copy)
- Team wiki (for quick reference)

## Compliance and Audit

### Backup Verification

- Weekly: Verify backup file integrity
- Monthly: Test restore procedure
- Quarterly: Full DR drill

### Audit Trail

- All backups logged in CloudWatch
- S3 access logs enabled
- Database audit logs enabled

### Compliance Requirements

- GDPR: Data retention policies enforced
- SOC 2: Backup encryption and access controls
- ISO 27001: Disaster recovery procedures documented

## Cost Considerations

### Backup Storage Costs

- S3 storage: ~$0.023 per GB per month
- Estimated monthly cost: $5-10 (for 30-day retention)
- Backup transfer: Included in AWS data transfer

### Disaster Recovery Costs

- Temporary infrastructure during recovery: ~$50-100
- Data transfer costs: Minimal (within AWS region)
- Total estimated DR cost: $100-200 per incident

## Conclusion

This disaster recovery strategy ensures that CloudToLocalLLM can be recovered from any failure within 30 minutes with minimal data loss. Regular testing and monitoring ensure the procedures remain effective and up-to-date.

For questions or updates to this strategy, contact the DevOps team.
