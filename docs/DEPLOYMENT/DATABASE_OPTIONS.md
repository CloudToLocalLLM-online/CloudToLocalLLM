# Database Options for CloudToLocalLLM

This document explains how to use a SQL database in two scenarios:
- Cloud Run with Google Cloud SQL (managed Postgres, private IP only)
- Self-hosted/local with Docker Compose Postgres

## 1) Cloud Run with Cloud SQL (Postgres)

### Architecture
- Cloud Run services (api, web, streaming)
- Cloud SQL Postgres instance
- Private connection via Serverless VPC Access (recommended) or public with IAM DB Auth (not covered here)

### Prerequisites
- Google Cloud project with billing
- Roles (for CI deployer and runtime SA):
  - CI/deployer: roles/run.admin, roles/artifactregistry.writer, roles/iam.serviceAccountUser, roles/cloudsql.admin (for provisioning), roles/compute.networkAdmin (for VPC connector)
  - Runtime SA (cloudtolocalllm-runner@...): roles/run.invoker, roles/cloudsql.client, roles/logging.logWriter, roles/monitoring.metricWriter

### Provisioning Steps (high level)
1. Enable APIs: sqladmin.googleapis.com, vpcaccess.googleapis.com
2. Create Cloud SQL Postgres instance (db-custom-1-3840 or similar)
3. Create a database and user: cloudtolocalllm / cloudtolocalllm
4. Create a Serverless VPC Access connector
5. Configure Cloud Run services with:
   - --add-cloudsql-instances=<INSTANCE_CONNECTION_NAME>
   - --vpc-connector=<CONNECTOR_NAME>
   - --set-env-vars="DB_TYPE=postgres,DB_HOST=/cloudsql/<INSTANCE_CONNECTION_NAME>,DB_NAME=cloudtolocalllm,DB_USER=cloudtolocalllm,DB_SSL=true"
   - --set-secrets="DB_PASSWORD=db-password:latest"

### Application Configuration
- API backend should detect DB_TYPE=postgres and use pg Pool instead of SQLite.
- Migrations should run against Postgres (e.g., via node-postgres).

### CI/CD Integration
- Add secret DB_PASSWORD (Secret Manager) and bind it in deploy step.
- Add GOOGLE_CLOUD_CREDENTIALS, GCP_PROJECT_ID, GCP_REGION to GitHub Secrets.
- Update deployment scripts to pass Cloud SQL flags/env to `gcloud run deploy`.

## 2) Self-hosted/Local (Docker Compose Postgres)

### Quick Start
- `docker compose -f docker-compose.db.yml up -d`
- Postgres runs on localhost:5432 with db/user cloudtolocalllm, password changeme.
- Set env for API backend:
  - DB_TYPE=postgres
  - DB_HOST=localhost
  - DB_PORT=5432
  - DB_NAME=cloudtolocalllm
  - DB_USER=cloudtolocalllm
  - DB_PASSWORD=changeme
  - DB_SSL=false

### Development Workflow
- Start DB via compose
- Run API with Postgres env
- Execute migrations (see below)

## Migration Strategy

### Current State
- migrations/database/migrate.js implements SQLite migrations and references a `pool` for Postgres that is not yet wired.

### Plan
1. Introduce a DB abstraction in the API backend (e.g., DatabaseClient) that supports drivers: sqlite, postgres.
2. For Postgres:
   - Use `pg` and Pool
   - Implement table creation/migrations: reuse migration SQL with parameterization where needed
   - Store migrations in a `schema_migrations` table (same shape as SQLite)
3. Bootstrapping:
   - Detect DB_TYPE and initialize driver accordingly
   - If Postgres: connect via host/port or Cloud SQL Unix socket at /cloudsql/<INSTANCE>
4. CLI:
   - `node services/api-backend/database/migrate.js init|validate|status|stats` should operate on the active DB driver

## Deployment Changes

### Cloud Run Deployment Flags (API Service)
- Add to `gcloud run deploy cloudtolocalllm-api`:
  - `--add-cloudsql-instances=$INSTANCE_CONNECTION`
  - `--vpc-connector=$VPC_CONNECTOR` (same region as Cloud Run)
  - `--set-env-vars="DB_TYPE=postgres,DB_HOST=/cloudsql/$INSTANCE_CONNECTION,DB_PORT=5432,DB_NAME=cloudtolocalllm,DB_USER=cloudtolocalllm,DB_SSL=true"`
  - `--set-secrets="DB_PASSWORD=db-password:latest"`
- Ensure Cloud SQL instance is created with `--no-assign-ip` and a VPC connector is configured.

### Local Development
- Use docker-compose.db.yml and set env as above.

## Security Considerations
- Store DB_PASSWORD in Secret Manager for Cloud Run; avoid committing credentials.
- Limit DB user permissions to least privilege.
- For Cloud SQL: prefer private IP and VPC connector; if public, restrict via authorized networks.

## Next Steps Checklist
- [ ] Add Postgres driver and pool usage in API backend
- [ ] Implement DB adapter with SQLite and Postgres
- [ ] Parameterize migrations for Postgres
- [ ] Update cloudrun-deploy workflow to optionally pass Cloud SQL flags
- [ ] Extend config/cloudrun/setup-environment.sh to create db-password secret
- [ ] Validate on staging

