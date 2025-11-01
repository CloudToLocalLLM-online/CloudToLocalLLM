/**
 * @fileoverview WebSocket server setup for tunnel connections
 * Integrates the TunnelProxy class with Express HTTP server
 */

import { WebSocketServer } from 'ws';
import { TunnelProxy } from './tunnel/tunnel-proxy.js';
import { AuthService } from './auth/auth-service.js';
import jwt from 'jsonwebtoken';

/**
 * Setup WebSocket server for tunnel connections
 * @param {http.Server} server - HTTP server instance
 * @param {Object} config - Configuration object
 * @param {winston.Logger} logger - Logger instance
 * @returns {TunnelProxy} Tunnel proxy instance
 */
export function setupWebSocketTunnel(server, config, logger) {
  const { AUTH0_DOMAIN, AUTH0_AUDIENCE } = config;

  // Create AuthService for JWT validation
  const authService = new AuthService({
    AUTH0_DOMAIN,
    AUTH0_AUDIENCE,
  });

  // Create WebSocket server
  const wss = new WebSocketServer({
    server,
    path: '/ws/tunnel',
    // Verify origin in production
    verifyClient: (info, callback) => {
      if (process.env.NODE_ENV === 'production') {
        const allowedOrigins = [
          `https://${config.DOMAIN}`,
          `https://app.${config.DOMAIN}`,
          `https://api.${config.DOMAIN}`,
        ];
        
        const origin = info.origin || info.req.headers.origin;
        if (origin && !allowedOrigins.includes(origin)) {
          logger.warn('WebSocket connection rejected - invalid origin', { origin });
          callback(false, 403, 'Invalid origin');
          return;
        }
      }
      callback(true);
    },
  });

  // Create TunnelProxy instance
  const tunnelProxy = new TunnelProxy(logger);

  logger.info('WebSocket server created', {
    path: '/ws/tunnel',
    port: server.address()?.port || 'not bound yet',
  });

  // Handle WebSocket connections
  wss.on('connection', async (ws, req) => {
    logger.info('New WebSocket connection attempt', {
      ip: req.socket.remoteAddress,
      userAgent: req.headers['user-agent'],
    });

    try {
      // Extract and validate JWT token from query params or headers
      const token = extractToken(req);
      
      if (!token) {
        logger.warn('WebSocket connection rejected - no token', {
          ip: req.socket.remoteAddress,
        });
        ws.close(4001, 'Authentication required');
        return;
      }

      // Validate token using AuthService
      const validationResult = await authService.validateToken(token);
      if (!validationResult.valid) {
        logger.warn('WebSocket connection rejected - token validation failed', {
          ip: req.socket.remoteAddress,
        });
        ws.close(4001, 'Invalid token');
        return;
      }
      const userId = validationResult.payload.sub;

      if (!userId) {
        logger.warn('WebSocket connection rejected - invalid token payload', {
          ip: req.socket.remoteAddress,
        });
        ws.close(4001, 'Invalid token');
        return;
      }

      logger.info('WebSocket authentication successful', {
        userId,
        ip: req.socket.remoteAddress,
      });

      // Register connection with TunnelProxy
      const connectionId = tunnelProxy.handleConnection(ws, userId);

      logger.info('Tunnel connection established', {
        userId,
        connectionId,
        totalConnections: tunnelProxy.connections.size,
      });

    } catch (error) {
      logger.error('WebSocket authentication failed', {
        error: error.message,
        ip: req.socket.remoteAddress,
      });
      ws.close(4001, 'Authentication failed');
    }
  });

  // Handle server-level errors
  wss.on('error', (error) => {
    logger.error('WebSocket server error', {
      error: error.message,
      stack: error.stack,
    });
  });

  // Log when server starts listening
  wss.on('listening', () => {
    logger.info('WebSocket server listening', {
      path: '/ws/tunnel',
    });
  });

  return tunnelProxy;
}

/**
 * Extract JWT token from WebSocket upgrade request
 * Checks query params and Authorization header
 * @param {http.IncomingMessage} req - HTTP request
 * @returns {string|null} JWT token or null
 */
function extractToken(req) {
  // Try query parameter first (common for WebSocket connections)
  const url = new URL(req.url, `http://${req.headers.host}`);
  const queryToken = url.searchParams.get('token');
  if (queryToken) {
    return queryToken;
  }

  // Try Authorization header
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }

  // Try sec-websocket-protocol header (alternative approach)
  const protocols = req.headers['sec-websocket-protocol'];
  if (protocols) {
    const parts = protocols.split(', ');
    for (const part of parts) {
      if (part.startsWith('token-')) {
        return part.substring(6);
      }
    }
  }

  return null;
}

