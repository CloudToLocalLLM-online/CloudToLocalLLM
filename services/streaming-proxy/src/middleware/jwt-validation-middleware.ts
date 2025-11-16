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

interface Auth0Config {
  domain: string;
  audience: string;
  issuer: string;
}

/**
 * JWT Validation Middleware
 * Validates JWT tokens from Auth0 with caching
 */
export class JWTValidationMiddleware implements AuthMiddleware {
  private readonly config: Auth0Config;
  private readonly validationCache: Map<string, CachedValidation> = new Map();
  private readonly cacheDuration = 5 * 60 * 1000; // 5 minutes
  private jwksCache: Map<string, string> = new Map();
  private jwksCacheExpiry: Date | null = null;

  constructor(config: Auth0Config) {
    this.config = config;
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

    try {
      // Decode token without verification
      const decoded = this.decodeToken(token);
      if (!decoded) {
        const result = { valid: false, error: 'Invalid token format' };
        this.cacheValidation(token, result);
        return result;
      }

      const { header, payload } = decoded;

      // Verify issuer
      if (payload.iss !== this.config.issuer) {
        const result = { valid: false, error: 'Invalid issuer' };
        this.cacheValidation(token, result);
        return result;
      }

      // Verify audience
      const audiences = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
      if (!audiences.includes(this.config.audience)) {
        const result = { valid: false, error: 'Invalid audience' };
        this.cacheValidation(token, result);
        return result;
      }

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

      // Get public key and verify signature
      const publicKey = await this.getPublicKey(header.kid);
      if (!publicKey) {
        const result = { valid: false, error: 'Unable to retrieve public key' };
        this.cacheValidation(token, result);
        return result;
      }

      const isValid = await this.verifySignature(token, publicKey);
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
   * Get public key from Auth0 JWKS endpoint
   */
  private async getPublicKey(kid: string): Promise<string | null> {
    // Check cache
    if (this.jwksCacheExpiry && Date.now() < this.jwksCacheExpiry.getTime()) {
      const cached = this.jwksCache.get(kid);
      if (cached) {
        return cached;
      }
    }

    try {
      const jwksUrl = `https://${this.config.domain}/.well-known/jwks.json`;
      const response = await fetch(jwksUrl);
      
      if (!response.ok) {
        console.error('Failed to fetch JWKS:', response.statusText);
        return null;
      }

      const jwks = await response.json();
      
      // Cache all keys
      this.jwksCache.clear();
      for (const key of jwks.keys) {
        if (key.kid && key.x5c && key.x5c.length > 0) {
          // Convert x5c certificate to PEM format
          const cert = key.x5c[0];
          const pem = `-----BEGIN CERTIFICATE-----\n${cert}\n-----END CERTIFICATE-----`;
          this.jwksCache.set(key.kid, pem);
        }
      }

      // Set cache expiry (1 hour)
      this.jwksCacheExpiry = new Date(Date.now() + 60 * 60 * 1000);

      return this.jwksCache.get(kid) || null;
    } catch (error) {
      console.error('Error fetching JWKS:', error);
      return null;
    }
  }

  /**
   * Verify JWT signature using public key
   */
  private async verifySignature(token: string, publicKey: string): Promise<boolean> {
    try {
      // Use Web Crypto API for signature verification
      const parts = token.split('.');
      const header = parts[0];
      const payload = parts[1];
      const signature = parts[2];

      const data = `${header}.${payload}`;
      const signatureBytes = this.base64UrlDecodeToBytes(signature);

      // Import public key
      const keyData = this.pemToArrayBuffer(publicKey);
      const cryptoKey = await crypto.subtle.importKey(
        'spki',
        keyData,
        {
          name: 'RSASSA-PKCS1-v1_5',
          hash: 'SHA-256',
        },
        false,
        ['verify']
      );

      // Verify signature
      const dataBytes = new TextEncoder().encode(data);
      const isValid = await crypto.subtle.verify(
        'RSASSA-PKCS1-v1_5',
        cryptoKey,
        signatureBytes as BufferSource,
        dataBytes
      );

      return isValid;
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

  /**
   * Base64 URL decode to bytes
   */
  private base64UrlDecodeToBytes(str: string): Uint8Array {
    // Replace URL-safe characters
    let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
    
    // Add padding
    while (base64.length % 4 !== 0) {
      base64 += '=';
    }

    // Decode
    return new Uint8Array(Buffer.from(base64, 'base64'));
  }

  /**
   * Convert PEM certificate to ArrayBuffer
   */
  private pemToArrayBuffer(pem: string): ArrayBuffer {
    // Remove PEM headers and newlines
    const b64 = pem
      .replace(/-----BEGIN CERTIFICATE-----/, '')
      .replace(/-----END CERTIFICATE-----/, '')
      .replace(/\n/g, '');

    const binary = Buffer.from(b64, 'base64');
    return binary.buffer.slice(binary.byteOffset, binary.byteOffset + binary.byteLength);
  }
}
