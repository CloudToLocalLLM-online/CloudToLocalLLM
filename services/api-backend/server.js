import express from 'express';
import http from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-client';
import { v4 as uuidv4 } from 'uuid';
import winston from 'winston';
import dotenv from 'dotenv';
import { StreamingProxyManager } from './streaming-proxy-manager.js';

import adminRoutes from './routes/admin.js';
// Enhanced tunnel system imports
import { TunnelServer } from './tunnel/tunnel-server.js';
import { AuthService } from './auth/auth-service.js';
import { DatabaseMigrator } from './database/migrate.js';
import { createTunnelRoutes } from './tunnel/tunnel-routes.js';
import { createMonitoringRoutes } from './routes/monitoring.js';
import { createDirectProxyRoutes } from './routes/direct-proxy-routes.js';
import { authenticateJWT } from './middleware/auth.js';
import { addTierInfo, getUserTier, getTierFeatures } from './middleware/tier-check.js';

dotenv.config();

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

// JWKS client for Auth0 token verification
const jwksClientInstance = jwksClient({
  jwksUri: `https://${AUTH0_DOMAIN}/.well-known/jwks.json`,
  requestHeaders: {},
  timeout: 30000,
  cache: true,
  rateLimit: true,
  jwksRequestsPerMinute: 5,
});

// Express app setup
const app = express();
const server = http.createServer(app);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ['\'self\''],
      connectSrc: ['\'self\'', 'wss:', 'https:'],
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

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(limiter);

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

    const key = await jwksClientInstance.getSigningKey(decoded.header.kid);
    const signingKey = key.getPublicKey();

    // Verify the token
    const verified = jwt.verify(token, signingKey, {
      audience: AUTH0_AUDIENCE,
      issuer: `https://${AUTH0_DOMAIN}/`,
      algorithms: ['RS256'],
    });

    req.user = verified;
    next();
  } catch (error) {
    logger.error('Token verification failed:', error);
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
}

// Store for active bridge connections
const bridgeConnections = new Map();

// Initialize streaming proxy manager
const proxyManager = new StreamingProxyManager();

// WebSocket server for bridge connections
const wss = new WebSocketServer({
  server,
  path: '/ws/bridge',
  verifyClient: async(info) => {
    try {
      const url = new URL(info.req.url, `http://${info.req.headers.host}`);
      const token = url.searchParams.get('token');

      if (!token) {
        logger.warn('WebSocket connection rejected: No token provided');
        return false;
      }

      // Verify token (similar to HTTP middleware)
      const decoded = jwt.decode(token, { complete: true });
      if (!decoded || !decoded.header.kid) {
        logger.warn('WebSocket connection rejected: Invalid token format');
        return false;
      }

      const key = await jwksClientInstance.getSigningKey(decoded.header.kid);
      const signingKey = key.getPublicKey();

      const verified = jwt.verify(token, signingKey, {
        audience: AUTH0_AUDIENCE,
        issuer: `https://${AUTH0_DOMAIN}/`,
        algorithms: ['RS256'],
      });

      // Store user info for the connection
      info.req.user = verified;
      return true;
    } catch (error) {
      logger.error('WebSocket token verification failed:', error);
      return false;
    }
  },
});

