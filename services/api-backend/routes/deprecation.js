/**
 * API Deprecation Routes
 *
 * Provides endpoints for deprecation information and migration guides.
 * Allows clients to discover deprecated endpoints and access migration documentation.
 *
 * Requirements: 12.5
 */

import express from 'express';
import {
  getDeprecationStatusReport,
  getAllDeprecatedEndpoints,
  getAllSunsetEndpoints,
  getMigrationGuide,
  getDeprecationInfo,
  MIGRATION_GUIDES,
} from '../services/deprecation-service.js';

const router = express.Router();

/**
 * @swagger
 * /api/deprecation/status:
 *   get:
 *     summary: Get API deprecation status report
 *     description: Returns information about all deprecated and sunset endpoints
 *     tags:
 *       - Deprecation
 *     responses:
 *       200:
 *         description: Deprecation status report
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *                 deprecatedEndpoints:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       path:
 *                         type: string
 *                       status:
 *                         type: string
 *                       deprecatedAt:
 *                         type: string
 *                       sunsetAt:
 *                         type: string
 *                       replacedBy:
 *                         type: string
 *                       daysUntilSunset:
 *                         type: integer
 *                 sunsetEndpoints:
 *                   type: array
 *                   items:
 *                     type: object
 *                 totalDeprecated:
 *                   type: integer
 *                 totalSunset:
 *                   type: integer
 */
router.get('/status', (req, res) => {
  try {
    const report = getDeprecationStatusReport();
    res.json(report);
  } catch {
    res.status(500).json({
      error: {
        code: 'DEPRECATION_STATUS_ERROR',
        message: 'Failed to retrieve deprecation status',
        statusCode: 500,
      },
    });
  }
});

/**
 * @swagger
 * /api/deprecation/deprecated:
 *   get:
 *     summary: Get list of deprecated endpoints
 *     description: Returns all currently deprecated API endpoints
 *     tags:
 *       - Deprecation
 *     responses:
 *       200:
 *         description: List of deprecated endpoints
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 endpoints:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       path:
 *                         type: string
 *                       status:
 *                         type: string
 *                       deprecatedAt:
 *                         type: string
 *                       sunsetAt:
 *                         type: string
 *                       replacedBy:
 *                         type: string
 *                       reason:
 *                         type: string
 *                       daysUntilSunset:
 *                         type: integer
 *                 count:
 *                   type: integer
 */
router.get('/deprecated', (req, res) => {
  try {
    const endpoints = getAllDeprecatedEndpoints();
    res.json({
      endpoints,
      count: endpoints.length,
    });
  } catch {
    res.status(500).json({
      error: {
        code: 'DEPRECATED_LIST_ERROR',
        message: 'Failed to retrieve deprecated endpoints',
        statusCode: 500,
      },
    });
  }
});

/**
 * @swagger
 * /api/deprecation/sunset:
 *   get:
 *     summary: Get list of sunset endpoints
 *     description: Returns all API endpoints that have been removed (sunset)
 *     tags:
 *       - Deprecation
 *     responses:
 *       200:
 *         description: List of sunset endpoints
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 endpoints:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       path:
 *                         type: string
 *                       status:
 *                         type: string
 *                       sunsetAt:
 *                         type: string
 *                       replacedBy:
 *                         type: string
 *                 count:
 *                   type: integer
 */
router.get('/sunset', (req, res) => {
  try {
    const endpoints = getAllSunsetEndpoints();
    res.json({
      endpoints,
      count: endpoints.length,
    });
  } catch {
    res.status(500).json({
      error: {
        code: 'SUNSET_LIST_ERROR',
        message: 'Failed to retrieve sunset endpoints',
        statusCode: 500,
      },
    });
  }
});

/**
 * @swagger
 * /api/deprecation/migration-guide/{guideId}:
 *   get:
 *     summary: Get migration guide for deprecated endpoint
 *     description: Returns detailed migration guide for a deprecated endpoint
 *     tags:
 *       - Deprecation
 *     parameters:
 *       - in: path
 *         name: guideId
 *         required: true
 *         schema:
 *           type: string
 *         description: Migration guide identifier (e.g., MIGRATION_V1_TO_V2)
 *     responses:
 *       200:
 *         description: Migration guide
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 title:
 *                   type: string
 *                 description:
 *                   type: string
 *                 steps:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       step:
 *                         type: integer
 *                       title:
 *                         type: string
 *                       description:
 *                         type: string
 *                       before:
 *                         type: string
 *                       after:
 *                         type: string
 *                 resources:
 *                   type: object
 *                 timeline:
 *                   type: object
 *       404:
 *         description: Migration guide not found
 */
router.get('/migration-guide/:guideId', (req, res) => {
  try {
    const { guideId } = req.params;
    const guide = MIGRATION_GUIDES[guideId];

    if (!guide) {
      return res.status(404).json({
        error: {
          code: 'MIGRATION_GUIDE_NOT_FOUND',
          message: `Migration guide '${guideId}' not found`,
          statusCode: 404,
          suggestion: 'Check the guide ID and try again',
        },
      });
    }

    res.json(guide);
  } catch {
    res.status(500).json({
      error: {
        code: 'MIGRATION_GUIDE_ERROR',
        message: 'Failed to retrieve migration guide',
        statusCode: 500,
      },
    });
  }
});

/**
 * @swagger
 * /api/deprecation/endpoint-info:
 *   get:
 *     summary: Get deprecation info for a specific endpoint
 *     description: Returns deprecation information for a specific API endpoint
 *     tags:
 *       - Deprecation
 *     parameters:
 *       - in: query
 *         name: path
 *         required: true
 *         schema:
 *           type: string
 *         description: API endpoint path (e.g., /v1/users)
 *     responses:
 *       200:
 *         description: Endpoint deprecation information
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 path:
 *                   type: string
 *                 status:
 *                   type: string
 *                 deprecatedAt:
 *                   type: string
 *                 sunsetAt:
 *                   type: string
 *                 replacedBy:
 *                   type: string
 *                 reason:
 *                   type: string
 *                 migrationGuide:
 *                   type: object
 *       404:
 *         description: Endpoint not found or not deprecated
 */
router.get('/endpoint-info', (req, res) => {
  try {
    const { path } = req.query;

    if (!path) {
      return res.status(400).json({
        error: {
          code: 'MISSING_PATH_PARAMETER',
          message: 'path query parameter is required',
          statusCode: 400,
          suggestion: 'Provide the endpoint path as a query parameter',
        },
      });
    }

    const info = getDeprecationInfo(path);

    if (!info) {
      return res.status(404).json({
        error: {
          code: 'ENDPOINT_NOT_DEPRECATED',
          message: `Endpoint '${path}' is not deprecated`,
          statusCode: 404,
        },
      });
    }

    res.json({
      path,
      ...info,
      migrationGuide: getMigrationGuide(path),
    });
  } catch {
    res.status(500).json({
      error: {
        code: 'ENDPOINT_INFO_ERROR',
        message: 'Failed to retrieve endpoint information',
        statusCode: 500,
      },
    });
  }
});

export default router;
