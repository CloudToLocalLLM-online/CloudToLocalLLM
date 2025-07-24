# Auth0 Tenant Migration Fix

## Issue Description

The CloudToLocalLLM application was experiencing an "unauthorized_client: Callback URL mismatch" error because the application was configured to use Auth0 tenant `dev-xafu7oedkd5wlrbo.us.auth0.com` but the Auth0 MCP was connected to tenant `dev-v2f2p008x3dr74ww.us.auth0.com`.

## Root Cause

**Configuration Mismatch**: The application configuration files contained Auth0 settings for the wrong tenant:
- **Application Config**: `dev-xafu7oedkd5wlrbo.us.auth0.com` with client ID `ESfES9tnQ4qGxFlwzXpDuRVXCyk0KF29`
- **Auth0 MCP**: Connected to `dev-v2f2p008x3dr74ww.us.auth0.com` with client ID `FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A`

## Solution Implemented

Updated all configuration files to use the current Auth0 tenant (`dev-v2f2p008x3dr74ww.us.auth0.com`) with the correct client ID (`FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A`).

## Files Modified

### 1. Flutter Application Configuration
- `lib/config/app_config.dart`
- `lib/config/app_config.dart.build-backup`

**Changes**:
```dart
// OLD
static const String auth0Domain = 'dev-xafu7oedkd5wlrbo.us.auth0.com';
static const String auth0ClientId = 'ESfES9tnQ4qGxFlwzXpDuRVXCyk0KF29';

// NEW
static const String auth0Domain = 'dev-v2f2p008x3dr74ww.us.auth0.com';
static const String auth0ClientId = 'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A';
```

### 2. Backend API Configuration
- `api-backend/server.js`
- `api-backend/middleware/auth.js`
- `api-backend/admin-server.js`

**Changes**:
```javascript
// OLD
const AUTH0_DOMAIN = process.env.AUTH0_DOMAIN || 'dev-xafu7oedkd5wlrbo.us.auth0.com';

// NEW
const AUTH0_DOMAIN = process.env.AUTH0_DOMAIN || 'dev-v2f2p008x3dr74ww.us.auth0.com';
```

### 3. Infrastructure Configuration
- `ansible/group_vars/all.yml`

**Changes**:
```yaml
# OLD
security:
  auth0:
    domain: dev-xafu7oedkd5wlrbo.us.auth0.com

# NEW
security:
  auth0:
    domain: dev-v2f2p008x3dr74ww.us.auth0.com
```

### 4. Documentation
- `docs/USER_DOCUMENTATION/FEATURES_GUIDE.md`

**Changes**:
```javascript
// OLD
const auth0Config = {
  domain: 'dev-xafu7oedkd5wlrbo.us.auth0.com',
  clientId: 'ESfES9tnQ4qGxFlwzXpDuRVXCyk0KF29',

// NEW
const auth0Config = {
  domain: 'dev-v2f2p008x3dr74ww.us.auth0.com',
  clientId: 'FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A',
```

## Auth0 Application Configuration Verified

The Auth0 application `FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A` in tenant `dev-v2f2p008x3dr74ww` is properly configured with:

### Callback URLs
- `http://localhost:55064`
- `http://localhost:8080/callback` ✅
- `http://127.0.0.1:8080/callback`
- `https://app.cloudtolocalllm.online/callback`
- `http://localhost:3000/callback`
- `http://127.0.0.1:3000/callback`

### Logout URLs
- `http://localhost:55064`
- `http://localhost:8080`
- `http://127.0.0.1:8080`
- `https://app.cloudtolocalllm.online`
- `http://localhost:3000`
- `http://127.0.0.1:3000`

### Web Origins
- `http://localhost:55064`
- `http://localhost:8080`
- `http://127.0.0.1:8080`
- `https://app.cloudtolocalllm.online`
- `http://localhost:3000`
- `http://127.0.0.1:3000`

### Application Settings
- **Type**: Single Page Application (SPA)
- **Grant Types**: `authorization_code`, `implicit`, `refresh_token`
- **Token Endpoint Auth Method**: `none`
- **OIDC Conformant**: `true`

## Testing

### Verification Steps
1. **Code Analysis**: ✅ `flutter analyze` - No issues found
2. **Configuration Consistency**: ✅ All files updated to use the same tenant
3. **Auth0 Application**: ✅ Callback URLs properly configured

### Manual Testing Required
After deployment, test the authentication flow:

1. **Start the application**:
   ```bash
   flutter run -d windows
   ```

2. **Test authentication**:
   - Navigate to login
   - Verify redirect to `dev-v2f2p008x3dr74ww.us.auth0.com`
   - Complete login process
   - Verify successful callback to `http://localhost:8080/callback`

## Environment Variables

If using environment variables, update them to match the new configuration:

```bash
# Update these environment variables
AUTH0_DOMAIN=dev-v2f2p008x3dr74ww.us.auth0.com
AUTH0_CLIENT_ID=FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A
AUTH0_AUDIENCE=https://app.cloudtolocalllm.online
```

## Expected Results

After this fix:
- ✅ **No more "Callback URL mismatch" errors**
- ✅ **Successful Auth0 authentication flow**
- ✅ **Proper token validation**
- ✅ **Consistent configuration across all components**

## Rollback Plan

If issues occur, revert to the previous configuration:

```dart
// Rollback values
static const String auth0Domain = 'dev-xafu7oedkd5wlrbo.us.auth0.com';
static const String auth0ClientId = 'ESfES9tnQ4qGxFlwzXpDuRVXCyk0KF29';
```

However, this would require reconfiguring the Auth0 MCP to use the original tenant.

## Notes

- The Auth0 MCP connection remains on `dev-v2f2p008x3dr74ww.us.auth0.com`
- All application components now use the same Auth0 tenant
- The callback URL `http://localhost:8080/callback` is properly configured in Auth0
- No additional Auth0 configuration changes are needed
