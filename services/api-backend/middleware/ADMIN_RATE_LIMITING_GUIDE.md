# Admin Rate Limiting Guide

## Overview

The admin rate limiting system provides configurable rate limits for different types of admin operations to protect the API from abuse while allowing legitimate admin activities.

## Rate Limit Types

### 1. Default Rate Limiter (`adminRateLimiter`)

- **Limit**: 100 requests per minute
- **Use for**: General admin operations (updates, modifications)
- **Example**: User updates, subscription changes, admin management

```javascript
import { adminRateLimiter } from '../middleware/admin-rate-limiter.js';
router.post('/users/:id', adminRateLimiter, adminAuth(['edit_users']), handler);
```

### 2. Burst Protection (`adminBurstLimiter`)

- **Limit**: 20 requests per 10 seconds
- **Use for**: Additional protection against rapid-fire requests
- **Example**: Can be combined with default limiter

```javascript
import {
  adminBurstLimiter,
  combineRateLimiters,
} from '../middleware/admin-rate-limiter.js';
router.post(
  '/critical',
  combineRateLimiters(adminBurstLimiter, adminRateLimiter),
  handler
);
```

### 3. Read-Only Limiter (`adminReadOnlyLimiter`)

- **Limit**: 200 requests per minute
- **Use for**: GET endpoints that only read data
- **Example**: User lists, reports, dashboard metrics

```javascript
import { adminReadOnlyLimiter } from '../middleware/admin-rate-limiter.js';
router.get('/users', adminReadOnlyLimiter, adminAuth(['view_users']), handler);
```

### 4. Expensive Operations (`adminExpensiveLimiter`)

- **Limit**: 10 requests per minute
- **Use for**: Resource-intensive operations
- **Example**: Report exports, bulk operations, data processing

```javascript
import { adminExpensiveLimiter } from '../middleware/admin-rate-limiter.js';
router.get(
  '/reports/export',
  adminExpensiveLimiter,
  adminAuth(['export_reports']),
  handler
);
```

### 5. Critical Operations (`adminCriticalLimiter`)

- **Limit**: 5 requests per hour
- **Use for**: Dangerous operations that modify or delete data
- **Example**: Data flush, user deletion, system-wide changes

```javascript
import { adminCriticalLimiter } from '../middleware/admin-rate-limiter.js';
router.post(
  '/flush/execute',
  adminCriticalLimiter,
  adminAuth(['super_admin']),
  handler
);
```

## Implementation Guidelines

### 1. Health Check Exemption

Health check endpoints are automatically exempted from rate limiting:

```javascript
// Automatically skipped
router.get('/health', handler);
```

### 2. Rate Limit Headers

All rate-limited responses include standard headers:

- `RateLimit-Limit`: Maximum requests allowed
- `RateLimit-Remaining`: Requests remaining in current window
- `RateLimit-Reset`: Time when the limit resets (ISO 8601)
- `Retry-After`: Seconds to wait before retrying (on 429 responses)

### 3. Error Response Format

When rate limit is exceeded (429 status):

```json
{
  "error": "Too many requests from this admin user",
  "code": "ADMIN_RATE_LIMIT_EXCEEDED",
  "retryAfter": 60,
  "timestamp": "2025-11-16T10:30:00.000Z"
}
```

### 4. Combining Multiple Limiters

Use `combineRateLimiters` to apply multiple limits:

```javascript
import {
  combineRateLimiters,
  adminBurstLimiter,
  adminRateLimiter,
} from '../middleware/admin-rate-limiter.js';

router.post(
  '/sensitive',
  combineRateLimiters(adminBurstLimiter, adminRateLimiter),
  adminAuth(['edit_users']),
  handler
);
```

## Current Implementation

### Admin Routes (`/api/admin/*`)

#### System Operations

- `GET /system/stats` - Read-only limiter (200/min)
- `POST /flush/prepare` - Default limiter (100/min)
- `POST /flush/execute` - Critical limiter (5/hour)
- `GET /flush/status/:id` - Read-only limiter (200/min)
- `GET /flush/history` - Read-only limiter (200/min)
- `POST /containers/cleanup` - Default limiter (100/min)
- `GET /health` - No limit (exempted)

