# Design Document: API Backend Enhancement

## Overview

This design document outlines the architecture and implementation approach for enhancing the API backend service in CloudToLocalLLM. The API backend serves as the central hub for authentication, user management, tunnel coordination, and service orchestration.

### Design Goals

1. **Reliability**: Robust error handling and recovery mechanisms
2. **Scalability**: Horizontal scaling with stateless design
3. **Security**: Comprehensive authentication and authorization
4. **Performance**: Sub-200ms response times with caching
5. **Observability**: Complete monitoring and tracing
6. **Maintainability**: Clean architecture and clear separation of concerns

### Design Principles

- **Separation of Concerns**: Clear boundaries between routing, business logic, and data access
- **Middleware Pipeline**: Sequential processing of requests
- **Error Handling**: Comprehensive error categorization and recovery
- **Stateless Design**: Easy horizontal scaling
- **Observability**: Comprehensive logging and metrics
- **Security First**: Authentication and authorization on all protected endpoints

## Architecture

### API Backend System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client Applications                       │
│              (Desktop, Web, Mobile, Third-party)                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    HTTPS    │  (TLS 1.3)
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                      Load Balancer                               │
│                    (Nginx/Kubernetes)                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼────────┐  ┌────────▼────────┐  ┌──────▼────────┐
│  API Instance  │  │  API Instance   │  │  API Instance │
│      (v2.0)    │  │      (v2.0)     │  │      (v2.0)   │
└───────┬────────┘  └────────┬────────┘  └──────┬────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼──────────┐  ┌──────▼──────────┐  ┌────▼────────────┐
│  PostgreSQL      │  │  Redis Cache    │  │  Message Queue  │
│  (Primary)       │  │  (Session/Cache)│  │  (Events)       │
└──────────────────┘  └─────────────────┘  └─────────────────┘
        │
        └─────────────────────────────────────────┐
                                                  │
                    ┌─────────────────────────────┼──────────────┐
                    │                             │              │
            ┌───────▼────────┐          ┌────────▼────────┐  ┌──▼──────────┐
            │  Tunnel Service │          │ Streaming Proxy │  │ Admin Service│
            │   (Phase 2)     │          │   (Phase 2)     │  │   (v2.0)    │
            └────────────────┘          └─────────────────┘  └─────────────┘
```

### Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Express Application                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Middleware Pipeline                         │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  1. Sentry Request Handler                              │  │
│  │  2. CORS Middleware                                     │  │
│  │  3. Helmet Security Headers                             │  │
│  │  4. Request Logging (Winston)                           │  │
│  │  5. Request Validation                                  │  │
│  │  6. Rate Limiting                                       │  │
│  │  7. Authentication (JWT)                                │  │
│  │  8. Authorization (RBAC)                                │  │
│  │  9. Request Compression                                 │  │
│  │  10. Error Handling                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│  ┌──────────────────────────▼──────────────────────────────┐  │
│  │              Route Handlers                             │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  • /auth - Authentication endpoints                     │  │
│  │  • /users - User management                             │  │
│  │  • /tunnel - Tunnel operations                          │  │
│  │  • /proxy - Streaming proxy management                  │  │
│  │  • /admin - Admin operations                            │  │
│  │  • /health - Health checks                              │  │
│  │  • /metrics - Prometheus metrics                        │  │
│  │  • /webhooks - Webhook management                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│  ┌──────────────────────────▼──────────────────────────────┐  │
│  │              Service Layer                              │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  • AuthService - JWT validation, token refresh          │  │
│  │  • UserService - User management and profiles           │  │
│  │  • TunnelService - Tunnel coordination                  │  │
│  │  • ProxyService - Streaming proxy management            │  │
│  │  • AdminService - Admin operations                      │  │
│  │  • MetricsService - Metrics collection                  │  │
│  │  • WebhookService - Webhook management                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│  ┌──────────────────────────▼──────────────────────────────┐  │
│  │              Data Access Layer                          │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  • UserRepository - User data access                    │  │
│  │  • TunnelRepository - Tunnel data access                │  │
│  │  • SessionRepository - Session management               │  │
│  │  • AuditRepository - Audit log storage                  │  │
│  │  • MetricsRepository - Metrics storage                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│  ┌──────────────────────────▼──────────────────────────────┐  │
│  │              Database Layer                             │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  • PostgreSQL Connection Pool                           │  │
│  │  • Redis Cache Layer                                    │  │
│  │  • Message Queue (RabbitMQ/Redis)                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Request Flow

### Standard Request Flow

```
1. Client Request
   ↓
