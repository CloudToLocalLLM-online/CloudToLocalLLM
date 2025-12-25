# ArgoCD Diagnostic, Remediation, and Strategic Roadmap

## 1. Current Status & Diagnostics (Phase 1 Completed)

### 1.1 Connectivity Analysis
- **Initial State**: `ERR_TOO_MANY_REDIRECTS` at `https://argocd.cloudtolocalllm.online/`.
- **Root Cause**: `argocd-server` was running with default flags (redirecting HTTP to HTTPS internally). Cloudflare Tunnel was connecting over HTTP, causing a redirect loop.
- **Resolution**: Applied optimized configuration with the `--insecure` flag and verified access via Playwright.

### 1.2 Resource State & Scheduling
- **Initial State**: Many pods in `Pending` state due to `Insufficient cpu`.
- **Constraint**: The single-node cluster (4 CPUs) was over-allocated (96% requested).
- **Resolution**:
    - Scaled all ArgoCD components down to **1 replica**.
    - Optimized resource requests: Reduced CPU from `250m-500m` to `10m-50m` per container.
    - Result: All components (`argocd-server`, `argocd-repo-server`, `argocd-application-controller`) are now **1/1 Running**.

### 1.3 Configuration Conflict Cleanup
- **Issue**: Deployment vs StatefulSet conflict for the controller and invalid command flags for repo-server.
- **Resolution**: 
    - Standardized `argocd-application-controller` as a single-replica `StatefulSet`.
    - Fixed binary flags (removed unsupported `--grpc-web-root-path-prefix` and `--timeout`).
    - Standardized on the known working image: `quay.io/argoproj/argocd:v3.2.2`.

---

## 2. Current App Sync Diagnostic (New Findings)

### 2.1 "Infrastructure" OutOfSync Root Cause
- **Issue**: Resource Duplication (SharedResourceWarning).
- **Detail**: The `infrastructure` app and `api-backend` app both include `namespace.yaml` and `network-policies.yaml` in their respective `kustomization.yaml` files.
- **Impact**: Constant synchronization conflict where each app tries to override the other's ownership of the same resources.

### 2.2 "API-Backend" Progressing/Degraded Root Cause
- **Issue**: Missing Secret Keys.
- **Detail**: The `db-migrate` init container fails because it cannot find `supabase-jwt-secret` and `supabase-url` in the `cloudtolocalllm-secrets` Secret.
- **Impact**: Deployment cannot proceed past the initialization phase.

---

## 3. Recommended Synchronization Strategy

### Phase 1: De-duplicate Ownership
1.  Modify `k8s/apps/local/api-backend/shared/base/kustomization.yaml`:
    - Remove `- namespace.yaml`
    - Remove `- network-policies.yaml`
2.  Ensure these remain in `k8s/apps/local/infrastructure/shared/base/infrastructure/kustomization.yaml`.

### Phase 2: Configuration Correction
1.  Inject missing keys into the Secret:
    ```bash
    kubectl patch secret cloudtolocalllm-secrets -n cloudtolocalllm --type='json' -p='[{"op": "add", "path": "/data/supabase-jwt-secret", "value": "BASE64_ENCODED_VAL"}, {"op": "add", "path": "/data/supabase-url", "value": "BASE64_ENCODED_VAL"}]'
    ```

### Phase 3: Final Reconciliation
1.  **Sync Infrastructure**: `argocd app sync infrastructure`
2.  **Sync API-Backend**: `argocd app sync api-backend`

---

## 4. Strategic Roadmap for Long-Term Resilience

### 4.1 Robust GitOps Upgrade Path
- **Regression Prevention**: Implement a pre-sync hook that runs `scripts/integration-test-deployments.sh` in a temporary namespace before applying changes to `production`.
- **Version Management**: Automated scanning of `quay.io` and `GitHub` for ArgoCD updates, with automated PRs to the `staging` overlay.

### 4.2 Persistent State & High Availability
- **Redis Migration**: Transition `argocd-redis` from a Deployment to a **StatefulSet** with a Persistent Volume Claim (PVC). This ensures that application state and OIDC tokens are preserved during cluster maintenance.
- **Anti-Affinity**: (Once cluster scale allows) Implement `podAntiAffinity` to ensure ArgoCD components are spread across multiple availability zones.

### 4.3 Automated SSL/TLS handling
- **Cert-Manager Standardization**: Migrate all subdomains to `cert-manager` with DNS-01 challenges (Azure/Cloudflare).
- **Certificate Rotation**: Automated health checks for certificate expiration via `scripts/monitor-nameservers.ps1`.

### 4.4 Proactive Health Monitoring
- **Alerting**: Deploy `argocd-monitoring-alerts.yaml` to the monitoring stack.
- **Availability Probes**: Implement external Blackbox exporter probes specifically for the ArgoCD UI and API endpoints.

---

## 5. Implementation Checklist

- [x] Fix Redirect Loop (ArgoCD Server `--insecure`)
- [x] Schedule Pods (Resource Optimization)
- [x] Resolve Component Conflicts (Cleanup RS/Deployments)
- [x] Identify OutOfSync Root Causes (Shared Resources & Missing Secrets)
- [ ] De-duplicate Manifests (Git modification)
- [ ] Patch Cluster Secrets
- [ ] Implement Redis Persistence (StatefulSet + PVC)
- [ ] Setup Proactive Alerts (Monitoring Integration)
