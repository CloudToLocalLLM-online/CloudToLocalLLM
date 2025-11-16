# Database Configuration Guide

## Overview

This guide covers the PostgreSQL database configuration for the Admin Center, including connection settings, SSL/TLS configuration, and connection pooling.

## Database Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         API Backend Pods (1-3 replicas)            │    │
│  │                                                     │    │
│  │  ┌──────────────────────────────────────────┐     │    │
│  │  │  Connection Pool (max 50 connections)    │     │    │
│  │  │  - Idle timeout: 10 minutes              │     │    │
│  │  │  - Connection timeout: 30 seconds        │     │    │
│  │  └──────────────────────────────────────────┘     │    │
│  │                      │                             │    │
│  └──────────────────────┼─────────────────────────────┘    │
│                         │                                   │
│                         │ SSL/TLS Connection                │
│                         ▼                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │         PostgreSQL StatefulSet                      │    │
│  │  - Host: postgres.cloudtolocalllm.svc.cluster.local│    │
│  │  - Port: 5432                                      │    │
│  │  - Database: cloudtolocalllm                       │    │
│  │  - User: appuser                                   │    │
│  │  - SSL Mode: require                               │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Database Connection Settings

### Environment Variables

The following environment variables configure the database connection:

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DB_TYPE` | Database type | `postgresql` | `postgresql` |
| `DB_HOST` | Database hostname | - | `postgres.cloudtolocalllm.svc.cluster.local` |
| `DB_PORT` | Database port | `5432` | `5432` |
| `DB_NAME` | Database name | - | `cloudtolocalllm` |
| `DB_USER` | Database username | - | `appuser` |
| `DB_PASSWORD` | Database password (secret) | - | `strong_password` |
| `DB_SSL_MODE` | SSL mode | `require` | `require`, `verify-ca`, `verify-full` |
| `DB_POOL_MAX` | Max connections per pod | `50` | `50` |
| `DB_POOL_IDLE_TIMEOUT` | Idle timeout (ms) | `600000` | `600000` (10 min) |
| `DB_POOL_CONNECTION_TIMEOUT` | Connection timeout (ms) | `30000` | `30000` (30 sec) |

### ConfigMap Configuration

Edit `k8s/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudtolocalllm-config
  namespace: cloudtolocalllm
data:
  # Database configuration
  DB_TYPE: "postgresql"
  DB_HOST: "postgres.cloudtolocalllm.svc.cluster.local"
  DB_PORT: "5432"
  DB_NAME: "cloudtolocalllm"
  DB_USER: "appuser"
  
  # Database Connection Pool
  DB_POOL_MAX: "50"
  DB_POOL_IDLE_TIMEOUT: "600000"
  DB_POOL_CONNECTION_TIMEOUT: "30000"
```

### Secrets Configuration

Edit `k8s/secrets.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudtolocalllm-secrets
  namespace: cloudtolocalllm
type: Opaque
stringData:
  # Database credentials
  postgres-password: "YOUR_STRONG_PASSWORD_HERE"
```

**Password Requirements:**
- Minimum 16 characters
- Include uppercase, lowercase, numbers, and special characters
- Generate with: `openssl rand -base64 24`

## SSL/TLS Configuration

### Enable SSL/TLS

PostgreSQL supports SSL/TLS encryption for secure connections.

#### 1. Generate SSL Certificates

```bash
# Generate self-signed certificate (for development)
openssl req -new -x509 -days 365 -nodes -text \
  -out server.crt \
  -keyout server.key \
  -subj "/CN=postgres.cloudtolocalllm.svc.cluster.local"

# Set permissions
chmod 600 server.key
chmod 644 server.crt
```

#### 2. Create Kubernetes Secret

```bash
kubectl create secret generic postgres-ssl \
  --from-file=server.crt=server.crt \
  --from-file=server.key=server.key \
  -n cloudtolocalllm
```

#### 3. Mount SSL Certificates in PostgreSQL Pod

Edit `k8s/postgres-statefulset.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
        - name: postgres
          volumeMounts:
            - name: ssl-certs
              mountPath: /var/lib/postgresql/ssl
              readOnly: true
          env:
            - name: POSTGRES_SSL_CERT_FILE
              value: /var/lib/postgresql/ssl/server.crt
            - name: POSTGRES_SSL_KEY_FILE
              value: /var/lib/postgresql/ssl/server.key
      volumes:
        - name: ssl-certs
          secret:
            secretName: postgres-ssl
            defaultMode: 0600
```

#### 4. Configure PostgreSQL SSL

Connect to PostgreSQL and enable SSL:

```sql
-- Enable SSL
ALTER SYSTEM SET ssl = 'on';
ALTER SYSTEM SET ssl_cert_file = '/var/lib/postgresql/ssl/server.crt';
ALTER SYSTEM SET ssl_key_file = '/var/lib/postgresql/ssl/server.key';

