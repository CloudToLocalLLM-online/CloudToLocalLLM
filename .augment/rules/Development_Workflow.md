---
type: "always_apply"
description: "CloudToLocalLLM Development Workflow and Practices"
---

## Principles
- Prefer modern tooling and configurations (e.g., ESLint 9 flat config) for new code; do not revert to legacy patterns unless strictly necessary.
- Separate concerns between local builds and cloud deployments: local PowerShell scripts for desktop builds; GitHub Actions for Cloud Run deployments.
- Preserve existing deployment configurations; add new options as additional choices rather than replacements.

## Branching and PRs
- Default branch: master (repo default). Working branch: main currently used. Confirm target when opening PRs.
- Create feature branches: feature/<short-description>, fix/<short-description>, chore/<short-description>.
- Small, focused PRs. Include a clear description, screenshots/logs for behavioral changes, and a test plan.
- Require at least one review for changes impacting deployment, auth, or security-sensitive areas.

## Commits
- Conventional commits encouraged: feat:, fix:, chore:, docs:, refactor:, test:, ci:.
- Commit early with working increments; avoid large unreviewed dumps.

## Dependency Management
- Always use package managers, never edit package files directly:
  - Node/JS: npm ci/install, pnpm add/remove, yarn add/remove
  - Dart/Flutter: flutter pub add/remove
  - Python: pip/poetry
  - Rust/Go/etc: use native tooling
- Run lockfile updates via the manager; do not hand-edit lockfiles.

## Secrets and Configuration
- Never hardcode secrets/API keys. Use GitHub Actions Secrets and GCP Secret Manager.
- Web GCIP API key must be provided via GCIP_API_KEY secret and injected at runtime (via cloudrun-config.js render). Remove or avoid legacy keys in source.
- Store DB passwords in Secret Manager; fetch in CI and pass as env to Cloud Run.

## Testing
- Write unit tests for critical services and auth flows.
- For code changes, ensure CI runs tests and basic builds.
- When touching authentication, test end-to-end on staging/production Cloud Run: GIS popup → GCIP exchange → secure API calls.

## Docker Best Practices for Flutter Web Apps
- **Use standard COPY pattern**: Copy source from build context, not git clone. This enables Docker layer caching and follows standard practices.
- **Optimize layer caching**: Copy pubspec files first, run `flutter pub get`, then copy rest of source. Dependencies are cached unless pubspec changes.
- **Multi-stage builds**: Build stage with Flutter image, runtime stage with lightweight nginx.
- **No user creation**: Use container's default non-root user. Never create users unless container doesn't provide one.
- **Standard pattern**:
  ```dockerfile
  FROM ghcr.io/cirruslabs/flutter:stable AS builder
  WORKDIR /app
  COPY pubspec.yaml pubspec.lock ./
  RUN flutter pub get
  COPY . .
  RUN flutter build web --release
  
  FROM nginxinc/nginx-unprivileged:alpine
  COPY --from=builder --chown=nginx:nginx /app/build/web /usr/share/nginx/html
  ```
- **Never run Flutter as root**: Use container defaults or explicit USER directive with existing user UID/GID.

## CI/CD
- Primary workflow: .github/workflows/cloudrun-deploy.yml
- Triggers: push to main/master on relevant paths, and manual workflow_dispatch.
- Auth to GCP via WIF: vars.WIF_PROVIDER and vars.WIF_SERVICE_ACCOUNT must be configured in repo/environment.
- Required secrets/vars:
  - secrets.GCIP_API_KEY for web
  - Secret Manager: db-password (created if missing by workflow)
  - vars.GCP_PROJECT_ID (default cloudtolocalllm-468303)
  - vars.GCP_REGION (prefer us-central1 for runtime; ensure consistency)
- Deployment order: build images → setup database (ensure instance exists, user/password, connection) → deploy services → verify health

## Rollback
- Keep :latest tags and commit SHA tags. To rollback, redeploy the previous SHA tag via gcloud or re-run the workflow with the desired ref.

## Code Quality
- Lint and format consistently. Avoid console.log in Node backend; use structured logger. In Flutter, prefer debugPrint with clear prefixes.
- Avoid deprecated APIs (e.g., google_sign_in plugin on web). Use GIS and GCIP endpoints directly.

## Documentation
- Update README/DEPLOYMENT docs and rule files when changing architecture, env var names, or deployment steps.
- Include troubleshooting notes for common issues (e.g., API key restrictions, Cloud SQL connectivity, WIF misconfig).
