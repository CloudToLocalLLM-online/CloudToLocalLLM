# Security Enhancements Guide

## Overview

This guide documents the security enhancements implemented for the CloudToLocalLLM API backend, specifically for Task 29 of the Admin Center feature.

## Components

### 1. Input Sanitization (`input-sanitizer.js`)

Comprehensive input sanitization to prevent injection attacks and XSS.

#### Features

- **String Sanitization**: Escapes HTML entities, removes script tags and event handlers
- **Email Validation**: Normalizes and validates email addresses
- **Number Validation**: Validates and sanitizes numeric inputs with min/max constraints
- **UUID Validation**: Validates UUID format
- **Date Validation**: Validates and sanitizes date inputs
- **Enum Validation**: Validates values against allowed lists
- **Object Sanitization**: Recursively sanitizes nested objects
- **SQL LIKE Pattern Sanitization**: Prevents SQL injection in search queries
- **Pagination Sanitization**: Validates and sanitizes page/limit parameters

#### Usage

```javascript
import {
  sanitizeAdminInput,
  sanitizeAll,
} from './middleware/input-sanitizer.js';

// Apply to all admin routes
app.use('/api/admin', sanitizeAdminInput);

// Apply to specific routes
app.post('/api/users', sanitizeAll, (req, res) => {
  // req.body, req.query, and req.params are now sanitized
});
```

#### Individual Sanitizers

```javascript
import {
  sanitizeString,
  sanitizeEmail,
  sanitizeNumber,
  sanitizeUUID,
  sanitizeDate,
  sanitizeEnum,
  sanitizeLikePattern,
} from './middleware/input-sanitizer.js';

// Sanitize email
const email = sanitizeEmail(req.body.email);

// Sanitize number with constraints
const amount = sanitizeNumber(req.body.amount, {
  min: 0,
  max: 10000,
  allowFloat: true,
});

// Sanitize UUID
const userId = sanitizeUUID(req.params.userId);

// Sanitize search pattern
const searchQuery = sanitizeLikePattern(req.query.search);
```

### 2. CORS Configuration (`cors-config.js`)

Secure CORS configuration with no wildcard origins.

#### Features

- **Whitelist-based Origins**: Only allows specific domains
- **No Wildcards**: Prevents unauthorized access
- **Credentials Support**: Configurable per endpoint type
- **Multiple Configurations**: Standard, Admin, and Webhook CORS
- **Environment-based**: Different settings for development/production
- **Origin Logging**: Logs blocked CORS attempts

#### Allowed Origins

**Production:**

- `https://app.cloudtolocalllm.online`
- `https://cloudtolocalllm.online`
- `https://docs.cloudtolocalllm.online`
- `https://admin.cloudtolocalllm.online`

**Development:**

- `http://localhost:3000`
- `http://localhost:8080`
- `http://localhost:5000`
- `http://127.0.0.1:3000`
- `http://127.0.0.1:8080`
- `http://127.0.0.1:5000`

#### Usage

```javascript
import {
  standardCors,
  adminCors,
  webhookCors,
} from './middleware/cors-config.js';

// Standard CORS for public endpoints
app.use('/api/public', standardCors);

// Strict CORS for admin endpoints
app.use('/api/admin', adminCors);

// Webhook-specific CORS
app.use('/api/webhooks', webhookCors);
```

#### Adding Custom Origins

Set the `ADDITIONAL_CORS_ORIGINS` environment variable:

```bash
ADDITIONAL_CORS_ORIGINS=https://staging.example.com,https://test.example.com
```

### 3. HTTPS Enforcement (`https-enforcer.js`)

HTTPS enforcement and security headers.

#### Features

- **HTTP to HTTPS Redirect**: Automatic redirect in production
- **HSTS Headers**: HTTP Strict Transport Security
- **Secure Cookies**: Automatic secure flag for cookies
- **Security Headers**: X-Content-Type-Options, X-Frame-Options, etc.
- **Admin Enforcement**: Stricter rules for admin endpoints
- **Environment-aware**: Different behavior for development/production

#### Security Headers Set

