# Simplified Tunnel System Architecture

## 📋 Overview

The Simplified Tunnel System represents a major architectural evolution in CloudToLocalLLM, replacing the complex multi-layered tunnel architecture with a streamlined design that reduces codebase complexity by approximately 70% while maintaining security and reliability.

**Key Design Principles:**
- **Single WebSocket Connection**: One persistent connection per desktop client
- **Standard HTTP Proxy Patterns**: No custom tunnel-aware code required
- **JWT Authentication**: Simple token-based user identification
- **Request Correlation**: Unique IDs for matching requests with responses
- **No Custom Encryption**: Rely on HTTPS/WSS for transport security

---

## 🏗️ **Architecture Overview**

### **High-Level Flow**
```
[Web User] → [Cloud Proxy] → [WebSocket] → [Desktop Client] → [Local Ollama]
     ↑              ↑             ↑              ↑              ↑
   Browser      Express.js    Single WS    SimpleTunnelClient  localhost:11434
```

### **Key Architectural Decisions**
1. **Single WebSocket Connection**: Each desktop client maintains one persistent WebSocket to the cloud
2. **HTTP Proxy Pattern**: Cloud containers make standard HTTP requests to a proxy endpoint
3. **JWT Authentication**: Simple token-based authentication for user identification
4. **Request Correlation**: Use correlation IDs to match requests with responses
5. **No Custom Encryption**: Rely on HTTPS/WSS for transport security

---

## 🔌 **Message Protocol Implementation**

### **Core Message Protocol**
**Location**: `api-backend/tunnel/message-protocol.js`

The message protocol provides a standardized communication layer between cloud API and desktop clients with comprehensive type definitions and validation.

#### **Message Types**
```javascript
export const MESSAGE_TYPES = {
  HTTP_REQUEST: 'http_request',
  HTTP_RESPONSE: 'http_response',
  PING: 'ping',
  PONG: 'pong',
  ERROR: 'error'
};
```

#### **HTTP Request Message**
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

#### **HTTP Response Message**
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

#### **Control Messages**
```json
// Ping Message
{
  "type": "ping",
  "id": "ping_123",
  "timestamp": "2025-01-15T10:30:00Z"
}

// Pong Message
{
  "type": "pong", 
  "id": "ping_123",
  "timestamp": "2025-01-15T10:30:00Z"
}

// Error Message
{
  "type": "error",
  "id": "req_abc123",
  "error": "Connection timeout",
  "code": 504
}
```

### **MessageProtocol Class**
The `MessageProtocol` class provides comprehensive utilities for message handling:

#### **Message Creation**
```javascript
// Create request message
const requestMsg = MessageProtocol.createRequestMessage({
  method: 'POST',
  path: '/api/chat',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ model: 'llama2', prompt: 'Hello' })
});

// Create response message
const responseMsg = MessageProtocol.createResponseMessage(requestId, {
  status: 200,
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ response: 'Hello! How can I help?' })
});
```

#### **Serialization & Validation**
```javascript
// Serialize message to JSON
const jsonString = MessageProtocol.serialize(message);

// Deserialize and validate
const message = MessageProtocol.deserialize(jsonString);

// Validate message types
const isValid = MessageProtocol.validateTunnelMessage(message);
```

#### **HTTP Object Extraction**
```javascript
// Extract HTTP request from tunnel message
const httpRequest = MessageProtocol.extractHttpRequest(tunnelRequestMessage);

// Extract HTTP response from tunnel message
const httpResponse = MessageProtocol.extractHttpResponse(tunnelResponseMessage);
```

---

## 🖥️ **Component Architecture**

### **1. SimpleTunnelClient (Desktop)**
**Purpose**: Lightweight desktop client that maintains tunnel connection

**Key Responsibilities**:
- Establish WebSocket connection with authentication
- Forward HTTP requests to local Ollama
- Send HTTP responses back through tunnel
- Handle connection recovery with exponential backoff

**Configuration**:
- WebSocket URL: `wss://api.cloudtolocalllm.online/ws/tunnel`
- Local Ollama URL: `http://localhost:11434`
- Reconnection intervals: 1s, 2s, 4s, 8s, 16s, 30s (max)

### **2. TunnelProxy (Cloud API)**
**Purpose**: Cloud-side proxy that routes requests to appropriate desktop clients

**Key Endpoints**:
- `GET /api/tunnel/:userId/health`: Health check for user's tunnel
- `ALL /api/tunnel/:userId/*`: Proxy requests to user's desktop client

**Key Methods**:
- `validateToken(jwt)`: Validate JWT and extract user ID
- `forwardRequest(userId, request)`: Send request through WebSocket
- `handleTimeout(requestId)`: Handle request timeouts (30s)

### **3. WebSocket Connection Management**
**Features**:
- Persistent connection per desktop client
- Automatic reconnection with exponential backoff
- Ping/pong health monitoring
- Request correlation and timeout handling

---

## 📊 **Data Models**

