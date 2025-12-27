# Security Enhancements Quick Reference

## Task 29: Backend Security Enhancements

### Status: ✅ COMPLETED

All three subtasks have been implemented:

- ✅ 29.1 Input Sanitization
- ✅ 29.2 CORS Configuration
- ✅ 29.3 HTTPS Enforcement

## Quick Start

### 1. Import Security Middleware

```javascript
// Input sanitization
import {
  sanitizeAdminInput,
  sanitizeAll,
} from './middleware/input-sanitizer.js';

// CORS configuration
import {
  standardCors,
  adminCors,
  webhookCors,
} from './middleware/cors-config.js';

// HTTPS enforcement
import {
  httpsEnforcement,
  adminHttpsEnforcement,
} from './middleware/https-enforcer.js';
```

### 2. Apply to Server

```javascript
const app = express();

// Trust proxy for HTTPS detection
app.set('trust proxy', 1);

// HTTPS enforcement (first)
app.use(httpsEnforcement);

// CORS (before routes)
app.use(standardCors);

// Body parsing
app.use(express.json());

// Input sanitization (after body parsing)
app.use(sanitizeAll);

// Admin routes with stricter security
app.use(
  '/api/admin',
  adminCors,
  adminHttpsEnforcement,
  sanitizeAdminInput,
  adminRoutes
);
```

## Common Use Cases

### Sanitize User Input

```javascript
import {
  sanitizeString,
  sanitizeEmail,
  sanitizeUUID,
} from './middleware/input-sanitizer.js';

// Sanitize string
const username = sanitizeString(req.body.username);

// Validate email
const email = sanitizeEmail(req.body.email);
if (!email) {
  return res.status(400).json({ error: 'Invalid email' });
}

// Validate UUID
const userId = sanitizeUUID(req.params.userId);
if (!userId) {
  return res.status(400).json({ error: 'Invalid user ID' });
}
```

### Prevent SQL Injection

```javascript
import { sanitizeLikePattern } from './middleware/input-sanitizer.js';

// Sanitize search query
const search = sanitizeLikePattern(req.query.search);

// Use parameterized query
const query = 'SELECT * FROM users WHERE email LIKE $1';
const result = await db.query(query, [`%${search}%`]);
```

### Configure CORS for New Endpoint

```javascript
// Public endpoint
app.get('/api/public/data', standardCors, handler);

// Admin endpoint
app.post('/api/admin/action', adminCors, handler);

// Webhook endpoint
app.post('/api/webhooks/stripe', webhookCors, handler);
```

### Enforce HTTPS

```javascript
import { requireHttps } from './middleware/https-enforcer.js';

// Require HTTPS for sensitive endpoint
app.post('/api/payment', requireHttps, paymentHandler);

// Admin endpoints automatically enforce HTTPS
app.use('/api/admin', adminHttpsEnforcement);
```

## Sanitization Functions

| Function                     | Purpose             | Example                                                |
| ---------------------------- | ------------------- | ------------------------------------------------------ |
| `sanitizeString(str)`        | Remove XSS, scripts | `sanitizeString('<script>alert(1)</script>')`          |
| `sanitizeEmail(email)`       | Validate email      | `sanitizeEmail('user@example.com')`                    |
| `sanitizeNumber(num, opts)`  | Validate number     | `sanitizeNumber('42', { min: 0, max: 100 })`           |
| `sanitizeUUID(uuid)`         | Validate UUID       | `sanitizeUUID('123e4567-e89b-12d3-a456-426614174000')` |
| `sanitizeDate(date)`         | Validate date       | `sanitizeDate('2025-01-01')`                           |
| `sanitizeEnum(val, allowed)` | Validate enum       | `sanitizeEnum('active', ['active', 'inactive'])`       |
| `sanitizeLikePattern(str)`   | Escape SQL LIKE     | `sanitizeLikePattern('user%')`                         |
| `sanitizePagination(query)`  | Validate page/limit | `sanitizePagination({ page: 1, limit: 50 })`           |

