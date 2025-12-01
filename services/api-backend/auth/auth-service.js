/**
 * @fileoverview Authentication Service for CloudToLocalLLM Tunnel
 * Handles JWT validation, session management, and role-based access control
 */

import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import fetch from 'node-fetch';
import jwksClient from 'jwks-rsa';
import { TunnelLogger } from '../utils/logger.js';
import { DatabaseMigrator } from '../database/migrate.js';

/**
 * Authentication service with Supabase integration
 * Uses separate authentication database for security isolation
 */
export class AuthService {
  constructor(config) {
    this.config = {
      SUPABASE_URL: process.env.SUPABASE_URL,
      SESSION_TIMEOUT: parseInt(process.env.SESSION_TIMEOUT) || 3600000, // 1 hour
      MAX_SESSIONS_PER_USER: parseInt(process.env.MAX_SESSIONS_PER_USER) || 5,
      ...config,
    };

    if (!this.config.SUPABASE_URL) {
      throw new Error('SUPABASE_URL environment variable is required');
    }

    this.logger = new TunnelLogger('auth-service');

    // Use separate auth database if provided, otherwise fallback to main database
    this.authDbMigrator = config.authDbMigrator || null;
    this.mainDbMigrator = config.dbMigrator || null;
    this.db = this.authDbMigrator || this.mainDbMigrator || new DatabaseMigrator();

    this.initialized = false;

    // Initialize JWKS client
    this.jwksClient = jwksClient({
      jwksUri: `${this.config.SUPABASE_URL}/auth/v1/.well-known/jwks.json`,
      cache: true,
      rateLimit: true,
      jwksRequestsPerMinute: 5,
    });
  }

