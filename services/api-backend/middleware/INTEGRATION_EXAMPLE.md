# Security Middleware Integration Example

## Complete server.js Integration

This document shows how to integrate the security enhancements into the existing `server.js` file.

## Step-by-Step Integration

### 1. Add Imports

Add these imports at the top of `server.js`, after the existing imports:

```javascript
// Existing imports
import express from 'express';
import http from 'http';
import cors from 'cors';
import helmet from 'helmet';
// ... other imports

// ADD: Security middleware imports
import {
  sanitizeAll,
  sanitizeAdminInput,
} from './middleware/input-sanitizer.js';
import {
  standardCors,
  adminCors,
  webhookCors,
} from './middleware/cors-config.js';
import {
  httpsEnforcement,
  adminHttpsEnforcement,
} from './middleware/https-enforcer.js';
```

### 2. Replace CORS Configuration

Find the existing CORS configuration and replace it:

```javascript
// REMOVE: Old CORS configuration
/*
app.use(cors({
  origin: [
    'https://app.cloudtolocalllm.online',
    'https://cloudtolocalllm.online',
    'https://docs.cloudtolocalllm.online',
    'http://localhost:3000',
    'http://localhost:8080',
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
*/

// ADD: New CORS configuration
app.use(standardCors);
```

### 3. Add HTTPS Enforcement

Add HTTPS enforcement after the `trust proxy` setting and before other middleware:

```javascript
// Existing trust proxy setting
app.set('trust proxy', 1);

// ADD: HTTPS enforcement
app.use(httpsEnforcement);

// Existing helmet configuration
app.use(
  helmet({
    // ... existing helmet config
  })
);
```

### 4. Add Input Sanitization

Add input sanitization after body parsing middleware:

```javascript
// Existing body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ADD: Input sanitization for all routes
app.use(sanitizeAll);
```

### 5. Update Webhook Routes

Update webhook routes to use webhook-specific CORS (before body parsing):

```javascript
// Webhook routes MUST be mounted before body parsing middleware
// Stripe requires raw body for signature verification

// MODIFY: Add webhook CORS
app.use('/api/webhooks', webhookCors, webhookRoutes);
```

### 6. Update Admin Routes

Update admin routes to use stricter security:

```javascript
// MODIFY: Admin routes with enhanced security
app.use(
  '/api/admin',
  adminCors,
  adminHttpsEnforcement,
  sanitizeAdminInput,
  adminRoutes
);

// MODIFY: Admin user routes
app.use(
  '/api/admin/users',
  adminCors,
  adminHttpsEnforcement,
  sanitizeAdminInput,
  adminUserRoutes
);

// MODIFY: Admin subscription routes
app.use(
  '/api/admin',
  adminCors,
  adminHttpsEnforcement,
  sanitizeAdminInput,
  adminSubscriptionRoutes
);
```

## Complete Integration Code

Here's the complete middleware section with all security enhancements:

```javascript
import express from 'express';
import http from 'http';
import helmet from 'helmet';
import dotenv from 'dotenv';
// ... other imports

// Security middleware
import {
  sanitizeAll,
  sanitizeAdminInput,
} from './middleware/input-sanitizer.js';
import {
  standardCors,
  adminCors,
  webhookCors,
} from './middleware/cors-config.js';
import {
  httpsEnforcement,
  adminHttpsEnforcement,
} from './middleware/https-enforcer.js';

dotenv.config();

const app = express();
const server = http.createServer(app);

// Trust proxy headers (required for rate limiting and HTTPS detection)
app.set('trust proxy', 1);

// HTTPS enforcement (before other middleware)
app.use(httpsEnforcement);

// Security middleware (helmet)
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        connectSrc: ["'self'", 'https:'],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'https:'],
      },
    },
  })
);

// CORS configuration (standard for most routes)
app.use(standardCors);

// Rate limiting (existing)
app.use(createConditionalRateLimiter());

// Webhook routes (before body parsing, with webhook CORS)
app.use('/api/webhooks', webhookCors, webhookRoutes);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Input sanitization (after body parsing)
app.use(sanitizeAll);

// ... other middleware and routes

// Admin routes with enhanced security
app.use(
  '/api/admin',
  adminCors,
  adminHttpsEnforcement,
  sanitizeAdminInput,
  adminRoutes
);

app.use(
  '/api/admin/users',
  adminCors,
  adminHttpsEnforcement,
  sanitizeAdminInput,
  adminUserRoutes
);

app.use(
  '/api/admin',
  adminCors,
  adminHttpsEnforcement,
  sanitizeAdminInput,
  adminSubscriptionRoutes
);

// ... rest of the routes
```

