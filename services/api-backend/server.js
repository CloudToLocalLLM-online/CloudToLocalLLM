import express from 'express';
import http from 'http';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import winston from 'winston';
import dotenv from 'dotenv';
import { StreamingProxyManager } from './streaming-proxy-manager.js';
import { auth } from 'express-oauth2-jwt-bearer';

import adminRoutes from './routes/admin.js';
// WebSocket tunnel system
import { setupWebSocketTunnel } from './websocket-server.js';
// HTTP polling tunnel system (fallback/legacy)
import { AuthService } from './auth/auth-service.js';
import { DatabaseMigrator } from './database/migrate.js';
import { DatabaseMigratorPG } from './database/migrate-pg.js';
import { createTunnelRoutes } from './tunnel/tunnel-routes.js';
import { createMonitoringRoutes } from './routes/monitoring.js';
import { authenticateJWT } from './middleware/auth.js';
import { addTierInfo, getUserTier } from './middleware/tier-check.js';

dotenv.config();

// Auth0 JWT validation middleware
const checkJwt = auth({
  audience: process.env.AUTH0_AUDIENCE || 'https://app.cloudtolocalllm.online',
  issuerBaseURL: process.env.AUTH0_DOMAIN ? `https://${process.env.AUTH0_DOMAIN}` : 'https://cloudtolocalllm.us.auth0.com',
  tokenSigningAlg: 'RS256'
});

// Initialize logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'cloudtolocalllm-api' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

// Configuration
const PORT = process.env.PORT || 8080;
const AUTH0_DOMAIN = process.env.AUTH0_DOMAIN || 'dev-v2f2p008x3dr74ww.us.auth0.com';
const AUTH0_AUDIENCE = process.env.AUTH0_AUDIENCE || 'https://app.cloudtolocalllm.online';
const DOMAIN = process.env.DOMAIN || 'cloudtolocalllm.online';

// AuthService will be initialized in initializeHttpPollingSystem()

// Express app setup
const app = express();
const server = http.createServer(app);

// Initialize WebSocket tunnel server
let tunnelProxyWebSocket;
try {
  tunnelProxyWebSocket = setupWebSocketTunnel(server, {
    AUTH0_DOMAIN,
    AUTH0_AUDIENCE,
    DOMAIN,
  }, logger);
  logger.info('WebSocket tunnel initialized successfully');
} catch (error) {
  logger.error('Failed to initialize WebSocket tunnel', {
    error: error.message,
    stack: error.stack,
  });
}

// Trust proxy headers (required for rate limiting behind nginx)
// Use specific proxy configuration to avoid ERR_ERL_PERMISSIVE_TRUST_PROXY
app.set('trust proxy', 1); // Trust first proxy (nginx)

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ['\'self\''],
      connectSrc: ['\'self\'', 'https:'],
      scriptSrc: ['\'self\'', '\'unsafe-inline\''],
      styleSrc: ['\'self\'', '\'unsafe-inline\''],
      imgSrc: ['\'self\'', 'data:', 'https:'],
    },
  },
}));

// CORS configuration
app.use(cors({
  origin: [
    'https://app.cloudtolocalllm.online',
    'https://cloudtolocalllm.online',
    'https://docs.cloudtolocalllm.online',
    'http://localhost:3000', // Development
    'http://localhost:8080',  // Development
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Rate limiting with different limits for bridge operations
const createConditionalRateLimiter = () => {
  // Standard rate limiter for general API endpoints
  const standardLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
  });

  // More lenient rate limiter for bridge operations
  const bridgeLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 500, // Allow more requests for bridge operations (5x standard limit)
    message: 'Too many bridge requests from this IP, please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
  });

  return (req, res, next) => {
    // Apply more lenient limits to bridge routes
    if (req.path.startsWith('/api/bridge/')) {
      return bridgeLimiter(req, res, next);
    }
    // Apply standard limits to all other routes
    return standardLimiter(req, res, next);
  };
};

