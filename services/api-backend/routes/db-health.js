/**
 * Database Health Check API Routes
 *
 * Provides endpoints for monitoring database connection pool health:
 * - GET /api/db/pool/health - Database connection health check
 * - GET /api/db/pool/metrics - Connection pool metrics
 * - GET /api/db/pool/status - Monitoring status
 *
 * Requirements: 17 (Data Persistence and Storage)
 */

import express from 'express';
import { healthCheck, getPoolMetrics } from '../database/db-pool.js';
import { getMonitoringStatus } from '../database/pool-monitor.js';
import { adminAuth } from '../middleware/admin-auth.js';
import logger from '../logger.js';

const router = express.Router();

/**
 * @swagger
 * /db/pool/health:
 *   get:
 *     summary: Database connection pool health check
 *     description: |
 *       Performs a health check on the database connection pool.
 *       Returns pool status, response time, and metrics.
 *       
 *       **Validates: Requirements 9.10**
 *       - Provides database health check endpoints
 *     tags:
 *       - Database
 *     responses:
 *       200:
 *         description: Pool is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   enum: [healthy, unhealthy, error]
 *                 responseTime:
 *                   type: integer
 *                   description: Response time in milliseconds
 *                 poolMetrics:
 *                   type: object
 *                   properties:
 *                     totalConnections:
 *                       type: integer
 *                     availableConnections:
 *                       type: integer
 *                     activeConnections:
 *                       type: integer
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *       503:
 *         description: Pool is unhealthy
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get('/pool/health', async(req, res) => {
  try {
    const result = await healthCheck();

    if (result.healthy) {
      res.json({
        status: 'healthy',
        responseTime: result.responseTime,
        poolMetrics: result.poolMetrics,
        timestamp: result.timestamp,
      });
    } else {
      res.status(503).json({
        status: 'unhealthy',
        error: result.error,
        responseTime: result.responseTime,
        timestamp: result.timestamp,
      });
    }
  } catch (error) {
    logger.error('🔴 [DB Health] Health check endpoint error', {
      error: error.message,
    });

    res.status(500).json({
      status: 'error',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

/**
 * @swagger
 * /db/pool/metrics:
 *   get:
 *     summary: Get database connection pool metrics
 *     description: |
 *       Returns detailed metrics about the database connection pool.
 *       Requires admin authentication.
 *       
 *       **Validates: Requirements 9.7**
 *       - Tracks database performance metrics
 *     tags:
 *       - Database
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Pool metrics retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                 metrics:
 *                   type: object
 *                   properties:
 *                     totalConnections:
 *                       type: integer
 *                     availableConnections:
 *                       type: integer
 *                     activeConnections:
 *                       type: integer
 *                     waitingRequests:
 *                       type: integer
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       403:
 *         $ref: '#/components/responses/ForbiddenError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get('/pool/metrics', adminAuth(['view_system_metrics']), (req, res) => {
  try {
    const metrics = getPoolMetrics();

    res.json({
      status: 'success',
      metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [DB Health] Metrics endpoint error', {
      error: error.message,
    });

    res.status(500).json({
      status: 'error',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

/**
 * GET /api/db/pool/status
 * Get monitoring status
 * Requires admin authentication
 *
 * Response:
 * - 200: Status retrieved successfully
 * - 401: Unauthorized (not admin)
 */
router.get('/pool/status', adminAuth(['view_system_metrics']), (req, res) => {
  try {
    const status = getMonitoringStatus();

    res.json({
      status: 'success',
      monitoring: status,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [DB Health] Status endpoint error', {
      error: error.message,
    });

    res.status(500).json({
      status: 'error',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

export default router;
