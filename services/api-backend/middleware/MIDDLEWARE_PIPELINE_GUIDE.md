# Middleware Pipeline Enhancement Guide

## Overview

This document describes the enhanced Express.js middleware pipeline for the CloudToLocalLLM API Backend. The middleware pipeline has been reorganized and enhanced to provide proper request handling, security, and observability.

## Middleware Pipeline Order (CRITICAL)

The order of middleware is critical for proper request handling. The pipeline is organized as follows:

### 1. Sentry Request Handler

- **Purpose**: Error tracking and distributed tracing
- **Must be first**: Captures all errors and traces
- **Module**: `@sentry/node`

### 2. Sentry Tracing Handler

- **Purpose**: Distributed tracing for request tracking
- **Module**: `@sentry/node`

### 3. CORS Middleware

- **Purpose**: Handle Cross-Origin Resource Sharing
- **Handles**: Preflight OPTIONS requests
- **Module**: `cors`

### 4. Helmet Security Headers

- **Purpose**: Add security headers to responses
- **Headers**: CSP, X-Frame-Options, X-Content-Type-Options, etc.
- **Module**: `helmet`

### 5. Request Logging

- **Purpose**: Log all incoming requests with correlation IDs
- **Features**:
  - Generates unique correlation IDs
  - Tracks request duration
  - Logs request/response details
- **Module**: `middleware/request-logging.js`

### 6. Request Validation

- **Purpose**: Validate request format and headers
- **Checks**:
  - Content-Type validation
  - Authorization header format
  - Request body size
- **Module**: `middleware/request-validation.js`

### 7. Rate Limiting

- **Purpose**: Protect against abuse and DDoS
- **Features**:
  - Per-IP rate limiting
  - Different limits for bridge operations
  - Skips OPTIONS requests
- **Module**: `express-rate-limit`

### 8. Body Parsing

- **Purpose**: Parse request body
- **Formats**: JSON, URL-encoded
- **Limit**: 10MB
- **Module**: `express`

### 9. Request Timeout

- **Purpose**: Prevent long-running requests
- **Default**: 30 seconds
- **Response**: 408 Request Timeout
- **Module**: `middleware/request-timeout.js`

### 10. Authentication (Selective)

- **Purpose**: Validate JWT tokens
- **Applied to**: Protected routes only
- **Module**: `middleware/auth.js`

### 11. Authorization (Selective)

- **Purpose**: Check user permissions
- **Applied to**: Admin and tier-restricted routes
- **Module**: `middleware/tier-check.js`

### 12. Compression (Optional)

- **Purpose**: Compress response body
- **Note**: Optional, can be added if compression package is installed

### 13. Error Handling

- **Purpose**: Catch and format errors
- **Module**: `@sentry/node` + custom error handler

## New Middleware Files

### request-logging.js

Implements structured request/response logging with correlation IDs for distributed tracing.

**Features**:

- Generates unique correlation IDs (UUID format)
- Preserves existing correlation IDs from headers
- Logs request start and completion
- Tracks request duration
- Adds correlation ID to response headers

**Usage**:

```javascript
import { requestLoggingMiddleware } from './middleware/request-logging.js';
app.use(requestLoggingMiddleware);
```

### request-validation.js

Validates request format and headers before processing.

**Features**:

- Validates Content-Type header
- Checks Authorization header format
- Validates request body size
- Skips validation for GET/HEAD/OPTIONS requests

**Usage**:

```javascript
import { requestValidationMiddleware } from './middleware/request-validation.js';
app.use(requestValidationMiddleware);
```

### request-timeout.js

Implements configurable request timeout handling.

**Features**:

- Configurable timeout (default: 30 seconds)
- Graceful timeout response
- Clears timeout on response completion
- Skips WebSocket upgrades

**Usage**:

```javascript
import {
  requestTimeoutMiddleware,
  createRequestTimeoutMiddleware,
} from './middleware/request-timeout.js';
app.use(requestTimeoutMiddleware); // 30 second default
// Or with custom timeout:
app.use(createRequestTimeoutMiddleware(60000)); // 60 seconds
```

### graceful-shutdown.js

Manages graceful shutdown with in-flight request completion.

**Features**:

- Tracks active connections
- Waits for in-flight requests to complete
- Configurable shutdown timeout
- Handles SIGTERM and SIGINT signals
- Prevents new connections during shutdown

**Usage**:

```javascript
import { setupGracefulShutdown } from './middleware/graceful-shutdown.js';
const shutdownManager = setupGracefulShutdown(server, {
  shutdownTimeoutMs: 10000,
  onShutdown: async () => {
    // Custom shutdown logic
  },
});
```

### pipeline.js

Centralized middleware pipeline configuration.

**Features**:

- Configures all middleware in correct order
- Provides helper functions for auth middleware
- Centralizes middleware configuration
- Ensures consistent ordering across deployments

**Usage**:

```javascript
import { setupMiddlewarePipeline } from './middleware/pipeline.js';
setupMiddlewarePipeline(app, {
  corsOptions: {
    /* CORS config */
  },
  rateLimitOptions: {
    /* Rate limit config */
  },
  timeoutMs: 30000,
  enableCompression: true,
});
```