#### User Management (`/api/admin/users`)

- `GET /` - Read-only limiter (200/min)
- `GET /:userId` - Read-only limiter (200/min)
- `PATCH /:userId` - Default limiter (100/min)
- `POST /:userId/suspend` - Default limiter (100/min)
- `POST /:userId/reactivate` - Default limiter (100/min)

#### Payment Management (`/api/admin/payments`)

- `GET /transactions` - Read-only limiter (200/min)
- `GET /transactions/:id` - Read-only limiter (200/min)
- `POST /refunds` - Default limiter (100/min)
- `GET /methods/:userId` - Read-only limiter (200/min)

#### Subscription Management (`/api/admin/subscriptions`)

- `GET /` - Read-only limiter (200/min)
- `GET /:id` - Read-only limiter (200/min)
- `PATCH /:id` - Default limiter (100/min)
- `POST /:id/cancel` - Default limiter (100/min)

#### Reports (`/api/admin/reports`)

- `GET /revenue` - Read-only limiter (200/min)
- `GET /subscriptions` - Read-only limiter (200/min)
- `GET /export` - Expensive limiter (10/min)

#### Audit Logs (`/api/admin/audit`)

- `GET /logs` - Read-only limiter (200/min)
- `GET /logs/:id` - Read-only limiter (200/min)
- `GET /export` - Expensive limiter (10/min)

#### Admin Management (`/api/admin/admins`)

- `GET /` - Read-only limiter (200/min)
- `POST /` - Default limiter (100/min)
- `DELETE /:userId/roles/:role` - Default limiter (100/min)

#### Dashboard (`/api/admin/dashboard`)

- `GET /metrics` - Read-only limiter (200/min)

## Monitoring

### Logging

All rate limit events are logged:

- **Debug**: Successful rate limit checks
- **Warn**: Rate limit exceeded events

### Statistics

Get rate limit statistics:

```javascript
import { getRateLimitStats } from '../middleware/admin-rate-limiter.js';
const stats = getRateLimitStats();
```

## Production Considerations

### Redis Store (Recommended)

For production deployments with multiple API instances, use a Redis store:

```javascript
import RedisStore from 'rate-limit-redis';
import { createClient } from 'redis';

const redisClient = createClient({
  url: process.env.REDIS_URL,
});

const store = new RedisStore({
  client: redisClient,
  prefix: 'admin_rl:',
});

// Pass store to rate limiter
const limiter = createAdminRateLimiter('default', { store });
```

### Monitoring

Monitor rate limit metrics in Grafana:

- Rate limit hit rate
- Top rate-limited admins
- Rate limit by endpoint
- 429 error rate

## Testing

### Manual Testing

```bash
# Test rate limit
for i in {1..101}; do
  curl -H "Authorization: Bearer $TOKEN" \
    http://localhost:3000/api/admin/users
done

# Should return 429 on 101st request
```

### Automated Testing

```javascript
describe('Admin Rate Limiting', () => {
  it('should enforce 100 req/min limit', async () => {
    // Make 100 requests
    for (let i = 0; i < 100; i++) {
      const res = await request(app)
        .get('/api/admin/users')
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
    }

    // 101st request should be rate limited
    const res = await request(app)
      .get('/api/admin/users')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(429);
  });
});
```

## Troubleshooting

### Rate Limit Not Working

1. Check middleware order (rate limiter should be before auth)
2. Verify admin user ID is being extracted correctly
3. Check logs for rate limit events

### Too Restrictive

1. Adjust limits in `admin-rate-limiter.js`
2. Consider using read-only limiter for GET endpoints
3. Implement caching to reduce API calls

### Memory Issues

1. Implement Redis store for distributed rate limiting
2. Adjust cleanup intervals
3. Monitor memory usage

## Requirements

This implementation satisfies Requirement 15 (Security and Data Protection):

- ✅ Rate limiting to prevent brute force attacks (max 5 failed login attempts per 15 minutes)
- ✅ 100 requests per minute per admin (default)
- ✅ 20 request burst allowance
- ✅ Stricter limits for expensive operations
- ✅ Looser limits for read-only operations
- ✅ Health check exemptions
- ✅ Rate limit headers in responses
- ✅ 429 status code on limit exceeded
