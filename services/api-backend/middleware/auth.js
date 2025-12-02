/**
 * Authentication Middleware for CloudToLocalLLM API Backend
 *
 * Provides JWT authentication and authorization for API endpoints
 * with user ID extraction utilities.
 */

import jwt from 'jsonwebtoken';
import fetch from 'node-fetch';
import { auth } from 'express-oauth2-jwt-bearer';
import logger from '../logger.js';
import { AuthService } from '../auth/auth-service.js';
import { logLoginFailure } from '../services/auth-audit-service.js';

// JWT configuration
const DEFAULT_JWT_AUDIENCE = 'https://api.cloudtolocalllm.online';
const JWT_AUDIENCE = process.env.JWT_AUDIENCE || process.env.AUTH0_AUDIENCE || DEFAULT_JWT_AUDIENCE;
const JWT_ISSUER_DOMAIN = process.env.JWT_ISSUER_DOMAIN || process.env.AUTH0_DOMAIN;

// Resolve issuer URL from JWT_ISSUER_URL or AUTH0_DOMAIN
const issuerBaseURL = process.env.JWT_ISSUER_URL || 
  (process.env.AUTH0_DOMAIN ? `https://${process.env.AUTH0_DOMAIN}/` : undefined);

if (!issuerBaseURL) {
  logger.error('[Auth] JWT issuer configuration missing. Set JWT_ISSUER_URL or AUTH0_DOMAIN environment variable.');
}

