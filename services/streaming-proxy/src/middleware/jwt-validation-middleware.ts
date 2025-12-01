/**
 * JWT Validation Middleware Implementation
 * Integrates with Supabase JWKS for token validation (RS256)
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
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

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
    url: string;
  };
}

/**
 * JWT Validation Middleware
 * Validates JWT tokens from Supabase with caching using RS256
 */
export class JWTValidationMiddleware implements AuthMiddleware {
  private readonly config: SupabaseConfig;
  private readonly validationCache: Map<string, CachedValidation> = new Map();
  private readonly cacheDuration = 5 * 60 * 1000; // 5 minutes
  private readonly client: jwksClient.JwksClient;

  constructor(config: SupabaseConfig) {
    this.config = config;
    this.client = jwksClient({
      jwksUri: `${config.supabase.url}/auth/v1/.well-known/jwks.json`,
      cache: true,
      rateLimit: true,
      jwksRequestsPerMinute: 5,
    });
  }

  /**
   * Get signing key from JWKS
   */
  private getKey(header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) {
    this.client.getSigningKey(header.kid, (err, key) => {
      if (err) {
        callback(err);
        return;
      }
      const signingKey = key?.getPublicKey();
      callback(null, signingKey);
    });
  }

  /**
   * Validate JWT token with caching
   */
  async validateToken(token: string): Promise<TokenValidationResult> {
    // Check cache first
    const cached = this.validationCache.get(token);
    if (cached && Date.now() - cached.cachedAt.getTime() < this.cacheDuration) {
      return cached.result;
    }

    return new Promise((resolve) => {
      jwt.verify(
        token,
        this.getKey.bind(this),
        { algorithms: ['RS256'] },
        (err, decoded) => {
          if (err) {
            let result: TokenValidationResult;
            if (err instanceof jwt.TokenExpiredError) {
              const decodedToken = jwt.decode(token) as JWTPayload;
              result = {
                valid: false,
                error: 'Token expired',
                userId: decodedToken?.sub,
                expiresAt: decodedToken?.exp ? new Date(decodedToken.exp * 1000) : undefined,
              };
            } else {
              result = {
                valid: false,
                error: err.message,
              };
            }
            // Cache invalid results too (except expired which are distinct)
            if (err.name !== 'TokenExpiredError') {
              this.cacheValidation(token, result);
            }
            resolve(result);
            return;
          }

          const payload = decoded as JWTPayload;
          const result: TokenValidationResult = {
            valid: true,
            userId: payload.sub,
            expiresAt: new Date(payload.exp * 1000),
          };

          this.cacheValidation(token, result);
          resolve(result);
        }
      );
    });
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

    const decoded = jwt.decode(token) as JWTPayload;
    if (!decoded) {
      throw new Error('Failed to decode token');
    }

    // Extract user tier from token claims
    const tier = this.extractUserTier(decoded);
    
    // Extract permissions
    const permissions = this.extractPermissions(decoded);

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
}
