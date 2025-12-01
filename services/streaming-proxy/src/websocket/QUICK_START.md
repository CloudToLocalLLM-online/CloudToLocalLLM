# WebSocket Connection Management - Quick Start

## Installation

No additional dependencies required. Uses the `ws` package already in the project.

## Basic Setup

### 1. Create WebSocket Server

```typescript
import { WebSocketServer } from 'ws';
import { WebSocketHandlerImpl } from './websocket';
import { JWTValidationMiddleware } from './middleware';
import { TokenBucketRateLimiter } from './rate-limiter';

// Create dependencies
const authMiddleware = new JWTValidationMiddleware({
  domain: process.env.SUPABASE_AUTH_DOMAIN!,
  audience: process.env.SUPABASE_AUTH_AUDIENCE!,
  issuer: process.env.SUPABASE_AUTH_ISSUER!,
});

const rateLimiter = new TokenBucketRateLimiter();

// Create WebSocket server
const wss = new WebSocketServer({ noServer: true });

// Create handler
const wsHandler = new WebSocketHandlerImpl(wss, authMiddleware, rateLimiter);
```

### 2. Handle HTTP Upgrade

```typescript
import { createServer } from 'http';

const server = createServer();

server.on('upgrade', async (req, socket, head) => {
  await wsHandler.handleUpgrade(req, socket, head);
});

server.listen(3001, () => {
  console.log('WebSocket server listening on port 3001');
});
```

### 3. Client Connection

```typescript
// Client-side (browser or Node.js)
const token = 'your-jwt-token';
const ws = new WebSocket(`ws://localhost:3001?token=${token}`);

ws.onopen = () => {
  console.log('Connected');
  
  // Send request
  ws.send(JSON.stringify({
    type: 'request',
    requestId: '123',
    payload: { action: 'test' },
    timestamp: Date.now(),
  }));
};

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  console.log('Response:', message);
};

ws.onerror = (error) => {
  console.error('Error:', error);
};

ws.onclose = (event) => {
  console.log(`Closed: ${event.code} - ${event.reason}`);
};
```

## Advanced Features

### Enable Compression

```typescript
import { CompressionManager } from './websocket';

const compressionManager = CompressionManager.createDefault();

const wss = new WebSocketServer({
  noServer: true,
  perMessageDeflate: compressionManager.getCompressionOptions(),
});

compressionManager.configureServer(wss);
```

### Monitor Heartbeat

```typescript
import { HeartbeatManager } from './websocket';

const heartbeatManager = new HeartbeatManager();

// Heartbeat is automatically managed by WebSocketHandlerImpl
// But you can use HeartbeatManager directly for custom monitoring

heartbeatManager.startHeartbeat(ws, (ws) => {
  console.log('Connection timeout');
  ws.close(1001, 'Connection timeout');
});
```

### Validate Frame Sizes

```typescript
import { FrameSizeValidator } from './websocket';

const validator = FrameSizeValidator.createDefault();

// Validation is automatically done by WebSocketHandlerImpl
// But you can use FrameSizeValidator directly for custom validation

ws.on('message', (data) => {
  if (!validator.validateAndHandle(ws, data.length, userId, connectionId)) {
    return; // Frame too large, connection closed
  }
  
  // Process message
});
```

### Graceful Shutdown

```typescript
import { GracefulCloseManager, CloseCode } from './websocket';

const closeManager = new GracefulCloseManager();

process.on('SIGTERM', async () => {
  console.log('Shutting down...');
  
  // Get all active connections
  const connections = []; // Get from wsHandler
  
  // Close all gracefully
  await closeManager.closeAll(connections, {
    code: CloseCode.SERVICE_RESTART,
    reason: 'Server restart',
    timeout: 5000,
  });
  
  process.exit(0);
});
```

## Health Monitoring

```typescript
// Check connection health
const health = await wsHandler.checkConnectionHealth();

console.log({
  active: health.activeConnections,
  healthy: health.healthyConnections,
  unhealthy: health.unhealthyConnections,
  avgLatency: health.averageLatency,
});

// Get compression stats
const compressionStats = compressionManager.getStats();
console.log(`Compression ratio: ${compressionManager.getCompressionRatioPercent()}%`);

// Get frame size stats
const frameSizeStats = validator.getStats();
console.log(validator.getSummary());
```

## Common Patterns

### Pattern 1: Authenticated WebSocket with Rate Limiting

```typescript
// Server automatically handles authentication and rate limiting
// Client just needs to provide token in query string or header

const ws = new WebSocket(`ws://localhost:3001?token=${token}`);
```

### Pattern 2: Request-Response Pattern

```typescript
// Client
const requestId = crypto.randomUUID();

ws.send(JSON.stringify({
  type: 'request',
  requestId,
  payload: { action: 'getData' },
  timestamp: Date.now(),
}));

ws.onmessage = (event) => {
  const response = JSON.parse(event.data);
  if (response.requestId === requestId) {
    console.log('Response received:', response.payload);
  }
};
```

### Pattern 3: Heartbeat Monitoring

```typescript
// Server automatically sends pings every 30 seconds
// Client should respond to pings (most WebSocket libraries do this automatically)

// To manually handle pings:
ws.on('ping', () => {
  ws.pong();
});
```

### Pattern 4: Graceful Reconnection

```typescript
// Client
let ws;
let reconnectAttempts = 0;
const maxReconnectAttempts = 10;

function connect() {
  ws = new WebSocket(`ws://localhost:3001?token=${token}`);
  
  ws.onclose = (event) => {
    if (event.code === 1000 || event.code === 1001) {
      // Normal closure
      console.log('Connection closed normally');
      return;
    }
    
    // Abnormal closure - reconnect
    if (reconnectAttempts < maxReconnectAttempts) {
      reconnectAttempts++;
      const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000);
      console.log(`Reconnecting in ${delay}ms...`);
      setTimeout(connect, delay);
    }
  };
  
  ws.onopen = () => {
    reconnectAttempts = 0;
    console.log('Connected');
  };
}

connect();
```

## Troubleshooting

### Connection Refused

```
Error: Connection refused
```

**Solution**: Check that the server is running and the port is correct.

### Authentication Failed

```
Error: 401 Unauthorized - Invalid token
```

**Solution**: Verify the JWT token is valid and not expired.

### Rate Limit Exceeded

```
Error: 429 Too Many Requests
```

**Solution**: Reduce request rate or upgrade user tier.

### Message Too Large

```
Error: 1009 - Message too large
```

**Solution**: Reduce message size or split into multiple messages.

### Connection Timeout

```
Error: 1001 - Connection timeout
```

**Solution**: Check network connectivity and ensure client responds to pings.

## Next Steps

1. Read the full [README.md](./README.md) for detailed documentation
2. Check [IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md) for implementation details
3. Review [TASK_11_COMPLETION.md](./TASK_11_COMPLETION.md) for requirements verification
4. Integrate with ConnectionPool for SSH forwarding
5. Add metrics collection and monitoring