wss.on('connection', (ws, req) => {
  const bridgeId = uuidv4();
  const userId = req.user?.sub;

  if (!userId) {
    logger.error('WebSocket connection established but no user ID found');
    ws.close(1008, 'Authentication failed');
    return;
  }

  logger.info(`Bridge connected: ${bridgeId} for user: ${userId}`);

  // Store connection
  bridgeConnections.set(bridgeId, {
    ws,
    userId,
    bridgeId,
    connectedAt: new Date(),
    lastPing: new Date(),
  });

  // Send welcome message
  ws.send(JSON.stringify({
    type: 'auth',
    id: uuidv4(),
    data: { success: true, bridgeId },
    timestamp: new Date().toISOString(),
  }));

  // Handle messages from bridge
  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data);
      handleBridgeMessage(bridgeId, message);
    } catch (error) {
      logger.error(`Failed to parse message from bridge ${bridgeId}:`, error);
    }
  });

  // Handle connection close
  ws.on('close', () => {
    logger.info(`Bridge disconnected: ${bridgeId}`);
    bridgeConnections.delete(bridgeId);

    // Clean up any pending requests for this bridge
    cleanupPendingRequestsForBridge(bridgeId);
  });

  // Handle errors
  ws.on('error', (error) => {
    logger.error(`Bridge ${bridgeId} error:`, error);
    bridgeConnections.delete(bridgeId);

    // Clean up any pending requests for this bridge
    cleanupPendingRequestsForBridge(bridgeId);
  });

  // Send ping every 30 seconds
  const pingInterval = setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'ping',
        id: uuidv4(),
        timestamp: new Date().toISOString(),
      }));
    } else {
      clearInterval(pingInterval);
    }
  }, 30000);
});

// Encrypted tunnel WebSocket server removed - using simplified tunnel system

// Store for pending requests (requestId -> response handler)
const pendingRequests = new Map();

// Encrypted tunnel code removed - using simplified tunnel system

// Clean up pending requests for a disconnected bridge
function cleanupPendingRequestsForBridge(bridgeId) {
  const requestsToCleanup = [];

  for (const [requestId, handler] of pendingRequests.entries()) {
    if (handler.bridgeId === bridgeId) {
      requestsToCleanup.push(requestId);
    }
  }

  requestsToCleanup.forEach(requestId => {
    const handler = pendingRequests.get(requestId);
    if (handler) {
      clearTimeout(handler.timeout);
      pendingRequests.delete(requestId);

      // Send error response to client
      handler.res.status(503).json({
        error: 'Bridge disconnected',
        message: 'The bridge connection was lost while processing your request.',
      });

      logger.warn(`Cleaned up pending request ${requestId} due to bridge ${bridgeId} disconnect`);
    }
  });
}

// Handle messages from bridge
function handleBridgeMessage(bridgeId, message) {
  const bridge = bridgeConnections.get(bridgeId);
  if (!bridge) {
    logger.warn(`Received message from unknown bridge: ${bridgeId}`);
    return;
  }

  bridge.lastPing = new Date();

  switch (message.type) {
  case 'pong':
    // Update last ping time
    logger.debug(`Received pong from bridge ${bridgeId}`);
    break;

  case 'response': {
    // Handle Ollama response from bridge
    const requestId = message.id;
    const responseHandler = pendingRequests.get(requestId);

    if (responseHandler) {
      logger.debug(`Received Ollama response from bridge ${bridgeId} for request ${requestId}`);

      // Clear timeout and remove from pending requests
      clearTimeout(responseHandler.timeout);
      pendingRequests.delete(requestId);

      // Send response to original HTTP client
      const { res } = responseHandler;
      const responseData = message.data;

      // Set response headers
      if (responseData.headers) {
        Object.entries(responseData.headers).forEach(([key, value]) => {
          res.setHeader(key, value);
        });
      }

      // Send response with status code and body
      res.status(responseData.statusCode || 200);

      if (responseData.body) {
        // Try to parse as JSON first, fallback to plain text
        try {
          const jsonBody = JSON.parse(responseData.body);
          res.json(jsonBody);
        } catch {
          res.send(responseData.body);
        }
      } else {
        res.end();
      }
    } else {
      logger.warn(`Received response for unknown request: ${requestId}`);
    }
    break;
  }

  default:
    logger.warn(`Unknown message type from bridge ${bridgeId}: ${message.type}`);
  }
}

// Create simplified tunnel routes and WebSocket server
const { router: tunnelRouter, tunnelProxy } = createTunnelRoutes(server, {
  AUTH0_DOMAIN,
  AUTH0_AUDIENCE,
}, logger);