  /**
   * Initialize authentication service
   */
  async initialize() {
    if (this.initialized) {
      return;
    }

    try {
      // If using separate auth database or main db migrator, it's already initialized in server.js
      if (!this.authDbMigrator && !this.mainDbMigrator) {
        await this.db.initialize();
      }
      this.initialized = true;

      this.logger.info('Authentication service initialized (Supabase RS256)');

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
   * Get signing key from JWKS
   */
  getKey(header, callback) {
    this.jwksClient.getSigningKey(header.kid, (err, key) => {
      if (err) {
        callback(err);
        return;
      }
      const signingKey = key.getPublicKey();
      callback(null, signingKey);
    });
  }

  /**
   * Validate JWT token
   * @param {string} token - JWT token to validate
   * @param {object} req - Request object
   * @param {object} preValidatedPayload - Optional pre-validated payload
   */
  async validateToken(token, req = {}, preValidatedPayload = null) {
    try {
      let payload;

      if (preValidatedPayload) {
        this.logger.info('Using pre-validated token payload');
        payload = preValidatedPayload;
      } else {
        // Full validation using Supabase JWKS (RS256)
        this.logger.info('Starting full token validation (Supabase RS256)');

        payload = await new Promise((resolve, reject) => {
          jwt.verify(
            token,
            this.getKey.bind(this),
            { algorithms: ['RS256'] },
            (err, decoded) => {
              if (err) {
                reject(err);
              } else {
                resolve(decoded);
              }
            }
          );
        });

        this.logger.info('Token verification successful');
      }

      // Create or update session
      const session = await this.createOrUpdateSession(payload, token, req);

      this.logger.info('Token validated successfully', {
        userId: payload.sub,
        sessionId: session.id,
      });

      return {
        valid: true,
        payload: payload,
        session: session,
      };
    } catch (error) {
      this.logger.warn('Token validation failed', {
        error: error.message,
        ip: req.ip,
      });

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
   * Validate JWT token for WebSocket connections (no session creation)
   * @param {string} token - JWT token to validate
   * @returns {Promise<Object>} Decoded token payload
   */
  async validateTokenForWebSocket(token) {
    try {
      this.logger.info('Starting WebSocket token validation (Supabase RS256)');

      const verified = await new Promise((resolve, reject) => {
        jwt.verify(
          token,
          this.getKey.bind(this),
          { algorithms: ['RS256'] },
          (err, decoded) => {
            if (err) {
              reject(err);
            } else {
              resolve(decoded);
            }
          }
        );
      });

      this.logger.info('WebSocket token verification successful', {
        userId: verified.sub,
        exp: verified.exp,
        iat: verified.iat,
      });

      return verified;
    } catch (error) {
      this.logger.warn('WebSocket token validation failed', {
        error: error.message,
      });

      throw error;
    }
  }



  /**
   * Create or update user session
   */
  async createOrUpdateSession(tokenPayload, token, req) {
    const userId = tokenPayload.sub;
    const tokenHash = this.hashToken(token);
    // Convert to SQLite-compatible datetime string
    const expiresAt = new Date(tokenPayload.exp * 1000).toISOString();
    const ip = req.ip || req.socket?.remoteAddress;
    const userAgent = req.headers?.['user-agent'];

    try {
      this.logger.info('Creating/updating session', {
        userId,
        tokenHashLength: tokenHash.length,
        expiresAt,
        ip,
        userAgent: userAgent?.substring(0, 100),
      });

      // Ensure database is initialized
      if (!this.db.db) {
        await this.db.initialize();
      }

      // Check for existing session with same token
      const existingSession = await this.db.db.get(
        'SELECT * FROM user_sessions WHERE user_id = ? AND jwt_token_hash = ?',
        [userId, tokenHash],
      );

      this.logger.info('Session lookup result', {
        existingSessionId: existingSession?.id,
        hasExistingSession: !!existingSession,
      });

      if (existingSession) {
        this.logger.info('Updating existing session', {
          sessionId: existingSession.id,
        });
        // Update existing session
        await this.db.db.run(
          'UPDATE user_sessions SET last_activity = CURRENT_TIMESTAMP, expires_at = ? WHERE id = ?',
          [expiresAt, existingSession.id],
        );

        this.logger.info('Session updated successfully');
        return existingSession;
      }

      this.logger.info('Creating new session');

      // Clean up old sessions for user
      await this.cleanupUserSessions(userId);

      this.logger.info('About to insert new session', {
        userId,
        tokenHashLength: tokenHash.length,
        expiresAt,
        ip,
        userAgentLength: userAgent?.length,
      });

      // Create new session
      const result = await this.db.db.run(
        `INSERT INTO user_sessions (user_id, jwt_token_hash, expires_at, ip_address, user_agent)
         VALUES (?, ?, ?, ?, ?)`,
        [userId, tokenHash, expiresAt, ip, userAgent],
      );

      this.logger.info('Session insert result', {
        lastID: result.lastID,
        changes: result.changes,
      });

      // Get the created session
      const session = await this.db.db.get(
        'SELECT * FROM user_sessions WHERE id = ?',
        [result.lastID || this.generateSessionId()],
      );

      if (!session) {
        throw new Error('Failed to retrieve created session');
      }

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
      // Handle UNIQUE constraint violation by trying to find and update existing session
      if (
        error.code === 'SQLITE_CONSTRAINT' &&
        error.message.includes('UNIQUE constraint failed')
      ) {
        this.logger.info(
          'UNIQUE constraint violation - attempting to find and update existing session',
          {
            userId,
            tokenHashLength: tokenHash.length,
          },
        );

        try {
          // Try to find the existing session again
          const existingSession = await this.db.db.get(
            'SELECT * FROM user_sessions WHERE user_id = ? AND jwt_token_hash = ?',
            [userId, tokenHash],
          );

          if (existingSession) {
            // Update the existing session
            await this.db.db.run(
              'UPDATE user_sessions SET last_activity = CURRENT_TIMESTAMP, expires_at = ? WHERE id = ?',
              [expiresAt, existingSession.id],
            );

            this.logger.info(
              'Successfully updated existing session after constraint violation',
              {
                sessionId: existingSession.id,
              },
            );

            return existingSession;
          }
        } catch (retryError) {
          this.logger.error('Failed to handle UNIQUE constraint violation', {
            originalError: error.message,
            retryError: retryError.message,
          });
        }
      }

      this.logger.error('Failed to create/update session', {
        userId,
        error: error.message,
        stack: error.stack,
        sqliteError: error.code,
        sqliteMessage: error.message,
        errorName: error.name,
        errorConstructor: error.constructor.name,
        fullError: JSON.stringify(error, Object.getOwnPropertyNames(error)),
      });
      this.logger.error('DETAILED SESSION ERROR', {
        error: error.message,
        stack: error.stack,
        properties: Object.getOwnPropertyNames(error),
      });
      throw error;
    }
  }

  /**
   * Get session by ID
   */
  async getSession(sessionId) {
    try {
      if (!this.db.db) {
        await this.db.initialize();
      }

      const result = await this.db.db.get(
        `SELECT * FROM user_sessions
         WHERE id = ? AND is_active = 1 AND expires_at > datetime('now')`,
        [sessionId],
      );

      return result || null;
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
      if (!this.db.db) {
        await this.db.initialize();
      }

      // Get user_id before updating
      const session = await this.db.db.get(
        'SELECT user_id FROM user_sessions WHERE id = ?',
        [sessionId],
      );

      if (session) {
        // Update session to inactive
        await this.db.db.run(
          'UPDATE user_sessions SET is_active = 0 WHERE id = ?',
          [sessionId],
        );

        const userId = session.user_id;

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
      if (!this.db.db) {
        await this.db.initialize();
      }

      // Get active sessions count
      const countResult = await this.db.db.get(
        'SELECT COUNT(*) as count FROM user_sessions WHERE user_id = ? AND is_active = 1',
        [userId],
      );

      const activeCount = parseInt(countResult.count);

      if (activeCount >= this.config.MAX_SESSIONS_PER_USER) {
        // Remove oldest sessions
        const sessionsToRemove =
          activeCount - this.config.MAX_SESSIONS_PER_USER + 1;

        await this.db.db.run(
          `UPDATE user_sessions
           SET is_active = 0
           WHERE id IN (
             SELECT id FROM user_sessions
             WHERE user_id = ? AND is_active = 1
             ORDER BY last_activity ASC
             LIMIT ?
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
      if (!this.db.db) {
        await this.db.initialize();
      }

      await this.db.db.run(
        `INSERT INTO audit_logs (event_type, event_category, action, metadata, user_id, ip_address, user_agent)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
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
      if (!this.db.db) {
        await this.db.initialize();
      }

      // Note: security_events table may not exist in SQLite schema, using audit_logs instead
      await this.db.db.run(
        `INSERT INTO audit_logs (event_type, event_category, action, metadata, user_id, ip_address, user_agent)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          eventType,
          'security',
          eventType,
          JSON.stringify(metadata),
          metadata.userId || null,
          metadata.ip || null,
          metadata.userAgent || null,
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
   * Generate session ID (fallback for SQLite)
   */
  generateSessionId() {
    return crypto.randomBytes(16).toString('hex');
  }

  /**
   * Start periodic session cleanup
   */
  startSessionCleanup() {
    // Clean up expired sessions every 15 minutes
    setInterval(
      async () => {
        try {
          if (!this.db.db) {
            await this.db.initialize();
          }

          // SQLite version: manually clean up expired sessions
          const result = await this.db.db.run(
            `UPDATE user_sessions SET is_active = 0
           WHERE expires_at < datetime('now') AND is_active = 1`,
          );

          const deletedCount = result.changes || 0;
          if (deletedCount > 0) {
            this.logger.info('Cleaned up expired sessions', { deletedCount });
          }
        } catch (error) {
          this.logger.error('Session cleanup failed', { error: error.message });
        }
      },
      15 * 60 * 1000,
    ); // 15 minutes
  }

  /**
   * Get authentication statistics
   */
  async getAuthStats() {
    try {
      if (!this.db.db) {
        await this.db.initialize();
      }

      // SQLite version: get stats with separate queries
      const activeSessions = await this.db.db.get(
        'SELECT COUNT(*) as count FROM user_sessions WHERE is_active = 1',
      );

      const validSessions = await this.db.db.get(
        'SELECT COUNT(*) as count FROM user_sessions WHERE expires_at > datetime(\'now\')',
      );

      const activeUsers = await this.db.db.get(
        'SELECT COUNT(DISTINCT user_id) as count FROM user_sessions WHERE is_active = 1',
      );

      const authEvents = await this.db.db.get(
        `SELECT COUNT(*) as count FROM audit_logs
         WHERE event_category = 'authentication' AND timestamp > datetime('now', '-24 hours')`,
      );

      const securityEvents = await this.db.db.get(
        `SELECT COUNT(*) as count FROM audit_logs
         WHERE event_category = 'security' AND timestamp > datetime('now', '-24 hours')`,
      );

      return {
        active_sessions: activeSessions.count,
        valid_sessions: validSessions.count,
        active_users: activeUsers.count,
        auth_events_24h: authEvents.count,
        security_events_24h: securityEvents.count,
      };
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