-- Reload configuration
SELECT pg_reload_conf();
```

#### 5. Update Connection String

The API backend will automatically use SSL when `DB_SSL_MODE` is set:

```javascript
// Connection string format
const connectionString = `postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=${DB_SSL_MODE}`;
```

### SSL Modes

| Mode | Description | Security Level |
|------|-------------|----------------|
| `disable` | No SSL | Low (not recommended) |
| `allow` | Try SSL, fallback to non-SSL | Low |
| `prefer` | Try SSL, fallback to non-SSL | Medium |
| `require` | Require SSL, no certificate verification | Medium |
| `verify-ca` | Require SSL, verify CA certificate | High |
| `verify-full` | Require SSL, verify CA and hostname | Highest |

**Recommended:** Use `require` for internal cluster connections, `verify-full` for external connections.

## Connection Pooling

Connection pooling improves performance by reusing database connections.

### Configuration

The API backend uses `pg` (node-postgres) with connection pooling:

```javascript
// services/api-backend/database/db-pool.js
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  
  // Connection pool settings
  max: parseInt(process.env.DB_POOL_MAX || '50'),
  idleTimeoutMillis: parseInt(process.env.DB_POOL_IDLE_TIMEOUT || '600000'),
  connectionTimeoutMillis: parseInt(process.env.DB_POOL_CONNECTION_TIMEOUT || '30000'),
  
  // SSL settings
  ssl: process.env.DB_SSL_MODE === 'require' ? {
    rejectUnauthorized: false
  } : false,
});

module.exports = pool;
```

### Pool Sizing

Calculate optimal pool size:

```
Total Connections = (Number of API Pods) × (DB_POOL_MAX)
```

**Examples:**

| Pods | Pool Size | Total Connections |
|------|-----------|-------------------|
| 1 | 50 | 50 |
| 2 | 25 | 50 |
| 3 | 20 | 60 |
| 5 | 10 | 50 |

**PostgreSQL Limits:**
- Default max connections: 100
- Recommended max connections: 200-300
- Reserve 10-20 connections for admin tasks

**Recommendations:**
- **Small deployment** (1-2 pods): 50 connections per pod
- **Medium deployment** (3-5 pods): 20-30 connections per pod
- **Large deployment** (5+ pods): 10-20 connections per pod

### Monitoring Connection Pool

Check pool metrics:

```bash
# View pool metrics in logs
kubectl logs deployment/api-backend -n cloudtolocalllm | grep "pool"

# Check active connections in PostgreSQL
kubectl exec -it statefulset/postgres -n cloudtolocalllm -- \
  psql -U appuser -d cloudtolocalllm -c \
  "SELECT count(*) as active_connections FROM pg_stat_activity WHERE datname = 'cloudtolocalllm';"
```

## Database Schema

### Admin Center Tables

The Admin Center uses the following tables:

1. **subscriptions** - User subscription data
2. **payment_transactions** - Payment transaction records
3. **payment_methods** - User payment methods
4. **refunds** - Refund records
5. **admin_roles** - Administrator roles and permissions
6. **admin_audit_logs** - Audit log entries

### Run Migrations

Apply database schema:

```bash
# Connect to API backend pod
kubectl exec -it deployment/api-backend -n cloudtolocalllm -- /bin/sh

# Run migrations
cd /app
node services/api-backend/database/migrations/run-migration.js

# Verify tables
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "\dt"
```

### Seed Development Data

Load test data for development:

```bash
# Run seed script
node services/api-backend/database/seeds/run-seed.js

# Verify data
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT * FROM admin_roles;"
```

## Database Backup and Restore

### Automated Backups

Create a CronJob for automated backups:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: cloudtolocalllm
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:15
              env:
                - name: PGHOST
                  value: postgres.cloudtolocalllm.svc.cluster.local
                - name: PGUSER
                  value: appuser
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: cloudtolocalllm-secrets
                      key: postgres-password
                - name: PGDATABASE
                  value: cloudtolocalllm
              command:
                - /bin/sh
                - -c
                - |
                  BACKUP_FILE="/backups/backup-$(date +%Y%m%d-%H%M%S).sql"
                  pg_dump > $BACKUP_FILE
                  gzip $BACKUP_FILE
                  echo "Backup completed: $BACKUP_FILE.gz"
              volumeMounts:
                - name: backups
                  mountPath: /backups
          volumes:
            - name: backups
              persistentVolumeClaim:
                claimName: postgres-backups
          restartPolicy: OnFailure
```

### Manual Backup

