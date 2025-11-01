# ⚠️ CRITICAL: GitHub Secret AUTH0_AUDIENCE Needs Update

## Problem
The Auth0 audience is still showing `api.cloudtolocalllm.online` instead of `app.cloudtolocalllm.online`.

## Root Cause
The GitHub Actions workflow (`.github/workflows/deploy-doks.yml`) uses `${{ secrets.AUTH0_AUDIENCE }}` to set the Kubernetes secret. If this GitHub secret still has the old value (`https://api.cloudtolocalllm.online`), it will override all our code changes.

## Solution

1. **Go to GitHub Repository Settings:**
   - Navigate to: `https://github.com/imrightguy/CloudToLocalLLM/settings/secrets/actions`

2. **Update the AUTH0_AUDIENCE secret:**
   - Find `AUTH0_AUDIENCE` in the secrets list
   - Click "Update"
   - Change from: `https://api.cloudtolocalllm.online`
   - Change to: `https://app.cloudtolocalllm.online`
   - Save

3. **Redeploy:**
   - After updating the secret, trigger a new deployment
   - The Kubernetes ConfigMap will be updated with the correct value

## Verification

After updating the secret and redeploying:
- Check Kubernetes ConfigMap: `kubectl get configmap cloudtolocalllm-config -n cloudtolocalllm -o yaml`
- Verify `AUTH0_AUDIENCE: "https://app.cloudtolocalllm.online"`
- Check browser console for: `🔧 Initializing Auth0 with audience: https://app.cloudtolocalllm.online`

## Code Changes Already Made ✅
All source code has been updated:
- ✅ `web/index.html` - uses `app.cloudtolocalllm.online`
- ✅ `web/auth0-bridge.js` - uses `app.cloudtolocalllm.online`
- ✅ `lib/config/app_config.dart` - uses `app.cloudtolocalllm.online`
- ✅ `k8s/configmap.yaml` - uses `app.cloudtolocalllm.online`
- ✅ `services/api-backend/server.js` - uses `app.cloudtolocalllm.online`

But the GitHub secret is overriding these values during deployment!

