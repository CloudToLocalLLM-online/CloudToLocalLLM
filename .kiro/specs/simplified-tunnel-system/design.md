# Design Document

## Overview

The simplified tunnel system replaces the current complex multi-layered architecture with a streamlined design using a single WebSocket connection and standard HTTP proxy patterns. This design reduces complexity while maintaining security and reliability.

## Architecture

### High-Level Architecture

```
[Web User] → [Cloud Proxy] → [WebSocket] → [Desktop Client] → [Local Ollama]
     ↑              ↑             ↑              ↑              ↑
   Browser      Express.js    Single WS    SimpleTunnelClient  localhost:11434
```

### Key Architectural Decisions

1. **Single WebSocket Connection**: Each desktop client maintains one persistent WebSocket to the cloud
2. **HTTP Proxy Pattern**: Cloud containers make standard HTTP requests to a proxy endpoint
3. **JWT Authentication**: Simple token-based authentication for user identification
4. **Request Correlation**: Use correlation IDs to match requests with responses
5. **No Custom Encryption**: Rely on HTTPS/WSS for transport security

## Components and Interfaces

### 1. SimpleTunnelClient (Desktop)

**Purpose**: Lightweight desktop client that maintains tunnel connection

**Key Methods**:
- `connect()`: Establish WebSocket connection with authentication
- `handleRequest(message)`: Forward HTTP requests to local Ollama
- `sendResponse(response)`: Send HTTP responses back through tunnel
- `reconnect()`: Handle connection recovery with exponential backoff

**Configuration**:
- WebSocket URL: `wss://api.cloudtolocalllm.online/ws/tunnel`
- Local Ollama URL: `http://localhost:11434`
- Reconnection intervals: 1s, 2s, 4s, 8s, 16s, 30s (max)

### 2. TunnelProxy (Cloud API)

**Purpose**: Cloud-side proxy that routes requests to appropriate desktop clients

**Key Endpoints**:
- `GET /api/tunnel/:userId/health`: Health check for user's tunnel
- `ALL /api/tunnel/:userId/*`: Proxy requests to user's desktop client

**Key Methods**:
- `validateToken(jwt)`: Validate JWT and extract user ID
- `forwardRequest(userId, request)`: Send request through WebSocket
- `handleTimeout(requestId)`: Handle request timeouts (30s)

### 3. WebSocket Message Protocol

**Request Message** (Cloud → Desktop):
```json
{
  "type": "http_request",
  "id": "req_abc123",
  "method": "POST",
  "path": "/api/chat",
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"model\":\"llama2\",\"prompt\":\"Hello\"}"
}
```

**Response Message** (Desktop → Cloud):
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

**Control Messages**:
```json
{
  "type": "ping",
  "id": "ping_123",
  "timestamp": "2025-01-15T10:30:00Z"
}

{
  "type": "pong", 
  "id": "ping_123",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

## Data Models

### TunnelConnection
```typescript
interface TunnelConnection {
  userId: string;
  websocket: WebSocket;
  isConnected: boolean;
  lastPing: Date;
  pendingRequests: Map<string, PendingRequest>;
}
```

### PendingRequest
```typescript
interface PendingRequest {
  id: string;
  timestamp: Date;
  timeout: NodeJS.Timeout;
  resolve: (response: HttpResponse) => void;
  reject: (error: Error) => void;
}
```

### HttpRequest/Response
```typescript
interface HttpRequest {
  method: string;
  path: string;
  headers: Record<string, string>;
  body?: string;
}

interface HttpResponse {
  status: number;
  headers: Record<string, string>;
  body: string;
}
```

## Error Handling

### Connection Errors
- **Desktop Offline**: Return HTTP 503 Service Unavailable
- **Authentication Failed**: Return HTTP 401 Unauthorized  
- **Request Timeout**: Return HTTP 504 Gateway Timeout after 30s
- **Invalid Request**: Return HTTP 400 Bad Request

### Reconnection Strategy
1. Detect connection loss via ping/pong or WebSocket events
2. Wait with exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (max)
3. Retry connection with fresh JWT token
4. Reset backoff on successful connection

### Error Logging
- Structured JSON logs with correlation IDs
- Separate log levels for debugging vs production
- Include user ID (hashed) for debugging without PII exposure

## Testing Strategy

### Unit Tests
- SimpleTunnelClient connection and reconnection logic
- TunnelProxy request routing and timeout handling
- Message serialization/deserialization
- JWT token validation

### Integration Tests
- End-to-end request/response flow
- Connection recovery scenarios
- Multiple concurrent users
- Error handling and timeouts

### Load Tests
- 100+ concurrent desktop clients
- 1000+ requests per minute per client
- Connection stability over 24+ hours
- Memory usage and connection pooling

### Migration Tests
- Gradual rollout with A/B testing
- Backward compatibility during transition
- Performance comparison with current system
- Rollback procedures

## Security Considerations

### Authentication
- JWT tokens with 1-hour expiration
- Token refresh mechanism for long-running connections
- User ID extraction and validation

### User Isolation
- Strict user ID validation on all requests
- No shared state between user connections
- Request routing validation

### Transport Security
- WSS (WebSocket Secure) for all connections
- HTTPS for all HTTP endpoints
- Certificate validation and pinning

### Rate Limiting
- Per-user request rate limits
- Connection attempt rate limits
- Resource usage monitoring

## Performance Optimizations

### Connection Management
- Connection pooling for WebSocket connections
- Efficient message queuing and correlation
- Memory-efficient request/response handling

### Monitoring
- Connection health metrics
- Request latency tracking
- Error rate monitoring
- Resource usage alerts

### Caching
- JWT token validation caching
- User connection state caching
- Health check result caching