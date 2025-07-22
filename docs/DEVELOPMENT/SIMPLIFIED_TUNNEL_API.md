# Simplified Tunnel System API Documentation

## Overview

The Simplified Tunnel System provides a streamlined architecture for connecting cloud-based web interfaces with local Ollama instances. This document describes the API endpoints, WebSocket protocol, and integration patterns for the new tunnel system.

## Architecture Summary

```
[Web User] → [Cloud Proxy] → [WebSocket] → [Desktop Client] → [Local Ollama]
     ↑              ↑             ↑              ↑              ↑
   Browser      Express.js    Single WS    SimpleTunnelClient  localhost:11434
```

## Authentication

All API endpoints require JWT authentication via Auth0. Include the token in the Authorization header:

```
Authorization: Bearer <jwt_token>
```

## WebSocket Connection

### Endpoint
```
wss://api.cloudtolocalllm.online/ws/tunnel?token=<jwt_token>
```

### Connection Flow
1. Desktop client connects with JWT token as query parameter
2. Server validates token and extracts user ID
3. Connection is established and health monitoring begins
4. Client can now receive HTTP requests to forward to local Ollama

### Message Protocol

All WebSocket messages use JSON format with the following structure:

#### Base Message Format
```json
{
  "type": "message_type",
  "id": "unique_message_id",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

#### HTTP Request Message (Cloud → Desktop)
```json
{
  "type": "http_request",
  "id": "req_abc123",
  "method": "POST",
  "path": "/api/chat",
  "headers": {
    "content-type": "application/json",
    "user-agent": "CloudToLocalLLM/1.0"
  },
  "body": "{\"model\":\"llama2\",\"prompt\":\"Hello\"}"
}
```

#### HTTP Response Message (Desktop → Cloud)
```json
{
  "type": "http_response",
  "id": "req_abc123",
  "status": 200,
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"response\":\"Hello! How can I help?\"}"
}
```

#### Ping Message (Cloud → Desktop)
```json
{
  "type": "ping",
  "id": "ping_123",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

#### Pong Message (Desktop → Cloud)
```json
{
  "type": "pong",
  "id": "ping_123",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

#### Error Message (Bidirectional)
```json
{
  "type": "error",
  "id": "req_abc123",
  "error": "Request timeout",
  "code": "REQUEST_TIMEOUT"
}
```

## HTTP API Endpoints

### Health Check Endpoints

#### GET /api/tunnel/health
Check overall tunnel system health.

**Response:**
```json
{
  "status": "healthy",
  "checks": {
    "hasConnections": true,
    "successRateOk": true,
    "timeoutRateOk": true,
    "averageResponseTimeOk": true
  },
  "connections": {
    "total": 5,
    "connectedUsers": 3,
    "totalCreated": 15
  },
  "requests": {
    "total": 1250,
    "successful": 1200,
    "failed": 30,
    "timeout": 20,
    "pending": 5,
    "successRate": 96.0,
    "timeoutRate": 1.6
  },
  "performance": {
    "averageResponseTime": 245.5
  },
  "timestamp": "2025-01-15T10:30:00Z"
}
```

#### GET /api/tunnel/health/:userId
Check specific user's tunnel connection status.

**Headers:**
- `Authorization: Bearer <jwt_token>`

**Response:**
```json
{
  "userId": "auth0|user123",
  "connected": true,
  "lastPing": "2025-01-15T10:29:30Z",
  "pendingRequests": 2,
  "timestamp": "2025-01-15T10:30:00Z"
}
```

**Error Responses:**
- `403 Forbidden` - User can only check their own tunnel status
- `401 Unauthorized` - Invalid or missing JWT token

### Status and Metrics

#### GET /api/tunnel/status
Get user's tunnel status and system metrics.

**Headers:**
- `Authorization: Bearer <jwt_token>`

**Response:**
```json
{
  "user": {
    "userId": "auth0|user123",
    "connected": true,
    "lastPing": "2025-01-15T10:29:30Z",
    "pendingRequests": 1
  },
  "system": {
    "connections": {
      "total": 5,
      "connectedUsers": 3,
      "totalCreated": 15
    },
    "requests": {
      "total": 1250,
      "successful": 1200,
      "failed": 30,
      "timeout": 20,
      "pending": 8,
      "successRate": 96.0,
      "timeoutRate": 1.6
    },
    "performance": {
      "averageResponseTime": 245.5
    }
  },
  "timestamp": "2025-01-15T10:30:00Z"
}
```

#### GET /api/tunnel/metrics
Get detailed performance metrics for authenticated user.

**Headers:**
- `Authorization: Bearer <jwt_token>`

**Response:**
```json
{
  "user": {
    "userId": "auth0|user123",
    "connected": true,
    "lastPing": "2025-01-15T10:29:30Z",
    "pendingRequests": 1
  },
  "system": {
    "connections": {
      "total": 5,
      "connectedUsers": 3,
      "totalCreated": 15
    },
    "requests": {
      "total": 1250,
      "successful": 1200,
      "failed": 30,
      "timeout": 20,
      "pending": 8,
      "successRate": 96.0,
      "timeoutRate": 1.6
    }
  },
  "performance": {
    "averageResponseTime": 245.5,
    "successRate": 96.0,
    "timeoutRate": 1.6
  },
  "timestamp": "2025-01-15T10:30:00Z"
}
```

### Proxy Endpoints

#### ALL /api/tunnel/:userId/*
Proxy HTTP requests to user's desktop client.

**Headers:**
- `Authorization: Bearer <jwt_token>`
- Any headers to forward to local Ollama

**Parameters:**
- `userId` - Target user ID (must match authenticated user)
- `*` - Path to forward to local Ollama (e.g., `/api/chat`)

**Request Body:**
Any body content to forward to local Ollama.

**Response:**
Returns the response from local Ollama, including status code, headers, and body.

**Example Request:**
```
POST /api/tunnel/auth0|user123/api/chat
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...
Content-Type: application/json

{
  "model": "llama2",
  "prompt": "Hello, how are you?",
  "stream": false
}
```

**Example Response:**
```json
{
  "model": "llama2",
  "created_at": "2025-01-15T10:30:00Z",
  "response": "Hello! I'm doing well, thank you for asking. How can I help you today?",
  "done": true
}
```

**Error Responses:**

##### 401 Unauthorized
```json
{
  "error": "Authentication failed",
  "message": "Authorization header with Bearer token is required",
  "code": "AUTH_TOKEN_MISSING"
}
```

##### 403 Forbidden
```json
{
  "error": "Access denied",
  "message": "You can only access your own tunnel",
  "code": "AUTH_TOKEN_INVALID"
}
```

##### 503 Service Unavailable
```json
{
  "error": "Service unavailable",
  "message": "Please ensure the CloudToLocalLLM desktop client is running and connected",
  "code": "DESKTOP_CLIENT_DISCONNECTED"
}
```

##### 504 Gateway Timeout
```json
{
  "error": "Gateway timeout",
  "message": "Request timed out after 30 seconds",
  "code": "REQUEST_TIMEOUT"
}
```

##### 429 Too Many Requests
```json
{
  "error": "Rate limit exceeded",
  "message": "Too many requests. Please try again later.",
  "code": "RATE_LIMIT_EXCEEDED",
  "retryAfter": 60
}
```

## Error Codes

| Code | Description | HTTP Status |
|------|-------------|-------------|
| `AUTH_TOKEN_MISSING` | Authorization header missing | 401 |
| `AUTH_TOKEN_INVALID` | Invalid or malformed token | 403 |
| `AUTH_TOKEN_EXPIRED` | Token has expired | 403 |
| `DESKTOP_CLIENT_DISCONNECTED` | Desktop client not connected | 503 |
| `REQUEST_TIMEOUT` | Request timed out (30s) | 504 |
| `WEBSOCKET_CONNECTION_FAILED` | WebSocket connection failed | 500 |
| `WEBSOCKET_SEND_FAILED` | Failed to send WebSocket message | 503 |
| `INVALID_MESSAGE_FORMAT` | Invalid message format | 400 |
| `MESSAGE_SERIALIZATION_FAILED` | Message serialization failed | 500 |
| `RATE_LIMIT_EXCEEDED` | Rate limit exceeded | 429 |
| `INTERNAL_SERVER_ERROR` | Internal server error | 500 |

## Rate Limiting

The tunnel system implements rate limiting to prevent abuse:

- **Per User Limits:**
  - 1000 requests per 15-minute window
  - 100 requests per 1-minute burst window
  - 50 concurrent requests maximum

- **Headers:**
  - `X-RateLimit-Limit` - Request limit per window
  - `X-RateLimit-Remaining` - Remaining requests in current window
  - `X-RateLimit-Reset` - Time when the rate limit resets (Unix timestamp)

## Security Features

### Authentication & Authorization
- JWT token validation using Auth0 JWKS
- User isolation - users can only access their own tunnels
- Token expiration and refresh handling

### Connection Security
- WSS (WebSocket Secure) for all WebSocket connections
- HTTPS for all HTTP endpoints
- Origin validation for WebSocket connections
- Certificate validation and pinning

### Audit Logging
- All authentication events logged
- Cross-user access attempts logged
- Rate limit violations logged
- Security events include correlation IDs for tracking

## Integration Examples

### Desktop Client Integration

```dart
// Connect to tunnel WebSocket
final client = SimpleTunnelClient(authService: authService);
await client.connect();

// Handle incoming HTTP requests
client.onHttpRequest = (request) async {
  final response = await forwardToLocalOllama(request);
  return response;
};
```

### Container Integration

```javascript
// Set environment variable for container
process.env.OLLAMA_BASE_URL = `https://api.cloudtolocalllm.online/api/tunnel/${userId}`;

// Use standard HTTP client
const response = await fetch(`${process.env.OLLAMA_BASE_URL}/api/chat`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${jwtToken}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    model: 'llama2',
    prompt: 'Hello world'
  })
});
```

### Web Client Integration

```javascript
// Configure API client to use tunnel proxy
const apiClient = new OllamaClient({
  baseURL: `https://api.cloudtolocalllm.online/api/tunnel/${userId}`,
  headers: {
    'Authorization': `Bearer ${jwtToken}`
  }
});

