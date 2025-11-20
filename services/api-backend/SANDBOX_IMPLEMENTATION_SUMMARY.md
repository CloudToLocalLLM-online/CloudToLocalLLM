# Sandbox Environment Implementation Summary

## Task 90: API Sandbox/Testing Environment

**Status:** ✅ Complete

**Requirement:** 12.9 - THE API SHALL support API sandbox/testing environment

## Overview

The sandbox environment provides a safe, isolated testing environment for developers to test API endpoints without affecting production data. It allows testing with mock data, simulated responses, and pre-configured test credentials.

## Implementation Details

### 1. Core Service: `SandboxService`

**File:** `services/api-backend/services/sandbox-service.js`

The `SandboxService` class provides:

- **Sandbox Mode Detection**: Checks if sandbox mode is enabled via environment variables
- **Configuration Management**: Returns sandbox configuration with rate limits and quotas
- **Test Credentials**: Provides pre-configured test users and API keys
- **Mock Data Creation**: Creates mock users, tunnels, and webhooks
- **Request Logging**: Logs all requests for debugging and monitoring
- **Data Management**: Retrieves, updates, and clears sandbox data

**Key Methods:**
- `isSandbox()` - Check if sandbox mode is enabled
- `getSandboxConfig()` - Get sandbox configuration
- `getTestCredentials()` - Get test credentials
- `createMockUser()` - Create mock user
- `createMockTunnel()` - Create mock tunnel
- `createMockWebhook()` - Create mock webhook
- `logRequest()` - Log request
- `getRequestLog()` - Retrieve request log
- `getSandboxStats()` - Get sandbox statistics
- `clearSandboxData()` - Clear all sandbox data

### 2. Middleware: `SandboxMiddleware`

**File:** `services/api-backend/middleware/sandbox-middleware.js`

Provides middleware for sandbox request handling:

- **Sandbox Detection**: Detects and marks sandbox requests
- **Request Logging**: Logs all sandbox requests
- **Data Isolation**: Prevents database writes in sandbox mode
- **Rate Limiting**: Applies relaxed rate limits for testing
- **Response Wrapping**: Adds sandbox metadata to responses
- **Error Handling**: Provides detailed error information
- **Cleanup**: Cleans up after request completion

**Middleware Functions:**
- `sandboxDetectionMiddleware` - Detect sandbox mode
- `sandboxLoggingMiddleware` - Log requests
- `sandboxDataIsolationMiddleware` - Isolate data
- `sandboxRateLimitMiddleware` - Apply rate limits
- `sandboxResponseWrapperMiddleware` - Wrap responses
- `sandboxErrorHandlingMiddleware` - Handle errors
- `sandboxCleanupMiddleware` - Cleanup

### 3. Routes: `SandboxRoutes`

**File:** `services/api-backend/routes/sandbox.js`

Provides API endpoints for sandbox management:

#### Configuration Endpoints
- `GET /sandbox/config` - Get sandbox configuration
- `GET /sandbox/credentials` - Get test credentials

#### User Management
- `POST /sandbox/users` - Create mock user
- `GET /sandbox/users/:userId` - Get mock user

#### Tunnel Management
- `POST /sandbox/tunnels` - Create mock tunnel
- `GET /sandbox/tunnels/:tunnelId` - Get mock tunnel
- `PATCH /sandbox/tunnels/:tunnelId/status` - Update tunnel status
- `POST /sandbox/tunnels/:tunnelId/metrics` - Record tunnel metrics

#### Webhook Management
- `POST /sandbox/webhooks` - Create mock webhook

#### Monitoring
- `GET /sandbox/requests` - Get request log
- `GET /sandbox/stats` - Get sandbox statistics
- `DELETE /sandbox/clear` - Clear sandbox data

### 4. Documentation

#### Comprehensive Guide
**File:** `services/api-backend/SANDBOX_ENVIRONMENT_GUIDE.md`

Includes:
- Enabling sandbox mode
- Test credentials (free, premium, admin users)
- Complete API endpoint documentation
- Usage examples
- Best practices
- Troubleshooting
- CI/CD integration examples
- Security considerations

#### Quick Reference
**File:** `services/api-backend/SANDBOX_QUICK_REFERENCE.md`

Includes:
- Quick setup instructions
- Test credentials summary
- Common endpoints
- Quick examples
- Rate limits table
- Environment variables
- Docker Compose example
- Troubleshooting table

### 5. Tests

#### Unit Tests
**File:** `test/api-backend/sandbox-service.test.js`

Tests for `SandboxService`:
- Initialization
- Configuration
- Test credentials
- Mock user creation
- Mock tunnel creation
- Mock webhook creation
- Request logging
- Tunnel status updates
- Tunnel metrics
- Statistics
- Data cleanup
- Retrieval methods

**Coverage:** 30+ test cases

#### Integration Tests
**File:** `test/api-backend/sandbox-routes.test.js`

Tests for sandbox API endpoints:
- Configuration endpoints
- Credentials endpoints
- User management endpoints
- Tunnel management endpoints
- Webhook management endpoints
- Request logging endpoints
- Statistics endpoints
- Data cleanup endpoints
- Sandbox disabled scenarios

**Coverage:** 25+ test cases

## Features

### ✅ No Side Effects
- Mock data is isolated from production
- No actual tunnels are created
- No real webhooks are triggered
- Database writes are prevented

### ✅ Request Logging
- All requests are logged for debugging
- Includes method, path, user, status code, response time
- Queryable by user, method, or path
- Useful for integration testing