### **TypeScript-Style Definitions**
```javascript
/**
 * @typedef {Object} HttpRequest
 * @property {string} method - HTTP method (GET, POST, PUT, DELETE, etc.)
 * @property {string} path - Request path (e.g., "/api/chat")
 * @property {Record<string, string>} headers - HTTP headers
 * @property {string} [body] - Request body (optional)
 */

/**
 * @typedef {Object} HttpResponse
 * @property {number} status - HTTP status code
 * @property {Record<string, string>} headers - HTTP response headers
 * @property {string} body - Response body
 */

/**
 * @typedef {Object} TunnelConnection
 * @property {string} userId - User identifier
 * @property {WebSocket} websocket - WebSocket connection
 * @property {boolean} isConnected - Connection status
 * @property {Date} lastPing - Last ping timestamp
 * @property {Map<string, PendingRequest>} pendingRequests - Active requests
 */
```

---

## 🔒 **Security Architecture**

### **Authentication**
- **JWT Tokens**: 1-hour expiration with refresh mechanism
- **User ID Extraction**: Secure user identification from tokens
- **Token Validation**: Comprehensive validation on all requests

### **User Isolation**
- **Strict User ID Validation**: All requests validated against user identity
- **No Shared State**: Complete isolation between user connections
- **Request Routing Validation**: Ensures requests reach correct user's desktop

### **Transport Security**
- **WSS (WebSocket Secure)**: All connections use secure WebSocket
- **HTTPS Endpoints**: All HTTP endpoints use TLS encryption
- **Certificate Validation**: Proper certificate validation and pinning

### **Rate Limiting**
- **Per-User Limits**: Request rate limits per user
- **Connection Limits**: Connection attempt rate limiting
- **Resource Monitoring**: Continuous resource usage monitoring

---

## 🔄 **Error Handling**

### **Connection Errors**
- **Desktop Offline**: Return HTTP 503 Service Unavailable
- **Authentication Failed**: Return HTTP 401 Unauthorized  
- **Request Timeout**: Return HTTP 504 Gateway Timeout after 30s
- **Invalid Request**: Return HTTP 400 Bad Request

### **Reconnection Strategy**
1. Detect connection loss via ping/pong or WebSocket events
2. Wait with exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (max)
3. Retry connection with fresh JWT token
4. Reset backoff on successful connection

### **Error Logging**
- **Structured JSON Logs**: Correlation IDs for debugging
- **Separate Log Levels**: Debug vs production logging
- **User ID Hashing**: Privacy-preserving debugging information

---

## 🚀 **Performance Optimizations**

### **Connection Management**
- **Connection Pooling**: Efficient WebSocket connection management
- **Message Queuing**: Optimized message correlation and queuing
- **Memory Efficiency**: Minimal memory footprint for request/response handling

### **Monitoring**
- **Connection Health Metrics**: Real-time connection monitoring
- **Request Latency Tracking**: Performance measurement and optimization
- **Error Rate Monitoring**: Comprehensive error tracking and alerting
- **Resource Usage Alerts**: Proactive resource monitoring

### **Caching**
- **JWT Token Validation Caching**: Reduced validation overhead
- **User Connection State Caching**: Optimized connection management
- **Health Check Result Caching**: Efficient health monitoring

---

## 🧪 **Testing Strategy**

### **Unit Tests**
- **Message Protocol Validation**: Comprehensive message format testing
- **Serialization/Deserialization**: JSON handling and edge cases
- **HTTP Request/Response Validation**: Input validation testing
- **JWT Token Validation**: Authentication and authorization testing

### **Integration Tests**
- **End-to-End Request/Response Flow**: Complete tunnel communication
- **Connection Recovery Scenarios**: Failure and reconnection testing
- **Multiple Concurrent Users**: Multi-user isolation testing
- **Error Handling and Timeouts**: Comprehensive error scenario testing

### **Load Tests**
- **100+ Concurrent Desktop Clients**: Scalability testing
- **1000+ Requests per Minute**: High-throughput testing
- **24+ Hour Connection Stability**: Long-running stability testing
- **Memory Usage and Connection Pooling**: Resource efficiency testing

---

## 🔄 **Migration Strategy**

### **Gradual Rollout**
- **A/B Testing**: Gradual rollout with performance comparison
- **Backward Compatibility**: Maintain existing system during transition
- **Performance Benchmarking**: Continuous performance comparison
- **Rollback Procedures**: Immediate rollback capability on issues

### **Implementation Status**
- ✅ **Task 1**: Core message protocol and data models (COMPLETED)
- 🔄 **Task 2**: SimpleTunnelClient for desktop platform (IN PROGRESS)
- ⏳ **Task 3**: Cloud-side TunnelProxy service (PLANNED)
- ⏳ **Task 4**: API backend integration (PLANNED)

---

## 🔧 **Development Guidelines**

### **Message Protocol Usage**
```javascript
// Always validate messages before processing
if (!MessageProtocol.validateTunnelMessage(message)) {
  throw new Error('Invalid message format');
}

// Use correlation IDs for request tracking
const requestId = message.id;
const response = await processRequest(message);
const responseMessage = MessageProtocol.createResponseMessage(requestId, response);
```

### **Error Handling Patterns**
```javascript
// Structured error responses
const errorMessage = MessageProtocol.createErrorMessage(
  requestId,
  'Connection timeout',
  504
);

// Comprehensive logging
logger.error('Tunnel request failed', {
  requestId,
  userId: hashedUserId,
  error: error.message,
  timestamp: new Date().toISOString()
});
```

---

This simplified tunnel architecture provides a robust, maintainable, and secure foundation for CloudToLocalLLM's tunnel communication while significantly reducing system complexity and improving developer experience.