# Authentication Fix Verification Checklist

## Pre-Deployment Verification

### Code Changes
- [x] `web/auth0-bridge.js` - AUTH0_AUDIENCE updated to `https://api.cloudtolocalllm.online`
- [x] `web/service-worker-init.js` - Service worker patch created and optimized
- [x] `web/index.html` - Service worker init script loaded before flutter_bootstrap.js
- [x] Documentation created: `docs/DEVELOPMENT/AUTH0_AUDIENCE_FIX.md`
- [x] Summary created: `AUTHENTICATION_FIX_SUMMARY.md`

### Backend Configuration (No Changes Needed)
- Backend already expects: `https://api.cloudtolocalllm.online`
- Default is set in: `services/api-backend/middleware/auth.js`
- Can be overridden via: `AUTH0_AUDIENCE` environment variable

## Deployment Steps

### Step 1: Build Web App
```bash
flutter build web --release
```

### Step 2: Deploy Web App
Deploy the updated web files to your hosting:
- `web/index.html` (updated)
- `web/auth0-bridge.js` (updated)
- `web/service-worker-init.js` (new)
- All other Flutter web build artifacts

### Step 3: Clear CDN Cache (if applicable)
```bash
# If using Cloudflare
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  --data '{"files":["https://app.cloudtolocalllm.online/*"]}'
```

### Step 4: Verify Deployment
- Navigate to https://app.cloudtolocalllm.online
- Open browser DevTools (F12)
- Go to Console tab
- Look for: `[Auth0 Bridge] Bridge loaded and ready`

## Post-Deployment Testing

### Test 1: Service Worker Loading
**Expected**: No 4000ms timeout warning
```
✓ Service worker loads quickly
✓ No "prepareServiceWorker took more than 4000ms" warning
✓ App initializes normally
```

### Test 2: Login Flow
**Expected**: Successful login with correct audience
```
✓ Click login button
✓ Auth0 login page appears
✓ Complete authentication
✓ Redirected back to app
✓ App shows authenticated state
```

### Test 3: API Calls
**Expected**: All API calls succeed with 200/201 status

#### Check in Browser DevTools Network Tab:

1. **POST /auth/sessions**
   - Status: 200 or 201 ✓
   - Authorization header: `Bearer <token>` ✓
   - Response: Session created ✓

2. **GET /user/tier**
   - Status: 200 ✓
   - Authorization header: `Bearer <token>` ✓
   - Response: User tier data ✓

3. **GET /ollama/bridge/status**
   - Status: 200 ✓
   - Authorization header: `Bearer <token>` ✓
   - Response: Bridge status ✓

4. **PUT /conversations/{id}**
   - Status: 200 ✓
   - Authorization header: `Bearer <token>` ✓
   - Response: Updated conversation ✓

### Test 4: Token Validation
**Expected**: Backend accepts token with correct audience

Check backend logs for:
```
[Auth] Token verification successful (Audience verified)
[Auth] User authenticated via RS256: <user_id>
```

### Test 5: Error Handling
**Expected**: Proper error messages if something fails

Test scenarios:
- [ ] Logout and login again → Should work
- [ ] Clear browser cache and login → Should work
- [ ] Open app in incognito/private window → Should work
- [ ] Try accessing protected routes without login → Should redirect to login

## Rollback Procedure

If issues occur:

### Option 1: Quick Rollback (within 24 hours)
```bash
# Revert to previous version
git revert <commit_hash>
flutter build web --release
# Deploy previous version
```

### Option 2: Full Rollback
1. Revert `web/auth0-bridge.js` to previous version
2. Clear Cloudflare cache
3. Notify users to clear browser cache
4. Users re-login to get new tokens

## Monitoring After Deployment

### Backend Logs
Monitor for:
- ✓ Successful token validations
- ✓ No audience mismatch errors
- ✓ No 401 errors on API calls

### Frontend Logs
Monitor for:
- ✓ Auth0 bridge initialization
- ✓ Successful login flow
- ✓ API calls with Authorization headers

### User Reports
- ✓ No login issues
- ✓ No API errors
- ✓ App loads quickly

## Success Criteria

All of the following must be true:

1. ✓ Service worker loads without timeout warning
2. ✓ Login completes successfully
3. ✓ App loads after authentication
4. ✓ All API calls return 200/201 (not 401)
5. ✓ Authorization headers are present in requests
6. ✓ Backend logs show successful token validation
7. ✓ No audience mismatch errors in logs
8. ✓ Users can perform all app functions

## Troubleshooting

### Issue: Still Getting 401 Errors

**Possible Causes**:
1. Browser cache not cleared
2. Old token still in use
3. Backend environment variable not set

**Solutions**:
```bash
# 1. Clear browser cache
# In browser: DevTools → Application → Clear site data

# 2. Verify backend environment
echo $AUTH0_AUDIENCE  # Should output: https://api.cloudtolocalllm.online

# 3. Check backend logs
kubectl logs -f deployment/api-backend | grep "Token verification"
```

### Issue: Service Worker Still Timing Out

**Possible Causes**:
1. Old service worker still cached
2. service-worker-init.js not loading

**Solutions**:
```bash
# 1. Clear service worker cache
# In browser: DevTools → Application → Service Workers → Unregister

# 2. Verify service-worker-init.js is loaded
# In browser: DevTools → Network → Filter by "service-worker-init.js"

# 3. Check browser console for errors
# In browser: DevTools → Console → Look for errors
```

### Issue: Auth0 Token Has Wrong Audience

**Possible Causes**:
1. Auth0 application not configured correctly
2. Frontend still using old audience

**Solutions**:
1. Verify Auth0 application identifier in Auth0 dashboard
2. Verify `web/auth0-bridge.js` has correct audience
3. Clear browser cache and re-login

## Sign-Off

- [ ] All tests passed
- [ ] No errors in logs
- [ ] Users can login and use app
- [ ] Ready for production

**Deployed by**: _______________
**Date**: _______________
**Version**: _______________
