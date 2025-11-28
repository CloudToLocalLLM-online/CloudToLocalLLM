import * as Sentry from '@sentry/node';
import express from 'express';
import http from 'http';
import winston from 'winston';
import dotenv from 'dotenv';
import swaggerUi from 'swagger-ui-express';
import { specs } from './swagger-config.js';
import { StreamingProxyManager } from './streaming-proxy-manager.js';
import {
  setupMiddlewarePipeline,
  getAuthMiddleware,
} from './middleware/pipeline.js';
import { setupGracefulShutdown } from './middleware/graceful-shutdown.js';

import adminRoutes from './routes/admin.js';
import adminUserRoutes from './routes/admin/users.js';
import adminSubscriptionRoutes from './routes/admin/subscriptions.js';
import userRoutes from './routes/users.js';
import userProfileRoutes, {
  initializeUserProfileService,
} from './routes/user-profile.js';
import sessionRoutes from './routes/sessions.js';
import clientLogRoutes from './routes/client-logs.js';
import webhookRoutes from './routes/webhooks.js';
import authRoutes from './routes/auth.js';
import apiKeysRouter from './routes/api-keys.js';
import tunnelRoutes, { initializeTunnelService } from './routes/tunnels.js';
// SSH tunnel integration
import { SSHProxy } from './tunnel/ssh-proxy.js';
import { AuthService } from './auth/auth-service.js';
import { DatabaseMigrator } from './database/migrate.js';
import { DatabaseMigratorPG } from './database/migrate-pg.js';
import { AuthDatabaseMigratorPG } from './database/migrate-auth-pg.js';
import { initializePool } from './database/db-pool.js';
import { startMonitoring, stopMonitoring } from './database/pool-monitor.js';
import dbHealthRoutes from './routes/db-health.js';
import databasePerformanceRoutes from './routes/database-performance.js';
import turnCredentialsRoutes from './routes/turn-credentials.js';
import { createTunnelRoutes } from './tunnel/tunnel-routes.js';
import { createMonitoringRoutes } from './routes/monitoring.js';
import { createConversationRoutes } from './routes/conversations.js';
import { authenticateJWT } from './middleware/auth.js';
import {
  addTierInfo,
  getUserTier,
  getTierFeatures,
} from './middleware/tier-check.js';
import { HealthCheckService } from './services/health-check.js';
import {
  createQueueStatusHandler,
  createQueueDrainHandler,
} from './middleware/request-queuing.js';
import rateLimitMetricsRoutes from './routes/rate-limit-metrics.js';
import prometheusMetricsRoutes from './routes/prometheus-metrics.js';
import changelogRoutes from './routes/changelog.js';
import { getVersionInfoHandler } from './middleware/api-versioning.js';

dotenv.config();

// Initialize Sentry
Sentry.init({
  dsn:
    process.env.SENTRY_DSN ||
    'https://b2fd3263e0ad7b490b0583f7df2e165a@o4509853774315520.ingest.us.sentry.io/4509853780541440',
  environment: process.env.NODE_ENV || 'development',
  release: process.env.VERSION || process.env.npm_package_version,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  serverName: process.env.HOSTNAME || 'api-backend',
  beforeSend(event) {
    // Add custom tags
    if (event.tags) {
      event.tags.service = 'api-backend';
      event.tags.region = process.env.AZURE_REGION || 'unknown';
    }
    return event;
  },
});

import Transport from 'winston-transport';

// ... (imports)

// Initialize Sentry
Sentry.init({
  // ... (existing config)
});

// Initialize Sentry Winston Transport
const SentryWinstonTransport = Sentry.createSentryWinstonTransport(Transport);

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
    new SentryWinstonTransport({
      level: 'info', // Capture info and above
    }),
  ],
});

// Configuration
const PORT = process.env.PORT || 8080;
const AUTH0_DOMAIN =
  process.env.AUTH0_DOMAIN || 'dev-v2f2p008x3dr74ww.us.auth0.com';
