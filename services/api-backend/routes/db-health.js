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
 * GET /api/db/pool/health
 * Perform a health check on the database connection pool
 * 
 * Response:
 * - 200: Pool is healthy
 * - 503: Pool is unhealthy or not initialized
 */
router.get('/pool/health', async (req, res) => {
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
 * GET /api/db/pool/metrics
 * Get current connection pool metrics
 * Requires admin authentication
 * 
 * Response:
 * - 200: Metrics retrieved successfully
 * - 401: Unauthorized (not admin)
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
