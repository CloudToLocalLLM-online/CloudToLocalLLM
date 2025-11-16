/**
 * Authentication Middleware Interface
 * Handles JWT validation and user context management
 */

export enum UserTier {
  FREE = 'free',
  PREMIUM = 'premium',
  ENTERPRISE = 'enterprise',
}

export interface TokenValidationResult {
  valid: boolean;
  userId?: string;
  expiresAt?: Date;
  error?: string;
}

export interface RateLimitConfig {
  requestsPerMinute: number;
  maxConcurrentConnections: number;
  maxQueueSize: number;
}

export interface UserContext {
  userId: string;
  tier: UserTier;
  permissions: string[];
  rateLimit: RateLimitConfig;
}

export interface AuthEvent {
  userId: string;
  eventType: 'login' | 'logout' | 'token_refresh' | 'validation_failed';
  timestamp: Date;
  metadata?: Record<string, any>;
}

export interface AuthMiddleware {
  /**
   * Validate JWT token
   */
  validateToken(token: string): Promise<TokenValidationResult>;

  /**
   * Refresh expired token
   */
  refreshToken(token: string): Promise<string>;

  /**
   * Get user context from token
   */
  getUserContext(token: string): Promise<UserContext>;

  /**
   * Log authentication attempt
   */
  logAuthAttempt(userId: string, success: boolean, reason?: string): void;

  /**
   * Log authentication event
   */
  logAuthEvent(event: AuthEvent): void;
}