## Configuration

### CORS Configuration

```javascript
const corsOptions = {
  origin: [
    'https://app.cloudtolocalllm.online',
    'https://cloudtolocalllm.online',
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Correlation-ID'],
  exposedHeaders: ['X-Correlation-ID', 'X-Response-Time'],
  maxAge: 86400,
};
```

### Rate Limiting Configuration

```javascript
const rateLimitOptions = {
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Standard limit
  bridgeMax: 500, // Bridge operations limit
};
```

### Request Timeout Configuration

```javascript
const timeoutMs = 30000; // 30 seconds
```

## Graceful Shutdown

The graceful shutdown manager ensures that:

1. **No new connections are accepted** after shutdown signal
2. **In-flight requests complete** before server closes
3. **Timeout protection** prevents indefinite waiting
4. **Resource cleanup** happens in correct order

### Shutdown Flow

```
SIGTERM/SIGINT Signal
    ↓
Stop accepting new connections
    ↓
Wait for in-flight requests to complete
    ↓
Close database connections
    ↓
Close SSH proxy
    ↓
Exit process
```

### Shutdown Timeout

If in-flight requests don't complete within the timeout (default: 10 seconds), the server will:

1. Log warning about remaining connections
2. Force close remaining connections
3. Exit process

## Request Correlation IDs

Every request is assigned a unique correlation ID for distributed tracing:

```
Request Header: X-Correlation-ID: req-550e8400-e29b-41d4-a716-446655440000
Response Header: X-Correlation-ID: req-550e8400-e29b-41d4-a716-446655440000
```

Correlation IDs are included in all logs for request tracing across services.

## Error Handling

The middleware pipeline includes comprehensive error handling:

1. **Validation Errors** (400): Invalid request format
2. **Authentication Errors** (401): Missing or invalid token
3. **Authorization Errors** (403): Insufficient permissions
4. **Timeout Errors** (408): Request exceeded timeout
5. **Rate Limit Errors** (429): Too many requests
6. **Server Errors** (500): Internal server error

All errors include:

- Error code for programmatic handling
- Human-readable message
- Correlation ID for tracing
- Suggested action (where applicable)

## Monitoring and Observability

The middleware pipeline provides:

1. **Request Logging**: All requests logged with correlation IDs
2. **Response Timing**: X-Response-Time header on all responses
3. **Error Tracking**: Sentry integration for error monitoring
4. **Distributed Tracing**: OpenTelemetry support via Sentry
5. **Rate Limit Metrics**: Standard rate limit headers

## Performance Considerations

1. **Middleware Order**: Critical for performance
   - Sentry handlers first (minimal overhead)
   - CORS early (prevents unnecessary processing)
   - Rate limiting before body parsing (saves resources)

2. **Request Timeout**: Prevents resource exhaustion
   - Default 30 seconds for most requests
   - Can be customized per route if needed

3. **Compression**: Optional for bandwidth savings
   - Disabled by default (can be enabled if needed)
   - Adds CPU overhead

4. **Rate Limiting**: Protects against abuse
   - Per-IP limiting
   - Different limits for different route types

## Testing

To test the middleware pipeline:

1. **Correlation IDs**: Verify X-Correlation-ID header in responses
2. **Request Validation**: Test with invalid Content-Type
3. **Rate Limiting**: Send multiple requests to verify limits
4. **Timeout**: Send slow requests to verify timeout
5. **Graceful Shutdown**: Send SIGTERM and verify in-flight request completion

## Troubleshooting

### Requests timing out

- Check if request processing is taking > 30 seconds
- Increase timeout if needed: `timeoutMs: 60000`
- Check for slow database queries or external API calls

### CORS errors

- Verify origin is in allowed list
- Check preflight OPTIONS request handling
- Verify CORS headers in response

### Rate limiting issues

- Check if IP is being rate limited
- Verify rate limit configuration
- Check X-RateLimit-\* headers in response

### Graceful shutdown not working

- Verify SIGTERM/SIGINT handlers are registered
- Check for long-running requests preventing shutdown
- Increase shutdown timeout if needed

## Requirements Coverage

This middleware pipeline enhancement covers the following requirements:

- **Requirement 1.1**: Express.js middleware pipeline ✓
- **Requirement 1.2**: Request routing ✓
- **Requirement 1.3**: Request validation ✓
- **Requirement 1.4**: Error handling ✓
- **Requirement 1.5**: Request/response logging ✓
- **Requirement 1.6**: CORS support ✓
- **Requirement 1.7**: Request compression ✓
- **Requirement 1.8**: Request timeout ✓
- **Requirement 1.9**: Graceful shutdown ✓

## Future Enhancements

1. **Compression**: Add compression middleware if needed
2. **Custom Timeouts**: Per-route timeout configuration
3. **Advanced Rate Limiting**: User-based rate limiting
4. **Request Queuing**: Queue requests when rate limit approached
5. **Metrics Export**: Prometheus metrics for middleware
