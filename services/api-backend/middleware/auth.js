/**
 * Authentication Middleware for CloudToLocalLLM API Backend
 *
 * Provides JWT authentication and authorization for API endpoints
 * with user ID extraction utilities.
 */

import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import Redis from 'ioredis';
import { RedisStore } from 'rate-limit-redis';
import rateLimit from 'express-rate-limit';
import logger from '../logger.js';
import { AuthService } from '../auth/auth-service.js';
import { logLoginFailure } from '../services/auth-audit-service.js';

// JWT configuration
const DEFAULT_JWT_AUDIENCE = 'https://api.cloudtolocalllm.online';
const JWT_AUDIENCE = process.env.JWT_AUDIENCE || DEFAULT_JWT_AUDIENCE;
const SUPABASE_JWT_SECRET = process.env.SUPABASE_JWT_SECRET;

if (!SUPABASE_JWT_SECRET) {
  logger.warn('[Auth] SUPABASE_JWT_SECRET is missing. JWT verification will fail.');
}

// Use AuthService for extended validation/session management
const authService = new AuthService({
  JWT_AUDIENCE,
});

let authServiceInitialized = false;

async function ensureAuthServiceInitialized() {
  if (authServiceInitialized) {
    return;
  }
  try {
    await authService.initialize();
    authServiceInitialized = true;
  } catch (error) {
    logger.error(' [Auth] Failed to initialize AuthService', {
      error: error.message,
    });
    throw error;
  }
}

/**
 * JWT Authentication Middleware
 * Validates JWT tokens and attaches user info to request
 *
 * Validates: Requirements 2.1, 2.2, 2.9, 2.10
 * - Validates JWT tokens from Supabase on every protected request
 * - Implements token refresh mechanism for expired tokens
 * - Implements token revocation for logout operations
 * - Enforces HTTPS for all authentication endpoints
 */
export async function authenticateJWT(req, res, next) {
  // Check HTTPS enforcement in production
  if (process.env.NODE_ENV === 'production' && req.protocol !== 'https') {
    logger.warn(' [Auth] Non-HTTPS request to protected endpoint', {
      protocol: req.protocol,
      path: req.path,
      ip: req.ip,
    });

    return res.status(403).json({
      error: 'HTTPS required',
      code: 'HTTPS_REQUIRED',
      message: 'Protected endpoints require HTTPS',
    });
  }

  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      error: 'Access token required',
      code: 'MISSING_TOKEN',
    });
  }

  try {
    // 1. Try to verify with Secret (HS256) - Fast path for internal/legacy tokens
    let decoded;
    try {
      decoded = jwt.verify(token, SUPABASE_JWT_SECRET, {
        algorithms: ['HS256'],
        audience: 'authenticated',
      });
    } catch (hs256Error) {
      // If HS256 fails, we'll try RS256 via AuthService below
      logger.debug(' [Auth] HS256 verification failed, trying RS256 via AuthService', {
        error: hs256Error.message,
      });
    }

    // 2. If HS256 succeeded, use the decoded payload
    if (decoded) {
      // Check token expiry
      const now = Math.floor(Date.now() / 1000);
      const expiresIn = (decoded.exp || 0) - now;
      const isExpiring = expiresIn <= 300;

      // Ensure AuthService is initialized (for session tracking)
      try {
        await ensureAuthServiceInitialized();
        // Use AuthService with pre-validated payload to create/update session
        const result = await authService.validateToken(token, req, decoded);

        if (result.valid) {
          req.user = result.payload;
          req.userId = result.payload.sub;
          req.auth = { payload: result.payload };
          req.tokenExpiring = isExpiring;
          return next();
        }
      } catch (serviceError) {
        // If AuthService fails but token is valid HS256, we might still want to proceed
        // depending on strictness. For now, let's fall back to just the token payload.
        logger.warn(' [Auth] AuthService session tracking failed for HS256 token', {
          error: serviceError.message,
        });
        req.user = decoded;
        req.userId = decoded.sub;
        req.auth = { payload: decoded };
        req.tokenExpiring = isExpiring;
        return next();
      }
    }

    // 3. If HS256 failed (decoded is undefined), try full validation via AuthService (RS256)
    await ensureAuthServiceInitialized();
    const result = await authService.validateToken(token, req);

    if (!result.valid) {
      throw new Error(result.error || 'Token validation failed');
    }

    // Success via RS256
    const now = Math.floor(Date.now() / 1000);
    const expiresIn = (result.payload.exp || 0) - now;
    const isExpiring = expiresIn <= 300;

    req.user = result.payload;
    req.userId = result.payload.sub;
    req.auth = { payload: result.payload };
    req.tokenExpiring = isExpiring;

    logger.debug(` [Auth] User authenticated via RS256: ${result.payload.sub}`);
    next();

  } catch (error) {
    logger.warn(' [Auth] Token verification failed', {
      message: error.message,
      code: error.code,
      name: error.name,
      ip: req.ip,
    });

    // Log failed authentication attempt
    logLoginFailure({
      userId: null,
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      reason: error.message || 'Token verification failed',
      details: {
        code: error.code || 'TOKEN_VERIFICATION_FAILED',
        endpoint: req.path,
        method: req.method,
      },
    }).catch((auditError) => {
      logger.error('[Auth] Failed to log authentication failure', {
        error: auditError.message,
      });
    });

    const status = 401;
    return res.status(status).json({
      error: 'Invalid or expired token',
      code: 'TOKEN_VERIFICATION_FAILED',
      details: error.message,
    });
  }
}

