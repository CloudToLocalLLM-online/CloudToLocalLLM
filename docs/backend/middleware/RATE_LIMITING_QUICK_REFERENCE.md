# Admin Rate Limiting - Quick Reference

## Import Statement

```javascript
import {
  adminRateLimiter, // 100 req/min - default
  adminBurstLimiter, // 20 req/10sec - burst protection
  adminReadOnlyLimiter, // 200 req/min - read operations
  adminExpensiveLimiter, // 10 req/min - expensive operations
  adminCriticalLimiter, // 5 req/hour - critical operations
  combineRateLimiters, // combine multiple limiters
} from '../middleware/admin-rate-limiter.js';
```

## Usage Examples

### Read-Only Endpoints (GET)

```javascript
router.get('/users', adminReadOnlyLimiter, adminAuth(['view_users']), handler);
```

### Standard Operations (POST, PATCH)

```javascript
router.post(
  '/users/:id/suspend',
  adminRateLimiter,
  adminAuth(['suspend_users']),
  handler
);
```

### Expensive Operations (Reports, Exports)

```javascript
router.get(
  '/reports/export',
  adminExpensiveLimiter,
  adminAuth(['export_reports']),
  handler
);
```

### Critical Operations (Data Deletion)

```javascript
router.post(
  '/flush/execute',
  adminCriticalLimiter,
  adminAuth(['super_admin']),
  handler
);
```

### Combined Limiters

```javascript
router.post(
  '/sensitive',
  combineRateLimiters(adminBurstLimiter, adminRateLimiter),
  adminAuth(['edit_users']),
  handler
);
```

## Rate Limits Summary

| Limiter                 | Limit | Window     | Use Case            |
| ----------------------- | ----- | ---------- | ------------------- |
| `adminReadOnlyLimiter`  | 200   | 1 minute   | GET endpoints       |
| `adminRateLimiter`      | 100   | 1 minute   | POST, PATCH, DELETE |
| `adminBurstLimiter`     | 20    | 10 seconds | Burst protection    |
| `adminExpensiveLimiter` | 10    | 1 minute   | Reports, exports    |
| `adminCriticalLimiter`  | 5     | 1 hour     | Data deletion       |

## Response Headers

### Success Response

```
RateLimit-Limit: 100
RateLimit-Remaining: 95
RateLimit-Reset: 2025-11-16T10:31:00.000Z
```

### Error Response (429)

```json
{
  "error": "Too many requests from this admin user",
  "code": "ADMIN_RATE_LIMIT_EXCEEDED",
  "retryAfter": 60,
  "timestamp": "2025-11-16T10:30:00.000Z"
}
```

## Health Check Exemption

Health check endpoints are automatically exempted:

```javascript
router.get('/health', handler); // No rate limiting
```

## Testing

```bash
# Test rate limit
for i in {1..101}; do
  curl -H "Authorization: Bearer $TOKEN" \
    http://localhost:3000/api/admin/users
done
# 101st request returns 429
```

## Production Setup

Use Redis store for multi-instance deployments:

```javascript
import RedisStore from 'rate-limit-redis';
import { createClient } from 'redis';

const redisClient = createClient({ url: process.env.REDIS_URL });
const store = new RedisStore({ client: redisClient, prefix: 'admin_rl:' });

const limiter = createAdminRateLimiter('default', { store });
```

## Monitoring

Track these metrics in Grafana:

- Rate limit hit rate by endpoint
- Top rate-limited admins
- 429 error rate
- Rate limit effectiveness

## Documentation

Full documentation: `ADMIN_RATE_LIMITING_GUIDE.md`
