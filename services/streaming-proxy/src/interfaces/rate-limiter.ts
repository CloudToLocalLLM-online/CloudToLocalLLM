/**
 * Rate Limiter Interface
 * Implements token bucket algorithm for rate limiting
 */

import { RateLimitConfig } from './auth-middleware';

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
  retryAfter?: number;
}

export interface RateLimitViolation {
  userId: string;
  ip: string;
  timestamp: Date;
  requestCount: number;
  limit: number;
}

export interface RateLimiter {
  /**
   * Check if request is within rate limit
   */
  checkLimit(userId: string, ip: string): Promise<RateLimitResult>;

  /**
   * Record a request for rate limiting
   */
  recordRequest(userId: string, ip: string): void;

  /**
   * Set user-specific rate limit
   */
  setUserLimit(userId: string, limit: RateLimitConfig): void;

  /**
   * Set global rate limit
   */
  setGlobalLimit(limit: RateLimitConfig): void;

  /**
   * Get rate limit violations within time window
   */
  getViolations(window: number): RateLimitViolation[];
}
