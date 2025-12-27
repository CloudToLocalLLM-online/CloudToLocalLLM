# SOP: Cloudflare Error 1033 Restoration Protocol
**High-Priority Technical Restoration for CloudToLocalLLM**

## 1. Executive Summary
This Standard Operating Procedure (SOP) defines the restoration workflow for resolving Cloudflare Error 1033 (Argo Tunnel Connection Refused).

### ⚠️ Security Warning: Zero-Cleartext Policy
- **NO HARDCODING:** All sensitive values (`CLOUDFLARE_API_KEY`, `CLOUDFLARE_EMAIL`, `CLOUDFLARE_DOMAIN`) must be injected via environment variables or Kubernetes Secrets.
- **AUDIT TRAIL:** Clear shell history after interactive credential usage (`history -c`).

## 2. DevSecOps Migration: GitHub Secrets
Migrate all sensitive configurations to GitHub repository secrets to enable secure automated restoration.

### 2.1. Required Repository Secrets
| Secret Name | Value Example |
| :--- | :--- |
| `CLOUDFLARE_API_KEY` | `abc12d49...` (Global API Key) |
| `CLOUDFLARE_EMAIL` | `cmaltais@cloudtolocalllm.online` |
| `CLOUDFLARE_DOMAIN` | `cloudtolocalllm.online` |
| `CLOUDFLARE_TUNNEL_ID`| `62da6c19-947b-4bf6-acad-100a73de4e0d` |
| `CLOUDFLARE_TUNNEL_TOKEN`| (Base64 encoded tunnel token) |

### 2.2. Kubernetes Secret Provisioning (via CI/CD)
The deployment pipeline automatically creates the following secrets:
- `cloudflare-api-credentials`: Contains `api-key` and `email`.
- `tunnel-credentials`: Contains `token`.

## 3. Phase 1: Secure Diagnostic Suite
Use the refactored script with zero hardcoded values.
```bash
export CLOUDFLARE_API_KEY="xxx"
export CLOUDFLARE_EMAIL="cmaltais@cloudtolocalllm.online"
export CLOUDFLARE_DOMAIN="cloudtolocalllm.online"
export CLOUDFLARE_TUNNEL_ID="62da6c19-947b-4bf6-acad-100a73de4e0d"

bash scripts/cloudflare-tunnel-diagnostic.sh
```

## 4. Phase 2: DNS Integrity Repair
If diagnostics indicate CNAME misalignment (Error 530), execute the repair script:
```bash
bash scripts/cloudflare-dns-repair.sh
```

## 5. Phase 3: Configuration Audit
Verify `config.yaml` mapping in the `cloudflared-config` ConfigMap. Ensure `service` URLs use full internal cluster DNS.

## 6. Phase 4: CI/CD Pipeline Automation
Trigger the restoration via GitHub CLI:
```bash
gh workflow run "🚀 Build Pipeline" --ref main -f promote=true
```

## 7. Phase 5: Final Verification
```bash
# Verify stack-wide HTTP/2 200 OK
for url in "https://cloudtolocalllm.online/" "https://app.cloudtolocalllm.online/health" "https://argocd.cloudtolocalllm.online/"; do
    curl -I -s --http2 "$url" | grep -E "HTTP/2|server:|CF-Ray:"
done
```

---
**SOP VERSION:** 1.6.0 (SECURE-REFACTOR)
**DATE:** 2025-12-27
**STATUS:** COMPLETED & VERIFIED
