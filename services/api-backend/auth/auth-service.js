/**
 * @fileoverview Authentication Service for CloudToLocalLLM Tunnel
 * Handles Auth0 JWT validation, session management, and role-based access control
 */

import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-client';
import crypto from 'crypto';
import { TunnelLogger } from '../utils/logger.js';
import { DatabaseMigrator } from '../database/migrate.js';

/**
 * Authentication service with Auth0 integration
 */
export class AuthService {
  constructor(config) {
    this.config = {
      AUTH0_DOMAIN: process.env.AUTH0_DOMAIN,
      AUTH0_AUDIENCE: process.env.AUTH0_AUDIENCE,
      JWT_SECRET: process.env.JWT_SECRET,
      SESSION_TIMEOUT: parseInt(process.env.SESSION_TIMEOUT) || 3600000, // 1 hour
      MAX_SESSIONS_PER_USER: parseInt(process.env.MAX_SESSIONS_PER_USER) || 5,
      ...config,
    };

    this.logger = new TunnelLogger('auth-service');
    this.db = new DatabaseMigrator();

    // JWKS client for Auth0 public key retrieval (simplified config to avoid cache issues)
    this.jwksClient = jwksClient({
      jwksUri: `https://${this.config.AUTH0_DOMAIN}/.well-known/jwks.json`,
      cache: false, // Disable cache temporarily to avoid maxAge error
      rateLimit: true,
      jwksRequestsPerMinute: 10,
      timeout: 30000,
    });

    this.initialized = false;
  }