// Make requests normally
const response = await apiClient.chat({
  model: 'llama2',
  messages: [{ role: 'user', content: 'Hello!' }]
});
```

## Performance Considerations

### Connection Management
- Single WebSocket connection per desktop client
- Connection pooling for efficient resource usage
- Automatic reconnection with exponential backoff

### Request Handling
- 30-second timeout for all requests
- Request correlation for proper response matching
- Message queuing during connection interruptions

### Monitoring
- Real-time performance metrics
- Health check endpoints for monitoring
- Alerting for performance degradation

## Migration from Legacy System

### Key Differences
- Single WebSocket connection (vs. multiple encrypted connections)
- Standard HTTP proxy pattern (vs. custom encryption layers)
- Simplified message protocol (vs. complex multi-layer protocol)
- JWT authentication (vs. custom authentication)

### Compatibility
- Maintains same external API for containers
- Desktop client requires update to SimpleTunnelClient
- Web interface remains unchanged

## Troubleshooting

### Common Issues

#### Desktop Client Won't Connect
1. Check JWT token validity
2. Verify network connectivity to `wss://api.cloudtolocalllm.online/ws/tunnel`
3. Check firewall settings
4. Review desktop client logs for specific errors

#### Requests Timing Out
1. Verify local Ollama is running on `localhost:11434`
2. Check desktop client connection status
3. Monitor network latency
4. Review tunnel proxy logs

#### High Error Rates
1. Check desktop client stability
2. Monitor connection quality
3. Review rate limiting settings
4. Check local Ollama performance

### Logging and Debugging

All tunnel operations include correlation IDs for tracking requests across the system. Use these IDs to trace issues through logs:

```
[2025-01-15T10:30:00Z] INFO: Request started [correlationId=abc123, userId=auth0|user123, method=POST, path=/api/chat]
[2025-01-15T10:30:01Z] INFO: Request completed [correlationId=abc123, responseTime=1250ms, statusCode=200]
```

## Support

For technical support or questions about the Simplified Tunnel System API:

1. Check the troubleshooting section above
2. Review system logs with correlation IDs
3. Contact the development team with specific error details
4. Include relevant correlation IDs and timestamps in support requests