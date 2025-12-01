/**
 * JWT Validation Middleware Implementation
 * Integrates with Auth0 JWKS for token validation
 * Implements caching and distinguishes between expired and invalid tokens
 */

import {
  AuthMiddleware,
  TokenValidationResult,
  UserContext,
  UserTier,
  RateLimitConfig,
  AuthEvent,
} from '../interfaces/auth-middleware';
import crypto from 'crypto';

interface JWTHeader {
  alg: string;
  typ: string;
  kid: string;
}

interface JWTPayload {
  sub: string;
  iss: string;
  aud: string | string[];
  exp: number;
  iat: number;
  [key: string]: any;
}

interface CachedValidation {
  result: TokenValidationResult;
  cachedAt: Date;
}

interface SupabaseConfig {
  supabase: {
    jwtSecret: string;
  };
}

/**
 * JWT Validation Middleware
 * Validates JWT tokens from Supabase with caching
 */
export class JWTValidationMiddleware implements AuthMiddleware {
  private readonly config: SupabaseConfig;
  private readonly validationCache: Map<string, CachedValidation> = new Map();
  private readonly cacheDuration = 5 * 60 * 1000; // 5 minutes

  constructor(config: SupabaseConfig) {
    this.config = config;
  }

  /**
   * Validate JWT token with caching
   */
  /**
   * Validate JWT token with caching
   */
  async validateToken(token: string): Promise<TokenValidationResult> {
    // Check cache first
    const cached = this.validationCache.get(token);
    if (cached && Date.now() - cached.cachedAt.getTime() < this.cacheDuration) {
      return cached.result;
    }

    try {
      // Decode token without verification
      const decoded = this.decodeToken(token);
      if (!decoded) {
        const result = { valid: false, error: 'Invalid token format' };
        this.cacheValidation(token, result);
        return result;
      }

      const { payload } = decoded;

      // Check expiration
      const now = Math.floor(Date.now() / 1000);
      if (payload.exp && payload.exp < now) {
        const result = {
          valid: false,
          error: 'Token expired',
          userId: payload.sub,
          expiresAt: new Date(payload.exp * 1000),
        };
        // Don't cache expired tokens
        return result;
      }

      // Verify signature using HS256 (HMAC-SHA256) with Supabase JWT Secret
      const isValid = await this.verifySignature(token, this.config.supabase.jwtSecret);
      if (!isValid) {
        const result = { valid: false, error: 'Invalid signature' };
        this.cacheValidation(token, result);
        return result;
      }

      // Token is valid
      const result: TokenValidationResult = {
        valid: true,
        userId: payload.sub,
        expiresAt: new Date(payload.exp * 1000),
      };

      this.cacheValidation(token, result);
      return result;
    } catch (error) {
      const result = {
        valid: false,
        error: error instanceof Error ? error.message : 'Unknown validation error',
      };
      return result;
    }
  }

  /**
   * Refresh expired token (placeholder - actual implementation depends on Auth0 setup)
   */
  async refreshToken(token: string): Promise<string> {
    // This would typically involve calling Auth0's token refresh endpoint
    // For now, throw an error indicating the client should re-authenticate
    throw new Error('Token refresh not implemented - please re-authenticate');
  }

  /**
   * Get user context from validated token
   */
  async getUserContext(token: string): Promise<UserContext> {
    const validation = await this.validateToken(token);
    
    if (!validation.valid || !validation.userId) {
      throw new Error('Invalid token - cannot extract user context');
    }

    const decoded = this.decodeToken(token);
    if (!decoded) {
      throw new Error('Failed to decode token');
    }

    const { payload } = decoded;

    // Extract user tier from token claims
    const tier = this.extractUserTier(payload);
    
    // Extract permissions
    const permissions = this.extractPermissions(payload);

    // Get rate limit config based on tier
    const rateLimit = this.getRateLimitForTier(tier);

    return {
      userId: validation.userId,
      tier,
      permissions,
      rateLimit,
    };
  }

