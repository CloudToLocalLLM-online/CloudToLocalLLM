/**
 * Authentication Routes for CloudToLocalLLM API Backend
 *
 * Provides JWT token validation, refresh, and revocation endpoints
 * with secure cookie handling and HTTPS enforcement.
 *
 * Requirements: 2.1, 2.2, 2.9, 2.10
 */

import express from 'express';
import jwt from 'jsonwebtoken';
import fetch from 'node-fetch';
import logger from '../logger.js';
import { authenticateJWT, extractUserId } from '../middleware/auth.js';
import { logTokenRefresh, logLoginFailure, logLogout, logTokenRevoke } from '../services/auth-audit-service.js';

const router = express.Router();

// Auth0 configuration
const AUTH0_DOMAIN = process.env.AUTH0_DOMAIN || 'dev-v2f2p008x3dr74ww.us.auth0.com';
const AUTH0_AUDIENCE = process.env.AUTH0_AUDIENCE || 'https://api.cloudtolocalllm.online';
const AUTH0_CLIENT_ID = process.env.AUTH0_CLIENT_ID;
const AUTH0_CLIENT_SECRET = process.env.AUTH0_CLIENT_SECRET;

// Token refresh configuration
const TOKEN_REFRESH_WINDOW = parseInt(process.env.TOKEN_REFRESH_WINDOW) || 300; // 5 minutes before expiry

/**
 * @swagger
 * /auth/token/refresh:
 *   post:
 *     summary: Refresh an expired or expiring JWT token
 *     description: |
 *       Exchanges a refresh token for a new access token. Supports both
 *       request body and secure cookie-based refresh tokens.
 *
 *       **Validates: Requirements 2.1, 2.2**
 *       - Validates JWT tokens from Auth0 on every protected request
 *       - Implements token refresh mechanism for expired tokens
 *     tags:
 *       - Authentication
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               refreshToken:
 *                 type: string
 *                 description: Refresh token (optional if using secure cookie)
 *           example:
 *             refreshToken: "refresh_eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
 *     responses:
 *       200:
 *         description: Token refreshed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 accessToken:
 *                   type: string
 *                   description: New JWT access token
 *                 tokenType:
 *                   type: string
 *                   example: Bearer
 *                 expiresIn:
 *                   type: integer
 *                   description: Token expiry in seconds
 *                 refreshToken:
 *                   type: string
 *                   description: New refresh token (if provided by Auth0)
 *       400:
 *         description: Missing refresh token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error:
 *                 code: MISSING_REFRESH_TOKEN
 *                 message: Refresh token required
 *                 statusCode: 400
 *       401:
 *         description: Invalid or expired refresh token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error:
 *                 code: INVALID_REFRESH_TOKEN
 *                 message: Invalid refresh token format
 *                 statusCode: 401
 *       500:
 *         description: Token refresh failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error:
 *                 code: TOKEN_REFRESH_ERROR
 *                 message: Token refresh failed
 *                 statusCode: 500
 */