2. Load Balancer Routes to API Instance
   ↓
3. Sentry Request Handler (Tracing)
   ↓
4. CORS Middleware (Preflight Check)
   ↓
5. Helmet Security Headers
   ↓
6. Request Logging (Correlation ID)
   ↓
7. Request Validation
   ↓
8. Rate Limiting Check
   ↓
9. JWT Authentication (if protected)
   ↓
10. RBAC Authorization (if admin)
    ↓
11. Request Compression
    ↓
12. Route Handler
    ↓
13. Service Layer Processing
    ↓
14. Data Access Layer
    ↓
15. Database Query
    ↓
16. Response Formatting
    ↓
17. Response Compression
    ↓
18. Response Logging
    ↓
19. Client Response
```

### Error Handling Flow

```
Error Occurs
   ↓
Error Categorization
   ├─ Validation Error (400)
   ├─ Authentication Error (401)
   ├─ Authorization Error (403)
   ├─ Not Found Error (404)
   ├─ Rate Limit Error (429)
   ├─ Server Error (500)
   └─ Service Unavailable (503)
   ↓
Error Logging (with context)
   ↓
Circuit Breaker Check
   ├─ If Open: Return 503
   └─ If Closed: Continue
   ↓
Error Response Formatting
   ├─ Error Code
   ├─ Error Message
   ├─ Correlation ID
   └─ Suggested Action
   ↓
Sentry Error Tracking
   ↓
Client Error Response
```

## Data Models

### User Model

```typescript
interface User {
  id: string;
  email: string;
  auth0Id: string;
  tier: 'free' | 'premium' | 'enterprise';
  profile: {
    firstName: string;
    lastName: string;
    avatar?: string;
    preferences: {
      theme: 'light' | 'dark';
      language: string;
      notifications: boolean;
    };
  };
  createdAt: Date;
  updatedAt: Date;
  lastLoginAt?: Date;
  isActive: boolean;
}
```

### Tunnel Model

```typescript
interface Tunnel {
  id: string;
  userId: string;
  name: string;
  status: 'created' | 'connecting' | 'connected' | 'disconnected' | 'error';
  endpoints: TunnelEndpoint[];
  config: {
    maxConnections: number;
    timeout: number;
    compression: boolean;
  };
  metrics: {
    requestCount: number;
    successCount: number;
    errorCount: number;
    averageLatency: number;
  };
  createdAt: Date;
  updatedAt: Date;
}

interface TunnelEndpoint {
  id: string;
  url: string;
  priority: number;
  weight: number;
  healthStatus: 'healthy' | 'unhealthy' | 'unknown';
  lastHealthCheck: Date;
}
```

### Session Model

```typescript
interface Session {
  id: string;
  userId: string;
  token: string;
  refreshToken: string;
  expiresAt: Date;
  createdAt: Date;
  ipAddress: string;
  userAgent: string;
  isActive: boolean;
}
```

### Audit Log Model

```typescript
interface AuditLog {
  id: string;
  userId: string;
  action: string;
  resource: string;
  resourceId: string;
  result: 'success' | 'failure';
  details: Record<string, any>;
  ipAddress: string;
  userAgent: string;
  timestamp: Date;
}
```

## Middleware Pipeline

### Middleware Order (Critical)

1. **Sentry Request Handler** - Tracing and error tracking
2. **CORS Middleware** - Handle preflight requests
3. **Helmet** - Security headers
4. **Request Logging** - Log all requests with correlation ID
5. **Request Validation** - Validate request format
6. **Rate Limiting** - Check rate limits
7. **Authentication** - Validate JWT tokens
8. **Authorization** - Check user permissions
9. **Request Compression** - Compress request body
10. **Error Handling** - Catch and format errors

### Middleware Implementation

```typescript
// Middleware pipeline setup
app.use(Sentry.Handlers.requestHandler());
app.use(cors(corsOptions));
app.use(helmet());
app.use(requestLoggingMiddleware);
app.use(requestValidationMiddleware);
app.use(rateLimitMiddleware);
app.use(authenticateJWT);
app.use(authorizeRBAC);
app.use(compression());
app.use(errorHandlingMiddleware);
```

## Service Layer

### AuthService

```typescript
class AuthService {
  validateToken(token: string): Promise<TokenPayload>;
  refreshToken(refreshToken: string): Promise<string>;
  revokeToken(token: string): Promise<void>;
  verifyPermission(userId: string, permission: string): Promise<boolean>;
}
```

### UserService

```typescript
class UserService {
  getUserById(userId: string): Promise<User>;
  updateUserProfile(userId: string, profile: Partial<User>): Promise<User>;
  getUserTier(userId: string): Promise<UserTier>;
  upgradeUserTier(userId: string, tier: UserTier): Promise<void>;
  deleteUser(userId: string): Promise<void>;
}
```

### TunnelService

```typescript
class TunnelService {
  createTunnel(userId: string, config: TunnelConfig): Promise<Tunnel>;
  startTunnel(tunnelId: string): Promise<void>;
  stopTunnel(tunnelId: string): Promise<void>;
  getTunnelStatus(tunnelId: string): Promise<TunnelStatus>;
  getTunnelMetrics(tunnelId: string): Promise<TunnelMetrics>;
  deleteTunnel(tunnelId: string): Promise<void>;
}
```

### ProxyService

```typescript
class ProxyService {
  startProxy(userId: string): Promise<ProxyInstance>;
  stopProxy(proxyId: string): Promise<void>;
  getProxyStatus(proxyId: string): Promise<ProxyStatus>;
  getProxyMetrics(proxyId: string): Promise<ProxyMetrics>;
  scaleProxy(proxyId: string, replicas: number): Promise<void>;
}
```

## Database Schema

### Users Table

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  auth0_id VARCHAR(255) UNIQUE NOT NULL,
  tier VARCHAR(50) NOT NULL DEFAULT 'free',
  profile JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP,
  is_active BOOLEAN DEFAULT true
);
```