  /**
   * Initialize authentication service
   */
  async initialize() {
    if (this.initialized) {
      return;
    }

    try {
      await this.db.initialize();
      this.initialized = true;

      this.logger.info('Authentication service initialized', {
        domain: this.config.AUTH0_DOMAIN,
        audience: this.config.AUTH0_AUDIENCE,
      });

      // Start session cleanup
      this.startSessionCleanup();

    } catch (error) {
      this.logger.error('Failed to initialize authentication service', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Validate JWT token
   */
  async validateToken(token, req = {}) {
    try {
      // Decode token to get header
      const decoded = jwt.decode(token, { complete: true });
      if (!decoded || !decoded.header.kid) {
        throw new Error('Invalid token format');
      }

      // Get signing key
      const key = await this.getSigningKey(decoded.header.kid);

      // Verify token
      const verified = jwt.verify(token, key, {
        audience: this.config.AUTH0_AUDIENCE,
        issuer: `https://${this.config.AUTH0_DOMAIN}/`,
        algorithms: ['RS256'],
      });

      // Create or update session
      const session = await this.createOrUpdateSession(verified, token, req);

      this.logger.info('Token validated successfully', {
        userId: verified.sub,
        sessionId: session.id,
      });

      return {
        valid: true,
        payload: verified,
        session: session,
      };

    } catch (error) {
      this.logger.warn('Token validation failed', {
        error: error.message,
        ip: req.ip,
      });

      // Log security event
      await this.logSecurityEvent('token_validation_failure', {
        error: error.message,
        ip: req.ip,
        userAgent: req.headers?.['user-agent'],
      });

      return {
        valid: false,
        error: error.message,
      };
    }
  }

  /**
   * Get signing key from JWKS
   */
  async getSigningKey(kid) {
    return new Promise((resolve, reject) => {
      this.jwksClient.getSigningKey(kid, (err, key) => {
        if (err) {
          reject(err);
        } else {
          resolve(key.getPublicKey());
        }
      });
    });
  }

  /**
   * Create or update user session
   */
  async createOrUpdateSession(tokenPayload, token, req) {
    const userId = tokenPayload.sub;
    const tokenHash = this.hashToken(token);
    const expiresAt = new Date(tokenPayload.exp * 1000);
    const ip = req.ip || req.socket?.remoteAddress;
    const userAgent = req.headers?.['user-agent'];

    try {
      // Check for existing session with same token
      const existingSession = await this.db.pool.query(
        'SELECT * FROM user_sessions WHERE user_id = $1 AND jwt_token_hash = $2',
        [userId, tokenHash],
      );

      if (existingSession.rows.length > 0) {
        // Update existing session
        const session = existingSession.rows[0];
        await this.db.pool.query(
          'UPDATE user_sessions SET last_activity = CURRENT_TIMESTAMP WHERE id = $1',
          [session.id],
        );

        return session;
      }

      // Clean up old sessions for user
      await this.cleanupUserSessions(userId);

      // Create new session
      const result = await this.db.pool.query(
        `INSERT INTO user_sessions (user_id, jwt_token_hash, expires_at, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5) RETURNING *`,
        [userId, tokenHash, expiresAt, ip, userAgent],
      );

      const session = result.rows[0];

      // Log session creation
      await this.logAuditEvent('session_created', 'authentication', {
        userId,
        sessionId: session.id,
        ip,
        userAgent,
      });

      this.logger.info('Session created', {
        userId,
        sessionId: session.id,
        expiresAt,
      });

      return session;

    } catch (error) {
      this.logger.error('Failed to create/update session', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get session by ID
   */
  async getSession(sessionId) {
    try {
      const result = await this.db.pool.query(
        `SELECT * FROM user_sessions 
         WHERE id = $1 AND is_active = true AND expires_at > CURRENT_TIMESTAMP`,
        [sessionId],
      );

      return result.rows[0] || null;
    } catch (error) {
      this.logger.error('Failed to get session', {
        sessionId,
        error: error.message,
      });
      return null;
    }
  }

  /**
   * Invalidate session
   */
  async invalidateSession(sessionId, reason = 'logout') {
    try {
      const result = await this.db.pool.query(
        'UPDATE user_sessions SET is_active = false WHERE id = $1 RETURNING user_id',
        [sessionId],
      );

      if (result.rows.length > 0) {
        const userId = result.rows[0].user_id;

        // Log session invalidation
        await this.logAuditEvent('session_invalidated', 'authentication', {
          userId,
          sessionId,
          reason,
        });

        this.logger.info('Session invalidated', {
          userId,
          sessionId,
          reason,
        });

        return true;
      }

      return false;
    } catch (error) {
      this.logger.error('Failed to invalidate session', {
        sessionId,
        error: error.message,
      });
      return false;
    }
  }

  /**
   * Clean up old sessions for user
   */
  async cleanupUserSessions(userId) {
    try {
      // Get active sessions count
      const countResult = await this.db.pool.query(
        'SELECT COUNT(*) as count FROM user_sessions WHERE user_id = $1 AND is_active = true',
        [userId],
      );

      const activeCount = parseInt(countResult.rows[0].count);

      if (activeCount >= this.config.MAX_SESSIONS_PER_USER) {
        // Remove oldest sessions
        const sessionsToRemove = activeCount - this.config.MAX_SESSIONS_PER_USER + 1;

        await this.db.pool.query(
          `UPDATE user_sessions 
           SET is_active = false 
           WHERE id IN (
             SELECT id FROM user_sessions 
             WHERE user_id = $1 AND is_active = true 
             ORDER BY last_activity ASC 
             LIMIT $2
           )`,
          [userId, sessionsToRemove],
        );

        this.logger.info('Cleaned up old sessions', {
          userId,
          removedSessions: sessionsToRemove,
        });
      }
    } catch (error) {
      this.logger.error('Failed to cleanup user sessions', {
        userId,
        error: error.message,
      });
    }
  }

  /**
   * Check user permissions
   */
  async checkPermissions(userId, resource, action) {
    // For now, implement basic permission checking
    // This can be extended with more sophisticated RBAC

    try {
      // Get user roles from token or database
      // For MVP, all authenticated users have basic permissions
      const allowedActions = ['connect', 'send_request', 'receive_response'];

      if (allowedActions.includes(action)) {
        return true;
      }

      // Log permission denial
      await this.logSecurityEvent('permission_denied', {
        userId,
        resource,
        action,
      });

      return false;
    } catch (error) {
      this.logger.error('Permission check failed', {
        userId,
        resource,
        action,
        error: error.message,
      });
      return false;
    }
  }

  /**
   * Log audit event
   */
  async logAuditEvent(eventType, category, metadata = {}) {
    try {
      await this.db.pool.query(
        `INSERT INTO audit_logs (event_type, event_category, action, metadata, user_id, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          eventType,
          category,
          eventType,
          JSON.stringify(metadata),
          metadata.userId || null,
          metadata.ip || null,
          metadata.userAgent || null,
        ],
      );
    } catch (error) {
      this.logger.error('Failed to log audit event', {
        eventType,
        error: error.message,
      });
    }
  }

  /**
   * Log security event
   */
  async logSecurityEvent(eventType, metadata = {}) {
    try {
      await this.db.pool.query(
        `INSERT INTO security_events (event_type, source_ip, user_agent, metadata, user_id)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          eventType,
          metadata.ip || null,
          metadata.userAgent || null,
          JSON.stringify(metadata),
          metadata.userId || null,
        ],
      );
    } catch (error) {
      this.logger.error('Failed to log security event', {
        eventType,
        error: error.message,
      });
    }
  }

  /**
   * Hash token for storage
   */
  hashToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  /**
   * Start periodic session cleanup
   */
  startSessionCleanup() {
    // Clean up expired sessions every 15 minutes
    setInterval(async() => {
      try {
        const result = await this.db.pool.query(
          'SELECT cleanup_expired_sessions() as deleted_count',
        );

        const deletedCount = result.rows[0].deleted_count;
        if (deletedCount > 0) {
          this.logger.info('Cleaned up expired sessions', { deletedCount });
        }
      } catch (error) {
        this.logger.error('Session cleanup failed', { error: error.message });
      }
    }, 15 * 60 * 1000); // 15 minutes
  }

  /**
   * Get authentication statistics
   */
  async getAuthStats() {
    try {
      const stats = await this.db.pool.query(`
        SELECT 
          (SELECT COUNT(*) FROM user_sessions WHERE is_active = true) as active_sessions,
          (SELECT COUNT(*) FROM user_sessions WHERE expires_at > CURRENT_TIMESTAMP) as valid_sessions,
          (SELECT COUNT(DISTINCT user_id) FROM user_sessions WHERE is_active = true) as active_users,
          (SELECT COUNT(*) FROM audit_logs WHERE event_category = 'authentication' AND timestamp > CURRENT_TIMESTAMP - INTERVAL '24 hours') as auth_events_24h,
          (SELECT COUNT(*) FROM security_events WHERE detected_at > CURRENT_TIMESTAMP - INTERVAL '24 hours') as security_events_24h
      `);

      return stats.rows[0];
    } catch (error) {
      this.logger.error('Failed to get auth stats', { error: error.message });
      return {};
    }
  }

  /**
   * Close authentication service
   */
  async close() {
    if (this.db) {
      await this.db.close();
    }
  }
}
