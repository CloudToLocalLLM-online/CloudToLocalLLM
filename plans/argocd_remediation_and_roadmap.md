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

## 2. Remediation Strategy (Phase 2)

### 2.1 Standardized RBAC & Security
- **Action**: Enforce least-privilege access using `argocd-rbac-cm.yaml`.
- **Monitoring**: Integration with SSO (Auth0/Entra) as defined in `scripts/setup-entra-auth.sh`.

### 2.2 Application Recovery
- **Immediate Task**: Resolve `api-backend` failures (`Init:CreateContainerConfigError`).
- **GitOps Flow**: Use the `bootstrap` application to re-sync all managed resources from the repository.

---

## 3. Strategic Roadmap for Long-Term Resilience

### 3.1 Robust GitOps Upgrade Path
- **Regression Prevention**: Implement a pre-sync hook that runs `scripts/integration-test-deployments.sh` in a temporary namespace before applying changes to `production`.
- **Version Management**: Automated scanning of `quay.io` and `GitHub` for ArgoCD updates, with automated PRs to the `staging` overlay.

### 3.2 Persistent State & High Availability
- **Redis Migration**: Transition `argocd-redis` from a Deployment to a **StatefulSet** with a Persistent Volume Claim (PVC). This ensures that application state and OIDC tokens are preserved during cluster maintenance.
- **Anti-Affinity**: (Once cluster scale allows) Implement `podAntiAffinity` to ensure ArgoCD components are spread across multiple availability zones.

### 3.3 Automated SSL/TLS handling
- **Cert-Manager Standardization**: Migrate all subdomains to `cert-manager` with DNS-01 challenges (Azure/Cloudflare).
- **Certificate Rotation**: Automated health checks for certificate expiration via `scripts/monitor-nameservers.ps1`.

### 3.4 Proactive Health Monitoring
- **Alerting**: Deploy `argocd-monitoring-alerts.yaml` to the monitoring stack.
- **Availability Probes**: Implement external Blackbox exporter probes specifically for the ArgoCD UI and API endpoints.
- **Automated Remediation**: Enhance `scripts/monitor-argocd.sh` to automatically trigger a `Recreate` rollout if the server detects a path-prefix or redirect loop again.

---

## 4. Implementation Checklist

- [x] Fix Redirect Loop (ArgoCD Server `--insecure`)
- [x] Schedule Pods (Resource Optimization)
- [x] Resolve Component Conflicts (Cleanup RS/Deployments)
- [ ] Implement Redis Persistence (StatefulSet + PVC)
- [ ] Bootstrap All Applications (Sync via Root App)
- [ ] Setup Proactive Alerts (Monitoring Integration)
