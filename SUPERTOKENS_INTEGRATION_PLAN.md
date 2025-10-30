# SuperTokens Integration Plan

## 🎯 Overview

Replace Auth0 with self-hosted SuperTokens for CloudToLocalLLM authentication.

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  cloudtolocalllm.online                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │  Web App (Flutter)│        │  Desktop App     │         │
│  │  app.*           │        │  (Windows)       │         │
│  └────────┬─────────┘         └─────────┬────────┘         │
│           │                             │                   │
│           │ SuperTokens SDK             │ JWT Auth          │
│           ▼                             ▼                   │
│  ┌─────────────────────────────────────────────┐           │
│  │         API Backend (Node.js)                │           │
│  │  • SuperTokens SDK                           │           │
│  │  • Session verification                      │           │
│  │  • Tunnel authentication                     │           │
│  │  api.cloudtolocalllm.online                  │           │
│  └────────────┬────────────────────────────────┘           │
│               │                                              │
│               ▼                                              │
│  ┌──────────────────────────────────┐                      │
│  │  SuperTokens Core                │                      │
│  │  • User management               │                      │
│  │  • Session management            │                      │
│  │  • Token generation              │                      │
│  │  auth.cloudtolocalllm.online     │                      │
│  └────────────┬─────────────────────┘                      │
│               │                                              │
│               ▼                                              │
│  ┌──────────────────────────────────┐                      │
│  │      PostgreSQL                  │                      │
│  │  • Users table                   │                      │
│  │  • Sessions table                │                      │
│  │  • Application data              │                      │
│  └──────────────────────────────────┘                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Implementation Tasks

### Phase 1: Deploy SuperTokens Core

**Issue #1: Deploy SuperTokens to Kubernetes**

**Steps:**
1. Create SuperTokens deployment manifest
2. Configure PostgreSQL connection
3. Set up auth.cloudtolocalllm.online ingress
4. Deploy and verify

**Files to create:**
- `k8s/supertokens-deployment.yaml`
- `k8s/supertokens-service.yaml`
- Update `k8s/ingress-nginx.yaml`

**Resources:**
- CPU: 500m, Memory: 1Gi
- Replicas: 2 (HA)
- PostgreSQL database: Use existing cluster

---

### Phase 2: Integrate API Backend

**Issue #2: Add SuperTokens to Node.js API**

**Steps:**
1. Install SuperTokens Node.js SDK
2. Initialize SuperTokens in `server.js`
3. Replace Auth0 middleware with SuperTokens
4. Update authentication routes
5. Configure session management

**Changes:**
- `services/api-backend/package.json` - Add `supertokens-node`
- `services/api-backend/server.js` - Initialize SuperTokens
- `services/api-backend/middleware/auth.js` - Replace Auth0
- New: `services/api-backend/config/supertokens.js`

**SuperTokens Recipes:**
- EmailPassword
- Session
- Dashboard

---

### Phase 3: Update Flutter Web App

**Issue #3: Integrate SuperTokens in Flutter Web**

**Steps:**
1. Add SuperTokens Flutter SDK
2. Create login/signup UI (or use pre-built)
3. Update token storage
4. Replace Auth0 calls with SuperTokens
5. Update auth state management

**Changes:**
- `pubspec.yaml` - Add `supertokens_flutter`
- `lib/services/auth_service.dart` - Replace Auth0
- `lib/screens/login_screen.dart` - New UI
- `lib/config/app_config.dart` - SuperTokens endpoints

---

### Phase 4: Update Desktop App

**Issue #4: Update Windows Desktop Authentication**

**Steps:**
1. Implement SuperTokens session flow
2. Update tunnel authentication
3. Replace Auth0 token handling
4. Test desktop → API → Ollama flow

**Changes:**
- `lib/services/auth_service.dart` - SuperTokens integration
- `lib/services/http_polling_tunnel_client.dart` - New auth flow
- Desktop app config for auth.cloudtolocalllm.online

---

### Phase 5: Remove Auth0

**Issue #5: Clean Up Auth0 Dependencies**

**Steps:**
1. Remove Auth0 environment variables
2. Delete Auth0 code
3. Update documentation
4. Clean up unused packages

**Files to update:**
- Remove `AUTH0_DOMAIN`, `AUTH0_AUDIENCE` from all configs
- Clean up Flutter Auth0 packages
- Update all documentation

---

### Phase 6: DNS & SSL Configuration

**Issue #6: Configure auth.cloudtolocalllm.online**

