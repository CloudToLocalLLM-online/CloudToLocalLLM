/**
 * @fileoverview Authentication Service for CloudToLocalLLM Tunnel
 * Handles Auth0 JWT validation, session management, and role-based access control
 */

import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import fetch from 'node-fetch';
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

    // Manual JWKS implementation to avoid jwks-client cache issues
    this.jwksUri = `https://${this.config.AUTH0_DOMAIN}/.well-known/jwks.json`;
    this.jwksCache = new Map(); // Simple in-memory cache
    this.jwksCacheExpiry = 0;

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
      this.logger.info('Starting token validation');

      // Decode token to get header
      const decoded = jwt.decode(token, { complete: true });
      if (!decoded || !decoded.header.kid) {
        throw new Error('Invalid token format - missing kid in header');
      }

      this.logger.info(`Token decoded successfully, kid: ${decoded.header.kid}`);

      // Get signing key
      const key = await this.getSigningKey(decoded.header.kid);

      this.logger.info('Got signing key, verifying token');

      // Verify token with full validation
      const verified = jwt.verify(token, key, {
        audience: this.config.AUTH0_AUDIENCE, // Re-enabled: Auth0 API is now configured
        issuer: `https://${this.config.AUTH0_DOMAIN}/`,
        algorithms: ['RS256'],
      });

      // Create or update session
      const session = await this.createOrUpdateSession(verified, token, req);

      this.logger.info('Token verification successful');
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
   * Get signing key from JWKS (manual implementation to avoid jwks-client issues)
   */
  async getSigningKey(kid) {
    try {
      this.logger.info(`Getting signing key for kid: ${kid}`);

      // Check cache first (5 minute expiry)
      const now = Date.now();
      if (this.jwksCacheExpiry > now && this.jwksCache.has(kid)) {
        this.logger.info(`Using cached key for kid: ${kid}`);
        return this.jwksCache.get(kid);
      }

      this.logger.info(`Fetching JWKS from: ${this.jwksUri}`);

      // Fetch JWKS from Auth0
      const response = await fetch(this.jwksUri);
      if (!response.ok) {
        throw new Error(`Failed to fetch JWKS: ${response.status} ${response.statusText}`);
      }

      const jwks = await response.json();
      this.logger.info(`Fetched JWKS with ${jwks.keys.length} keys`);

      // Find the key with matching kid
      const key = jwks.keys.find(k => k.kid === kid);
      if (!key) {
        const availableKids = jwks.keys.map(k => k.kid);
        throw new Error(`Key with kid '${kid}' not found in JWKS. Available kids: ${availableKids.join(', ')}`);
      }

      this.logger.info(`Found key for kid: ${kid}, converting to PEM`);

      // Convert JWK to PEM format
      const publicKey = this.jwkToPem(key);

      this.logger.info('Successfully converted key to PEM format');

      // Cache the result for 5 minutes
      this.jwksCache.set(kid, publicKey);
      this.jwksCacheExpiry = now + (5 * 60 * 1000);

      return publicKey;
    } catch (error) {
      this.logger.error(`Failed to get signing key for kid '${kid}':`, error);
      throw error;
    }
  }

  /**
   * Convert JWK to PEM format using manual RSA key construction
   */
  jwkToPem(jwk) {
    // For RS256, we need to convert the JWK to PEM
    if (jwk.kty !== 'RSA') {
      throw new Error('Only RSA keys are supported');
    }

    try {
      // Try the modern Node.js crypto approach first
      const keyObject = crypto.createPublicKey({
        key: jwk,
        format: 'jwk',
      });

      return keyObject.export({
        type: 'spki',
        format: 'pem',
      });
    } catch (error) {
      this.logger.error('Modern crypto approach failed, trying manual conversion:', error);

      // Fallback: Manual RSA key construction
      // This is a more compatible approach for older Node.js versions
      // Note: For manual ASN.1 construction, we would use:
      // const n = Buffer.from(jwk.n, 'base64url');
      // const e = Buffer.from(jwk.e, 'base64url');
      // But we're using the x5c certificate approach instead

      // For now, let's try using the x5c certificate if available
      if (jwk.x5c && jwk.x5c.length > 0) {
        const cert = jwk.x5c[0];
        const pemCert = `-----BEGIN CERTIFICATE-----\n${cert.match(/.{1,64}/g).join('\n')}\n-----END CERTIFICATE-----`;

        // Extract public key from certificate
        const certObject = crypto.createPublicKey(pemCert);
        return certObject.export({
          type: 'spki',
          format: 'pem',
        });
      }

      throw new Error('Unable to convert JWK to PEM format');
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
      // Ensure database is initialized
      if (!this.db.db) {
        await this.db.initialize();
      }

      // Check for existing session with same token
      const existingSession = await this.db.db.get(
        'SELECT * FROM user_sessions WHERE user_id = ? AND jwt_token_hash = ?',
        [userId, tokenHash],
      );

      if (existingSession) {
        // Update existing session
        await this.db.db.run(
          'UPDATE user_sessions SET last_activity = CURRENT_TIMESTAMP WHERE id = ?',
          [existingSession.id],
        );

        return existingSession;
      }

      // Clean up old sessions for user
      await this.cleanupUserSessions(userId);

      // Create new session
      const result = await this.db.db.run(
        `INSERT INTO user_sessions (user_id, jwt_token_hash, expires_at, ip_address, user_agent)
         VALUES (?, ?, ?, ?, ?)`,
        [userId, tokenHash, expiresAt, ip, userAgent],
      );

      // Get the created session
      const session = await this.db.db.get(
        'SELECT * FROM user_sessions WHERE id = ?',
        [result.lastID || this.generateSessionId()],
      );

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
        stack: error.stack,
        sqliteError: error.code,
        sqliteMessage: error.message,
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
        const sessionsToRemove = activeCount - this.config.MAX_SESSIONS_PER_USER + 1;

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
    setInterval(async() => {
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
    }, 15 * 60 * 1000); // 15 minutes
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