const AUTH0_AUDIENCE =
  process.env.AUTH0_AUDIENCE || 'https://api.cloudtolocalllm.online';

// AuthService will be initialized in initializeHttpPollingSystem()

// Express app setup
const app = express();

// Trust proxy headers (required for rate limiting behind nginx)
// Use specific proxy configuration to avoid ERR_ERL_PERMISSIVE_TRUST_PROXY
app.set('trust proxy', 1); // Trust first proxy (nginx)

// CORS configuration
const corsOptions = {
  origin: function (origin, callback) {
    const allowedOrigins = [
      'https://app.cloudtolocalllm.online',
      'https://cloudtolocalllm.online',
      'https://docs.cloudtolocalllm.online',
    ];
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin || allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Requested-With',
    'Accept',
    'Origin',
    'X-Correlation-ID',
  ],
  exposedHeaders: [
    'Content-Length',
    'X-Requested-With',
    'X-Correlation-ID',
    'X-Response-Time',
  ],
  maxAge: 86400, // Cache preflight for 24 hours
  preflightContinue: false,
  optionsSuccessStatus: 204,
};

// Setup middleware pipeline with proper ordering
setupMiddlewarePipeline(app, {
  corsOptions,
  rateLimitOptions: {
    windowMs: 15 * 60 * 1000,
    max: 100,
    bridgeMax: 500,
  },
  timeoutMs: 30000,
  enableCompression: true,
});

const server = http.createServer(app);

// Setup graceful shutdown with in-flight request completion
const shutdownManager = setupGracefulShutdown(server, {
  shutdownTimeoutMs: 10000,
  onShutdown: async () => {
    logger.info('Running custom shutdown handlers');
    // Custom shutdown logic will be added here
  },
});

// SSH tunnel server and auth service (initialized in initializeTunnelSystem)
let sshProxy = null;
let sshAuthService = null;

// Health check service
const healthCheckService = new HealthCheckService(logger);

// Webhook routes MUST be mounted before body parsing middleware
// Stripe requires raw body for signature verification
app.use('/api/webhooks', webhookRoutes);
app.use('/webhooks', webhookRoutes); // Also register without /api prefix for api subdomain

// Swagger UI documentation endpoint
// Serves OpenAPI specification and interactive Swagger UI
app.use(
  '/api/docs',
  swaggerUi.serve,
  swaggerUi.setup(specs, {
    swaggerOptions: {
      url: '/api/docs/swagger.json',
      displayOperationId: true,
      filter: true,
      showExtensions: true,
      deepLinking: true,
    },
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'CloudToLocalLLM API Documentation',
  }),
);

// Serve OpenAPI specification as JSON
app.get('/api/docs/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(specs);
});

// Also serve docs without /api prefix for api subdomain
app.use(
  '/docs',
  swaggerUi.serve,
  swaggerUi.setup(specs, {
    swaggerOptions: {
      url: '/docs/swagger.json',
      displayOperationId: true,
      filter: true,
      showExtensions: true,
      deepLinking: true,
    },
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'CloudToLocalLLM API Documentation',
  }),
);

app.get('/docs/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(specs);
});

// Auth middleware wrapper for backward compatibility
async function authenticateToken(req, res, next) {
  const authMiddleware = getAuthMiddleware();
  return authMiddleware(req, res, next);
}

// Bridge connections removed - using HTTP polling only

// Initialize streaming proxy manager
const proxyManager = new StreamingProxyManager();

// Create WebSocket-based tunnel routes
const tunnelRouter = createTunnelRoutes(
  {
    AUTH0_DOMAIN,
    AUTH0_AUDIENCE,
  },
  sshProxy,
  logger,
  sshAuthService,
);

// Create monitoring routes
const monitoringRouter = createMonitoringRoutes(sshProxy, logger);

// API Routes
// Register routes both with /api prefix (for other subdomains) and without (for api subdomain)