**Steps:**
1. Add DNS A record for auth subdomain
2. Update ingress for SSL
3. Verify cert-manager creates certificate
4. Test HTTPS access

**DNS Records:**
```
auth.cloudtolocalllm.online  A  <LOAD_BALANCER_IP>
```

---

### Phase 7: End-to-End Testing

**Issue #7: Complete Integration Testing**

**Test Scenarios:**
1. Web app user registration
2. Web app login → Ollama chat
3. Desktop app login → tunnel → Ollama
4. Session refresh
5. Logout
6. Password reset (if implemented)

---

## 📦 SuperTokens Configuration

### Environment Variables

```env
# SuperTokens Core
SUPERTOKENS_CONNECTION_URI=http://supertokens:3567
SUPERTOKENS_API_KEY=lCZy2QVIFheqHKG9PAwsDotUv0Wj8NBX

# PostgreSQL (for SuperTokens)
POSTGRESQL_CONNECTION_URI=postgresql://appuser:DY9MqI76vm2WnyNK0SZJeTkbxEwgho4l@postgres:5432/cloudtolocalllm

# API Configuration
API_DOMAIN=api.cloudtolocalllm.online
WEBSITE_DOMAIN=app.cloudtolocalllm.online
```

### SuperTokens Recipes

```javascript
// services/api-backend/config/supertokens.js
import SuperTokens from "supertokens-node";
import Session from "supertokens-node/recipe/session";
import EmailPassword from "supertokens-node/recipe/emailpassword";
import Dashboard from "supertokens-node/recipe/dashboard";

SuperTokens.init({
  framework: "express",
  supertokens: {
    connectionURI: process.env.SUPERTOKENS_CONNECTION_URI,
    apiKey: process.env.SUPERTOKENS_API_KEY,
  },
  appInfo: {
    appName: "CloudToLocalLLM",
    apiDomain: "https://api.cloudtolocalllm.online",
    websiteDomain: "https://app.cloudtolocalllm.online",
    apiBasePath: "/auth",
    websiteBasePath: "/auth"
  },
  recipeList: [
    EmailPassword.init(),
    Session.init(),
    Dashboard.init()
  ]
});
```

---

## 🔐 Security Features

- ✅ Secure password hashing (bcrypt)
- ✅ JWT access tokens (short-lived)
- ✅ Refresh tokens (long-lived, rotating)
- ✅ Session management
- ✅ CSRF protection
- ✅ Rate limiting
- ✅ Email verification (optional)
- ✅ Password reset (optional)

---

## 📈 Migration Path

### Before (Auth0)
```
User → Auth0 Login → Auth0 Token → API Backend → Ollama
```

### After (SuperTokens)
```
User → SuperTokens UI → SuperTokens Session → API Backend → Ollama
```

---

## 🧪 Testing Checklist

- [ ] SuperTokens core deployed
- [ ] PostgreSQL tables created
- [ ] API backend authentication working
- [ ] Web app login/signup working
- [ ] Desktop app authentication working
- [ ] Tunnel authentication working
- [ ] Session refresh working
- [ ] Logout working
- [ ] SSL certificates valid
- [ ] All Auth0 code removed

---

## 📚 Resources

- **SuperTokens Docs**: https://supertokens.com/docs
- **Node.js Integration**: https://supertokens.com/docs/emailpassword/quick-setup/backend
- **Flutter Integration**: https://supertokens.com/docs/emailpassword/quick-setup/frontend
- **Kubernetes Deployment**: https://supertokens.com/docs/emailpassword/pre-built-ui/setup/core/with-docker
- **GitHub**: https://github.com/supertokens/supertokens-core

---

## ⏱️ Estimated Timeline

- **Phase 1** (SuperTokens Deploy): 1 hour
- **Phase 2** (API Integration): 2 hours
- **Phase 3** (Web App): 2 hours
- **Phase 4** (Desktop App): 2 hours
- **Phase 5** (Cleanup): 1 hour
- **Phase 6** (DNS/SSL): 30 minutes
- **Phase 7** (Testing): 1 hour

**Total**: ~10 hours of implementation

---

## 🎯 Success Criteria

✅ Users can register/login on web app  
✅ Users can login on desktop app  
✅ Desktop app connects to API via tunnel  
✅ Chat with local Ollama works end-to-end  
✅ Sessions persist and refresh automatically  
✅ All Auth0 dependencies removed  
✅ SSL working on auth.cloudtolocalllm.online  
✅ Production ready and documented  

---

**Next**: Create GitHub Issues and start implementation! 🚀