/**
 * Extract user ID from authenticated request
 * @param {Object} req - Express request object
 * @returns {string} User ID from JWT token
 */
export function extractUserId(req) {
  if (!req.user || !req.user.sub) {
    throw new Error('User not authenticated or user ID not available');
  }
  return req.user.sub;
}

/**
 * Extract user email from authenticated request
 * @param {Object} req - Express request object
 * @returns {string|null} User email from JWT token
 */
export function extractUserEmail(req) {
  return req.user?.email || null;
}

/**
 * Check if user has specific permission/scope
 * @param {string} requiredScope - Required scope/permission
 * @returns {Function} Express middleware function
 */
export function requireScope(requiredScope) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTHENTICATION_REQUIRED',
      });
    }

    const userScopes = req.user.scope ? req.user.scope.split(' ') : [];

    if (!userScopes.includes(requiredScope)) {
      logger.warn(
        ` [Auth] User ${req.user.sub} missing required scope: ${requiredScope}`,
      );
      return res.status(403).json({
        error: 'Insufficient permissions',
        code: 'INSUFFICIENT_PERMISSIONS',
        requiredScope,
      });
    }

    next();
  };
}

/**
 * Optional authentication middleware
 * Attaches user info if token is present and valid, but doesn't require it
 */
export async function optionalAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    // No token provided, continue without authentication
    return next();
  }

  try {
    // Try to verify with Secret (HS256)
    const decoded = jwt.verify(token, SUPABASE_JWT_SECRET, {
      algorithms: ['HS256'],
      audience: 'authenticated',
    });

    if (decoded) {
      // Validate via AuthService (session logic)
      const result = await authService.validateToken(token, req, decoded);

      if (result.valid) {
        req.user = result.payload;
        req.userId = result.payload.sub;
        // Set req.auth for consistency with authenticateJWT
        req.auth = { payload: result.payload };
        logger.debug(
          ` [Auth] Optional auth successful via JWT: ${result.payload.sub}`,
        );
      }
    }
  } catch (error) {
    // Token verification failed, but that's okay for optional auth
    logger.debug(
      ' [Auth] Optional auth failed, continuing without authentication:',
      error.message,
    );
  }

  next();
}

/**
 * Container authentication middleware
 * Validates container tokens for internal API calls
 */
