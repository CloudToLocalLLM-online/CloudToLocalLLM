/**
 * @fileoverview Express routes for tunnel system health and status checks.
 * TODO: Replace with Chisel tunnel routes (see CHISEL_INTEGRATION_PLAN.md)
 * This file is a placeholder - old tunnel implementation removed.
 */

import express from 'express';
import winston from 'winston';
import { TunnelLogger, ERROR_CODES, ErrorResponseBuilder } from '../utils/logger.js';
import { AuthService } from '../auth/auth-service.js';
import { addTierInfo, requireFeature } from '../middleware/tier-check.js';

/**
 * Creates tunnel-related routes, primarily for health and status checks.
 * @param {Object} config - Configuration object.
 * @param {string} config.AUTH0_DOMAIN - Auth0 domain.
 * @param {string} config.AUTH0_AUDIENCE - Auth0 audience.
 * @param {Object} tunnelProxy - The tunnel proxy instance (ChiselProxy when implemented).
 * @param {winston.Logger} [logger] - Logger instance.
 * @returns {express.Router} The configured Express router.
 */
export function createTunnelRoutes(config, tunnelProxy, logger = winston.createLogger()) {
  const { AUTH0_DOMAIN, AUTH0_AUDIENCE } = config;
  const router = express.Router();

  const tunnelLogger = logger instanceof TunnelLogger ? logger : new TunnelLogger('tunnel-routes');

  const authService = new AuthService({
    AUTH0_DOMAIN,
    AUTH0_AUDIENCE,
  });

  async function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json(ErrorResponseBuilder.authenticationError('Bearer token is required.', ERROR_CODES.AUTH_TOKEN_MISSING));
    }

    try {
      const payload = await authService.validateToken(token);
      req.userId = payload.sub;
      next();
    } catch (error) {
      tunnelLogger.logSecurity('auth_token_invalid', null, { error: error.message });
      res.status(403).json(ErrorResponseBuilder.authenticationError('Invalid or expired token.', ERROR_CODES.AUTH_TOKEN_INVALID));
    }
  }

  router.use(authenticateToken);
  router.use(addTierInfo);

  // TODO: Replace with Chisel health checks (see CHISEL_INTEGRATION_PLAN.md)
  // Health check for a specific user's tunnel connection
  router.get('/health/:userId', requireFeature('tunneling'), (req, res) => {
    const { userId } = req.params;
    if (userId !== req.userId) {
      return res.status(403).json({ error: 'Forbidden', message: 'You can only check your own tunnel status.' });
    }
    // TODO: Replace with Chisel connection status
    if (!tunnelProxy) {
      return res.json({ 
        userId, 
        connected: false, 
        message: 'Chisel integration pending',
        timestamp: new Date().toISOString() 
      });
    }
    // const status = tunnelProxy.getUserConnectionStatus(userId);
    // res.json({ userId, ...status, timestamp: new Date().toISOString() });
    res.json({ userId, connected: false, message: 'Chisel integration pending', timestamp: new Date().toISOString() });
  });

  // General system-wide tunnel health
  router.get('/health', (req, res) => {
    try {
      // TODO: Replace with Chisel health status
      if (!tunnelProxy) {
        return res.status(503).json({ 
          status: 'pending',
          message: 'Chisel integration pending',
          timestamp: new Date().toISOString() 
        });
      }
      // const healthStatus = tunnelProxy.getHealthStatus();
      // const statusCode = healthStatus.status === 'healthy' ? 200 : 503;
      // res.status(statusCode).json(healthStatus);
      res.status(503).json({ status: 'pending', message: 'Chisel integration pending', timestamp: new Date().toISOString() });
    } catch (error) {
      tunnelLogger.logTunnelError(ERROR_CODES.INTERNAL_SERVER_ERROR, 'Failed to get tunnel health status', { error: error.message });
      res.status(500).json(ErrorResponseBuilder.internalServerError('Failed to retrieve health status.', ERROR_CODES.INTERNAL_SERVER_ERROR));
    }
  });

  // Get performance and connection metrics
  router.get('/metrics', requireFeature('tunneling'), (req, res) => {
    // TODO: Replace with Chisel metrics
    if (!tunnelProxy) {
      return res.json({
        system: { message: 'Chisel integration pending' },
        timestamp: new Date().toISOString(),
      });
    }
    // const stats = tunnelProxy.getStats();
    // res.json({
    //   system: stats,
    //   timestamp: new Date().toISOString(),
    // });
    res.json({
      system: { message: 'Chisel integration pending' },
      timestamp: new Date().toISOString(),
    });
  });

  return router;
}