### Tunnels Table

```sql
CREATE TABLE tunnels (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  name VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL,
  config JSONB,
  metrics JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Sessions Table

```sql
CREATE TABLE sessions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  token VARCHAR(1024) NOT NULL,
  refresh_token VARCHAR(1024) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ip_address VARCHAR(45),
  user_agent TEXT,
  is_active BOOLEAN DEFAULT true
);
```

### Audit Logs Table

```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  action VARCHAR(255) NOT NULL,
  resource VARCHAR(255) NOT NULL,
  resource_id VARCHAR(255),
  result VARCHAR(50) NOT NULL,
  details JSONB,
  ip_address VARCHAR(45),
  user_agent TEXT,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Error Handling Strategy

### Error Categories

```typescript
enum ErrorCategory {
  VALIDATION = 'validation',
  AUTHENTICATION = 'authentication',
  AUTHORIZATION = 'authorization',
  NOT_FOUND = 'not_found',
  RATE_LIMIT = 'rate_limit',
  SERVER = 'server',
  SERVICE_UNAVAILABLE = 'service_unavailable',
}

interface APIError {
  code: string;
  message: string;
  category: ErrorCategory;
  statusCode: number;
  details?: Record<string, any>;
  suggestion?: string;
}
```

### Error Response Format

```json
{
  "error": {
    "code": "TUNNEL_001",
    "message": "Tunnel not found",
    "category": "not_found",
    "statusCode": 404,
    "correlationId": "req-12345",
    "suggestion": "Check tunnel ID and try again"
  }
}
```

## Monitoring and Metrics

### Prometheus Metrics

```typescript
// Request metrics
const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency',
  labelNames: ['method', 'route', 'status'],
});

const httpRequestTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
});

// Service metrics
const tunnelConnectionsActive = new Gauge({
  name: 'tunnel_connections_active',
  help: 'Active tunnel connections',
});

const proxyInstancesActive = new Gauge({
  name: 'proxy_instances_active',
  help: 'Active proxy instances',
});

// Database metrics
const dbConnectionPoolSize = new Gauge({
  name: 'db_connection_pool_size',
  help: 'Database connection pool size',
});

const dbQueryDuration = new Histogram({
  name: 'db_query_duration_seconds',
  help: 'Database query latency',
  labelNames: ['query_type'],
});
```

## Deployment

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-backend
  template:
    metadata:
      labels:
        app: api-backend
    spec:
      containers:
      - name: api-backend
        image: cloudtolocalllm/api-backend:v2.0
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: redis-url
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

## Success Criteria

- All 12 requirements implemented with 100% acceptance criteria coverage
- API response time < 200ms (95th percentile)
- API throughput > 1000 requests/second
- 99.9% uptime
- Zero security incidents
- 100% endpoint documentation coverage
- Comprehensive error handling and recovery
- Full integration with Phase 2 tunnel features