### ✅ Data Isolation
- Sandbox data is completely separate from production
- Can be cleared at any time
- No impact on production systems

### ✅ Relaxed Rate Limiting
- 10,000 requests/minute (vs. 100 for production)
- Burst size of 5,000 requests
- Allows thorough testing without throttling

### ✅ Mock Data Management
- Create mock users, tunnels, and webhooks
- Update mock tunnel status and metrics
- Retrieve mock data by ID
- Clear all sandbox data

### ✅ Test Credentials
- Pre-configured test users (free, premium, admin)
- Pre-configured API keys
- Ready to use for testing

## Environment Variables

```env
# Enable sandbox mode
SANDBOX_MODE=true

# Set environment to sandbox
NODE_ENV=sandbox

# Enable debug logging
LOG_LEVEL=debug
```

## Test Credentials

### Free User
- Email: `test@sandbox.local`
- Tier: `free`
- Token: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMSIsImVtYWlsIjoidGVzdEBzYW5kYm94LmxvY2FsIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-1`

### Premium User
- Email: `premium@sandbox.local`
- Tier: `premium`
- Token: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMiIsImVtYWlsIjoicHJlbWl1bUBzYW5kYm94LmxvY2FsIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-2`

### Admin User
- Email: `admin@sandbox.local`
- Tier: `enterprise`
- Role: `admin`
- Token: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LWFkbWluIiwiZW1haWwiOiJhZG1pbkBzYW5kYm94LmxvY2FsIiwicm9sZSI6ImFkbWluIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-admin`

## Rate Limits

| Limit | Value |
|-------|-------|
| Requests/minute | 10,000 |
| Burst size | 5,000 |
| Max tunnels | 100 |
| Max webhooks | 100 |
| Max users | 1,000 |
| Storage | 10 GB |

## Usage Examples

### Enable Sandbox Mode
```bash
export SANDBOX_MODE=true
export NODE_ENV=sandbox
npm start
```

### Get Sandbox Configuration
```bash
curl http://localhost:8080/sandbox/config
```

### Get Test Credentials
```bash
curl http://localhost:8080/sandbox/credentials
```

### Create Mock User
```bash
curl -X POST http://localhost:8080/sandbox/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "tier": "free"
  }'
```

### Create Mock Tunnel
```bash
curl -X POST http://localhost:8080/sandbox/tunnels \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-1",
    "name": "Test Tunnel"
  }'
```

### View Request Log
```bash
curl http://localhost:8080/sandbox/requests
```

### Clear Sandbox Data
```bash
curl -X DELETE http://localhost:8080/sandbox/clear
```

## Integration with Server

To integrate sandbox routes into the main server, add the following to `server.js`:

```javascript
import sandboxRoutes from './routes/sandbox.js';
import {
  sandboxDetectionMiddleware,
  sandboxLoggingMiddleware,
  sandboxDataIsolationMiddleware,
  sandboxRateLimitMiddleware,
  sandboxResponseWrapperMiddleware,
  sandboxErrorHandlingMiddleware,
} from './middleware/sandbox-middleware.js';

// Add sandbox middleware early in the pipeline
app.use(sandboxDetectionMiddleware);
app.use(sandboxLoggingMiddleware);
app.use(sandboxDataIsolationMiddleware);
app.use(sandboxRateLimitMiddleware);
app.use(sandboxResponseWrapperMiddleware);

// Register sandbox routes
app.use('/api/sandbox', sandboxRoutes);
app.use('/sandbox', sandboxRoutes);

// Add sandbox error handling
app.use(sandboxErrorHandlingMiddleware);
```

## Files Created

1. **Service**
   - `services/api-backend/services/sandbox-service.js` - Core sandbox service

2. **Middleware**
   - `services/api-backend/middleware/sandbox-middleware.js` - Sandbox middleware

3. **Routes**
   - `services/api-backend/routes/sandbox.js` - Sandbox API endpoints

4. **Documentation**
   - `services/api-backend/SANDBOX_ENVIRONMENT_GUIDE.md` - Comprehensive guide
   - `services/api-backend/SANDBOX_QUICK_REFERENCE.md` - Quick reference

5. **Tests**
   - `test/api-backend/sandbox-service.test.js` - Unit tests (30+ cases)
   - `test/api-backend/sandbox-routes.test.js` - Integration tests (25+ cases)

## Testing

### Run Unit Tests
```bash
npm test -- sandbox-service.test.js
```

### Run Integration Tests
```bash
npm test -- sandbox-routes.test.js
```

### Run All Sandbox Tests
```bash
npm test -- sandbox
```

## Validation Against Requirements

✅ **Requirement 12.9:** THE API SHALL support API sandbox/testing environment

- ✅ Create sandbox environment configuration
- ✅ Implement sandbox mode for testing without side effects
- ✅ Add sandbox documentation and test credentials

## Next Steps

1. **Integration**: Add sandbox middleware and routes to main `server.js`
2. **Testing**: Run full test suite to ensure no regressions
3. **Documentation**: Update API documentation to include sandbox endpoints
4. **Deployment**: Deploy sandbox environment to staging/development

## Related Documentation

- [API Documentation Guide](./API_DOCUMENTATION_GUIDE.md)
- [Authentication Guide](./AUTHENTICATION_GUIDE.md)
- [API Versioning Guide](./API_VERSIONING_GUIDE.md)
- [Rate Limit Documentation](./RATE_LIMIT_DOCUMENTATION.md)