- `Strict-Transport-Security`: HSTS with 1-year max-age (2 years for admin)
- `X-Content-Type-Options`: nosniff
- `X-Frame-Options`: DENY
- `X-XSS-Protection`: 1; mode=block
- `Referrer-Policy`: strict-origin-when-cross-origin (no-referrer for admin)
- `Permissions-Policy`: Restricts browser features

#### Usage

```javascript
import {
  httpsEnforcement,
  adminHttpsEnforcement,
} from './middleware/https-enforcer.js';

// Apply to all routes
app.use(httpsEnforcement);

// Stricter enforcement for admin routes
app.use('/api/admin', adminHttpsEnforcement);
```

#### Cookie Security

Cookies are automatically configured with:

- `secure: true` (production only)
- `httpOnly: true` (always)
- `sameSite: 'strict'` (default)

```javascript
// Cookies are automatically secured
res.cookie('session', token, {
  maxAge: 3600000,
  // secure, httpOnly, and sameSite are added automatically
});
```

## Integration with Server

### Recommended Setup

```javascript
import express from 'express';
import { standardCors, adminCors } from './middleware/cors-config.js';
import {
  httpsEnforcement,
  adminHttpsEnforcement,
} from './middleware/https-enforcer.js';
import {
  sanitizeAll,
  sanitizeAdminInput,
} from './middleware/input-sanitizer.js';

const app = express();

// 1. Trust proxy (for rate limiting and HTTPS detection)
app.set('trust proxy', 1);

// 2. HTTPS enforcement (before other middleware)
app.use(httpsEnforcement);

// 3. CORS configuration
app.use(standardCors);

// 4. Body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 5. Input sanitization for all routes
app.use(sanitizeAll);

// 6. Admin routes with stricter security
app.use(
  '/api/admin',
  adminCors,
  adminHttpsEnforcement,
  sanitizeAdminInput,
  adminRoutes
);
```

## Security Best Practices

### 1. Input Validation

Always validate and sanitize user input:

```javascript
// Bad
const userId = req.params.userId;
const query = `SELECT * FROM users WHERE id = '${userId}'`;

// Good
import { sanitizeUUID } from './middleware/input-sanitizer.js';
const userId = sanitizeUUID(req.params.userId);
if (!userId) {
  return res.status(400).json({ error: 'Invalid user ID' });
}
const query = 'SELECT * FROM users WHERE id = $1';
const result = await db.query(query, [userId]);
```

### 2. SQL Injection Prevention

Use parameterized queries:

```javascript
// Bad
const search = req.query.search;
const query = `SELECT * FROM users WHERE email LIKE '%${search}%'`;

// Good
import { sanitizeLikePattern } from './middleware/input-sanitizer.js';
const search = sanitizeLikePattern(req.query.search);
const query = 'SELECT * FROM users WHERE email LIKE $1';
const result = await db.query(query, [`%${search}%`]);
```

### 3. XSS Prevention

Sanitize all string outputs:

```javascript
import { sanitizeString } from './middleware/input-sanitizer.js';

// Sanitize before storing
const username = sanitizeString(req.body.username);

// Sanitize before displaying
res.json({
  username: sanitizeString(user.username),
});
```

### 4. CORS Configuration

Never use wildcard origins in production:

```javascript
// Bad
app.use(cors({ origin: '*' }));

// Good
import { standardCors } from './middleware/cors-config.js';
app.use(standardCors);
```

### 5. HTTPS Enforcement

Always enforce HTTPS in production:

```javascript
// Automatic enforcement
import { httpsEnforcement } from './middleware/https-enforcer.js';
app.use(httpsEnforcement);

// Manual check for sensitive endpoints
import { requireHttps } from './middleware/https-enforcer.js';
app.post('/api/payment', requireHttps, paymentHandler);
```

## Testing

### Testing Input Sanitization

```javascript
import {
  sanitizeString,
  sanitizeEmail,
  sanitizeUUID,
} from './middleware/input-sanitizer.js';

describe('Input Sanitization', () => {
  test('sanitizes XSS attempts', () => {
    const malicious = '<script>alert("XSS")</script>';
    const sanitized = sanitizeString(malicious);
    expect(sanitized).not.toContain('<script>');
  });

  test('validates email format', () => {
    expect(sanitizeEmail('valid@example.com')).toBe('valid@example.com');
    expect(sanitizeEmail('invalid')).toBeNull();
  });

  test('validates UUID format', () => {
    const validUUID = '123e4567-e89b-12d3-a456-426614174000';
    expect(sanitizeUUID(validUUID)).toBe(validUUID);
    expect(sanitizeUUID('invalid-uuid')).toBeNull();
  });
});
```