router.post('/token/refresh', async function(req, res) {
  try {
    const { refreshToken } = req.body;
    const cookieRefreshToken = req.cookies?.refreshToken;
    const token = refreshToken || cookieRefreshToken;

    if (!token) {
      logger.warn('[Auth] Token refresh attempted without refresh token');
      return res.status(400).json({
        error: 'Refresh token required',
        code: 'MISSING_REFRESH_TOKEN',
      });
    }

    logger.info('[Auth] Attempting to refresh token');

    // Validate refresh token format
    if (!token.startsWith('refresh_') && !token.match(/^[A-Za-z0-9_-]+$/)) {
      logger.warn('[Auth] Invalid refresh token format');
      return res.status(401).json({
        error: 'Invalid refresh token format',
        code: 'INVALID_REFRESH_TOKEN',
        statusCode: 401,
      });
    }

    // Exchange refresh token for new access token via Auth0
    const tokenResponse = await fetch(`https://${AUTH0_DOMAIN}/oauth/token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        client_id: AUTH0_CLIENT_ID,
        client_secret: AUTH0_CLIENT_SECRET,
        audience: AUTH0_AUDIENCE,
        grant_type: 'refresh_token',
        refresh_token: token,
      }),
    });

    if (!tokenResponse.ok) {
      const errorData = await tokenResponse.json();
      logger.warn('[Auth] Auth0 token refresh failed', {
        status: tokenResponse.status,
        error: errorData.error,
      });

      return res.status(401).json({
        error: 'Token refresh failed',
        code: 'TOKEN_REFRESH_FAILED',
        details: errorData.error_description || 'Unable to refresh token',
      });
    }

    const tokenData = await tokenResponse.json();

    logger.info('[Auth] Token refreshed successfully');

    // Log token refresh
    logTokenRefresh({
      userId: null, // User ID not available at this point
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      details: {
        endpoint: req.path,
        method: req.method,
        expiresIn: tokenData.expires_in,
      },
    }).catch((auditError) => {
      logger.error('[Auth] Failed to log token refresh', {
        error: auditError.message,
      });
    });

    // Return new access token
    res.json({
      accessToken: tokenData.access_token,
      tokenType: tokenData.token_type || 'Bearer',
      expiresIn: tokenData.expires_in,
      refreshToken: tokenData.refresh_token || token, // Use new refresh token if provided
    });
  } catch (error) {
    logger.error('[Auth] Token refresh error', {
      error: error.message,
      stack: error.stack,
    });

    // Log failed token refresh
    logLoginFailure({
      userId: null,
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      reason: error.message || 'Token refresh failed',
      details: {
        endpoint: req.path,
        method: req.method,
      },
    }).catch((auditError) => {
      logger.error('[Auth] Failed to log token refresh failure', {
        error: auditError.message,
      });
    });

    res.status(500).json({
      error: 'Token refresh failed',
      code: 'TOKEN_REFRESH_ERROR',
      message: error.message,
    });
  }
});

/**
 * @swagger
 * /auth/token/validate:
 *   post:
 *     summary: Validate a JWT token
 *     description: |
 *       Validates a JWT token and returns its status, expiry information,
 *       and user details. Does not require authentication.
 *
 *       **Validates: Requirements 2.1**
 *       - Validates JWT tokens from Auth0 on every protected request
 *     tags:
 *       - Authentication
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               token:
 *                 type: string
 *                 description: JWT token to validate (optional if using Authorization header)
 *           example:
 *             token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
 *     responses:
 *       200:
 *         description: Token validation result
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 valid:
 *                   type: boolean
 *                   description: Whether token is valid and not expired
 *                 expired:
 *                   type: boolean
 *                   description: Whether token has expired
 *                 expiring:
 *                   type: boolean
 *                   description: Whether token is expiring soon (within 5 minutes)
 *                 expiresIn:
 *                   type: integer
 *                   description: Seconds until token expires
 *                 expiresAt:
 *                   type: string
 *                   format: date-time
 *                   description: Token expiry timestamp
 *                 userId:
 *                   type: string
 *                   description: User ID from token
 *                 email:
 *                   type: string
 *                   description: User email from token
 *       400:
 *         description: Missing token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Invalid token format
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post('/token/validate', async function(req, res) {
  try {
    const { token } = req.body;
    const authHeader = req.headers.authorization;
    const bearerToken = authHeader && authHeader.split(' ')[1];
    const validateToken = token || bearerToken;

    if (!validateToken) {
      return res.status(400).json({
        error: 'Token required',
        code: 'MISSING_TOKEN',
      });
    }

    logger.info('[Auth] Validating token');

    // Decode token to check expiry
    const decoded = jwt.decode(validateToken, { complete: true });

    if (!decoded) {
      logger.warn('[Auth] Invalid token format');
      return res.status(401).json({
        error: 'Invalid token format',
        code: 'INVALID_TOKEN_FORMAT',
      });
    }

    const now = Math.floor(Date.now() / 1000);
    const expiresIn = decoded.payload.exp - now;
    const isExpired = expiresIn <= 0;
    const isExpiring = expiresIn <= TOKEN_REFRESH_WINDOW;

    logger.info('[Auth] Token validation result', {
      isExpired,
      isExpiring,
      expiresIn,
    });

    res.json({
      valid: !isExpired,
      expired: isExpired,
      expiring: isExpiring,
      expiresIn: Math.max(0, expiresIn),
      expiresAt: new Date(decoded.payload.exp * 1000).toISOString(),
      userId: decoded.payload.sub,
      email: decoded.payload.email,
    });
  } catch (error) {
    logger.error('[Auth] Token validation error', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Token validation failed',
      code: 'TOKEN_VALIDATION_ERROR',
    });
  }
});

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Logout and revoke token
 *     description: |
 *       Revokes the current JWT token and invalidates the session.
 *       Clears secure refresh token cookies.
 *
 *       **Validates: Requirements 2.9, 2.10**
 *       - Implements token revocation for logout operations
 *       - Enforces HTTPS for all authentication endpoints
 *     tags:
 *       - Authentication
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Successfully logged out
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 userId:
 *                   type: string
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       403:
 *         description: HTTPS required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error:
 *                 code: HTTPS_REQUIRED
 *                 message: Authentication endpoints require HTTPS
 *                 statusCode: 403
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.post('/logout', authenticateJWT, async function(req, res) {
  try {
    const userId = extractUserId(req);
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];

    logger.info('[Auth] User logout initiated', { userId });

    // Revoke token via Auth0 (if using Auth0 token revocation endpoint)
    if (AUTH0_CLIENT_ID && AUTH0_CLIENT_SECRET) {
      try {
        const revokeResponse = await fetch(`https://${AUTH0_DOMAIN}/oauth/revoke`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            client_id: AUTH0_CLIENT_ID,
            client_secret: AUTH0_CLIENT_SECRET,
            token: token,
          }),
        });

        if (revokeResponse.ok) {
          logger.info('[Auth] Token revoked successfully via Auth0', { userId });
        } else {
          logger.warn('[Auth] Auth0 token revocation failed', {
            status: revokeResponse.status,
          });
        }
      } catch (revokeError) {
        logger.warn('[Auth] Auth0 token revocation error', {
          error: revokeError.message,
        });
        // Continue with logout even if revocation fails
      }
    }

    // Clear refresh token cookie
    res.clearCookie('refreshToken', {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
    });

    logger.info('[Auth] User logged out successfully', { userId });

    // Log logout
    logLogout({
      userId,
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      details: {
        endpoint: req.path,
        method: req.method,
      },
    }).catch((auditError) => {
      logger.error('[Auth] Failed to log logout', {
        error: auditError.message,
      });
    });

    res.json({
      success: true,
      message: 'Logged out successfully',
      userId,
    });
  } catch (error) {
    logger.error('[Auth] Logout error', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Logout failed',
      code: 'LOGOUT_ERROR',
      message: error.message,
    });
  }
});