// Simplified tunnel routes
app.use('/api/tunnel', tunnelRouter);
app.use('/tunnel', tunnelRouter); // Also register without /api prefix for api subdomain

// Performance monitoring routes
app.use('/api/monitoring', monitoringRouter);
app.use('/monitoring', monitoringRouter); // Also register without /api prefix for api subdomain

// Conversation management routes (initialized after database is ready)
// Will be set up in initializeTunnelSystem() after dbMigrator is initialized

// Database health endpoint
const dbHealthHandler = async (req, res) => {
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
};
app.get('/api/db/health', dbHealthHandler);
app.get('/db/health', dbHealthHandler); // Also register without /api prefix for api subdomain

// Authentication routes (token refresh, validation, logout)
app.use('/api/auth', authRoutes);
app.use('/auth', authRoutes); // Also register without /api prefix for api subdomain

// Session management routes
app.use('/api/auth/sessions', sessionRoutes);
app.use('/auth/sessions', sessionRoutes); // Also register without /api prefix for api subdomain

// Client log ingestion
app.use('/api/client-logs', clientLogRoutes);
app.use('/client-logs', clientLogRoutes); // Also register without /api prefix for api subdomain

// Database health check routes
app.use('/api/db', dbHealthRoutes);
app.use('/db', dbHealthRoutes); // Also register without /api prefix for api subdomain

// Database performance metrics routes
app.use('/api/database/performance', databasePerformanceRoutes);
app.use('/database/performance', databasePerformanceRoutes); // Also register without /api prefix for api subdomain

// TURN server credentials (authenticated)
app.use('/api/turn', turnCredentialsRoutes);
app.use('/turn', turnCredentialsRoutes); // Also register without /api prefix for api subdomain

// Administrative routes
app.use('/api/admin', adminRoutes);
app.use('/admin', adminRoutes); // Also register without /api prefix for api subdomain
app.use('/api/admin/users', adminUserRoutes);
app.use('/admin/users', adminUserRoutes); // Also register without /api prefix for api subdomain
app.use('/api/admin', adminSubscriptionRoutes);
app.use('/admin', adminSubscriptionRoutes); // Also register without /api prefix for api subdomain

// User tier management routes
app.use('/api/users', userRoutes);
app.use('/users', userRoutes); // Also register without /api prefix for api subdomain

// User profile management routes
app.use('/api/users', userProfileRoutes);
app.use('/users', userProfileRoutes); // Also register without /api prefix for api subdomain

// API Key management routes (for service-to-service authentication)
app.use('/api/api-keys', apiKeysRouter);
app.use('/api-keys', apiKeysRouter); // Also register without /api prefix for api subdomain

// Tunnel lifecycle management routes
app.use('/api/tunnels', tunnelRoutes);
app.use('/tunnels', tunnelRoutes); // Also register without /api prefix for api subdomain

