# Rate Limit Exemptions Implementation

## Overview

This document describes the implementation of rate limit exemptions for critical operations in the API backend. The exemption mechanism allows certain critical operations (health checks, authentication, admin operations) to bypass rate limiting while maintaining security and audit trails.

## Requirements

**Requirement 6.7:** THE API SHALL support rate limit exemptions for critical operations

### Acceptance Criteria

- Create exemption mechanism
- Implement exemption validation
- Add exemption logging

## Implementation

### 1. Exemption Manager (`middleware/rate-limit-exemptions.js`)

The `RateLimitExemptionManager` class provides the core exemption functionality:

#### Key Features

- **Exemption Rules**: Define rules that match requests and exempt them from rate limiting
- **Rule Matching**: Flexible matcher functions to identify exempt requests
- **Quota Management**: Optional per-user exemption quotas to prevent abuse
- **Logging**: Comprehensive logging of exemption checks and validations
- **Statistics**: Track exemption usage and statistics

#### Exemption Types

```javascript
{
  CRITICAL_OPERATION: 'critical_operation',
  ADMIN_OPERATION: 'admin_operation',
  HEALTH_CHECK: 'health_check',
  AUTHENTICATION: 'authentication',
  EMERGENCY: 'emergency',
}
```

#### Default Exemption Rules

1. **Health Check** (`health-check`)
   - Exempts: `/health`, `/api/health`, `/db/health`, `/api/db/health`
   - Type: `health_check`
   - Always enabled

2. **Authentication** (`authentication`)
   - Exempts: `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/callback`
   - Type: `authentication`
   - Always enabled

3. **Admin Operations** (`admin-operations`)
   - Exempts: `/admin/*` and `/api/admin/*` for users with `admin` role
   - Type: `admin_operation`
   - Requires RBAC validation

### 2. Exemption Middleware (`middleware/rate-limit-exemptions.js`)

The `createRateLimitExemptionMiddleware` function creates Express middleware that:

1. Checks if a request matches any exemption rule
2. Stores the exemption result in `req.rateLimitExemption`
3. Passes control to the next middleware

### 3. Rate Limiter Integration (`middleware/rate-limiter.js`)

The `TunnelRateLimiter` class has been updated to:

1. Accept exemption results from the exemption middleware
2. Bypass rate limiting for exempt requests
3. Add exemption headers to responses:
   - `X-RateLimit-Exempt: true`
   - `X-RateLimit-Exempt-Rule: <rule-id>`

### 4. Management Routes (`routes/rate-limit-exemptions.js`)

Admin endpoints for managing exemptions:

#### Endpoints

- `GET /api/admin/rate-limit-exemptions` - List all exemption rules
- `POST /api/admin/rate-limit-exemptions` - Add new exemption rule
- `PATCH /api/admin/rate-limit-exemptions/:id/enable` - Enable rule
- `PATCH /api/admin/rate-limit-exemptions/:id/disable` - Disable rule
- `DELETE /api/admin/rate-limit-exemptions/:id` - Remove rule
- `POST /api/admin/rate-limit-exemptions/reset/user/:userId` - Reset user exemptions
- `POST /api/admin/rate-limit-exemptions/reset/all` - Reset all exemptions

## Usage

### Adding Custom Exemption Rules

```javascript
exemptionManager.addRule(
  'custom-rule-id',
  exemptionManager.config.exemptionTypes.CRITICAL_OPERATION,
  (req) => req.path === '/api/critical-operation',
  {
    description: 'Custom critical operation',
    enabled: true,
    maxExemptionsPerUser: 100, // Optional quota
  }
);
```

### Checking Exemptions

```javascript
const result = exemptionManager.checkExemption(req);

if (result.exempt) {
  console.log(`Request exempt via rule: ${result.ruleId}`);
  console.log(`Exemption type: ${result.type}`);
}
```

### Middleware Pipeline Integration

```javascript
import { RateLimitExemptionManager, createRateLimitExemptionMiddleware } from './middleware/rate-limit-exemptions.js';

const exemptionManager = new RateLimitExemptionManager();
const exemptionMiddleware = createRateLimitExemptionMiddleware(exemptionManager);

// Add to middleware pipeline BEFORE rate limiter
app.use(exemptionMiddleware);
app.use(rateLimitMiddleware);
```

## Logging

### Exemption Logging

When `logExemptions` is enabled, the manager logs:

```
{
  correlationId: 'req-123',
  userId: 'user-456',
  ruleId: 'health-check',
  type: 'health_check',
  path: '/health',
  method: 'GET'
}
```

### Exemption Validation Logging

When `logExemptionValidation` is enabled, the manager logs:

```
{
  correlationId: 'req-123',
  userId: 'user-456',
  ruleId: 'quota-rule',
  exemptionCount: 50,
  maxExemptions: 100
}
```

## Security Considerations

1. **RBAC Validation**: Admin operation exemptions require proper role validation
2. **Quota Management**: Per-user exemption quotas prevent abuse
3. **Audit Logging**: All exemption checks are logged for security audits
4. **Rule Validation**: Matcher functions are wrapped in try-catch to prevent errors
5. **Graceful Degradation**: If exemption manager fails, requests are not exempt

## Testing

### Test Coverage

- 30 comprehensive tests covering:
  - Exemption rule matching
  - Custom rule creation and management
  - Exemption quotas
  - Integration with rate limiter
  - Exemption statistics
  - Middleware functionality
  - Admin operations exemption
  - Global exemption disabling

### Running Tests

```bash
npm test -- test/api-backend/rate-limit-exemptions.test.js
```

### Test Results

```
Test Suites: 1 passed, 1 total
Tests:       30 passed, 30 total
```

## Configuration

### Default Configuration

```javascript
{
  enabled: true,
  logExemptions: true,
  logExemptionValidation: true,
  exemptionTypes: {
    CRITICAL_OPERATION: 'critical_operation',
    ADMIN_OPERATION: 'admin_operation',
    HEALTH_CHECK: 'health_check',
    AUTHENTICATION: 'authentication',
    EMERGENCY: 'emergency',
  }
}
```

### Custom Configuration

```javascript
const exemptionManager = new RateLimitExemptionManager({
  enabled: true,
  logExemptions: false, // Disable logging for performance
  logExemptionValidation: true,
});
```

## Performance Impact

- **Minimal Overhead**: Exemption checks are O(n) where n is the number of rules (typically < 10)
- **Memory Efficient**: Exemption quotas use Map for O(1) lookups
- **No Database Calls**: All exemption logic is in-memory

## Future Enhancements

1. **Dynamic Rule Loading**: Load exemption rules from database
2. **Rule Conditions**: Support complex conditions (time-based, IP-based, etc.)
3. **Exemption Analytics**: Track exemption usage patterns
4. **Rule Templates**: Pre-built rule templates for common scenarios
5. **Exemption Expiration**: Time-based exemption expiration

## Files Modified

1. `middleware/rate-limit-exemptions.js` - New exemption manager
2. `middleware/rate-limiter.js` - Updated to support exemptions
3. `routes/rate-limit-exemptions.js` - New management routes
4. `test/api-backend/rate-limit-exemptions.test.js` - Comprehensive tests

## Validation

✅ All 30 tests passing
✅ Exemption rules working correctly
✅ Rate limiter integration verified
✅ Logging implemented
✅ Admin routes functional
✅ Security considerations addressed
