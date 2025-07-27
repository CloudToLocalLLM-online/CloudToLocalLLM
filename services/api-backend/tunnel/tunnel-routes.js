/**
 * @fileoverview Express routes and middleware for simplified tunnel system
 * Handles HTTP proxy endpoints and WebSocket connection setup
 */

import express from 'express';
import { WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-client';
import winston from 'winston';
import { TunnelProxy } from './tunnel-proxy.js';
import { TunnelLogger, ERROR_CODES, ErrorResponseBuilder } from '../utils/logger.js';
import { createTunnelRateLimitMiddleware } from '../middleware/rate-limiter.js';
// JWT validation is handled by the custom authenticateToken function below
import { createConnectionSecurityMiddleware, createWebSocketSecurityValidator } from '../middleware/connection-security.js';
import { createSecurityAuditMiddleware } from '../middleware/security-audit-logger.js';
import { createDirectProxyRoutes } from '../routes/direct-proxy-routes.js';
import { addTierInfo, requireFeature } from '../middleware/tier-check.js';

const router = express.Router();

/**
 * Create tunnel routes and WebSocket server
 * @param {http.Server} server - HTTP server instance
 * @param {Object} config - Configuration object
 * @param {string} config.AUTH0_DOMAIN - Auth0 domain
 * @param {string} config.AUTH0_AUDIENCE - Auth0 audience
 * @param {winston.Logger} [logger] - Logger instance
 * @returns {Object} Router and tunnel proxy instance
 */
export function createTunnelRoutes(server, config, logger = winston.createLogger()) {
  const { AUTH0_DOMAIN, AUTH0_AUDIENCE } = config;

  // Use enhanced logger if winston logger provided, otherwise create new TunnelLogger
  const tunnelLogger = logger instanceof TunnelLogger ? logger : new TunnelLogger('tunnel-routes');

  // JWKS client for token verification
  const jwksClientInstance = jwksClient({
    jwksUri: `https://${AUTH0_DOMAIN}/.well-known/jwks.json`,
    requestHeaders: {},
    timeout: 30000,
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5,
  });

  // Create tunnel proxy instance with enhanced logger
  const tunnelProxy = new TunnelProxy(tunnelLogger);

  // Create rate limiting middleware with tunnel-specific configuration
  const rateLimitMiddleware = createTunnelRateLimitMiddleware({
    windowMs: 15 * 60 * 1000, // 15 minutes
    maxRequests: 1000, // requests per window per user
    burstWindowMs: 60 * 1000, // 1 minute
    maxBurstRequests: 100, // requests per burst window per user
    maxConcurrentRequests: 50, // concurrent requests per user
    includeHeaders: true,
  });

  // JWT validation is handled by the custom authenticateToken function defined below

  // Create connection security middleware
  const connectionSecurityMiddleware = createConnectionSecurityMiddleware({
    enforceHttps: process.env.NODE_ENV === 'production',
    minTlsVersion: 'TLSv1.2',
    allowSelfSignedCerts: process.env.NODE_ENV !== 'production',
    websocketOriginCheck: true,
    allowedOrigins: [
      'https://app.cloudtolocalllm.online',
      'https://cloudtolocalllm.online',
      'https://docs.cloudtolocalllm.online',
      ...(process.env.NODE_ENV !== 'production' ? ['http://localhost:3000', 'http://localhost:8080'] : []),
    ],
  });

  // Create security audit middleware
  const securityAuditMiddleware = createSecurityAuditMiddleware({
    logLevel: process.env.LOG_LEVEL || 'info',
    enableConsoleOutput: true,
    enableFileOutput: process.env.NODE_ENV === 'production',
    auditLogFile: 'logs/security-audit.log',
    hashUserIds: true,
    hashIpAddresses: true,
    includeUserAgent: true,
    enableRealTimeAlerts: process.env.NODE_ENV === 'production',
    alertThresholds: {
      failedAuthAttempts: 10,
      suspiciousActivity: 5,
      rateLimitViolations: 20,
    },
  });

  /**
   * Verify JWT token and extract user ID
   * @param {string} token - JWT token
   * @returns {Promise<string>} User ID
   */
  async function verifyToken(token) {
    const decoded = jwt.decode(token, { complete: true });
    if (!decoded || !decoded.header.kid) {
      throw new Error('Invalid token format');
    }

    const key = await jwksClientInstance.getSigningKey(decoded.header.kid);
    const signingKey = key.getPublicKey();

    const verified = jwt.verify(token, signingKey, {
      audience: AUTH0_AUDIENCE,
      issuer: `https://${AUTH0_DOMAIN}/`,
      algorithms: ['RS256'],
    });

    return verified.sub;
  }

  /**
   * Middleware to authenticate and extract user ID from JWT token
   */
  async function authenticateToken(req, res, next) {
    const correlationId = tunnelLogger.generateCorrelationId();
    req.correlationId = correlationId;

    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      const errorResponse = ErrorResponseBuilder.authenticationError(
        'Authorization header with Bearer token is required',
        ERROR_CODES.AUTH_TOKEN_MISSING,
      );

      tunnelLogger.logSecurity('auth_token_missing', null, {
        correlationId,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        path: req.path,
      });

      return res.status(401).json(errorResponse);
    }

    try {
      const userId = await verifyToken(token);
      req.userId = userId;

      tunnelLogger.debug('Authentication successful', {
        correlationId,
        userId,
        path: req.path,
        method: req.method,
      });

      next();
    } catch (error) {
      let errorCode = ERROR_CODES.AUTH_TOKEN_INVALID;
      let message = 'The provided token is invalid or has expired';

      if (error.name === 'TokenExpiredError') {
        errorCode = ERROR_CODES.AUTH_TOKEN_EXPIRED;
        message = 'The provided token has expired';
      } else if (error.name === 'JsonWebTokenError') {
        errorCode = ERROR_CODES.AUTH_TOKEN_INVALID;
        message = 'The provided token is malformed or invalid';
      }

      const errorResponse = ErrorResponseBuilder.authenticationError(message, errorCode);

      tunnelLogger.logSecurity('auth_token_invalid', null, {
        correlationId,
        error: error.message,
        errorName: error.name,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        path: req.path,
      });

      return res.status(403).json(errorResponse);
    }
  }

  /**
   * Middleware to check if user's desktop client is connected
   */
  function requireTunnelConnection(req, res, next) {
    if (!tunnelProxy.isUserConnected(req.userId)) {
      const errorResponse = ErrorResponseBuilder.serviceUnavailableError(
        'Please ensure the CloudToLocalLLM desktop client is running and connected',
        ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED,
      );

      tunnelLogger.logRequest('failed', req.correlationId, req.userId, {
        correlationId: req.correlationId,
        reason: 'Desktop client not connected',
        path: req.path,
        method: req.method,
      });

      return res.status(503).json(errorResponse);
    }
    next();
  }

  // Create WebSocket security validator
  const websocketSecurityValidator = createWebSocketSecurityValidator({
    enforceHttps: process.env.NODE_ENV === 'production',
    minTlsVersion: 'TLSv1.2',
    allowSelfSignedCerts: process.env.NODE_ENV !== 'production',
    websocketOriginCheck: true,
    allowedOrigins: [
      'https://app.cloudtolocalllm.online',
      'https://cloudtolocalllm.online',
      'https://docs.cloudtolocalllm.online',
      ...(process.env.NODE_ENV !== 'production' ? ['http://localhost:3000', 'http://localhost:8080'] : []),
    ],
  });

  // WebSocket server for tunnel connections
  const wss = new WebSocketServer({
    server,
    path: '/ws/tunnel',
    verifyClient: async(info) => {
      const correlationId = tunnelLogger.generateCorrelationId();

      try {
        // First check connection security
        if (!websocketSecurityValidator(info)) {
          tunnelLogger.logSecurity('websocket_security_validation_failed', null, {
            correlationId,
            ip: info.req.socket.remoteAddress,
            origin: info.req.headers.origin,
            userAgent: info.req.headers['user-agent'],
          });
          return false;
        }

        const url = new URL(info.req.url, `http://${info.req.headers.host}`);
        const token = url.searchParams.get('token');

        if (!token) {
          tunnelLogger.logSecurity('websocket_auth_token_missing', null, {
            correlationId,
            ip: info.req.socket.remoteAddress,
            userAgent: info.req.headers['user-agent'],
          });
          return false;
        }

        const userId = await verifyToken(token);
        info.req.userId = userId;
        info.req.correlationId = correlationId;

        tunnelLogger.debug('WebSocket authentication successful', {
          correlationId,
          userId,
        });

        return true;
      } catch (error) {
        tunnelLogger.logSecurity('websocket_auth_failed', null, {
          correlationId,
          error: error.message,
          errorName: error.name,
          ip: info.req.socket.remoteAddress,
          userAgent: info.req.headers['user-agent'],
        });
        return false;
      }
    },
  });

  // Handle WebSocket connections
  wss.on('connection', (ws, req) => {
    const userId = req.userId;
    const correlationId = req.correlationId;

    if (!userId) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.AUTH_TOKEN_INVALID,
        'WebSocket connection without user ID',
        { correlationId },
      );
      ws.close(1008, 'Authentication failed');
      return;
    }

    try {
      const connectionId = tunnelProxy.handleConnection(ws, userId);
      tunnelLogger.logConnection('websocket_established', connectionId, userId, {
        correlationId,
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.WEBSOCKET_CONNECTION_FAILED,
        'Failed to handle tunnel WebSocket connection',
        {
          correlationId,
          userId,
          error: error.message,
        },
      );
      ws.close(1011, 'Internal server error');
    }
  });

  // Apply security middleware to all routes
  router.use(connectionSecurityMiddleware);
  router.use(securityAuditMiddleware);

  // Add tier information to all authenticated requests
  router.use(authenticateToken, addTierInfo);

  // Health check endpoint for specific user's tunnel
  router.get('/health/:userId', authenticateToken, (req, res) => {
    const { userId } = req.params;

    // Verify user can only check their own tunnel
    if (userId !== req.userId) {
      return res.status(403).json({
        error: 'Access denied',
        message: 'You can only check your own tunnel status',
      });
    }

    const status = tunnelProxy.getUserConnectionStatus(userId);
    res.json({
      userId,
      ...status,
      timestamp: new Date().toISOString(),
    });
  });

  // General tunnel status endpoint
  router.get('/status', authenticateToken, (req, res) => {
    const status = tunnelProxy.getUserConnectionStatus(req.userId);
    const stats = tunnelProxy.getStats();

    res.json({
      user: {
        userId: req.userId,
        ...status,
      },
      system: stats,
      timestamp: new Date().toISOString(),
    });
  });

  // Health check endpoint for tunnel system
  router.get('/health', (req, res) => {
    try {
      const healthStatus = tunnelProxy.getHealthStatus();
      const statusCode = healthStatus.status === 'healthy' ? 200 : 503;

      res.status(statusCode).json(healthStatus);
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to get tunnel health status',
        { error: error.message },
      );

      res.status(500).json(
        ErrorResponseBuilder.internalServerError(
          'Failed to retrieve health status',
          ERROR_CODES.INTERNAL_SERVER_ERROR,
        ),
      );
    }
  });

  // Direct proxy routes for free tier users (no containers)
  const directProxyRouter = createDirectProxyRoutes(tunnelProxy);
  router.use('/direct-proxy/:userId', (req, res, next) => {
    // Verify user can only access their own direct proxy
    if (req.params.userId !== req.userId) {
      return res.status(403).json({
        error: 'Access denied',
        message: 'You can only access your own direct proxy',
        code: 'DIRECT_PROXY_ACCESS_DENIED',
      });
    }
    next();
  }, directProxyRouter);

  // Performance metrics endpoint
  router.get('/metrics', authenticateToken, (req, res) => {
    try {
      const stats = tunnelProxy.getStats();
      const userStatus = tunnelProxy.getUserConnectionStatus(req.userId);

      res.json({
        user: {
          userId: req.userId,
          ...userStatus,
        },
        system: stats,
        performance: {
          averageResponseTime: stats.performance.averageResponseTime,
          successRate: stats.requests.successRate,
          timeoutRate: stats.requests.timeoutRate,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to get tunnel metrics',
        {
          userId: req.userId,
          correlationId: req.correlationId,
          error: error.message,
        },
      );

      res.status(500).json(
        ErrorResponseBuilder.internalServerError(
          'Failed to retrieve metrics',
          ERROR_CODES.INTERNAL_SERVER_ERROR,
        ),
      );
    }
  });

  // Proxy middleware for tunnel requests with rate limiting (premium/enterprise users)
  router.all('/:userId/*', authenticateToken, rateLimitMiddleware, requireFeature('containerOrchestration'), requireTunnelConnection, async(req, res) => {
    const { userId } = req.params;
    const startTime = Date.now();

    // Verify user can only access their own tunnel
    if (userId !== req.userId) {
      // Log cross-user access attempt to audit logger
      if (req.auditLogger) {
        req.auditLogger.logCrossUserAccessAttempt({
          correlationId: req.correlationId,
          requestedUserId: userId,
          actualUserId: req.userId,
          ip: req.ip,
          userAgent: req.get('User-Agent'),
          path: req.path,
          method: req.method,
          resource: req.path,
          action: req.method.toLowerCase(),
        });
      }

      const errorResponse = ErrorResponseBuilder.createErrorResponse(
        ERROR_CODES.AUTH_TOKEN_INVALID,
        'You can only access your own tunnel',
        403,
      );

      tunnelLogger.logSecurity('unauthorized_tunnel_access', req.userId, {
        correlationId: req.correlationId,
        requestedUserId: userId,
        actualUserId: req.userId,
        path: req.path,
        method: req.method,
      });

      return res.status(403).json(errorResponse);
    }

    // Extract the target path (everything after /:userId)
    const targetPath = '/' + req.params[0];

    // Build HTTP request object with validation
    try {
      const httpRequest = {
        method: req.method,
        path: targetPath,
        headers: { ...req.headers },
        ...(req.body && Object.keys(req.body).length > 0 && {
          body: typeof req.body === 'string' ? req.body : JSON.stringify(req.body),
        }),
      };

      // Remove proxy-specific headers
      delete httpRequest.headers['authorization'];
      delete httpRequest.headers['host'];
      delete httpRequest.headers['x-forwarded-for'];
      delete httpRequest.headers['x-real-ip'];

      tunnelLogger.debug('Forwarding request to desktop client', {
        correlationId: req.correlationId,
        userId,
        method: req.method,
        path: targetPath,
        headersCount: Object.keys(httpRequest.headers).length,
        hasBody: !!httpRequest.body,
      });

      const httpResponse = await tunnelProxy.forwardRequest(userId, httpRequest);
      const responseTime = Date.now() - startTime;

      // Set response headers
      Object.entries(httpResponse.headers || {}).forEach(([key, value]) => {
        try {
          res.setHeader(key, value);
        } catch (headerError) {
          tunnelLogger.warn('Failed to set response header', {
            correlationId: req.correlationId,
            userId,
            headerKey: key,
            headerValue: value,
            error: headerError.message,
          });
        }
      });

      // Send response
      res.status(httpResponse.status);

      if (httpResponse.body) {
        // Try to parse as JSON first, fallback to plain text
        try {
          const jsonBody = JSON.parse(httpResponse.body);
          res.json(jsonBody);
        } catch {
          res.send(httpResponse.body);
        }
      } else {
        res.end();
      }

      tunnelLogger.logPerformance('tunnel_request', responseTime, {
        correlationId: req.correlationId,
        userId,
        method: req.method,
        path: targetPath,
        statusCode: httpResponse.status,
        responseSize: httpResponse.body?.length || 0,
      });
    } catch (error) {
      const responseTime = Date.now() - startTime;

      tunnelLogger.logRequest('failed', req.correlationId, userId, {
        correlationId: req.correlationId,
        method: req.method,
        path: targetPath,
        responseTime,
        error: error.message,
        errorCode: error.code,
      });

      // Determine appropriate error response based on error code
      let errorResponse;
      let statusCode;

      if (error.code === ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED) {
        statusCode = 503;
        errorResponse = ErrorResponseBuilder.serviceUnavailableError(
          'Desktop client is not connected',
          ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED,
        );
      } else if (error.code === ERROR_CODES.REQUEST_TIMEOUT) {
        statusCode = 504;
        errorResponse = ErrorResponseBuilder.gatewayTimeoutError(
          'Request timed out after 30 seconds',
          ERROR_CODES.REQUEST_TIMEOUT,
        );
      } else if (error.code === ERROR_CODES.WEBSOCKET_SEND_FAILED) {
        statusCode = 503;
        errorResponse = ErrorResponseBuilder.serviceUnavailableError(
          'Failed to communicate with desktop client',
          ERROR_CODES.WEBSOCKET_SEND_FAILED,
        );
      } else if (error.code === ERROR_CODES.INVALID_REQUEST_FORMAT) {
        statusCode = 400;
        errorResponse = ErrorResponseBuilder.badRequestError(
          'Invalid request format',
          ERROR_CODES.INVALID_REQUEST_FORMAT,
        );
      } else {
        statusCode = 500;
        errorResponse = ErrorResponseBuilder.internalServerError(
          'Failed to process tunnel request',
          ERROR_CODES.INTERNAL_SERVER_ERROR,
        );
      }

      res.status(statusCode).json(errorResponse);
    }
  });

  return {
    router,
    tunnelProxy,
    wss,
  };
}