// LLM Tunnel Cloud Proxy Endpoints (support both /api/ollama and /ollama)
const handleOllamaProxyRequest = async (req, res) => {
  const startTime = Date.now();
  const requestId = `llm-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  const userId = req.auth?.payload.sub;

  if (!userId) {
    return res.status(401).json({
      error: 'Authentication required',
      code: 'AUTH_REQUIRED',
      message: 'Please authenticate to access LLM services.',
    });
  }

  try {
    const basePath = req.path.startsWith('/ollama') ? '/ollama' : '/api/ollama';
    let ollamaPath = req.path.substring(basePath.length);
    if (!ollamaPath || ollamaPath.length === 0) {
      ollamaPath = '/';
    } else if (!ollamaPath.startsWith('/')) {
      ollamaPath = `/${ollamaPath}`;
    }
    const forwardHeaders = { ...req.headers };
    [
      'host',
      'authorization',
      'connection',
      'upgrade',
      'proxy-authenticate',
      'proxy-authorization',
      'te',
      'trailers',
      'transfer-encoding',
    ].forEach((h) => delete forwardHeaders[h]);

    const httpRequest = {
      id: requestId,
      method: req.method,
      path: ollamaPath,
      headers: forwardHeaders,
      body:
        req.method !== 'GET' && req.method !== 'HEAD'
          ? JSON.stringify(req.body)
          : undefined,
    };

    logger.debug(' [LLMTunnel] Forwarding request through tunnel', {
      userId,
      requestId,
      path: ollamaPath,
    });

    if (ollamaPath === '/bridge/status') {
      const isConnected = sshProxy && sshProxy.isUserConnected(userId);
      return res.json({
        status: isConnected ? 'connected' : 'disconnected',
        message: isConnected ? 'Bridge is connected' : 'Bridge is disconnected',
      });
    }

    if (!sshProxy) {
      return res.status(503).json({
        error: 'Tunnel system not available',
        code: 'TUNNEL_NOT_AVAILABLE',
        message: 'SSH tunnel server not initialized',
      });
    }

    const response = await sshProxy.forwardRequest(userId, httpRequest);

    const duration = Date.now() - startTime;
    logger.info(' [LLMTunnel] Request completed successfully via tunnel', {
      userId,
      requestId,
      duration,
      status: response.status,
    });

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
      } catch {
        res.send(response.body);
      }
    } else {
      res.end();
    }
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error(' [LLMTunnel] Request failed via tunnel', {
      userId,
      requestId,
      duration,
      error: error.message,
      code: error.code,
    });

    if (error.code === 'REQUEST_TIMEOUT') {
      return res
        .status(504)
        .json({ error: 'LLM request timeout', code: 'LLM_REQUEST_TIMEOUT' });
    }
    if (error.code === 'DESKTOP_CLIENT_DISCONNECTED') {
      return res.status(503).json({
        error: 'Desktop client not connected',
        code: 'DESKTOP_CLIENT_DISCONNECTED',
      });
    }
    res
      .status(500)
      .json({ error: 'LLM tunnel error', code: 'LLM_TUNNEL_ERROR' });
  }
};

const OLLAMA_ROUTE_PATHS = [
  '/api/ollama',
  '/api/ollama/:path(.*)',
  '/ollama',
  '/ollama/:path(.*)',
];
app.all(
  OLLAMA_ROUTE_PATHS,
  authenticateJWT,
  addTierInfo,
  handleOllamaProxyRequest,
);

// User tier endpoint
const userTierHandler = [
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const userTier = getUserTier(req.user);
      const features = getTierFeatures(userTier);

      res.json({
        tier: userTier,
        features: features,
        upgradeUrl:
          process.env.UPGRADE_URL ||
          'https://app.cloudtolocalllm.online/upgrade',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error getting user tier:', error);
      res.status(500).json({
        error: 'Failed to determine user tier',
        code: 'TIER_ERROR',
      });
    }
  },
];
app.get('/api/user/tier', ...userTierHandler);
app.get('/user/tier', ...userTierHandler); // Also register without /api prefix for api subdomain

// Health check endpoints
const healthHandler = async (req, res) => {
  try {
    const healthStatus = await healthCheckService.getHealthStatus();

    // Return appropriate HTTP status code based on health status
    let statusCode = 200;
    if (healthStatus.status === 'unhealthy') {
      statusCode = 503; // Service Unavailable
    } else if (healthStatus.status === 'degraded') {
      statusCode = 200; // Still return 200 but indicate degraded status
    }

    res.status(statusCode).json(healthStatus);
  } catch (error) {
    logger.error('Health check endpoint error:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      service: 'cloudtolocalllm-api',
      error: 'Health check failed',
      message: error.message,
    });
  }
};
app.get('/health', healthHandler);
app.get('/api/health', healthHandler); // Also register with /api prefix for backward compatibility

// API Version Information Endpoint
// Returns information about supported API versions
/**
 * @swagger
 * /api/versions:
 *   get:
 *     summary: Get API version information
 *     description: Returns information about all supported API versions, including current version, default version, and deprecation status
 *     tags:
 *       - System
 *     responses:
 *       200:
 *         description: API version information
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/APIVersionInfo'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
const versionInfoHandler = getVersionInfoHandler();
app.get('/api/versions', versionInfoHandler);
app.get('/versions', versionInfoHandler); // Also register without /api prefix for api subdomain

// Rate limit metrics routes
app.use('/api/metrics', rateLimitMetricsRoutes);
app.use('/metrics', rateLimitMetricsRoutes); // Also register without /api prefix for api subdomain

// Prometheus metrics routes
app.use('/api/prometheus', prometheusMetricsRoutes);
app.use('/prometheus', prometheusMetricsRoutes); // Also register without /api prefix for api subdomain

// Changelog and release notes routes
app.use('/api/changelog', changelogRoutes);
app.use('/changelog', changelogRoutes); // Also register without /api prefix for api subdomain

// Queue status endpoints
const queueStatusHandler = createQueueStatusHandler();
app.get('/api/queue/status', queueStatusHandler);
app.get('/queue/status', queueStatusHandler); // Also register without /api prefix for api subdomain

// Queue drain endpoint (for testing/debugging)
const queueDrainHandler = createQueueDrainHandler();
app.post('/api/queue/drain', authenticateJWT, queueDrainHandler);
app.post('/queue/drain', authenticateJWT, queueDrainHandler); // Also register without /api prefix for api subdomain

// WebSocket bridge endpoints removed - using HTTP polling only

// Streaming Proxy Management Endpoints

// Start streaming proxy for user
const proxyStartHandler = authenticateToken;
const proxyStartRoute = [
  proxyStartHandler,
  async (req, res) => {
    try {
      const userId = req.user.sub;
      const userToken = req.headers.authorization;

      logger.info(`Starting streaming proxy for user: ${userId}`);

      // Pass the user object for tier checking
      const proxyMetadata = await proxyManager.provisionProxy(
        userId,
        userToken,
        req.user,
      );

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
  },
];
app.post('/api/proxy/start', ...proxyStartRoute);
app.post('/proxy/start', ...proxyStartRoute); // Also register without /api prefix for api subdomain

// Stop streaming proxy for user
const proxyStopRoute = [
  authenticateToken,
  async (req, res) => {
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
  },
];
app.post('/api/proxy/stop', ...proxyStopRoute);
app.post('/proxy/stop', ...proxyStopRoute); // Also register without /api prefix for api subdomain

// Provision streaming proxy for user (with test mode support)
const proxyProvisionRoute = [
  authenticateToken,
  async (req, res) => {
    try {
      const userId = req.user.sub;
      const userToken = req.headers.authorization;
      const { testMode = false } = req.body;

      logger.info(
        `Provisioning streaming proxy for user: ${userId}, testMode: ${testMode}`,
      );

      if (testMode) {
        // In test mode, simulate successful provisioning without creating actual containers
        logger.info(
          `Test mode: Simulating proxy provisioning for user ${userId}`,
        );

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
      const proxyMetadata = await proxyManager.provisionProxy(
        userId,
        userToken,
        req.user,
      );

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
      logger.error(
        `Failed to provision proxy for user ${req.user.sub}:`,
        error,
      );
      res.status(500).json({
        error: 'Failed to provision streaming proxy',
        message: error.message,
        testMode: req.body.testMode || false,
      });
    }
  },
];
app.post('/api/streaming-proxy/provision', ...proxyProvisionRoute);
app.post('/streaming-proxy/provision', ...proxyProvisionRoute); // Also register without /api prefix for api subdomain

// Get streaming proxy status
const proxyStatusRoute = [
  authenticateToken,
  async (req, res) => {
    try {
      const userId = req.user.sub;
      const status = await proxyManager.getProxyStatus(userId);

      // Update activity if proxy is running
      if (status.status === 'running') {
        proxyManager.updateProxyActivity(userId);
      }

      res.json(status);
    } catch (error) {
      logger.error(
        `Failed to get proxy status for user ${req.user.sub}:`,
        error,
      );
      res.status(500).json({
        error: 'Failed to get proxy status',
        message: error.message,
      });
    }
  },
];
app.get('/api/proxy/status', ...proxyStatusRoute);
app.get('/proxy/status', ...proxyStatusRoute); // Also register without /api prefix for api subdomain

// Ollama proxy endpoints removed - using HTTP polling tunnel system instead

// The error handler must be registered before any other error middleware and after all controllers

// Sentry Error Handler must be before any other error middleware and after all controllers
Sentry.setupExpressErrorHandler(app);

// Error handling middleware
app.use((error, req, res, _next) => {
  logger.error('Unhandled error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message:
      process.env.NODE_ENV === 'development'
        ? error.message
        : 'Something went wrong',
  });
});

// Conversation routes - implemented directly due to router mounting issues
app.get('/conversations/', authenticateJWT, async (req, res) => {
  try {
    const userId = req.auth?.payload?.sub || req.user?.sub;
    if (!userId) {
      return res
        .status(401)
        .json({ error: 'Unauthorized', message: 'User ID not found in token' });
    }

    if (!dbMigrator || !dbMigrator.pool) {
      return res
        .status(503)
        .json({
          error: 'Service Unavailable',
          message: 'Database not initialized',
        });
    }

    const client = await dbMigrator.pool.connect();
    try {
      const { rows } = await client.query(
        `SELECT id, title, model, created_at, updated_at, metadata
         FROM conversations
         WHERE user_id = $1
         ORDER BY updated_at DESC`,
        [userId],
      );

      res.json({ conversations: rows });
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error('Failed to get conversations', { error: error.message });
    res
      .status(500)
      .json({
        error: 'Internal Server Error',
        message: 'Failed to get conversations',
      });
  }
});

app.put('/conversations/:id', authenticateJWT, async (req, res) => {
  try {
    const userId = req.auth?.payload?.sub || req.user?.sub;
    const conversationId = req.params.id;
    const { title, messages, model, metadata } = req.body;

    if (!userId) {
      return res
        .status(401)
        .json({ error: 'Unauthorized', message: 'User ID not found in token' });
    }

    if (!dbMigrator || !dbMigrator.pool) {
      return res
        .status(503)
        .json({
          error: 'Service Unavailable',
          message: 'Database not initialized',
        });
    }

    const client = await dbMigrator.pool.connect();
    try {
      await client.query('BEGIN');

      // Check if conversation exists
      const { rows: conversationRows } = await client.query(
        'SELECT id FROM conversations WHERE id = $1 AND user_id = $2',
        [conversationId, userId],
      );

      if (conversationRows.length === 0) {
        // Create new conversation
        const newModel = model || 'gpt-3.5-turbo';
        const newTitle = title || 'New Conversation';

        await client.query(
          `INSERT INTO conversations (id, user_id, title, model, metadata)
           VALUES ($1, $2, $3, $4, $5::jsonb)`,
          [
            conversationId,
            userId,
            newTitle,
            newModel,
            JSON.stringify(metadata || {}),
          ],
        );
      } else {
        // Update existing conversation
        if (title) {
          await client.query(
            'UPDATE conversations SET title = $1 WHERE id = $2',
            [title, conversationId],
          );
        }
        if (metadata) {
          await client.query(
            'UPDATE conversations SET metadata = $1::jsonb WHERE id = $2',
            [JSON.stringify(metadata), conversationId],
          );
        }
      }

      // Replace messages if provided
      if (messages && Array.isArray(messages)) {
        await client.query('DELETE FROM messages WHERE conversation_id = $1', [
          conversationId,
        ]);

        for (const msg of messages) {
          await client.query(
            `INSERT INTO messages (conversation_id, role, content, model, status, error, timestamp, metadata)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)`,
            [
              conversationId,
              msg.role || 'user',
              msg.content || '',
              msg.model || model || null,
              msg.status || 'sent',
              msg.error || null,
              msg.timestamp ? new Date(msg.timestamp) : new Date(),
              msg.metadata ? JSON.stringify(msg.metadata) : '{}',
            ],
          );
        }
      }

      await client.query('COMMIT');

      // Get updated conversation
      const { rows: updatedConversation } = await client.query(
        'SELECT id, title, model, created_at, updated_at, metadata FROM conversations WHERE id = $1',
        [conversationId],
      );

      const { rows: messageRows } = await client.query(
        `SELECT id, role, content, model, status, error, timestamp, metadata
         FROM messages WHERE conversation_id = $1 ORDER BY timestamp ASC`,
        [conversationId],
      );

      res.json({
        success: true,
        conversation: {
          ...updatedConversation[0],
          messages: messageRows,
        },
      });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error('Failed to update conversation', {
      error: error.message,
      conversationId: req.params.id,
    });
    res
      .status(500)
      .json({
        error: 'Internal Server Error',
        message: 'Failed to update conversation',
      });
  }
});

// Also mount at /api/conversations for backward compatibility
app.get('/api/conversations/', async (req, res) => {
  // Redirect to the main route
  const url = req.originalUrl.replace('/api/conversations/', '/conversations/');
  res.redirect(307, url);
});

app.put('/api/conversations/:id', async (req, res) => {
  // Redirect to the main route
  const url = req.originalUrl.replace('/api/conversations/', '/conversations/');
  res.redirect(307, url);
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// LLM Security and Monitoring Helper Functions - Removed unused functions
// (getRateLimitsForTier, checkRateLimit, recordRequest, logLLMAuditEvent)

// Initialize Tunnel System
let authService = null;
let dbMigrator = null;
let authDbMigrator = null;

async function initializeTunnelSystem() {
  logger.info('Starting initialization of tunnel system...');
  try {
    // Initialize centralized database connection pool (Requirement 17)
    logger.info('Initializing centralized database connection pool...');
    initializePool();
    logger.info('Database connection pool initialized successfully');

    // Initialize application database
    const dbType = process.env.DB_TYPE || 'sqlite';
    dbMigrator =
      dbType === 'postgresql'
        ? new DatabaseMigratorPG()
        : new DatabaseMigrator();

    await dbMigrator.initialize();
    await dbMigrator.createMigrationsTable();
    await dbMigrator.applyInitialSchema();
    await dbMigrator.migrate();

    const validation = await dbMigrator.validateSchema();
    if (!validation.allValid) {
      throw new Error('Database schema validation failed');
    }

    // Register database with health check service
    healthCheckService.registerDatabase(dbMigrator);
    logger.info('Database registered with health check service');

    // Start database pool monitoring (Requirement 17)
    logger.info('Starting database pool monitoring...');
    startMonitoring();
    logger.info('Database pool monitoring started successfully');

    // Initialize authentication database (separate instance)
    if (process.env.AUTH_DB_HOST) {
      logger.info('Initializing separate authentication database...');
      authDbMigrator = new AuthDatabaseMigratorPG({}, logger);
      await authDbMigrator.initialize();
      await authDbMigrator.migrate();
      logger.info('Authentication database initialized successfully');
    }

    // Initialize auth service (optional - don't fail if it doesn't work)
    try {
      authService = new AuthService({
        AUTH0_DOMAIN,
        AUTH0_AUDIENCE,
        authDbMigrator, // Pass auth database connection to auth service
        dbMigrator, // Pass main database connection to auth service
      });
      await authService.initialize();
      logger.info('Authentication service initialized successfully');

      // Register auth service with health check service
      healthCheckService.registerService('auth-service', async () => {
        return {
          status: authService ? 'healthy' : 'unhealthy',
          message: authService
            ? 'Authentication service is running'
            : 'Authentication service is not available',
        };
      });

      // Use the same auth service for SSH proxy
      sshAuthService = authService;

      // Initialize SSH Proxy
      try {
        sshProxy = new SSHProxy(
          logger,
          {
            sshPort: parseInt(process.env.SSH_PORT) || 2222,
          },
          sshAuthService,
        );
        await sshProxy.start();
        logger.info('SSH tunnel server initialized successfully');

        // Register SSH proxy with health check service
        healthCheckService.registerService('ssh-tunnel', async () => {
          return {
            status: sshProxy && sshProxy.isRunning ? 'healthy' : 'unhealthy',
            message:
              sshProxy && sshProxy.isRunning
                ? 'SSH tunnel is running'
                : 'SSH tunnel is not running',
          };
        });
      } catch (sshError) {
        logger.error('Failed to initialize SSH tunnel server', {
          error: sshError.message,
          stack: sshError.stack,
        });

        // Register SSH proxy as unhealthy
        healthCheckService.registerService('ssh-tunnel', async () => {
          return {
            status: 'unhealthy',
            message: 'SSH tunnel failed to initialize',
          };
        });
      }
    } catch (error) {
      logger.warn(
        'Authentication service initialization failed, continuing without auth features',
        { error: error.message },
      );
      authService = null; // Set to null so routes can handle missing auth service
    }

    // Initialize user profile service after database is ready
    try {
      await initializeUserProfileService();
      logger.info('User profile service initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize user profile service', {
        error: error.message,
      });
      // Don't fail the entire server startup, just log the error
    }

    // Initialize tunnel service after database is ready
    try {
      await initializeTunnelService();
      logger.info('Tunnel service initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize tunnel service', {
        error: error.message,
      });
      // Don't fail the entire server startup, just log the error
    }

    // Initialize conversation routes after database is ready
    logger.info('About to initialize conversation routes');
    try {
      // Temporary test route directly on app
      app.get('/test-route', (req, res) => {
        logger.info('Test route accessed directly on app');
        res.json({ message: 'Direct app route working' });
      });

      // Test direct routes on app
      app.get('/conversations/test', (req, res) => {
        logger.info('Direct conversation test route accessed');
        res.json({ message: 'Direct conversation test working' });
      });

      app.get('/conversations/', (req, res) => {
        logger.info('Direct conversation root route accessed');
        res.json({ message: 'Direct conversation root working' });
      });

      const conversationRouter = createConversationRoutes(dbMigrator, logger);
      logger.info('Conversation router created', {
        routerExists: !!conversationRouter,
      });
      app.use('/api/conversations', conversationRouter);
      app.use('/conversations-router', conversationRouter); // Use different path to avoid conflict
      logger.info('Conversation API routes initialized');

      // Add 404 handler after all routes are mounted
      app.use((req, res) => {
        res.status(404).json({ error: 'Not found' });
      });
      logger.info('404 handler registered');
    } catch (error) {
      logger.error('Failed to initialize conversation routes', {
        error: error.message,
        stack: error.stack,
      });
      // Don't fail the entire server startup, just log the error
      // Still add 404 handler
      app.use((req, res) => {
        res.status(404).json({ error: 'Not found' });
      });
    }

    logger.info('WebSocket tunnel system ready');

    // Register custom shutdown handler with graceful shutdown manager
    shutdownManager.shutdown = async () => {
      await gracefulShutdown();
    };

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
    // Stop database pool monitoring (Requirement 17)
    logger.info('Stopping database pool monitoring...');
    stopMonitoring();
    logger.info('Database pool monitoring stopped');

    if (sshProxy) {
      await sshProxy.stop();
    }
    if (authService) {
      await authService.close();
    }
    if (authDbMigrator) {
      await authDbMigrator.close();
    }
    if (dbMigrator) {
      await dbMigrator.close();
    }

    logger.info('All services closed successfully');
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
