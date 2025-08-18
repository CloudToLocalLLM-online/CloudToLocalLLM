### Phase 1: Core CI/CD Foundation (Milestone 1)

This phase focuses on establishing the basic CI/CD workflows, including building, deploying, and managing configurations.

1.  **CLO-32: GitHub Actions Workflow Optimization & Fixes:**
    *   Consolidate and optimize existing GitHub Actions workflows.
    *   Implement concurrency groups to prevent deployment conflicts.
    *   Configure caching for dependencies (npm, Flutter).
    *   Standardize the use of GCP project ID and region.

2.  **CLO-33: Cloud Run Deployment Automation:**
    *   Automate the deployment of web, API, and streaming services to Cloud Run.
    *   Utilize Workload Identity Federation (WIF) for secure authentication.
    *   Implement image tagging with `:latest` and git SHA.
    *   Configure environment variables and Cloud SQL integration.

3.  **CLO-35: Environment Config & Secrets Management:**
    *   Standardize the management of environment configurations and secrets.
    *   Utilize GitHub Secrets for non-sensitive variables.
    *   Integrate GCP Secret Manager for sensitive credentials.
    *   Implement a process for rendering runtime configurations without exposing secrets.

4.  **CLO-37: Deployment Validation & Rollback:**
    *   Implement post-deployment health checks for all services.
    *   Define and document a clear rollback strategy.
    *   Create a GitHub Actions job to verify endpoints and store results.

### Phase 2: Testing and Quality Gates (Milestone 2)

This phase focuses on integrating testing and quality checks into the CI/CD pipeline.

5.  **CLO-36: Testing Integration in CI/CD:**
    *   Integrate unit and integration tests for all services.
    *   Upload test summaries as artifacts to GitHub Actions.
    *   Configure the pipeline to run tests before deployment.

6.  **CLO-34: Build Pipeline Improvements (Web/API/Streaming):**
    *   Optimize the build process for all services.
    *   Implement multi-stage Docker builds for smaller images.
    *   Add linting and type-checking steps to the pipeline.

7.  **CLO-44: Playwright E2E Smoke (Web):**
    *   Add end-to-end smoke tests for critical user flows.
    *   Integrate Playwright tests into the CI/CD pipeline.

8.  **CLO-45: k6 Load Smoke for API:**
    *   Add k6-based smoke tests to the CI pipeline.
    *   This will help ensure that the API can handle sudden spikes in traffic.

### Phase 3: Observability and Monitoring

This phase focuses on adding observability and monitoring to the CI/CD pipeline and the deployed services.

9.  **CLO-39: Sentry Integration (Web/API/Streaming):**
    *   Integrate Sentry for error monitoring across all services.
    *   Configure release tracking and environment tagging.

10. **CLO-40: OpenTelemetry Baseline Metrics & Tracing:**
    *   Add OpenTelemetry instrumentation for baseline metrics and tracing.
    *   Export telemetry data to Google Cloud Monitoring.

11. **CLO-41: Cloud Monitoring Dashboards & Alerts:**
    *   Create dashboards in Google Cloud Monitoring to visualize key metrics.
    *   Configure alerts for critical events, such as high error rates or latency.

### Phase 4: Developer Experience and Documentation

This phase focuses on improving the developer experience and documenting the CI/CD pipeline.

12. **CLO-42: ESLint 9 Flat Config & Prettier Standardization:**
    *   Standardize the use of ESLint and Prettier across all Node.js services.
    *   Add a linting step to the CI pipeline to enforce code style.

13. **CLO-46: Pre-commit Hooks for Lint/Test:**
    *   Implement pre-commit hooks to run linting and tests locally.
    *   This will help catch errors before they are pushed to the repository.

14. **CLO-43: Dependabot & Minimal Security Scans:**
    *   Enable Dependabot to automatically update dependencies.
    *   Add a security scan to the CI pipeline to check for vulnerabilities.

15. **CLO-38: CI/CD Documentation:**
    *   Document the CI/CD workflows, including setup, configuration, and troubleshooting.
    *   Create a guide for contributors on how to use the CI/CD pipeline.

### Future Considerations

*   **CLO-53: Investigate Migration from Cloud Run to Kubernetes:**
    *   This is a research task to evaluate the feasibility of migrating from Cloud Run to Kubernetes. The outcome of this investigation may lead to a separate project.