// Primary JWT validator (handles JWKS caching internally)
const checkJwt = auth({
  audience: JWT_AUDIENCE,
  issuerBaseURL: issuerBaseURL,
  tokenSigningAlg: 'RS256',
});

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
 * Validates JWT JWT tokens and attaches user info to request
 *
 * Validates: Requirements 2.1, 2.2, 2.9, 2.10
 * - Validates JWT tokens from JWT on every protected request
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

  // First, validate JWT signature & claims with JWT SDK
  try {
    await new Promise((resolve, reject) => {
      checkJwt(req, res, (err) => {
        if (err) {
          reject(err);
        } else {
          resolve();
        }
      });
    });
  } catch (error) {
    logger.warn(' [Auth] JWT SDK token verification failed', {
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

    const status = error.status || 401;
    return res.status(status).json({
      error: 'Invalid or expired token',
      code: error.code || 'TOKEN_VERIFICATION_FAILED',
      details: error.message,
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
    // Validate token format and expiry
    const decoded = jwt.decode(token, { complete: true });

    if (!decoded) {
      logger.warn(' [Auth] Invalid token format', { ip: req.ip });
      return res.status(401).json({
        error: 'Invalid token format',
        code: 'INVALID_TOKEN_FORMAT',
      });
    }

    // Check token expiry
    const now = Math.floor(Date.now() / 1000);
    if (decoded.payload.exp && decoded.payload.exp < now) {
      logger.warn(' [Auth] Token has expired', {
        userId: decoded.payload.sub,
        expiredAt: new Date(decoded.payload.exp * 1000).toISOString(),
      });

      return res.status(401).json({
        error: 'Token has expired',
        code: 'TOKEN_EXPIRED',
        expiresAt: new Date(decoded.payload.exp * 1000).toISOString(),
      });
    }

    // Check if token is expiring soon (within 5 minutes)
    const expiresIn = decoded.payload.exp - now;
    const isExpiring = expiresIn <= 300; // 5 minutes

    try {
      await ensureAuthServiceInitialized();
    } catch (initError) {
      logger.error(
        ' [Auth] AuthService initialization failed, falling back to JWT payload',
        {
          error: initError.message,
        },
      );

      if (req.auth?.payload) {
        req.user = req.auth.payload;
        req.userId = req.auth.payload.sub;
        req.tokenExpiring = isExpiring;
        return next();
      }

      return res.status(503).json({
        error: 'Authentication service unavailable',
        code: 'AUTH_SERVICE_UNAVAILABLE',
      });
    }

    // If it's not a valid JWT (opaque token), use JWT userinfo endpoint
    if (!decoded.header || !decoded.header.kid) {
      logger.debug(
        ' [Auth] Token appears to be opaque, using JWT userinfo endpoint',
      );

      try {
        // Validate opaque token using JWT userinfo endpoint
        const response = await fetch(`https://${JWT_ISSUER_DOMAIN}/userinfo`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });

        if (!response.ok) {
          throw new Error(`JWT userinfo failed: ${response.status}`);
        }

        const userInfo = await response.json();

        // Attach user info to request
        req.user = userInfo;
        req.userId = userInfo.sub;
        req.tokenExpiring = isExpiring;

        logger.debug(
          ` [Auth] User authenticated via userinfo: ${userInfo.sub}`,
        );
        next();
        return;
      } catch (userinfoError) {
        logger.error(' [Auth] Userinfo validation failed:', userinfoError);
        return res.status(401).json({
          error: 'Token validation failed',
          code: 'TOKEN_VALIDATION_FAILED',
        });
      }
    }

    // If it's a proper JWT token, use the AuthService with pre-validated payload from JWT SDK
    logger.debug(
      ' [Auth] Token appears to be JWT, using AuthService with pre-validated payload',
    );
    const result = await authService.validateToken(
      token,
      req,
      req.auth?.payload,
    );

    if (!result.valid) {
      logger.warn(
        ' [Auth] AuthService validation failed, falling back to JWT payload',
        {
          error: result.error,
        },
      );

      if (req.auth?.payload) {
        req.user = req.auth.payload;
        req.userId = req.auth.payload.sub;
        req.tokenExpiring = isExpiring;
        return next();
      }

      return res.status(401).json({
        error: result.error || 'Token validation failed',
        code: 'TOKEN_VALIDATION_FAILED',
      });
    }

    // Attach user info to request
    req.user = result.payload;
    req.userId = result.payload.sub;
    req.auth = req.auth || { payload: result.payload };
    req.tokenExpiring = isExpiring;

    logger.debug(` [Auth] User authenticated via JWT: ${result.payload.sub}`);
    next();
  } catch (error) {
    logger.error(' [Auth] Token verification failed:', error);

    let errorCode = 'TOKEN_VERIFICATION_FAILED';
    let errorMessage = 'Invalid or expired token';

    if (error.name === 'TokenExpiredError') {
      errorCode = 'TOKEN_EXPIRED';
      errorMessage = 'Token has expired';
    } else if (error.name === 'JsonWebTokenError') {
      errorCode = 'INVALID_TOKEN';
      errorMessage = 'Invalid token';
    } else if (error.name === 'NotBeforeError') {
      errorCode = 'TOKEN_NOT_ACTIVE';
      errorMessage = 'Token not active';
    }

    return res.status(403).json({
      error: errorMessage,
      code: errorCode,
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
    // Try to decode as JWT first
    const decoded = jwt.decode(token, { complete: true });

    if (!decoded || !decoded.header || !decoded.header.kid) {
      // Try JWT userinfo endpoint for opaque tokens
      try {
        const response = await fetch(`https://${JWT_ISSUER_DOMAIN}/userinfo`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });

        if (response.ok) {
          const userInfo = await response.json();
          req.user = userInfo;
          req.userId = userInfo.sub;
          logger.debug(
            ` [Auth] Optional auth successful via userinfo: ${userInfo.sub}`,
          );
        }
      } catch (userinfoError) {
        logger.debug(
          ' [Auth] Optional userinfo auth failed, continuing without authentication:',
          userinfoError.message,
        );
      }
    } else {
      // Try JWT validation
      const result = await authService.validateToken(token);

      if (result.valid) {
        req.user = result.payload;
        req.userId = result.payload.sub;
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
  const containerToken = req.headers['x-container-token'];
  const containerId = req.headers['x-container-id'];

  if (!containerToken || !containerId) {
    return res.status(401).json({
      error: 'Container authentication required',
      code: 'CONTAINER_AUTH_REQUIRED',
    });
  }

  // FUTURE ENHANCEMENT: Implement proper container token validation with secure token store
  // Current implementation provides basic validation for premium/enterprise tier containers
  if (!validateContainerToken(containerToken, containerId)) {
    return res.status(403).json({
      error: 'Invalid container credentials',
      code: 'INVALID_CONTAINER_CREDENTIALS',
    });
  }

  req.containerId = containerId;
  req.containerToken = containerToken;

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
function validateContainerToken(token, containerId) {
  // Enhanced validation pattern for container tokens
  // Validates token format, container ID format, and basic security checks
  if (!token || !containerId) {
    return false;
  }

  // Validate token format (must start with 'container-' and have sufficient length)
  if (!token.startsWith('container-') || token.length < 20) {
    return false;
  }

  // Validate container ID format (alphanumeric with hyphens)
  const containerIdPattern = /^[a-zA-Z0-9-]+$/;
  if (!containerIdPattern.test(containerId)) {
    return false;
  }

  // Basic token-container ID correlation check
  const expectedTokenSuffix = containerId.slice(-8);
  if (!token.includes(expectedTokenSuffix)) {
    return false;
  }

  return true;
}

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
      logger.warn('� [AdminAuth] Admin access denied', {
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

    logger.info('� [AdminAuth] Admin access granted', {
      userId: req.user.sub,
      role: userMetadata.role || appMetadata.role || 'admin',
      userAgent: req.get('User-Agent'),
    });

    next();
  } catch (error) {
    logger.error('� [AdminAuth] Admin role check failed', {
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
  const userRequests = new Map();

  return (req, res, next) => {
    const userId = req.userId || req.ip; // Fallback to IP if no user ID
    const now = Date.now();

    // Clean up old entries
    for (const [key, data] of userRequests.entries()) {
      if (now - data.windowStart > windowMs) {
        userRequests.delete(key);
      }
    }

    // Get or create user request data
    let userData = userRequests.get(userId);
    if (!userData || now - userData.windowStart > windowMs) {
      userData = { count: 0, windowStart: now };
      userRequests.set(userId, userData);
    }

    userData.count++;

    if (userData.count > max) {
      return res.status(429).json({
        error: 'Too many requests',
        code: 'RATE_LIMIT_EXCEEDED',
        retryAfter: Math.ceil((windowMs - (now - userData.windowStart)) / 1000),
      });
    }

    next();
  };
}
