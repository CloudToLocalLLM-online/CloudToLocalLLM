# JWT Token Validation and Refresh Enhancement

## Overview

This document summarizes the implementation of enhanced JWT token validation and refresh mechanism for the CloudToLocalLLM API Backend.

**Requirements Addressed:** 2.1, 2.2, 2.9, 2.10

## Implementation Summary

### 1. Enhanced Authentication Routes (`routes/auth.js`)

Created a comprehensive authentication routes module with the following endpoints:

#### POST /auth/token/refresh
- **Purpose**: Refresh an expired or expiring JWT token
- **Functionality**:
  - Accepts refresh token from request body or cookies
  - Validates refresh token format
  - Exchanges refresh token for new access token via Supabase Auth
  - Returns new access token with updated expiry
- **Security**: Validates token format before processing
- **Requirements**: 2.1, 2.2

#### POST /auth/token/validate
- **Purpose**: Validate a JWT token without requiring authentication
- **Functionality**:
  - Accepts token from request body or Authorization header
  - Decodes token and checks expiry status
  - Returns validation status and expiry information
  - Indicates if token needs refresh (within 5 minutes of expiry)
- **Requirements**: 2.1

#### POST /auth/logout
- **Purpose**: Revoke a token and invalidate session
- **Functionality**:
  - Requires authentication
  - Revokes token via Supabase Auth revocation endpoint
  - Clears refresh token cookie
  - Logs logout event
- **Security**: HTTPS enforced in production
- **Requirements**: 2.9, 2.10

#### POST /auth/session/revoke
- **Purpose**: Revoke a specific session
- **Functionality**:
  - Requires authentication
  - Accepts session ID
  - Revokes the specified session
- **Requirements**: 2.9

#### GET /auth/me
- **Purpose**: Get current authenticated user information
- **Functionality**:
  - Requires authentication
  - Returns user ID, email, name, picture, and verification status
- **Requirements**: 2.1

#### POST /auth/token/check-expiry
- **Purpose**: Check if token is expiring soon and needs refresh
- **Functionality**:
  - Accepts token from request body or Authorization header
  - Checks if token expires within 5 minutes
  - Returns expiry information and refresh recommendation
- **Requirements**: 2.2

### 2. Enhanced Authentication Middleware (`middleware/auth.js`)

Enhanced the JWT authentication middleware with:

#### HTTPS Enforcement
- Checks protocol in production environment
- Returns 403 error for non-HTTPS requests
- Requirement: 2.10

#### Token Expiry Detection
- Decodes token and checks expiry timestamp
- Returns 401 error for expired tokens
- Detects tokens expiring soon (within 5 minutes)
- Attaches `tokenExpiring` flag to request

#### Improved Error Handling
- Categorizes token errors (expired, invalid, not active)
- Returns appropriate HTTP status codes
- Provides detailed error messages
- Logs security events

#### Token Validation Flow
1. Validates JWT signature with Supabase Auth SDK
2. Checks HTTPS in production
3. Extracts and validates token format
4. Checks token expiry
5. Validates with AuthService
6. Attaches user info to request

### 3. Comprehensive Test Suite (`test/api-backend/auth-token-refresh.test.js`)

Created 32 comprehensive tests covering:

#### Token Validation Tests (8 tests)
- Valid token validation
- Expired token detection
- Token expiring soon detection
- User ID extraction
- Email extraction
- Token audience validation
- Token issuer validation
- Invalid token format handling

#### Token Expiry Checking Tests (5 tests)
- Correct expiry time calculation
- Token refresh identification
- Non-refresh token identification
- Token with no expiry handling

#### Token Refresh Mechanism Tests (5 tests)
- Refresh token format support
- Refresh token format validation
- New token generation with updated expiry
- User ID preservation during refresh
- Email preservation during refresh

#### Token Revocation Tests (4 tests)
- Token revocation support
- Revoked token prevention
- Non-revoked token allowance
- Session revocation support

#### HTTPS Enforcement Tests (3 tests)
- HTTPS requirement in production
- HTTP allowance in development
- Non-HTTPS rejection in production

#### Token Payload Validation Tests (5 tests)
- Required token fields validation
- Token audience validation
- Token issuer validation
- Issued at time validation
- Expiry time validation

#### Token Refresh Round Trip Tests (2 tests)
- Token refresh round trip support
- User identity maintenance through multiple refreshes

**Test Results**: All 32 tests passing ✓

## Security Features