app.use(createConditionalRateLimiter());

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Auth middleware
async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    // Get the signing key
    const decoded = jwt.decode(token, { complete: true });
    if (!decoded || !decoded.header.kid) {
      return res.status(401).json({ error: 'Invalid token format' });
    }

    // Verify the token using AuthService (fallback if not initialized)
    if (!authService) {
      return res.status(503).json({ error: 'Authentication service not ready' });
    }
    const verified = await authService.validateToken(token);

    req.user = verified;
    next();
  } catch (error) {
    logger.error('Token verification failed:', error);
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
}

// Bridge connections removed - using HTTP polling only

// Initialize streaming proxy manager
const proxyManager = new StreamingProxyManager();

// Create WebSocket-based tunnel routes
const tunnelRouter = createTunnelRoutes({
  AUTH0_DOMAIN,
  AUTH0_AUDIENCE,
}, tunnelProxyWebSocket, logger);

// Create monitoring routes
const monitoringRouter = createMonitoringRoutes(tunnelProxyWebSocket, logger);

// API Routes

// Simplified tunnel routes
app.use('/api/tunnel', tunnelRouter);

// Performance monitoring routes
app.use('/api/monitoring', monitoringRouter);

// Database health endpoint
app.get('/api/db/health', async(req, res) => {
  try {
    if (!dbMigrator) {
      return res.status(503).json({
        status: 'error',
        message: 'Database migrator not initialized',
        timestamp: new Date().toISOString(),
      });
    }

    // Perform a simple health check
    const validation = await dbMigrator.validateSchema();
    const dbType = process.env.DB_TYPE || 'sqlite';

    res.json({
      status: validation.allValid ? 'healthy' : 'degraded',
      database_type: dbType,
      schema_validation: validation.results,
      all_tables_valid: validation.allValid,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Database health check failed:', error);
    res.status(503).json({
      status: 'error',
      message: 'Database health check failed',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Administrative routes
app.use('/api/admin', adminRoutes);

// LLM Tunnel Cloud Proxy Endpoints
app.all('/api/ollama/*', authenticateJWT, addTierInfo, async(req, res) => {
  const startTime = Date.now();
  const requestId = `llm-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const userId = req.auth?.payload.sub;
  const userTier = getUserTier(req.auth?.payload);

  if (!userId) {
    return res.status(401).json({
      error: 'Authentication required',
      code: 'AUTH_REQUIRED',
      message: 'Please authenticate to access LLM services.',
    });
  }

  try {
    const ollamaPath = req.path.replace('/api/ollama', '') || '/';
    const forwardHeaders = { ...req.headers };
    ['host', 'authorization', 'connection', 'upgrade', 'proxy-authenticate', 'proxy-authorization', 'te', 'trailers', 'transfer-encoding'].forEach(h => delete forwardHeaders[h]);

    const httpRequest = {
      id: requestId,
      method: req.method,
      path: ollamaPath,
      headers: forwardHeaders,
      body: req.method !== 'GET' && req.method !== 'HEAD' ? JSON.stringify(req.body) : undefined,
    };

    logger.debug(' [LLMTunnel] Forwarding request through WebSocket tunnel', { userId, requestId, path: ollamaPath });

    const response = await tunnelProxyWebSocket.forwardRequest(userId, httpRequest);

    const duration = Date.now() - startTime;
    logger.info(' [LLMTunnel] Request completed successfully via WebSocket', { userId, requestId, duration, status: response.status });

    if (response.headers) {
      Object.entries(response.headers).forEach(([key, value]) => {
        if (key.toLowerCase() !== 'transfer-encoding') {
          res.set(key, value);
        }
      });
    }

    res.status(response.status || 200);
    if (response.body) {
      try {
        res.json(JSON.parse(response.body));
      } catch (e) {
        res.send(response.body);
      }
    } else {
      res.end();
    }

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error(' [LLMTunnel] Request failed via WebSocket', { userId, requestId, duration, error: error.message, code: error.code });

    if (error.code === 'REQUEST_TIMEOUT') {
      return res.status(504).json({ error: 'LLM request timeout', code: 'LLM_REQUEST_TIMEOUT' });
    }
    if (error.code === 'DESKTOP_CLIENT_DISCONNECTED') {
      return res.status(503).json({ error: 'Desktop client not connected', code: 'DESKTOP_CLIENT_DISCONNECTED' });
    }
    res.status(500).json({ error: 'LLM tunnel error', code: 'LLM_TUNNEL_ERROR' });
  }
});

// User tier endpoint
app.get('/api/user/tier', authenticateJWT, addTierInfo, (req, res) => {
  try {
    const userTier = getUserTier(req.user);
    const features = getTierFeatures(userTier);

    res.json({
      tier: userTier,
      features: features,
      upgradeUrl: process.env.UPGRADE_URL || 'https://app.cloudtolocalllm.online/upgrade',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Error getting user tier:', error);
    res.status(500).json({
      error: 'Failed to determine user tier',
      code: 'TIER_ERROR',
    });
  }
});

// Health check endpoints
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    tunnelSystem: 'websocket',
  });
});

// API health check endpoint (for web app compatibility)
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    tunnelSystem: 'websocket',
    service: 'cloudtolocalllm-api',
  });
});

// WebSocket bridge endpoints removed - using HTTP polling only

// Streaming Proxy Management Endpoints

// Start streaming proxy for user
app.post('/api/proxy/start', authenticateToken, async(req, res) => {
  try {
    const userId = req.user.sub;
    const userToken = req.headers.authorization;

    logger.info(`Starting streaming proxy for user: ${userId}`);

    // Pass the user object for tier checking
    const proxyMetadata = await proxyManager.provisionProxy(userId, userToken, req.user);

    res.json({
      success: true,
      message: 'Streaming proxy started successfully',
      proxy: {
        proxyId: proxyMetadata.proxyId,
        status: proxyMetadata.status,
        createdAt: proxyMetadata.createdAt,
        directTunnel: proxyMetadata.directTunnel || false,
        endpoint: proxyMetadata.endpoint || null,
        userTier: proxyMetadata.userTier || 'free',
      },
    });
  } catch (error) {
    logger.error(`Failed to start proxy for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to start streaming proxy',
      message: error.message,
    });
  }
});

// Stop streaming proxy for user
app.post('/api/proxy/stop', authenticateToken, async(req, res) => {
  try {
    const userId = req.user.sub;

    logger.info(`Stopping streaming proxy for user: ${userId}`);

    const success = await proxyManager.terminateProxy(userId);

    if (success) {
      res.json({
        success: true,
        message: 'Streaming proxy stopped successfully',
      });
    } else {
      res.status(404).json({
        error: 'No active proxy found',
        message: 'No streaming proxy is currently running for this user',
      });
    }
  } catch (error) {
    logger.error(`Failed to stop proxy for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to stop streaming proxy',
      message: error.message,
    });
  }
});

// Provision streaming proxy for user (with test mode support)
app.post('/api/streaming-proxy/provision', authenticateToken, async(req, res) => {
  try {
    const userId = req.user.sub;
    const userToken = req.headers.authorization;
    const { testMode = false } = req.body;

    logger.info(`Provisioning streaming proxy for user: ${userId}, testMode: ${testMode}`);

    if (testMode) {
      // In test mode, simulate successful provisioning without creating actual containers
      logger.info(`Test mode: Simulating proxy provisioning for user ${userId}`);

      res.json({
        success: true,
        message: 'Streaming proxy provisioned successfully (test mode)',
        testMode: true,

        proxy: {
          proxyId: `test-proxy-${userId}`,
          status: 'simulated',
          createdAt: new Date().toISOString(),
        },
      });
      return;
    }

    // Normal mode - provision actual proxy
    const proxyMetadata = await proxyManager.provisionProxy(userId, userToken, req.user);

    res.json({
      success: true,
      message: 'Streaming proxy provisioned successfully',
      testMode: false,

      proxy: {
        proxyId: proxyMetadata.proxyId,
        status: proxyMetadata.status,
        createdAt: proxyMetadata.createdAt,
        directTunnel: proxyMetadata.directTunnel || false,
        endpoint: proxyMetadata.endpoint || null,
        userTier: proxyMetadata.userTier || 'free',
      },
    });
  } catch (error) {
    logger.error(`Failed to provision proxy for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to provision streaming proxy',
      message: error.message,
      testMode: req.body.testMode || false,
    });
  }
});

// Get streaming proxy status
app.get('/api/proxy/status', authenticateToken, async(req, res) => {
  try {
    const userId = req.user.sub;
    const status = await proxyManager.getProxyStatus(userId);

    // Update activity if proxy is running
    if (status.status === 'running') {
      proxyManager.updateProxyActivity(userId);
    }

    res.json(status);
  } catch (error) {
    logger.error(`Failed to get proxy status for user ${req.user.sub}:`, error);
    res.status(500).json({
      error: 'Failed to get proxy status',
      message: error.message,
    });
  }
});

// Ollama proxy endpoints removed - using HTTP polling tunnel system instead

// The error handler must be registered before any other error middleware and after all controllers

// Error handling middleware
app.use((error, req, res, _next) => {
  logger.error('Unhandled error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong',
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// LLM Security and Monitoring Helper Functions

// Rate limiting storage
const rateLimitStorage = new Map();

// Get rate limits based on user tier
function getRateLimitsForTier(tier) {
  const limits = {
    free: {
      requestsPerMinute: 10,
      requestsPerHour: 100,
      requestsPerDay: 500,
      maxTokensPerRequest: 2000,
    },
    pro: {
      requestsPerMinute: 60,
      requestsPerHour: 1000,
      requestsPerDay: 10000,
      maxTokensPerRequest: 4000,
    },
    enterprise: {
      requestsPerMinute: 120,
      requestsPerHour: 5000,
      requestsPerDay: 50000,
      maxTokensPerRequest: 8000,
    },
  };

  return limits[tier] || limits.free;
}

// Check rate limit for user
function checkRateLimit(userId, providerId, limits) {
  const key = `${userId}:${providerId}`;
  const now = Date.now();

  // Get or create request history
  let history = rateLimitStorage.get(key) || [];

  // Clean old requests (older than 24 hours)
  history = history.filter(timestamp => now - timestamp < 24 * 60 * 60 * 1000);

  // Check per-minute limit
  const minuteRequests = history.filter(timestamp => now - timestamp < 60 * 1000).length;
  if (minuteRequests >= limits.requestsPerMinute) {
    logger.warn(`Rate limit exceeded for ${userId}:${providerId} - per minute`, {
      userId,
      providerId,
      minuteRequests,
      limit: limits.requestsPerMinute,
    });
    return false;
  }

  // Check per-hour limit
  const hourRequests = history.filter(timestamp => now - timestamp < 60 * 60 * 1000).length;
  if (hourRequests >= limits.requestsPerHour) {
    logger.warn(`Rate limit exceeded for ${userId}:${providerId} - per hour`, {
      userId,
      providerId,
      hourRequests,
      limit: limits.requestsPerHour,
    });
    return false;
  }

  // Check per-day limit
  const dayRequests = history.length;
  if (dayRequests >= limits.requestsPerDay) {
    logger.warn(`Rate limit exceeded for ${userId}:${providerId} - per day`, {
      userId,
      providerId,
      dayRequests,
      limit: limits.requestsPerDay,
    });
    return false;
  }

  return true;
}

// Record a request for rate limiting
function recordRequest(userId, providerId) {
  const key = `${userId}:${providerId}`;
  const history = rateLimitStorage.get(key) || [];

  history.push(Date.now());
  rateLimitStorage.set(key, history);
}

// Log LLM audit event
function logLLMAuditEvent(eventData) {
  const auditEvent = {
    id: `audit-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    timestamp: new Date().toISOString(),
    type: 'llm_interaction',
    ...eventData,
  };

  // Log to Winston for persistence
  logger.info('LLM Audit Event', auditEvent);

  // Additional security logging for failed requests
  if (!eventData.success) {
    logger.warn('LLM Request Failed', {
      userId: eventData.userId,
      providerId: eventData.providerId,
      error: eventData.errorMessage,
      requestId: eventData.requestId,
    });
  }

  // Log suspicious activity
  if (eventData.responseTime > 60000) { // Requests taking longer than 1 minute
    logger.warn('Long-running LLM request detected', {
      userId: eventData.userId,
      providerId: eventData.providerId,
      responseTime: eventData.responseTime,
      requestId: eventData.requestId,
    });
  }
}

// Clean up rate limiting storage periodically (every hour)
setInterval(() => {
  const now = Date.now();
  const cutoff = 24 * 60 * 60 * 1000; // 24 hours

  for (const [key, history] of rateLimitStorage.entries()) {
    const filteredHistory = history.filter(timestamp => now - timestamp < cutoff);
    if (filteredHistory.length === 0) {
      rateLimitStorage.delete(key);
    } else {
      rateLimitStorage.set(key, filteredHistory);
    }
  }

  logger.debug('Rate limiting storage cleaned up', {
    activeKeys: rateLimitStorage.size,
  });
}, 60 * 60 * 1000); // Run every hour

// Initialize Tunnel System
let authService = null;
let dbMigrator = null;

async function initializeTunnelSystem() {
  logger.info('Starting initialization of tunnel system...');
  try {
    const dbType = process.env.DB_TYPE || 'sqlite';
    dbMigrator = dbType === 'postgresql' ? new DatabaseMigratorPG() : new DatabaseMigrator();

    await dbMigrator.initialize();
    await dbMigrator.createMigrationsTable();
    await dbMigrator.applyInitialSchema();

    const validation = await dbMigrator.validateSchema();
    if (!validation.allValid) {
      throw new Error('Database schema validation failed');
    }

    authService = new AuthService({
      AUTH0_DOMAIN,
      AUTH0_AUDIENCE,
    });
    await authService.initialize();

    logger.info('WebSocket tunnel system ready');

    process.on('SIGTERM', gracefulShutdown);
    process.on('SIGINT', gracefulShutdown);

    logger.info('Tunnel system initialized successfully');

  } catch (error) {
    logger.error('Failed to initialize tunnel system', {
      error: error.message,
      stack: error.stack,
    });
    process.exit(1);
  }
}

async function gracefulShutdown() {
  logger.info('Received shutdown signal, starting graceful shutdown...');

  try {
    if (tunnelProxyWebSocket) {
      tunnelProxyWebSocket.cleanup();
    }
    if (authService) {
      await authService.close();
    }
    if (dbMigrator) {
      await dbMigrator.close();
    }

    server.close(() => {
      logger.info('Server closed successfully');
      process.exit(0);
    });

    setTimeout(() => {
      logger.error('Forced shutdown after timeout');
      process.exit(1);
    }, 10000);

  } catch (error) {
    logger.error('Error during shutdown', { error: error.message });
    process.exit(1);
  }
}

// Start server with enhanced tunnel system
async function startServer() {
  logger.info('Starting server...');
  try {
    await initializeTunnelSystem();

    server.listen(PORT, () => {
      logger.info(`CloudToLocalLLM API Backend listening on port ${PORT}`);
      logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
      logger.info('WebSocket tunnel system is ready');
    });

  } catch (error) {
    logger.error('Failed to start server', { error: error.message });
    process.exit(1);
  }
}

// Start the server
startServer();
