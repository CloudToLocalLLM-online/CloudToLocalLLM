# Auth0 Migration and Re-initialization Plan (Zero-Hardcode Policy)

This document outlines the steps to migrate the CloudToLocalLLM project to a new Auth0 tenant while strictly enforcing a **Zero-Hardcode Policy**. No sensitive configuration (Tenant Domains, Client IDs, or Secrets) shall remain in the source code as fallback values.

## 1. Hardcoded Dependency Audit

The following files contain hardcoded defaults or direct references to the defunct tenant:

- **Backend:**
    - `services/api-backend/middleware/auth.js`: Hardcoded `AUTH0_DOMAIN`.
    - `services/streaming-proxy/src/middleware/auth-config.ts`: Hardcoded `jwksUri` and default `AUTH0_DOMAIN`.
- **Frontend (Flutter):**
    - `lib/auth/providers/auth0_auth_provider.dart`: Hardcoded `defaultValue` for `AUTH0_DOMAIN` and `AUTH0_CLIENT_ID`.
    - `lib/auth/providers/windows_oauth_provider.dart`: Hardcoded `defaultValue` and a custom redirect URL scheme.
- **Infrastructure:**
    - `k8s/apps/local/*/configmap-patch.yaml`: Multiple environment-specific patches for development, staging, and production.
    - `docker-compose.yml`: Hardcoded environment variables.
- **Documentation:**
    - Numerous guides in `docs/` and `.kiro/` referencing the old tenant.

## 2. Auth0 CLI Re-initialization Sequence

Assume the Auth0 CLI is located at `./.config/bin/auth0`.

### A. Authenticate with the New Tenant
```bash
./.config/bin/auth0 login
```

### B. Create a New Single Page Application (SPA)
```bash
./.config/bin/auth0 apps create \
  --name "CloudToLocalLLM-Web" \
  --type "spa" \
  --auth-method "none" \
  --callbacks "http://localhost:3000/callback, https://app.cloudtolocalllm.online/callback" \
  --logout-urls "http://localhost:3000, https://app.cloudtolocalllm.online" \
  --origins "http://localhost:3000, https://app.cloudtolocalllm.online"
```

### C. Create the Project API (Resource Server)
```bash
./.config/bin/auth0 apis create \
  --name "CloudToLocalLLM-API" \
  --identifier "https://api.cloudtolocalllm.online" \
  --offline-access
```

### D. Define Required Scopes
```bash
./.config/bin/auth0 apis scopes update https://api.cloudtolocalllm.online \
  --scopes "openid,profile,email,offline_access"
```

## 3. Updated File Templates

### .env.auth0 (Proposed Content)
```bash
AUTH0_DOMAIN=new-tenant.us.auth0.com
AUTH0_CLIENT_ID=new_client_id_from_step_2B
AUTH0_CLIENT_SECRET=new_client_secret_if_needed
AUTH0_ISSUER_URL=https://new-tenant.us.auth0.com/
AUTH0_AUDIENCE=https://api.cloudtolocalllm.online
```

### env.template (Updated to include Auth0)
```bash
# Auth0 Configuration
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_AUDIENCE=https://api.cloudtolocalllm.online
```

## 4. Debugging & Verification Checklist

- [ ] **SDK Initialization:** Verify `createAuth0Client` in the frontend receives the new `domain` and `client_id`.
- [ ] **Network Inspector:** Check the `/authorize` request URL. It should point to `https://new-tenant.us.auth0.com/authorize`.
- [ ] **Audience Check:** Ensure the `audience` parameter in the login request matches the API Identifier created in step 2C.
- [ ] **Callback Handling:** Verify the browser redirects to `http://localhost:3000/callback` and that the URL contains a `code` or `error` parameter.
- [ ] **Session Persistence:** Check if `auth0.getUser()` returns user data after a page refresh. Verify that the `auth0` cookie is present and has `Secure; SameSite=None`.
- [ ] **Token Validation:** Decode the JWT in the backend. Verify the `iss` (issuer) and `aud` (audience) claims match the new tenant.
- [ ] **ArgoCD Sync:** Verify that the ArgoCD application is healthy and synchronized. Check that the ConfigMaps and Secrets in the cluster have the correct injected values.

## 5. ArgoCD Deployment Strategy

To deploy these changes securely via ArgoCD:

1.  **Secret Injection:** Use a secret management solution (e.g., AWS Secrets Manager, HashiCorp Vault, or SealedSecrets) to store the real Auth0 credentials.
2.  **ConfigMap Template:** Ensure Kustomize or Helm is configured to inject environment variables into the placeholders (`${AUTH0_DOMAIN}`, etc.) during the deployment phase.
3.  **Sync Policy:** Set the ArgoCD sync policy to `Automated` with `Prune` and `SelfHeal` enabled to ensure the cluster state always matches the repository's sanitized templates.
4.  **Verification:** Use the ArgoCD UI or `argocd app get cloudtolocalllm` to verify that all resources are in a `Synced` state.

## 6. Implementation Roadmap (Strict Enforcement)

1.  **Switch to Code Mode:** To apply the necessary file changes.
2.  **Update Environment Files:**
    - Populate `.env.auth0` with new values.
    - Update `env.template` to include placeholders for ALL required Auth0 variables.
3.  **Refactor Backend (Zero-Fallback):**
    - `services/api-backend/middleware/auth.js`: Remove hardcoded domain/audience fallbacks; throw error if missing.
    - `services/streaming-proxy/src/middleware/auth-config.ts`: Remove hardcoded `jwksUri` and domain; use strict environment injection.
4.  **Refactor Frontend (Environment-Only):**
    - `lib/auth/providers/auth0_auth_provider.dart`: Remove `defaultValue` for all Auth0 constants.
    - `lib/auth/providers/windows_oauth_provider.dart`: Remove all hardcoded fallbacks and tenant-specific URL schemes.
5.  **Refactor Infrastructure (Template-Based):**
    - `k8s/`: Replace hardcoded values in ConfigMap patches with placeholders that must be populated via CI/CD (GitHub Secrets).
6.  **Update and Execute Setup Script:**
    - Refactor `scripts/setup-auth0-auth.sh` to require all inputs (no hidden defaults) and ensure it validates the presence of required tools (gh, auth0).
7.  **Final Sanitization:**
    - Perform a global regex scan to ensure `dev-v2f2p008x3dr74ww` and `FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A` are completely removed from the non-documentation codebase.
