# ArgoCD Stabilization Plan

## 1. Audit Current State
**Status**: 🔴 Critical System Failure
**Findings**:
- **ArgoCD**: Operational.
- **Managed Apps**: Widespread failure (`api-backend`, `web-frontend`, `monitoring`, `postgres`).
- **Root Cause**: Invalid `cloudtolocalllm-secrets` in `cloudtolocalllm` namespace.
    - Missing Key: `postgres-auth-password` (blocking Postgres).
    - Missing Key: `admin-password` (blocking Grafana).
    - Probable Missing Keys: `auth0-client-secret`, `stripe-secret-key` (blocking API).
- **Symptoms**: `CreateContainerConfigError`, `Init:0/2`.

## 2. Identify Failure Points
- **Secret Management**: Current secret generation process is manual or flawed, leading to incomplete secrets.
- **Dependency Chain**: 
    - Secrets -> Postgres -> API Backend -> Web Frontend.
    - Failure at the bottom (Secrets) cascades up.
- **Observability**: Monitoring (Grafana) is self-hosted and dependent on the same failing secrets, causing a "blind spot" during outages.

## 3. Implement Monitoring
*Immediate Actions:*
- **Fix Grafana**: Restore `admin-password` to bring up dashboards.
- **External Alerting**: Implement a simple external checker (e.g., cron job or uptime robot) that does not depend on the cluster's internal state.

*Long-term:*
- **Prometheus Rules**: Add alerts for `CreateContainerConfigError` and `ImagePullBackOff`.
- **ArgoCD Alerts**: Alert on "Degraded" status persisting > 15m.

## 4. Refactor Manifests
- **Validation**: Add schema validation for Secrets to ensure all required keys are present before application.
- **Decoupling**: Move Monitoring (Grafana/Prometheus) to a separate secret or namespace to prevent "blindness" when application secrets fail.
- **Resilience**: Update `api-backend` to handle missing DB connections more gracefully (retry logic instead of crash loop).

## 5. Enhance Rollback
- **Secret Versioning**: Implement External Secrets Operator (Azure KeyVault) or Sealed Secrets to manage secrets as code. This allows rolling back configuration changes via Git.
- **ArgoCD Sync Policy**: Enable `selfHeal` and `prune` for critical infrastructure components to prevent drift.

## 6. Test Disaster Recovery
- **Scenario**: "Total Secret Loss".
- **Action**: Create a script to regenerate valid `cloudtolocalllm-secrets` from a secure vault (e.g., Azure KeyVault or a local `.env` backup).
- **Verification**: Run this script against the current broken state to verify recovery.

## 7. Document Procedures
- **Runbook**: "Restoring Application Secrets".
- **Guide**: "Bootstrapping the Cluster from Scratch" (ensuring secrets are created *before* apps).

---

## Execution - Phase 1: Fix Secrets (Immediate)
1.  **Retrieve Values**: Fetch correct passwords from Azure KeyVault or local `.env`.
2.  **Patch Secret**: Re-create `cloudtolocalllm-secrets` with ALL required keys.
    ```bash
    kubectl create secret generic cloudtolocalllm-secrets \
      --from-literal=postgres-auth-password=<VALUE> \
      --from-literal=admin-password=<VALUE> \
      ... \
      --dry-run=client -o yaml | kubectl apply -f -    
    ```
3.  **Restart Pods**: Delete failing pods to pick up the new secret.

## Execution - Phase 2: Verify & Monitor
1.  Check `postgres-auth-0` comes up.
2.  Check `api-backend` connects to DB.
3.  Check `grafana` starts.