  /**
   * Log authentication attempt
   */
  logAuthAttempt(userId: string, success: boolean, reason?: string): void {
    const logEntry = {
      timestamp: new Date().toISOString(),
      userId,
      success,
      reason,
      type: 'auth_attempt',
    };

    console.log(JSON.stringify(logEntry));
  }

  /**
   * Log authentication event
   */
  logAuthEvent(event: AuthEvent): void {
    const logEntry = {
      timestamp: event.timestamp.toISOString(),
      userId: event.userId,
      eventType: event.eventType,
      metadata: event.metadata,
      type: 'auth_event',
    };

    console.log(JSON.stringify(logEntry));
  }

  /**
   * Decode JWT token without verification
   */
  private decodeToken(token: string): { header: JWTHeader; payload: JWTPayload } | null {
    try {
      const parts = token.split('.');
      if (parts.length !== 3) {
        return null;
      }

      const header = JSON.parse(this.base64UrlDecode(parts[0]));
      const payload = JSON.parse(this.base64UrlDecode(parts[1]));

      return { header, payload };
    } catch {
      return null;
    }
  }



  /**
   * Verify JWT signature using HS256 (HMAC-SHA256)
   */
  private async verifySignature(token: string, secret: string): Promise<boolean> {
    try {
      const parts = token.split('.');
      const header = parts[0];
      const payload = parts[1];
      const signature = parts[2];

      const data = `${header}.${payload}`;
      
      // Calculate expected signature
      const hmac = crypto.createHmac('sha256', secret);
      hmac.update(data);
      const calculatedSignature = hmac.digest('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');

      return signature === calculatedSignature;
    } catch (error) {
      console.error('Signature verification error:', error);
      return false;
    }
  }

  /**
   * Cache validation result
   */
  private cacheValidation(token: string, result: TokenValidationResult): void {
    this.validationCache.set(token, {
      result,
      cachedAt: new Date(),
    });

    // Clean up old cache entries periodically
    if (this.validationCache.size > 1000) {
      this.cleanupCache();
    }
  }

  /**
   * Clean up expired cache entries
   */
  private cleanupCache(): void {
    const now = Date.now();
    for (const [token, cached] of this.validationCache.entries()) {
      if (now - cached.cachedAt.getTime() > this.cacheDuration) {
        this.validationCache.delete(token);
      }
    }
  }

  /**
   * Extract user tier from token payload
   */
  private extractUserTier(payload: JWTPayload): UserTier {
    // Check for tier in custom claims
    const tier = payload['https://cloudtolocalllm.com/tier'] || 
                 payload.tier || 
                 payload['app_metadata']?.tier;

    switch (tier?.toLowerCase()) {
      case 'premium':
        return UserTier.PREMIUM;
      case 'enterprise':
        return UserTier.ENTERPRISE;
      default:
        return UserTier.FREE;
    }
  }

  /**
   * Extract permissions from token payload
   */
  private extractPermissions(payload: JWTPayload): string[] {
    const permissions = payload.permissions || 
                       payload['https://cloudtolocalllm.com/permissions'] ||
                       [];
    
    return Array.isArray(permissions) ? permissions : [];
  }

  /**
   * Get rate limit configuration for user tier
   */
  private getRateLimitForTier(tier: UserTier): RateLimitConfig {
    switch (tier) {
      case UserTier.ENTERPRISE:
        return {
          requestsPerMinute: 1000,
          maxConcurrentConnections: 10,
          maxQueueSize: 500,
        };
      case UserTier.PREMIUM:
        return {
          requestsPerMinute: 300,
          maxConcurrentConnections: 5,
          maxQueueSize: 200,
        };
      case UserTier.FREE:
      default:
        return {
          requestsPerMinute: 100,
          maxConcurrentConnections: 3,
          maxQueueSize: 100,
        };
    }
  }

  /**
   * Base64 URL decode to string
   */
  private base64UrlDecode(str: string): string {
    // Replace URL-safe characters
    let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
    
    // Add padding
    while (base64.length % 4 !== 0) {
      base64 += '=';
    }

    // Decode
    return Buffer.from(base64, 'base64').toString('utf-8');
  }




}
