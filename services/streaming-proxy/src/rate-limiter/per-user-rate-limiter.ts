/**
 * Per-User Rate Limiter
 * 
 * Manages rate limiting on a per-user basis with tier-based limits.
 * Integrates with UserContextManager to load user-specific limits.
 * 
 * Requirements: 4.3, 4.8
 */

import { TokenBucketRateLimiter } from './token-bucket-rate-limiter';
import { RateLimitConfig, UserTier } from '../interfaces/auth-middleware';
import { RateLimitResult } from '../interfaces/rate-limiter';

/**
 * Default rate limits per user tier
 */
export const DEFAULT_TIER_LIMITS: Record<UserTier, RateLimitConfig> = {
  [UserTier.FREE]: {
    requestsPerMinute: 60,
    maxConcurrentConnections: 1,
    maxQueueSize: 50,
  },
  [UserTier.PREMIUM]: {
    requestsPerMinute: 300,
    maxConcurrentConnections: 3,
    maxQueueSize: 200,
  },
  [UserTier.ENTERPRISE]: {
    requestsPerMinute: 1000,
    maxConcurrentConnections: 10,
    maxQueueSize: 500,
  },
};

export interface UserRateLimitInfo {
  userId: string;
  tier: UserTier;
  limit: RateLimitConfig;
  currentUsage: {
    requestsInLastMinute: number;
    remaining: number;
    resetAt: Date;
  };
}

export class PerUserRateLimiter {
  private rateLimiter: TokenBucketRateLimiter;
  private userTiers: Map<string, UserTier> = new Map();

  constructor(defaultLimit?: RateLimitConfig) {
    const globalLimit = defaultLimit || DEFAULT_TIER_LIMITS[UserTier.FREE];
    this.rateLimiter = new TokenBucketRateLimiter(globalLimit);
  }

  /**
   * Check if user is within rate limit
   * Loads user-specific limits based on tier
   */
  async checkUserLimit(userId: string, ip: string, tier?: UserTier): Promise<RateLimitResult> {
    // Update user tier if provided
    if (tier) {
      this.setUserTier(userId, tier);
    }

    // Ensure user has limits configured
    this.ensureUserLimits(userId);

    // Check limit using token bucket
    return await this.rateLimiter.checkLimit(userId, ip);
  }

  /**
   * Record a request for a user
   * Tracks request counts per user
   */
  recordUserRequest(userId: string, ip: string): void {
    this.rateLimiter.recordRequest(userId, ip);
  }

  /**
   * Set user tier and update rate limits accordingly
   */
  setUserTier(userId: string, tier: UserTier): void {
    this.userTiers.set(userId, tier);
    const limit = DEFAULT_TIER_LIMITS[tier];
    this.rateLimiter.setUserLimit(userId, limit);
  }

  /**
   * Set custom rate limit for a specific user
   * Overrides tier-based limits
   */
  setCustomUserLimit(userId: string, limit: RateLimitConfig): void {
    this.rateLimiter.setUserLimit(userId, limit);
  }

  /**
   * Get user rate limit information
   */
  async getUserLimitInfo(userId: string, ip: string): Promise<UserRateLimitInfo> {
    const tier = this.userTiers.get(userId) || UserTier.FREE;
    const limit = DEFAULT_TIER_LIMITS[tier];
    
    // Check current status without consuming tokens
    const result = await this.rateLimiter.checkLimit(userId, ip);
    
    return {
      userId,
      tier,
      limit,
      currentUsage: {
        requestsInLastMinute: limit.requestsPerMinute - result.remaining,
        remaining: result.remaining,
        resetAt: result.resetAt,
      },
    };
  }

  /**
   * Get rate limit headers for HTTP response
   * Returns standard rate limit headers
   */
  getRateLimitHeaders(result: RateLimitResult, limit: RateLimitConfig): Record<string, string> {
    const headers: Record<string, string> = {
      'X-RateLimit-Limit': limit.requestsPerMinute.toString(),
      'X-RateLimit-Remaining': result.remaining.toString(),
      'X-RateLimit-Reset': Math.floor(result.resetAt.getTime() / 1000).toString(),
    };

    if (result.retryAfter !== undefined) {
      headers['Retry-After'] = result.retryAfter.toString();
    }

    return headers;
  }

  /**
   * Block requests exceeding limits
   * Returns error response with retry information
   */
  createRateLimitError(result: RateLimitResult, userId: string): {
    statusCode: number;
    error: string;
    retryAfter: number;
    resetAt: string;
  } {
    return {
      statusCode: 429,
      error: 'Rate limit exceeded',
      retryAfter: result.retryAfter || 60,
      resetAt: result.resetAt.toISOString(),
    };
  }

  /**
   * Get violations for a specific user
   */
  getUserViolations(userId: string, window: number = 3600000): Array<{
    timestamp: Date;
    ip: string;
  }> {
    const allViolations = this.rateLimiter.getViolations(window);
    return allViolations
      .filter(v => v.userId === userId)
      .map(v => ({
        timestamp: v.timestamp,
        ip: v.ip,
      }));
  }

  /**
   * Check if user has exceeded rate limit multiple times
   * Useful for detecting abuse
   */
  isUserAbusive(userId: string, threshold: number = 10, window: number = 3600000): boolean {
    const violations = this.getUserViolations(userId, window);
    return violations.length >= threshold;
  }

  /**
   * Ensure user has rate limits configured
   */
  private ensureUserLimits(userId: string): void {
    const tier = this.userTiers.get(userId) || UserTier.FREE;
    const limit = DEFAULT_TIER_LIMITS[tier];
    this.rateLimiter.setUserLimit(userId, limit);
  }

  /**
   * Clean up old data
   */
  cleanup(maxIdleTime: number = 3600000): void {
    this.rateLimiter.cleanupOldBuckets(maxIdleTime);
  }

  /**
   * Get statistics for monitoring
   */
  getStats(): {
    totalUsers: number;
    tierDistribution: Record<UserTier, number>;
    recentViolations: number;
  } {
    const tierDistribution: Record<UserTier, number> = {
      [UserTier.FREE]: 0,
      [UserTier.PREMIUM]: 0,
      [UserTier.ENTERPRISE]: 0,
    };

    for (const tier of this.userTiers.values()) {
      tierDistribution[tier]++;
    }

    const recentViolations = this.rateLimiter.getViolations(60000).length;

    return {
      totalUsers: this.userTiers.size,
      tierDistribution,
      recentViolations,
    };
  }
}
