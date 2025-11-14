/**
 * @fileoverview SSH Authentication Handler for JWT-based authentication
 * Handles JWT validation and user authentication for SSH connections
 */

/**
 * SSH Authentication Handler for JWT-based authentication
 */
export class SSHAuthHandler {
  /**
   * @param {AuthService} authService - AuthService for JWT validation
   * @param {winston.Logger} logger - Logger instance
   */
  constructor(authService, logger) {
    this.authService = authService;
    this.logger = logger;
  }

  /**
   * Validate JWT token for SSH authentication
   * @param {string} token - JWT token
   * @returns {Object|null} Decoded token payload or null if invalid
   */
  validateToken(token) {
    try {
      const decoded = this.authService.verifyToken(token);
      return decoded;
    } catch (error) {
      this.logger.warn('JWT validation failed for SSH auth', {
        error: error.message,
      });
      return null;
    }
  }

  /**
   * Authenticate SSH client using JWT
   * @param {Object} ctx - SSH authentication context
   * @param {string} userId - Expected user ID
   * @returns {boolean} True if authentication successful
   */
  authenticate(ctx, userId = null) {
    try {
      // Only accept password authentication (JWT as password)
      if (ctx.method !== 'password') {
        this.logger.debug('SSH auth method not supported', {
          method: ctx.method,
          username: ctx.username,
        });
        return false;
      }

      const token = ctx.password;

      if (!token) {
        this.logger.warn('SSH auth missing password (JWT token)');
        return false;
      }

      // Validate JWT token
      const decoded = this.validateToken(token);

      if (!decoded) {
        this.logger.warn('SSH auth invalid JWT token', {
          username: ctx.username,
        });
        return false;
      }

      // Check if user ID matches (if provided)
      if (userId && decoded.sub !== userId) {
        this.logger.warn('SSH auth user ID mismatch', {
          expected: userId,
          actual: decoded.sub,
          username: ctx.username,
        });
        return false;
      }

      // Check if username matches user ID (optional additional check)
      if (ctx.username && ctx.username !== decoded.sub) {
        this.logger.warn('SSH auth username mismatch', {
          username: ctx.username,
          userId: decoded.sub,
        });
        // Allow this for now, as username might be different
      }

      this.logger.info('SSH authentication successful', {
        userId: decoded.sub,
        username: ctx.username,
      });

      // Store user info in context for later use
      ctx.user = decoded;

      return true;

    } catch (error) {
      this.logger.error('SSH authentication error', {
        error: error.message,
        username: ctx.username,
      });
      return false;
    }
  }

  /**
   * Extract JWT from WebSocket connection
   * @param {Object} request - WebSocket upgrade request
   * @returns {Object|null} Extracted auth info or null
   */
  extractWebSocketAuth(request) {
    try {
      const url = new URL(request.url, `http://${request.headers.host}`);
      const token = url.searchParams.get('token');
      const userId = url.searchParams.get('userId');

      if (!token || !userId) {
        return null;
      }

      // Validate the token
      const decoded = this.validateToken(token);

      if (!decoded || decoded.sub !== userId) {
        return null;
      }

      return {
        token,
        userId,
        decoded,
      };

    } catch (error) {
      this.logger.warn('WebSocket auth extraction failed', {
        error: error.message,
      });
      return null;
    }
  }

  /**
   * Create SSH authentication middleware
   * @returns {Function} Authentication middleware function
   */
  createAuthMiddleware() {
    return (ctx) => {
      const authenticated = this.authenticate(ctx);

      if (authenticated) {
        ctx.accept();
      } else {
        ctx.reject(['password']);
      }
    };
  }

  /**
   * Create WebSocket authentication middleware
   * @returns {Function} WebSocket auth middleware function
   */
  createWebSocketAuthMiddleware() {
    return (ws, request) => {
      const auth = this.extractWebSocketAuth(request);

      if (!auth) {
        this.logger.warn('WebSocket authentication failed');
        ws.close(1008, 'Authentication required');
        return false;
      }

      // Attach auth info to WebSocket
      ws.auth = auth;

      this.logger.info('WebSocket authentication successful', {
        userId: auth.userId,
      });

      return true;
    };
  }

  /**
   * Get user info from authenticated context
   * @param {Object} ctx - Authenticated context
   * @returns {Object|null} User info or null
   */
  getUserFromContext(ctx) {
    return ctx.user || null;
  }

  /**
   * Check if user has required tier/permission
   * @param {Object} user - User object from JWT
   * @param {string} requiredTier - Required tier level
   * @returns {boolean} True if user has permission
   */
  checkTierPermission(user, requiredTier = 'free') {
    const userTier = user.tier || 'free';

    // Simple tier hierarchy: free < premium
    const tierLevels = {
      'free': 0,
      'premium': 1,
    };

    const userLevel = tierLevels[userTier] || 0;
    const requiredLevel = tierLevels[requiredTier] || 0;

    return userLevel >= requiredLevel;
  }
}
