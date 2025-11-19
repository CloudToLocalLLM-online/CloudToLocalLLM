import express from 'express';
import http from 'http';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import winston from 'winston';
import dotenv from 'dotenv';
import { StreamingProxyManager } from './streaming-proxy-manager.js';

import adminRoutes from './routes/admin.js';
import adminUserRoutes from './routes/admin/users.js';
import adminSubscriptionRoutes from './routes/admin/subscriptions.js';
import sessionRoutes from './routes/sessions.js';
import clientLogRoutes from './routes/client-logs.js';
import webhookRoutes from './routes/webhooks.js';
// SSH tunnel integration
import { SSHProxy } from './tunnel/ssh-proxy.js';
import { AuthService } from './auth/auth-service.js';
import { DatabaseMigrator } from './database/migrate.js';
import { DatabaseMigratorPG } from './database/migrate-pg.js';
import { AuthDatabaseMigratorPG } from './database/migrate-auth-pg.js';
import { initializePool } from './database/db-pool.js';
import { startMonitoring, stopMonitoring } from './database/pool-monitor.js';
import dbHealthRoutes from './routes/db-health.js';
import turnCredentialsRoutes from './routes/turn-credentials.js';
import { createTunnelRoutes } from './tunnel/tunnel-routes.js';
import { createMonitoringRoutes } from './routes/monitoring.js';
import { createConversationRoutes } from './routes/conversations.js';
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
const AUTH0_DOMAIN =
  process.env.AUTH0_DOMAIN || 'dev-v2f2p008x3dr74ww.us.auth0.com';
const AUTH0_AUDIENCE =
  process.env.AUTH0_AUDIENCE || 'https://api.cloudtolocalllm.online';

// AuthService will be initialized in initializeHttpPollingSystem()

// Express app setup
const app = express();
const server = http.createServer(app);

// SSH tunnel server and auth service (initialized in initializeTunnelSystem)
let sshProxy = null;
let sshAuthService = null;

// Trust proxy headers (required for rate limiting behind nginx)
// Use specific proxy configuration to avoid ERR_ERL_PERMISSIVE_TRUST_PROXY
app.set('trust proxy', 1); // Trust first proxy (nginx)

// CORS configuration - MUST be before ALL other middleware (including Helmet)
// This ensures preflight OPTIONS requests are handled correctly
const corsOptions = {
  origin: function(origin, callback) {
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
  ],
  exposedHeaders: ['Content-Length', 'X-Requested-With'],
  maxAge: 86400, // Cache preflight for 24 hours
  preflightContinue: false,
  optionsSuccessStatus: 204,
};

// Apply CORS middleware FIRST - before Helmet and other middleware
app.use(cors(corsOptions));

// Handle preflight requests explicitly BEFORE other routes
// This ensures OPTIONS requests are handled before rate limiting or other middleware
app.options('*', cors(corsOptions), (req, res) => {
  // Explicitly end the OPTIONS request with 204 No Content
  res.status(204).end();
});

// Security middleware (after CORS to avoid interference)
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ['\'self\''],
        connectSrc: ['\'self\'', 'https:'],
        scriptSrc: ['\'self\'', '\'unsafe-inline\''],
        styleSrc: ['\'self\'', '\'unsafe-inline\''],
        imgSrc: ['\'self\'', 'data:', 'https:'],
      },
    },
    crossOriginResourcePolicy: { policy: 'cross-origin' }, // Allow CORS requests
  }),
);

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
    // Skip rate limiting for OPTIONS (preflight) requests
    // CORS preflight requests should not be rate limited
    if (req.method === 'OPTIONS') {
      return next();
    }
    // Apply more lenient limits to bridge routes
    if (req.path.startsWith('/api/bridge/')) {
      return bridgeLimiter(req, res, next);
    }
    // Apply standard limits to all other routes
    return standardLimiter(req, res, next);
  };
};

app.use(createConditionalRateLimiter());

// Webhook routes MUST be mounted before body parsing middleware
// Stripe requires raw body for signature verification
app.use('/api/webhooks', webhookRoutes);
app.use('/webhooks', webhookRoutes); // Also register without /api prefix for api subdomain

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
      return res
        .status(503)
        .json({ error: 'Authentication service not ready' });
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
const dbHealthHandler = async(req, res) => {
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

// Session management routes
app.use('/api/auth/sessions', sessionRoutes);
app.use('/auth/sessions', sessionRoutes); // Also register without /api prefix for api subdomain

// Client log ingestion
app.use('/api/client-logs', clientLogRoutes);
app.use('/client-logs', clientLogRoutes); // Also register without /api prefix for api subdomain

// Database health check routes
app.use('/api/db', dbHealthRoutes);
app.use('/db', dbHealthRoutes); // Also register without /api prefix for api subdomain

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

// LLM Tunnel Cloud Proxy Endpoints (support both /api/ollama and /ollama)
const handleOllamaProxyRequest = async(req, res) => {
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
      return res
        .status(503)
        .json({
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
  '/api/ollama/*',
  '/ollama',
  '/ollama/*',
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
const healthHandler = (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    tunnelSystem: 'websocket',
    service: 'cloudtolocalllm-api',
  });
};
app.get('/health', healthHandler);
app.get('/api/health', healthHandler); // Also register with /api prefix for backward compatibility

// WebSocket bridge endpoints removed - using HTTP polling only

// Streaming Proxy Management Endpoints

// Start streaming proxy for user
const proxyStartHandler = authenticateToken;
const proxyStartRoute = [
  proxyStartHandler,
  async(req, res) => {
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
  async(req, res) => {
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
  async(req, res) => {
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
  async(req, res) => {
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

    const validation = await dbMigrator.validateSchema();
    if (!validation.allValid) {
      throw new Error('Database schema validation failed');
    }

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
      });
      await authService.initialize();
      logger.info('Authentication service initialized successfully');

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
      } catch (sshError) {
        logger.error('Failed to initialize SSH tunnel server', {
          error: sshError.message,
          stack: sshError.stack,
        });
      }

    } catch (error) {
      logger.warn(
        'Authentication service initialization failed, continuing without auth features',
        { error: error.message },
      );
      authService = null; // Set to null so routes can handle missing auth service
    }

    // Initialize conversation routes after database is ready
    const conversationRouter = createConversationRoutes(dbMigrator, logger);
    app.use('/api/conversations', conversationRouter);
    app.use('/conversations', conversationRouter); // Also register without /api prefix for api subdomain
    logger.info('Conversation API routes initialized');

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