## CORS Configurations

| Configuration  | Use Case   | Credentials    | Origins            |
| -------------- | ---------- | -------------- | ------------------ |
| `standardCors` | Public API | Yes            | Whitelist          |
| `adminCors`    | Admin API  | Yes (required) | Admin domains only |
| `webhookCors`  | Webhooks   | No             | Payment providers  |

## Security Headers

| Header                      | Value                                          | Purpose               |
| --------------------------- | ---------------------------------------------- | --------------------- |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | Force HTTPS           |
| `X-Content-Type-Options`    | `nosniff`                                      | Prevent MIME sniffing |
| `X-Frame-Options`           | `DENY`                                         | Prevent clickjacking  |
| `X-XSS-Protection`          | `1; mode=block`                                | Enable XSS filter     |
| `Referrer-Policy`           | `strict-origin-when-cross-origin`              | Control referrer      |
| `Permissions-Policy`        | `geolocation=(), microphone=()...`             | Restrict features     |

## Environment Variables

```bash
# CORS
ADDITIONAL_CORS_ORIGINS=https://staging.example.com,https://test.example.com

# HTTPS
NODE_ENV=production  # Enables HTTPS enforcement
FORCE_HTTPS=true     # Force HTTPS in development
```

## Testing

```javascript
// Test input sanitization
const sanitized = sanitizeString('<script>alert(1)</script>');
expect(sanitized).not.toContain('<script>');

// Test CORS
const response = await request(app)
  .get('/api/health')
  .set('Origin', 'https://app.cloudtolocalllm.online');
expect(response.headers['access-control-allow-origin']).toBeDefined();

// Test HTTPS redirect
process.env.NODE_ENV = 'production';
const response = await request(app)
  .get('/api/users')
  .set('X-Forwarded-Proto', 'http');
expect(response.status).toBe(301);
```

## Troubleshooting

### CORS Blocked

- Check origin is in allowed list
- Add to `ADDITIONAL_CORS_ORIGINS`
- Verify credentials are sent

### HTTPS Redirect Loop

- Set `trust proxy` correctly
- Check `X-Forwarded-Proto` header
- Verify load balancer configuration

### Input Rejected

- Check validation constraints
- Verify data format
- Use correct sanitizer

## Files Created

1. `middleware/input-sanitizer.js` - Input sanitization functions
2. `middleware/cors-config.js` - CORS configuration
3. `middleware/https-enforcer.js` - HTTPS enforcement
4. `middleware/SECURITY_ENHANCEMENTS_GUIDE.md` - Detailed guide
5. `middleware/SECURITY_QUICK_REFERENCE.md` - This file

## Next Steps

1. Update `server.js` to use new middleware
2. Apply `sanitizeAdminInput` to admin routes
3. Test security enhancements
4. Update deployment configuration
5. Monitor security logs

## Requirements Met

✅ **Requirement 15**: Security and Data Protection

- Input sanitization prevents SQL injection and XSS
- CORS restricts access to authorized domains
- HTTPS enforcement protects data in transit
- Security headers provide defense in depth

## Dependencies

```json
{
  "validator": "^13.11.0" // Added for input validation
}
```

## Integration Checklist

- [ ] Import security middleware in `server.js`
- [ ] Apply `httpsEnforcement` globally
- [ ] Replace existing CORS with new configuration
- [ ] Apply `sanitizeAll` after body parsing
- [ ] Apply `sanitizeAdminInput` to admin routes
- [ ] Test all endpoints
- [ ] Update environment variables
- [ ] Deploy to staging
- [ ] Monitor logs for security events
- [ ] Deploy to production

## Support

For questions or issues:

1. Check `SECURITY_ENHANCEMENTS_GUIDE.md` for detailed documentation
2. Review test cases in test files
3. Check logs for security warnings
4. Consult OWASP guidelines for best practices