### Testing CORS

```javascript
import request from 'supertest';
import app from './server.js';

describe('CORS Configuration', () => {
  test('allows requests from whitelisted origins', async () => {
    const response = await request(app)
      .get('/api/health')
      .set('Origin', 'https://app.cloudtolocalllm.online');

    expect(response.status).not.toBe(403);
    expect(response.headers['access-control-allow-origin']).toBe(
      'https://app.cloudtolocalllm.online'
    );
  });

  test('blocks requests from unauthorized origins', async () => {
    const response = await request(app)
      .get('/api/health')
      .set('Origin', 'https://malicious.com');

    expect(response.status).toBe(500); // CORS error
  });
});
```

### Testing HTTPS Enforcement

```javascript
describe('HTTPS Enforcement', () => {
  test('redirects HTTP to HTTPS in production', async () => {
    process.env.NODE_ENV = 'production';

    const response = await request(app)
      .get('/api/users')
      .set('X-Forwarded-Proto', 'http');

    expect(response.status).toBe(301);
    expect(response.headers.location).toMatch(/^https:/);
  });

  test('sets HSTS header in production', async () => {
    process.env.NODE_ENV = 'production';

    const response = await request(app)
      .get('/api/health')
      .set('X-Forwarded-Proto', 'https');

    expect(response.headers['strict-transport-security']).toBeDefined();
  });
});
```

## Monitoring and Logging

### CORS Violations

CORS violations are automatically logged:

```
CORS: Blocked request from unauthorized origin: https://malicious.com
```

### HTTPS Violations

HTTP requests in production are logged:

```
HTTP request redirected to HTTPS: GET /api/users
```

### Input Sanitization

Malicious input attempts can be logged by adding custom logging:

```javascript
import { sanitizeString } from './middleware/input-sanitizer.js';

function sanitizeAndLog(input, fieldName) {
  const sanitized = sanitizeString(input);
  if (sanitized !== input) {
    logger.warn(`Potentially malicious input detected in ${fieldName}`, {
      original: input,
      sanitized: sanitized,
    });
  }
  return sanitized;
}
```

## Environment Variables

### CORS Configuration

- `ADDITIONAL_CORS_ORIGINS`: Comma-separated list of additional allowed origins
- `NODE_ENV`: Set to 'production' to disable development origins

### HTTPS Enforcement

- `NODE_ENV`: Set to 'production' to enable HTTPS enforcement
- `FORCE_HTTPS`: Set to 'true' to force HTTPS even in development

## Troubleshooting

### CORS Issues

**Problem**: Requests blocked by CORS

**Solution**:

1. Check if origin is in allowed list
2. Add origin to `ADDITIONAL_CORS_ORIGINS` environment variable
3. Verify credentials are being sent with request

### HTTPS Redirect Loop

**Problem**: Infinite redirect loop

**Solution**:

1. Ensure `trust proxy` is set correctly
2. Check `X-Forwarded-Proto` header from load balancer
3. Verify nginx/load balancer is setting correct headers

### Input Sanitization Breaking Functionality

**Problem**: Valid input being rejected

**Solution**:

1. Check validation constraints (min/max for numbers)
2. Verify UUID format is correct
3. Use appropriate sanitizer for data type
4. Add custom validation if needed

## Compliance

These security enhancements help meet the following requirements:

- **Requirement 15**: Security and Data Protection
  - Input sanitization prevents SQL injection and XSS
  - CORS configuration prevents unauthorized access
  - HTTPS enforcement protects data in transit

- **PCI DSS Compliance**:
  - Secure transmission of payment data
  - Protection against common attacks

- **GDPR Compliance**:
  - Data protection in transit
  - Access control via CORS

## References

- [OWASP Input Validation Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)
- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [MDN CORS Documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [MDN HSTS Documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security)
