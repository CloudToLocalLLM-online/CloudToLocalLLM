/**
 * @fileoverview Authentication Service for CloudToLocalLLM Tunnel
 * Handles JWT JWT validation, session management, and role-based access control
 */

import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import jwksClient from 'jwks-rsa';
import { TunnelLogger } from '../utils/logger.js';
import { DatabaseMigrator } from '../database/migrate.js';
import { DatabaseMigratorPG } from '../database/migrate-pg.js';

/**
 * Authentication service with JWT integration
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

    // Determine which database implementation to use
    if (this.authDbMigrator) {
      this.db = this.authDbMigrator;
    } else if (this.mainDbMigrator) {
      this.db = this.mainDbMigrator;
    } else {
      // Fallback based on environment
      const dbType = process.env.DB_TYPE || 'sqlite';
      if (dbType === 'postgresql') {
        this.db = new DatabaseMigratorPG();
      } else {
        this.db = new DatabaseMigrator();
      }
    }

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
   * Helper to execute queries on either SQLite or Postgres
   * Handles parameter conversion (? -> $n) and standardized return format
   */
  async runQuery(sql, params = [], type = 'all') {
    if (process.env.DB_TYPE === 'postgresql') {
      // Postgres implementation
      // Convert ? to $1, $2, etc. (Naive replacement, assumes no ? in strings)
      let paramCount = 0;
      const pgSql = sql.replace(/\?/g, () => {
        paramCount++;
        return `$${paramCount}`;
      });

      // Special handling for INSERT to get lastID
      let finalSql = pgSql;
      if (type === 'run' && sql.trim().toUpperCase().startsWith('INSERT') && !sql.toLowerCase().includes('returning')) {
        finalSql += ' RETURNING id';
      }

      try {
        const result = await this.db.pool.query(finalSql, params);

        if (type === 'run') {
          return {
            lastID: result.rows[0]?.id, // Only works if we added RETURNING id
            changes: result.rowCount
          };
        } else if (type === 'get') {
          return result.rows[0];
        } else {
          return result.rows;
        }
      } catch (err) {
        // Handle unique constraint violation normalization if needed
        if (err.code === '23505') { // unique_violation
          const wrapper = new Error('UNIQUE constraint failed: ' + err.detail);
          wrapper.code = 'SQLITE_CONSTRAINT'; // Mimic SQLite code for logic compatibility
          throw wrapper;
        }
        throw err;
      }
    } else {
      // SQLite implementation
      if (!this.db.db) await this.db.initialize();

      try {
        if (type === 'run') {
          return await this.db.db.run(sql, params);
        } else if (type === 'get') {
          return await this.db.db.get(sql, params);
        } else {
          return await this.db.db.all(sql, params);
        }
      } catch (err) {
        throw err;
      }
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
   * Resolve internal user ID from Auth0 ID
   * Handles difference between SQLite (uses Auth0 ID) and Postgres (uses UUID)
   */
  async resolveUserId(auth0Id, userInfo = {}) {
    // For SQLite, we just use the Auth0 ID directly
    if (!process.env.DB_TYPE || process.env.DB_TYPE === 'sqlite') {
      return auth0Id;
    }

    // For PostgreSQL, we must map to a UUID in the users table
    try {
      // 1. Try to find existing user
      const existingUser = await this.runQuery(
        'SELECT id FROM users WHERE jwt_id = ?',
        [auth0Id],
        'get'
      );

      if (existingUser) {
        return existingUser.id; // Return the UUID
      }

      // 2. Verified user doesn't exist, create new user
      this.logger.info('Creating new user record for Auth0 ID', { auth0Id });

      const newUser = await this.runQuery(
        `INSERT INTO users (jwt_id, email, name, nickname, picture, email_verified, locale, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
        [
          auth0Id,
          userInfo.email || `${auth0Id}@placeholder.local`, // Fallback for email
          userInfo.name,
          userInfo.nickname,
          userInfo.picture,
          userInfo.email_verified || false,
          userInfo.locale
        ],
        'run'
      );

      if (newUser && newUser.lastID) {
        this.logger.info('Created new user', { userId: newUser.lastID });
        return newUser.lastID;
      }

      throw new Error('Failed to create user record');

    } catch (error) {
      this.logger.error('Failed to resolve user ID', { auth0Id, error: error.message });
      throw error;
    }
  }

  /**
   * Create or update user session
   */
  async createOrUpdateSession(tokenPayload, token, req) {
    const auth0Id = tokenPayload.sub;
    const tokenHash = this.hashToken(token);
    // Convert to SQLite-compatible datetime string
    const expiresAt = new Date(tokenPayload.exp * 1000).toISOString();
    const ip = req.ip || req.socket?.remoteAddress;
    const userAgent = req.headers?.['user-agent'];
    const nowFunc = process.env.DB_TYPE === 'postgresql' ? 'NOW()' : 'CURRENT_TIMESTAMP';

    try {
      this.logger.info('Creating/updating session', {
        auth0Id,
        tokenHashLength: tokenHash.length,
        expiresAt,
        ip,
        userAgent: userAgent?.substring(0, 100),
      });

      // Ensure database is initialized
      if (!this.db.pool && !this.db.db) {
        await this.db.initialize();
      }

      // Resolve the internal User ID
      const userId = await this.resolveUserId(auth0Id, tokenPayload);

      // Check for existing session with same token
      const existingSession = await this.runQuery(
        'SELECT * FROM user_sessions WHERE user_id = ? AND jwt_token_hash = ?',
        [userId, tokenHash],
        'get'
      );

      this.logger.info('Session lookup result', {
        existingSessionId: existingSession?.id,
        hasExistingSession: !!existingSession,
      });

      if (existingSession) {
        this.logger.info('Updating existing session', {
          sessionId: existingSession.id,
        });

        await this.runQuery(
          `UPDATE user_sessions SET last_activity = ${nowFunc}, expires_at = ? WHERE id = ?`,
          [expiresAt, existingSession.id],
          'run'
        );

        this.logger.info('Session updated successfully');
        existingSession.last_activity = new Date();
        existingSession.expires_at = expiresAt;
        return existingSession;
      }

      this.logger.info('Creating new session');

      // Clean up old sessions for user
      await this.cleanupUserSessions(userId);

      // Create new session
      const result = await this.runQuery(
        `INSERT INTO user_sessions (user_id, jwt_token_hash, expires_at, ip_address, user_agent${process.env.DB_TYPE === 'postgresql' ? ', session_token' : ''})
         VALUES (?, ?, ?, ?, ?${process.env.DB_TYPE === 'postgresql' ? ', ?' : ''})`,
        process.env.DB_TYPE === 'postgresql'
          ? [userId, tokenHash, expiresAt, ip, userAgent, this.generateSessionId()]
          : [userId, tokenHash, expiresAt, ip, userAgent],
        'run'
      );

      // Get the created session
      let session;
      if (result.lastID) {
        session = await this.runQuery(
          'SELECT * FROM user_sessions WHERE id = ?',
          [result.lastID],
          'get'
        );
      } else {
        session = await this.runQuery(
          'SELECT * FROM user_sessions WHERE user_id = ? AND jwt_token_hash = ?',
          [userId, tokenHash],
          'get'
        );
      }

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
      // Handle UNIQUE constraint violation
      if (
        (error.code === 'SQLITE_CONSTRAINT' && error.message.includes('UNIQUE')) ||
        (error.message.includes('UNIQUE constraint failed'))
      ) {
        // Resolve logic again just in case
        const userId = await this.resolveUserId(auth0Id, tokenPayload);

        this.logger.info(
          'UNIQUE constraint violation - attempting to find and update existing session',
          { userId }
        );

        try {
          const existingSession = await this.runQuery(
            'SELECT * FROM user_sessions WHERE user_id = ? AND jwt_token_hash = ?',
            [userId, tokenHash],
            'get'
          );

          if (existingSession) {
            await this.runQuery(
              `UPDATE user_sessions SET last_activity = ${nowFunc}, expires_at = ? WHERE id = ?`,
              [expiresAt, existingSession.id],
              'run'
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
        auth0Id,
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
      const result = await this.runQuery(
        `SELECT * FROM user_sessions
         WHERE id = ? AND is_active = 1 AND expires_at > ${process.env.DB_TYPE === 'postgresql' ? 'NOW()' : "datetime('now')"}`,
        [sessionId],
        'get'
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
      // Get user_id before updating
      const session = await this.runQuery(
        'SELECT user_id FROM user_sessions WHERE id = ?',
        [sessionId],
        'get'
      );

      if (session) {
        // Update session to inactive
        await this.runQuery(
          'UPDATE user_sessions SET is_active = 0 WHERE id = ?',
          [sessionId],
          'run'
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
      // Get active sessions count
      const countResult = await this.runQuery(
        'SELECT COUNT(*) as count FROM user_sessions WHERE user_id = ? AND is_active = 1',
        [userId],
        'get'
      );

      const activeCount = parseInt(countResult.count);

      if (activeCount >= this.config.MAX_SESSIONS_PER_USER) {
        // Remove oldest sessions
        const sessionsToRemove =
          activeCount - this.config.MAX_SESSIONS_PER_USER + 1;

        const subQuery = `
          SELECT id FROM user_sessions
          WHERE user_id = ? AND is_active = 1
          ORDER BY last_activity ASC
          LIMIT ?
        `;

        await this.runQuery(
          `UPDATE user_sessions
           SET is_active = 0
           WHERE id IN (${subQuery})`,
          [userId, sessionsToRemove],
          'run'
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
      // Create valid JSON string for metadata
      const metaStr = JSON.stringify(metadata);

      // Determine column name for JSON metadata based on DB type
      // PG uses 'details' (JSONB), SQLite uses 'metadata' (TEXT)
      // BUT schema.pg.sql says 'details' for audit_logs?
      // YES. schema.pg.sql: details JSONB. schema.sql: metadata TEXT.
      const jsonColumnName = process.env.DB_TYPE === 'postgresql' ? 'details' : 'metadata';

      await this.runQuery(
        `INSERT INTO audit_logs (event_type, event_category, action, ${jsonColumnName}, user_id, ip_address, user_agent)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          eventType,
          category,
          eventType,
          metaStr,
          metadata.userId || null,
          metadata.ip || null,
          metadata.userAgent || null,
        ],
        'run'
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
    return this.logAuditEvent(eventType, 'security', metadata);
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
          const nowFunc = process.env.DB_TYPE === 'postgresql' ? 'NOW()' : "datetime('now')";
          // Clean up expired sessions
          const result = await this.runQuery(
            `UPDATE user_sessions SET is_active = 0
             WHERE expires_at < ${nowFunc} AND is_active = 1`,
            [],
            'run'
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
      const nowFunc = process.env.DB_TYPE === 'postgresql' ? 'NOW()' : "datetime('now')";

      const activeSessions = await this.runQuery(
        'SELECT COUNT(*) as count FROM user_sessions WHERE is_active = 1',
        [], 'get'
      );

      const validSessions = await this.runQuery(
        `SELECT COUNT(*) as count FROM user_sessions WHERE expires_at > ${nowFunc}`,
        [], 'get'
      );

      const activeUsers = await this.runQuery(
        'SELECT COUNT(DISTINCT user_id) as count FROM user_sessions WHERE is_active = 1',
        [], 'get'
      );

      // PG specific interval syntax vs SQLite
      const interval = process.env.DB_TYPE === 'postgresql' ? "NOW() - INTERVAL '24 HOURS'" : "datetime('now', '-24 hours')";
      const timestampColumn = process.env.DB_TYPE === 'postgresql' ? 'created_at' : 'timestamp';

      const authEvents = await this.runQuery(
        `SELECT COUNT(*) as count FROM audit_logs
         WHERE event_category = 'authentication' AND ${timestampColumn} > ${interval}`,
        [], 'get'
      );

      const securityEvents = await this.runQuery(
        `SELECT COUNT(*) as count FROM audit_logs
         WHERE event_category = 'security' AND ${timestampColumn} > ${interval}`,
        [], 'get'
      );

      return {
        active_sessions: activeSessions?.count || 0,
        valid_sessions: validSessions?.count || 0,
        active_users: activeUsers?.count || 0,
        auth_events_24h: authEvents?.count || 0,
        security_events_24h: securityEvents?.count || 0,
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