```bash
# Create backup
kubectl exec -it statefulset/postgres -n cloudtolocalllm -- \
  pg_dump -U appuser cloudtolocalllm > backup-$(date +%Y%m%d).sql

# Compress backup
gzip backup-$(date +%Y%m%d).sql
```

### Restore from Backup

```bash
# Decompress backup
gunzip backup-20251116.sql.gz

# Restore database
kubectl exec -i statefulset/postgres -n cloudtolocalllm -- \
  psql -U appuser cloudtolocalllm < backup-20251116.sql
```

## Performance Optimization

### Indexes

Ensure proper indexes are created:

```sql
-- User lookups
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_auth0_id ON users(auth0_id);

-- Subscription queries
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_tier ON subscriptions(tier);

-- Payment transaction queries
CREATE INDEX idx_payment_transactions_user_id ON payment_transactions(user_id);
CREATE INDEX idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX idx_payment_transactions_created_at ON payment_transactions(created_at DESC);

-- Audit log queries
CREATE INDEX idx_admin_audit_logs_admin_user_id ON admin_audit_logs(admin_user_id);
CREATE INDEX idx_admin_audit_logs_created_at ON admin_audit_logs(created_at DESC);
```

### Query Optimization

Use EXPLAIN ANALYZE to optimize slow queries:

```sql
-- Analyze query performance
EXPLAIN ANALYZE
SELECT * FROM payment_transactions
WHERE user_id = 'user-uuid'
ORDER BY created_at DESC
LIMIT 50;
```

### Vacuum and Analyze

Regular maintenance:

```sql
-- Vacuum database
VACUUM ANALYZE;

-- Vacuum specific table
VACUUM ANALYZE payment_transactions;

-- Auto-vacuum settings
ALTER SYSTEM SET autovacuum = on;
ALTER SYSTEM SET autovacuum_naptime = '1min';
```

## Monitoring

### Database Metrics

Monitor these metrics:

- **Connection count**: Active vs idle connections
- **Query performance**: Slow queries, query duration
- **Table sizes**: Disk usage per table
- **Index usage**: Index hit rate
- **Replication lag**: If using replication

### Prometheus Metrics

Expose PostgreSQL metrics:

```yaml
# Install postgres_exporter
kubectl apply -f https://raw.githubusercontent.com/prometheus-community/postgres_exporter/master/postgres_exporter.yaml
```

### Grafana Dashboard

Import PostgreSQL dashboard:

1. Go to Grafana
2. Import dashboard ID: 9628 (PostgreSQL Database)
3. Select Prometheus datasource
4. View metrics

## Troubleshooting

### Connection Issues

**Issue: "Connection refused"**

```bash
# Check if PostgreSQL is running
kubectl get pods -n cloudtolocalllm | grep postgres

# Check PostgreSQL logs
kubectl logs statefulset/postgres -n cloudtolocalllm

# Test connection from API pod
kubectl exec -it deployment/api-backend -n cloudtolocalllm -- \
  psql -h postgres.cloudtolocalllm.svc.cluster.local -U appuser -d cloudtolocalllm
```

**Issue: "Too many connections"**

```sql
-- Check current connections
SELECT count(*) FROM pg_stat_activity;

-- Check max connections
SHOW max_connections;

-- Increase max connections
ALTER SYSTEM SET max_connections = 200;
SELECT pg_reload_conf();
```

**Issue: "SSL connection required"**

```bash
# Check SSL mode
kubectl get configmap cloudtolocalllm-config -n cloudtolocalllm -o yaml | grep DB_SSL

# Verify SSL is enabled in PostgreSQL
kubectl exec -it statefulset/postgres -n cloudtolocalllm -- \
  psql -U appuser -d cloudtolocalllm -c "SHOW ssl;"
```

### Performance Issues

**Issue: Slow queries**

```sql
-- Find slow queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC;

-- Kill slow query
SELECT pg_terminate_backend(pid);
```

**Issue: High disk usage**

```sql
-- Check table sizes
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Vacuum to reclaim space
VACUUM FULL;
```

## Security Best Practices

### 1. Strong Passwords

- Use strong passwords (16+ characters)
- Rotate passwords every 90 days
- Never commit passwords to version control

### 2. Least Privilege

```sql
-- Create read-only user for reporting
CREATE USER readonly_user WITH PASSWORD 'strong_password';
GRANT CONNECT ON DATABASE cloudtolocalllm TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;

-- Revoke unnecessary privileges
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
```

### 3. Network Security

- Use SSL/TLS for all connections
- Restrict database access to cluster only
- Use network policies to limit access

### 4. Audit Logging

```sql
-- Enable query logging
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_duration = on;
SELECT pg_reload_conf();
```

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [node-postgres Documentation](https://node-postgres.com/)
- [PostgreSQL SSL Documentation](https://www.postgresql.org/docs/current/ssl-tcp.html)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
