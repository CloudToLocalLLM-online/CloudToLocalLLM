---
type: "agent_requested"
description: "CloudToLocalLLM Architecture Rules and Reference"
---

## Purpose
Authoritative reference for the CloudToLocalLLM system architecture. These rules guide design, integration, configuration, and deployment across components so the system remains secure, observable, and operable.

## System Overview
- Frontend: Flutter Web app served via Nginx on Cloud Run
- Backend API: Node.js/Express on Cloud Run (primary data/API plane)
- Streaming Proxy: Cloud Run service optimized for streaming responses
- Authentication: Google Cloud Identity Platform (GCIP) using Google Identity Services (GIS) on the web; no deprecated google_sign_in plugin for web
- Data Store: Cloud SQL for PostgreSQL in production; SQLite permitted only for local development
- CI/CD: GitHub Actions with Workload Identity Federation (WIF) to GCP
- Secrets: GitHub Actions Secrets and GCP Secret Manager (for runtime values like DB passwords)

## Services and Names
- Web: cloudtolocalllm-web
- API: cloudtolocalllm-api
- Streaming: cloudtolocalllm-streaming
- Project: cloudtolocalllm-468303
- Regions: Prefer us-central1 for runtime services; keep build/push region variables consistent across the workflow. Avoid multi-region drift.

## Authentication and Identity
- GCIP + GIS is the only supported authentication flow on web.
- The GCIP API key must not be hardcoded in the built app. It is injected at runtime via an environment variable GCIP_API_KEY that renders into cloudrun-config.js.
- The web container’s entrypoint renders web/cloudrun-config.template.js to cloudrun-config.js using envsubst with GCIP_API_KEY.
- The Flutter app must resolve the API key on web from window.cloudRunConfig.gcipApiKey first, then optional meta[name="gcip-api-key"], and only finally fall back to AppConfig.gcipApiKey for non-web/local contexts.
- Ensure the GCIP API key meets all platform restrictions:
  - Identity Toolkit API enabled
  - API restrictions include Identity Toolkit API
  - Application restrictions allow https://app.cloudtolocalllm.online/*
- Auth domain and tenant configuration must match GCIP setup; tenant IDs selected explicitly per flow.

## Configuration Contract
- Web service receives:
  - GCIP_API_KEY (required)
  - FIREBASE_PROJECT_ID (optional; aids admin SDK contexts where used)
- API service receives:
  - DB_TYPE=postgresql in production
  - DB_HOST, DB_USER, DB_PASSWORD, DB_NAME
  - CLOUD_SQL_CONNECTION_NAME when using Cloud SQL Connector (/cloudsql/ mount)
  - FIREBASE_PROJECT_ID when Firebase Admin SDK is used server-side
  - LOG_LEVEL, NODE_ENV
- Streaming service receives minimal env (LOG_LEVEL, NODE_ENV) unless otherwise required.

## Database
- Production: Cloud SQL for PostgreSQL instance cloudtolocalllm-db.
- Local development: SQLite is allowed for quick start; do not use SQLite in Cloud Run.
- The API service must initialize the PostgreSQL migrator (DatabaseMigratorPG) when DB_TYPE=postgresql; otherwise it uses SQLite migrator locally.
- Database schema migrations run on boot; /api/db/health must report status and schema validation results.

## Networking and Endpoints
- Primary public web URL: https://app.cloudtolocalllm.online
- API and streaming subdomains (via Cloud Run custom domains) should be configured and referenced in web/cloudrun-config.js.
- CORS and allowed origins must include app.cloudtolocalllm.online and Cloud Run service URLs during rollout.
- Cloud Run services should be public where intended; sensitive admin endpoints must remain protected.

## Security
- Never hardcode secrets or API keys in source. Replace the legacy hardcoded GCIP key with runtime-configured GCIP_API_KEY.
- Lock down GCIP API key with API and application restrictions.
- Cloud Run service accounts:
  - Use dedicated service accounts (e.g., cloudtolocalllm-runner@<project>.iam.gserviceaccount.com)
  - Grant minimum roles: Cloud Run Invoker, Cloud SQL Client (API service), Secret Manager Secret Accessor (as needed).
- Database credentials should be stored in GCP Secret Manager; the GitHub workflow may read and pass them at deploy time.
- Enforce HTTPS across all public endpoints; avoid mixed content.

## Observability and Health
- Web: /health static endpoint (Nginx) returns 200 OK.
- API: /health and /api/db/health. Use structured logging (JSON-friendly) and include correlation IDs when possible.
- Use Cloud Logging and Cloud Run logs for monitoring deployments and runtime issues. Prefer log levels: error, warn, info, debug (default to info in prod).

## Performance and Scaling
- Cloud Run parameters should be tuned per service:
  - Web: memory ~1Gi, cpu=1, concurrency ~80
  - API: memory ~2Gi, cpu=2, concurrency ~100; timeout suitable for long operations; min instances typically 0 unless warm starts required
  - Streaming: tuned for long-lived requests; higher timeout
- Avoid CPU-intensive operations in the web container; push compute to API/streaming services.

## CI/CD and Image Build
- GitHub Actions workflow .github/workflows/cloudrun-deploy.yml builds images per service, pushes to Artifact Registry, and deploys with gcloud run deploy.
- Workload Identity Federation (WIF) must be configured with vars.WIF_PROVIDER and vars.WIF_SERVICE_ACCOUNT.
- GCIP_API_KEY must be provided via GitHub Actions secrets and injected into the web service.
- The API service deployment must include Cloud SQL attachment (--add-cloudsql-instances) when using DB_HOST=/cloudsql/...

## Conventions
- Code must not rely on platform-specific plugins that are deprecated for web (e.g., google_sign_in for web). Use GIS directly.
- Keep region, project ID, and naming consistent across config files and workflows.
- Put environment-specific overrides into CI/CD (secrets/vars), not into source files.

## Change Management
- Architectural changes affecting security, auth flows, or data stores must be reviewed.
- Any change that alters external contracts (URLs, auth method, env var names) must come with migration notes and CI/CD updates.