// Create direct proxy routes for free tier users
const directProxyRouter = createDirectProxyRoutes(tunnelProxy);

// Create monitoring routes
const monitoringRouter = createMonitoringRoutes(tunnelProxy, logger);

// API Routes

// Simplified tunnel routes
app.use('/api/tunnel', tunnelRouter);

// Direct proxy routes for free tier users
app.use('/api/direct-proxy', directProxyRouter);

// Performance monitoring routes
app.use('/api/monitoring', monitoringRouter);

// Encrypted tunnel routes removed - using simplified tunnel system

// Administrative routes
app.use('/api/admin', adminRoutes);

// LLM Tunnel Cloud Proxy Endpoints
// These endpoints provide the missing /api/ollama/* routes that the web platform expects
app.all('/api/ollama/*', authenticateJWT, addTierInfo, async(req, res) => {
  const startTime = Date.now();
  const requestId = `llm-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const userId = req.user?.sub;
  const userTier = getUserTier(req.user);

  if (!userId) {
    return res.status(401).json({
      error: 'Authentication required',
      code: 'AUTH_REQUIRED',
      message: 'Please authenticate to access LLM services.',
    });
  }

  // Rate limiting based on user tier
  const rateLimits = getRateLimitsForTier(userTier);
  if (!checkRateLimit(userId, 'ollama', rateLimits)) {
    return res.status(429).json({
      error: 'Rate limit exceeded',
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'You have exceeded the rate limit for your tier. Please try again later.',
      tier: userTier,
      limits: rateLimits,
      requestId,
    });
  }

  try {
    logger.info('🦙 [LLMTunnel] Processing LLM request', {
      userId,
      userTier,
      method: req.method,
      path: req.path,
      requestId,
    });

    // Extract the Ollama API path (remove /api/ollama prefix)
    const ollamaPath = req.path.replace('/api/ollama', '') || '/';

    // Prepare headers for forwarding (remove hop-by-hop headers)
    const forwardHeaders = { ...req.headers };
    const headersToRemove = [
      'host', 'connection', 'upgrade', 'proxy-authenticate',
      'proxy-authorization', 'te', 'trailers', 'transfer-encoding',
    ];
    headersToRemove.forEach(header => {
      delete forwardHeaders[header];
    });

    // Create HTTP request object for tunnel proxy
    const httpRequest = {
      id: requestId,
      method: req.method,
      path: ollamaPath,
      headers: forwardHeaders,
      body: req.method !== 'GET' && req.method !== 'HEAD' ? JSON.stringify(req.body) : undefined,
      query: req.query,
      timeout: 60000, // 60 seconds for LLM requests (longer than standard)
    };

    logger.debug('🔄 [LLMTunnel] Forwarding request through tunnel', {
      userId,
      userTier,
      method: req.method,
      path: ollamaPath,
      requestId,
      hasBody: !!httpRequest.body,
    });

    // Forward request through tunnel proxy using LLM-optimized method
    const response = await tunnelProxy.forwardLLMRequest(userId, httpRequest);

    const duration = Date.now() - startTime;

    // Record successful request for rate limiting
    recordRequest(userId, 'ollama');

    // Log audit event
    logLLMAuditEvent({
      userId,
      providerId: 'ollama',
      requestType: req.method,
      requestPath: ollamaPath,
      requestSize: httpRequest.body ? httpRequest.body.length : 0,
      responseSize: response.body ? response.body.length : 0,
      responseTime: duration,
      success: true,
      userTier,
      requestId,
    });

    logger.info('✅ [LLMTunnel] Request completed successfully', {
      userId,
      userTier,
      method: req.method,
      path: ollamaPath,
      requestId,
      statusCode: response.statusCode,
      duration,
    });

    // Set response headers
    if (response.headers) {
      Object.entries(response.headers).forEach(([key, value]) => {
        if (key.toLowerCase() !== 'transfer-encoding') {
          res.set(key, value);
        }
      });
    }

    // Send response
    res.status(response.statusCode || 200);
    if (response.body) {
      res.send(response.body);
    } else {
      res.end();
    }

  } catch (error) {
    const duration = Date.now() - startTime;

    // Log audit event for failed request
    logLLMAuditEvent({
      userId,
      providerId: 'ollama',
      requestType: req.method,
      requestPath: req.path.replace('/api/ollama', ''),
      requestSize: req?.body ? req.body.length : 0,
      responseTime: duration,
      success: false,
      errorMessage: error.message,
      userTier,
      requestId,
    });

    logger.error('❌ [LLMTunnel] Request failed', {
      userId,
      userTier,
      method: req.method,
      path: req.path,
      error: error.message,
      code: error.code,
      duration,
      requestId,
    });

    // Handle specific tunnel errors with appropriate HTTP status codes
    if (error.message === 'LLM request timeout' || error.code === 'REQUEST_TIMEOUT') {
      return res.status(504).json({
        error: 'LLM request timeout',
        code: 'LLM_REQUEST_TIMEOUT',
        message: 'The request to your local LLM service timed out. This may happen with complex queries.',
        timeout: 60000,
        requestId,
      });
    }

    if (error.code === 'DESKTOP_CLIENT_DISCONNECTED' || error.message.includes('not connected')) {
      return res.status(503).json({
        error: 'Desktop client not connected',
        code: 'DESKTOP_CLIENT_DISCONNECTED',
        message: 'Please ensure your CloudToLocalLLM desktop client is running and connected.',
        requestId,
        troubleshooting: [
          'Download and install the CloudToLocalLLM desktop client',
          'Ensure the desktop client is running and authenticated',
          'Check that your local LLM service (Ollama) is running',
          'Verify your firewall allows the desktop client to connect',
        ],
      });
    }

    if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
      return res.status(502).json({
        error: 'Local LLM service unavailable',
        code: 'LOCAL_LLM_UNAVAILABLE',
        message: 'Unable to connect to your local LLM service.',
        requestId,
        troubleshooting: [
          'Ensure Ollama or your LLM service is running',
          'Check that the service is accessible on the expected port',
          'Verify the desktop client configuration',
        ],
      });
    }

    // Generic error response
    res.status(500).json({
      error: 'LLM tunnel error',
      code: 'LLM_TUNNEL_ERROR',
      message: 'An error occurred while processing your LLM request.',
      requestId,
    });
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

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    bridges: bridgeConnections.size,
  });
});

// Bridge status
app.get('/ollama/bridge/status', authenticateToken, (req, res) => {
  const userBridges = Array.from(bridgeConnections.values())
    .filter(bridge => bridge.userId === req.user.sub);

  res.json({
    connected: userBridges.length > 0,
    bridges: userBridges.map(bridge => ({
      bridgeId: bridge.bridgeId,
      connectedAt: bridge.connectedAt,
      lastPing: bridge.lastPing,
    })),
  });
});

// Bridge registration
app.post('/ollama/bridge/register', authenticateToken, (req, res) => {
  const { bridge_id, version, platform } = req.body;

  logger.info(`Bridge registration: ${bridge_id} v${version} on ${platform} for user ${req.user.sub}`);

  res.json({
    success: true,
    message: 'Bridge registered successfully',
    bridgeId: bridge_id,
  });
});

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

// Ollama proxy endpoints
app.all('/ollama/*', authenticateToken, async(req, res) => {
  const userBridges = Array.from(bridgeConnections.values())
    .filter(bridge => bridge.userId === req.user.sub);

  if (userBridges.length === 0) {
    return res.status(503).json({
      error: 'No bridge connected',
      message: 'Please ensure the CloudToLocalLLM desktop bridge is running and connected.',
    });
  }

  // Use the first available bridge
  const bridge = userBridges[0];
  const requestId = uuidv4();

  // Set up timeout for the request (30 seconds)
  const timeout = setTimeout(() => {
    const responseHandler = pendingRequests.get(requestId);
    if (responseHandler) {
      pendingRequests.delete(requestId);
      logger.warn(`Request timeout for ${requestId}`);
      res.status(504).json({
        error: 'Gateway timeout',
        message: 'The bridge did not respond within the timeout period.',
      });
    }
  }, 30000);

  // Store response handler for correlation
  pendingRequests.set(requestId, {
    res,
    timeout,
    bridgeId: bridge.bridgeId,
    startTime: new Date(),
  });

  // Forward request to bridge
  const bridgeMessage = {
    type: 'request',
    id: requestId,
    data: {
      method: req.method,
      path: req.path.replace('/ollama', ''),
      headers: req.headers,
      body: req.body ? JSON.stringify(req.body) : undefined,
    },
    timestamp: new Date().toISOString(),
  };

  try {
    bridge.ws.send(JSON.stringify(bridgeMessage));
    logger.debug(`Forwarded request ${requestId} to bridge ${bridge.bridgeId}`);
  } catch (error) {
    // Clean up on send failure
    clearTimeout(timeout);
    pendingRequests.delete(requestId);

    logger.error(`Failed to forward request to bridge ${bridge.bridgeId}:`, error);
    res.status(500).json({ error: 'Failed to communicate with bridge' });
  }
});

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

// Initialize enhanced tunnel system
let tunnelServer = null;
let authService = null;
let dbMigrator = null;

async function initializeEnhancedTunnelSystem() {
  try {
    logger.info('Initializing enhanced tunnel system...');

    // Initialize database
    dbMigrator = new DatabaseMigrator();
    await dbMigrator.initialize();
    await dbMigrator.createMigrationsTable();

    // Apply initial schema if needed
    await dbMigrator.applyInitialSchema();

    // Validate schema
    const validation = await dbMigrator.validateSchema();
    if (!validation.allValid) {
      throw new Error('Database schema validation failed');
    }

    // Initialize authentication service
    authService = new AuthService({
      AUTH0_DOMAIN,
      AUTH0_AUDIENCE,
    });
    await authService.initialize();

    // Initialize tunnel server
    tunnelServer = new TunnelServer(server, {
      AUTH0_DOMAIN,
      AUTH0_AUDIENCE,
      maxConnections: 1000,
      heartbeatInterval: 30000,
      compressionEnabled: true,
    });

    // Start tunnel server
    tunnelServer.start();

    // Setup graceful shutdown
    process.on('SIGTERM', gracefulShutdown);
    process.on('SIGINT', gracefulShutdown);

    logger.info('Enhanced tunnel system initialized successfully');

  } catch (error) {
    logger.error('Failed to initialize enhanced tunnel system', {
      error: error.message,
      stack: error.stack,
    });
    process.exit(1);
  }
}

async function gracefulShutdown() {
  logger.info('Received shutdown signal, starting graceful shutdown...');

  try {
    // Stop tunnel server
    if (tunnelServer) {
      tunnelServer.stop();
    }

    // Close authentication service
    if (authService) {
      await authService.close();
    }

    // Close database connection
    if (dbMigrator) {
      await dbMigrator.close();
    }

    // Close HTTP server
    server.close(() => {
      logger.info('Server closed successfully');
      process.exit(0);
    });

    // Force exit after 10 seconds
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
  try {
    // Initialize enhanced tunnel system first
    await initializeEnhancedTunnelSystem();

    // Start HTTP server
    server.listen(PORT, () => {
      logger.info(`CloudToLocalLLM API Backend listening on port ${PORT}`);
      logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
      logger.info(`Auth0 Domain: ${AUTH0_DOMAIN}`);
      logger.info(`Auth0 Audience: ${AUTH0_AUDIENCE}`);
      logger.info('Enhanced tunnel system is ready');
      logger.info('LLM Security and Monitoring enabled');
    });

  } catch (error) {
    logger.error('Failed to start server', { error: error.message });
    process.exit(1);
  }
}

// Start the server
startServer();