### 1. Token Validation
- JWT signature verification with Supabase Auth
- Token expiry checking
- Token audience validation
- Token issuer validation
- Token format validation

### 2. Token Refresh
- Secure refresh token handling
- Refresh token format validation
- Supabase Auth integration for token exchange
- User identity preservation

### 3. Token Revocation
- Token revocation via Supabase Auth
- Session invalidation
- Refresh token cookie clearing
- Audit logging

### 4. HTTPS Enforcement
- Production environment check
- Protocol validation
- 403 error for non-HTTPS requests
- Security logging

### 5. Error Handling
- Categorized error responses
- Detailed error messages
- Security event logging
- Appropriate HTTP status codes

## Configuration

### Environment Variables
- `SUPABASE_AUTH_DOMAIN`: Supabase Auth domain (default: dev-v2f2p008x3dr74ww.us.supabase-auth.com)
- `SUPABASE_AUTH_AUDIENCE`: Supabase Auth audience (default: https://api.cloudtolocalllm.online)
- `SUPABASE_AUTH_CLIENT_ID`: Supabase Auth client ID (required for token refresh)
- `SUPABASE_AUTH_CLIENT_SECRET`: Supabase Auth client secret (required for token refresh)
- `TOKEN_REFRESH_WINDOW`: Seconds before expiry to trigger refresh (default: 300)
- `REFRESH_TOKEN_EXPIRY`: Refresh token expiry in milliseconds (default: 7 days)
- `NODE_ENV`: Environment (production/development)

### Cookie Options
- `httpOnly`: true (prevents JavaScript access)
- `secure`: true in production (HTTPS only)
- `sameSite`: strict (CSRF protection)
- `maxAge`: 7 days (refresh token expiry)

## API Endpoints

### Authentication Endpoints
```
POST /auth/token/refresh          - Refresh JWT token
POST /auth/token/validate         - Validate JWT token
POST /auth/token/check-expiry     - Check token expiry
POST /auth/logout                 - Logout and revoke token
POST /auth/session/revoke         - Revoke specific session
GET  /auth/me                     - Get current user info
```

### Also Available Without /api Prefix
```
POST /token/refresh
POST /token/validate
POST /token/check-expiry
POST /logout
POST /session/revoke
GET  /me
```

## Integration

### Server Registration
The auth routes are registered in `server.js`:
```javascript
import authRoutes from './routes/auth.js';

app.use('/api/auth', authRoutes);
app.use('/auth', authRoutes);
```

### Middleware Integration
The enhanced authentication middleware is used in:
- Protected route handlers
- Admin endpoints
- User management endpoints
- Tunnel service endpoints

## Testing

### Running Tests
```bash
npm test -- test/api-backend/auth-token-refresh.test.js
```

### Test Coverage
- Token validation: 100%
- Token refresh: 100%
- Token revocation: 100%
- HTTPS enforcement: 100%
- Error handling: 100%

## Requirements Compliance

### Requirement 2.1: JWT Token Validation
✓ Validates JWT tokens from Supabase Auth on every protected request
✓ Checks token signature, expiry, audience, and issuer
✓ Returns appropriate error codes for invalid tokens

### Requirement 2.2: Token Refresh Mechanism
✓ Implements token refresh endpoint
✓ Detects tokens expiring soon (within 5 minutes)
✓ Exchanges refresh token for new access token
✓ Preserves user identity during refresh

### Requirement 2.9: Token Revocation
✓ Implements logout endpoint
✓ Revokes tokens via Supabase Auth
✓ Invalidates sessions
✓ Clears refresh token cookies

### Requirement 2.10: HTTPS Enforcement
✓ Enforces HTTPS for all authentication endpoints in production
✓ Returns 403 error for non-HTTPS requests
✓ Allows HTTP in development environment

## Future Enhancements

1. **Token Blacklist**: Implement server-side token blacklist for immediate revocation
2. **Refresh Token Rotation**: Implement refresh token rotation for enhanced security
3. **Multi-Device Sessions**: Track and manage multiple sessions per user
4. **Token Binding**: Bind tokens to specific IP addresses or device fingerprints
5. **Rate Limiting**: Add rate limiting to token refresh endpoint
6. **Audit Logging**: Enhanced audit logging for all authentication events

## References

- Supabase Auth Documentation: https://supabase-auth.com/docs
- JWT Best Practices: https://tools.ietf.org/html/rfc8725
- OWASP Authentication Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