export function authenticateContainer(req, res, next) {
  const timestamp = req.headers['x-timestamp'];
  const signature = req.headers['x-signature'];
  const containerId = req.headers['x-container-id'];
  const sharedSecret = process.env.CONTAINER_SHARED_SECRET; // Load from secure env var

  if (!timestamp || !signature || !containerId) {
    return res.status(401).json({
      error: 'Container authentication headers required',
      code: 'CONTAINER_AUTH_HEADERS_REQUIRED',
    });
  }

  // 1. Check timestamp validity (e.g., within 5 minutes)
  const now = Date.now();
  const requestTime = new Date(timestamp).getTime();
  if (isNaN(requestTime) || Math.abs(now - requestTime) > 300000) { // 5 minutes
    return res.status(403).json({
      error: 'Invalid or expired timestamp',
      code: 'INVALID_TIMESTAMP',
    });
  }

  // 2. Reconstruct the message and generate the expected signature
  const message = `${timestamp}.${req.method}.${req.path}`;
  const expectedSignature = crypto
    .createHmac('sha256', sharedSecret)
    .update(message)
    .digest('hex');

  // 3. Compare signatures
  if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSignature))) {
    return res.status(403).json({
      error: 'Invalid signature',
      code: 'INVALID_SIGNATURE',
    });
  }

  req.containerId = containerId;
  logger.debug(` [Auth] Container authenticated: ${containerId}`);
  next();
}

/**
 * Validate container token (enhanced placeholder implementation)
 * FUTURE ENHANCEMENT: Implement proper container authentication with secure token store
 *
 * Current implementation provides basic validation for premium/enterprise tier containers.
 * This is sufficient for tier-based architecture deployment as free tier users don't use containers.
 */

/**
 * Admin authentication middleware
 * Requires admin role/scope for access with comprehensive role checking
 */
export function requireAdmin(req, res, next) {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    // Check for admin role in multiple possible locations
    const userMetadata =
      req.user['https://cloudtolocalllm.com/user_metadata'] || {};
    const appMetadata =
      req.user['https://cloudtolocalllm.com/app_metadata'] || {};
    const userRoles = req.user['https://cloudtolocalllm.online/roles'] || [];
    const userScopes = req.user.scope ? req.user.scope.split(' ') : [];

    // Check various places where admin role might be stored
    const hasAdminRole =
      userMetadata.role === 'admin' ||
      appMetadata.role === 'admin' ||
      userRoles.includes('admin') ||
      userScopes.includes('admin') ||
      (req.user.permissions && req.user.permissions.includes('admin')) ||
      req.user.role === 'admin';

    if (!hasAdminRole) {
      logger.warn(' [AdminAuth] Admin access denied', {
        userId: req.user.sub,
        userMetadata,
        appMetadata,
        userRoles,
        userScopes,
        permissions: req.user.permissions,
        userAgent: req.get('User-Agent'),
        ipAddress: req.ip,
      });

      return res.status(403).json({
        error: 'Admin access required',
        code: 'ADMIN_ACCESS_REQUIRED',
        message: 'This operation requires administrative privileges',
      });
    }

    logger.info(' [AdminAuth] Admin access granted', {
      userId: req.user.sub,
      role: userMetadata.role || appMetadata.role || 'admin',
      userAgent: req.get('User-Agent'),
    });

    next();
  } catch (error) {
    logger.error(' [AdminAuth] Admin role check failed', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Admin role verification failed',
      code: 'ADMIN_CHECK_FAILED',
    });
  }
}

/**
 * Rate limiting by user ID
 * @param {Object} options - Rate limiting options
 * @returns {Function} Express middleware function
 */
export function rateLimitByUser(options = {}) {
  const { windowMs = 15 * 60 * 1000, max = 100 } = options;

  // Create a Redis client.
  const redisClient = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD,
  });

  // Create a new store for the rate limiter.
  const store = new RedisStore({
    sendCommand: (...args) => redisClient.call(...args),
  });

  // Create a rate limiter that uses the Redis store.
  return rateLimit({
    store,
    windowMs,
    max,
    keyGenerator: (req) => req.userId || req.ip, // Use user ID or fallback to IP
    handler: (req, res) => {
      res.status(429).json({
        error: 'Too many requests',
        code: 'RATE_LIMIT_EXCEEDED',
      });
    },
  });
}