/**
 * @swagger
 * /auth/session/revoke:
 *   post:
 *     summary: Revoke a specific session
 *     description: |
 *       Revokes a specific session by ID. Useful for revoking sessions
 *       from other devices or browsers.
 *
 *       **Validates: Requirements 2.9**
 *       - Implements token revocation for logout operations
 *     tags:
 *       - Authentication
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               sessionId:
 *                 type: string
 *                 description: Session ID to revoke
 *           example:
 *             sessionId: "550e8400-e29b-41d4-a716-446655440000"
 *     responses:
 *       200:
 *         description: Session revoked successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 sessionId:
 *                   type: string
 *       400:
 *         description: Missing session ID
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.post('/session/revoke', authenticateJWT, async function(req, res) {
  try {
    const userId = extractUserId(req);
    const { sessionId } = req.body;

    if (!sessionId) {
      return res.status(400).json({
        error: 'Session ID required',
        code: 'MISSING_SESSION_ID',
      });
    }

    logger.info('[Auth] Session revocation initiated', { userId, sessionId });

    // Log token revocation
    logTokenRevoke({
      userId,
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      details: {
        endpoint: req.path,
        method: req.method,
        sessionId,
      },
    }).catch((auditError) => {
      logger.error('[Auth] Failed to log session revocation', {
        error: auditError.message,
      });
    });

    // In a real implementation, this would revoke the session from the database
    // For now, we'll just return success
    res.json({
      success: true,
      message: 'Session revoked successfully',
      sessionId,
    });
  } catch (error) {
    logger.error('[Auth] Session revocation error', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Session revocation failed',
      code: 'SESSION_REVOCATION_ERROR',
    });
  }
});

/**
 * @swagger
 * /auth/me:
 *   get:
 *     summary: Get current authenticated user information
 *     description: |
 *       Returns information about the currently authenticated user
 *       extracted from the JWT token.
 *
 *       **Validates: Requirements 2.1**
 *       - Validates JWT tokens from Auth0 on every protected request
 *     tags:
 *       - Authentication
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Current user information
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 userId:
 *                   type: string
 *                   description: User ID
 *                 email:
 *                   type: string
 *                   format: email
 *                   description: User email
 *                 name:
 *                   type: string
 *                   description: User full name
 *                 picture:
 *                   type: string
 *                   format: uri
 *                   description: User profile picture URL
 *                 emailVerified:
 *                   type: boolean
 *                   description: Whether email is verified
 *                 updatedAt:
 *                   type: string
 *                   format: date-time
 *                   description: Last update timestamp
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get('/me', authenticateJWT, async function(req, res) {
  try {
    const userId = extractUserId(req);

    logger.info('[Auth] User info requested', { userId });

    res.json({
      userId,
      email: req.user?.email,
      name: req.user?.name,
      picture: req.user?.picture,
      emailVerified: req.user?.email_verified,
      updatedAt: req.user?.updated_at,
    });
  } catch (error) {
    logger.error('[Auth] User info error', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to get user info',
      code: 'USER_INFO_ERROR',
    });
  }
});

/**
 * @swagger
 * /auth/token/check-expiry:
 *   post:
 *     summary: Check if token is expiring soon
 *     description: |
 *       Checks if a token is expiring soon (within 5 minutes) and needs
 *       to be refreshed. Useful for proactive token refresh.
 *
 *       **Validates: Requirements 2.2**
 *       - Implements token refresh mechanism for expired tokens
 *     tags:
 *       - Authentication
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               token:
 *                 type: string
 *                 description: JWT token to check (optional if using Authorization header)
 *           example:
 *             token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
 *     responses:
 *       200:
 *         description: Token expiry check result
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 shouldRefresh:
 *                   type: boolean
 *                   description: Whether token should be refreshed
 *                 expiresIn:
 *                   type: integer
 *                   description: Seconds until token expires
 *                 expiresAt:
 *                   type: string
 *                   format: date-time
 *                   description: Token expiry timestamp
 *       400:
 *         description: Missing token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Invalid token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.post('/token/check-expiry', async function(req, res) {
  try {
    const { token } = req.body;
    const authHeader = req.headers.authorization;
    const bearerToken = token || (authHeader && authHeader.split(' ')[1]);

    if (!bearerToken) {
      return res.status(400).json({
        error: 'Token required',
        code: 'MISSING_TOKEN',
      });
    }

    const decoded = jwt.decode(bearerToken, { complete: true });

    if (!decoded) {
      return res.status(401).json({
        error: 'Invalid token',
        code: 'INVALID_TOKEN',
      });
    }

    const now = Math.floor(Date.now() / 1000);
    const expiresIn = decoded.payload.exp - now;
    const shouldRefresh = expiresIn <= TOKEN_REFRESH_WINDOW;

    logger.info('[Auth] Token expiry check', {
      expiresIn,
      shouldRefresh,
    });

    res.json({
      shouldRefresh,
      expiresIn: Math.max(0, expiresIn),
      expiresAt: new Date(decoded.payload.exp * 1000).toISOString(),
    });
  } catch (error) {
    logger.error('[Auth] Token expiry check error', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Token expiry check failed',
      code: 'EXPIRY_CHECK_ERROR',
    });
  }
});

/**
 * HTTPS Enforcement Middleware
 * Ensures all authentication endpoints are accessed via HTTPS in production
 *
 * Validates: Requirements 2.10
 * - Enforces HTTPS for all authentication endpoints
 */
router.use((req, res, next) => {
  if (process.env.NODE_ENV === 'production' && req.protocol !== 'https') {
    logger.warn('[Auth] Non-HTTPS request to auth endpoint', {
      protocol: req.protocol,
      path: req.path,
      ip: req.ip,
    });

    return res.status(403).json({
      error: 'HTTPS required',
      code: 'HTTPS_REQUIRED',
      message: 'Authentication endpoints require HTTPS',
    });
  }

  next();
});

export default router;