## Middleware Order

The order of middleware is critical for security:

1. **Trust Proxy** - Detect HTTPS behind load balancer
2. **HTTPS Enforcement** - Redirect HTTP to HTTPS
3. **Helmet** - Set security headers
4. **CORS** - Validate origins
5. **Rate Limiting** - Prevent abuse
6. **Webhook Routes** - Before body parsing (raw body needed)
7. **Body Parsing** - Parse JSON/URL-encoded bodies
8. **Input Sanitization** - Sanitize all inputs
9. **Routes** - Application routes

## Testing the Integration

### 1. Start the Server

```bash
cd services/api-backend
npm start
```

### 2. Test Input Sanitization

```bash
# Test XSS prevention
curl -X POST http://localhost:8080/api/test \
  -H "Content-Type: application/json" \
  -d '{"text": "<script>alert(1)</script>"}'

# Should return sanitized input without script tags
```

### 3. Test CORS

```bash
# Test allowed origin
curl -X GET http://localhost:8080/api/health \
  -H "Origin: https://app.cloudtolocalllm.online" \
  -v

# Should see Access-Control-Allow-Origin header

# Test blocked origin
curl -X GET http://localhost:8080/api/health \
  -H "Origin: https://malicious.com" \
  -v

# Should see CORS error
```

### 4. Test HTTPS Enforcement

```bash
# Set production mode
export NODE_ENV=production

# Test HTTP request
curl -X GET http://localhost:8080/api/users \
  -H "X-Forwarded-Proto: http" \
  -v

# Should see 301 redirect to HTTPS
```

### 5. Test Admin Security

```bash
# Test admin endpoint with wrong origin
curl -X GET http://localhost:8080/api/admin/users \
  -H "Origin: https://malicious.com" \
  -H "Authorization: Bearer <token>" \
  -v

# Should be blocked by CORS
```

## Environment Configuration

### Development

```bash
NODE_ENV=development
# HTTPS enforcement disabled
# Development origins allowed
```

### Production

```bash
NODE_ENV=production
# HTTPS enforcement enabled
# Only production origins allowed
# Secure cookies enabled
# HSTS headers enabled
```

### Custom Origins

```bash
# Add custom origins for staging/testing
ADDITIONAL_CORS_ORIGINS=https://staging.cloudtolocalllm.online,https://test.cloudtolocalllm.online
```

## Verification Checklist

After integration, verify:

- [ ] Server starts without errors
- [ ] Health endpoint responds
- [ ] CORS headers present in responses
- [ ] HTTPS redirect works in production
- [ ] HSTS header present in production
- [ ] Input sanitization working (test with XSS)
- [ ] Admin routes require admin CORS
- [ ] Webhook routes work with webhook CORS
- [ ] Secure cookies set in production
- [ ] Security headers present in all responses

## Rollback Plan

If issues occur, you can quickly rollback:

1. **Remove security imports**:

```javascript
// Comment out security imports
// import { sanitizeAll, sanitizeAdminInput } from './middleware/input-sanitizer.js';
// import { standardCors, adminCors, webhookCors } from './middleware/cors-config.js';
// import { httpsEnforcement, adminHttpsEnforcement } from './middleware/https-enforcer.js';
```

2. **Restore old CORS**:

```javascript
// Restore old CORS configuration
app.use(
  cors({
    origin: [
      'https://app.cloudtolocalllm.online',
      // ... old origins
    ],
    credentials: true,
  })
);
```

3. **Remove middleware calls**:

```javascript
// Comment out new middleware
// app.use(httpsEnforcement);
// app.use(sanitizeAll);
```

4. **Restart server**:

```bash
npm start
```

## Monitoring

After deployment, monitor:

1. **Error Logs**:

```bash
# Check for CORS errors
grep "CORS: Blocked" logs/app.log

# Check for HTTPS redirects
grep "HTTP request redirected" logs/app.log
```

2. **Metrics**:

- CORS blocked requests per hour
- HTTP to HTTPS redirects per hour
- Input sanitization triggers per hour

3. **Alerts**:

- High rate of CORS violations
- High rate of HTTPS violations
- Unusual input patterns

## Support

If you encounter issues:

1. Check `SECURITY_ENHANCEMENTS_GUIDE.md` for detailed documentation
2. Review `SECURITY_QUICK_REFERENCE.md` for common solutions
3. Check logs for specific error messages
4. Test individual middleware components
5. Verify environment variables are set correctly

## Next Steps

After successful integration:

1. Deploy to staging environment
2. Run security tests
3. Monitor for issues
4. Deploy to production
5. Continue with Task 30 (Deployment and Configuration)
