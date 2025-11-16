/**
 * Token Bucket Rate Limiter Implementation
 * 
 * Implements the token bucket algorithm for rate limiting requests per user and IP.
 * 
 * ## Algorithm Overview
 * 
 * The token bucket algorithm works as follows:
 * 
 * 1. **Bucket Initialization**: Each user/IP gets a bucket with:
 *    - `capacity`: Maximum tokens (e.g., 100 for 100 requests/minute)
 *    - `tokens`: Current token count (starts at capacity)
 *    - `refillRate`: Tokens added per second (capacity / 60)
 * 
 * 2. **Token Refill**: On each check, tokens are added based on elapsed time:
 *    ```
 *    tokensToAdd = (now - lastRefill) / 1000 * refillRate
 *    tokens = min(capacity, tokens + tokensToAdd)
 *    ```
 * 
 * 3. **Request Processing**: Each request consumes 1 token:
 *    - If tokens >= 1: Allow request, decrement tokens
 *    - If tokens < 1: Reject request, return retry-after time
 * 
 * 4. **Retry-After Calculation**: Time until next token available:
 *    ```
 *    tokensNeeded = 1 - currentTokens
 *    retryAfter = ceil(tokensNeeded / refillRate)
 *    ```
 * 
 * ## Configuration
 * 
 * - `requestsPerMinute`: Capacity and refill rate (e.g., 100)
 * - Per-user limits: Can override global limit for specific users
 * - Per-IP limits: Separate bucket for DDoS protection
 * 
 * ## Usage Example
 * 
 * ```typescript
 * const limiter = new TokenBucketRateLimiter({
 *   requestsPerMinute: 100,
 *   maxConcurrentConnections: 3,
 *   maxQueueSize: 100,
 * });
 * 
 * // Check if request is allowed
 * const result = await limiter.checkLimit(userId, ipAddress);
 * if (!result.allowed) {
 *   return res.status(429).json({
 *     error: 'Rate limit exceeded',
 *     retryAfter: result.retryAfter,
 *   });
 * }
 * 
 * // Record the request
 * limiter.recordRequest(userId, ipAddress);
 * ```
 * 
 * ## Performance Characteristics
 * 
 * - **Time Complexity**: O(1) for check and record operations
 * - **Space Complexity**: O(n) where n = number of active users/IPs
 * - **Memory Cleanup**: Old buckets cleaned up after 1 hour of inactivity
 * 
 * Requirements: 4.3
 */

import { RateLimiter, RateLimitResult, RateLimitViolation } from '../interfaces/rate-limiter';
import { RateLimitConfig } from '../interfaces/auth-middleware';

/**
 * Token bucket state for a single user or IP
 * 
 * @interface TokenBucket
 * @property tokens - Current number of available tokens
 * @property capacity - Maximum tokens in bucket
 * @property refillRate - Tokens added per second
 * @property lastRefill - Timestamp of last refill (milliseconds)
 */
interface TokenBucket {
  /** Current number of available tokens */
  tokens: number;
  
  /** Maximum tokens in bucket (capacity) */
  capacity: number;
  
  /** Tokens added per second (capacity / 60) */
  refillRate: number;
  
  /** Timestamp of last refill in milliseconds */
  lastRefill: number;
}

interface BucketKey {
  userId?: string;
  ip?: string;
}

/**
 * Token Bucket Rate Limiter Implementation
 * 
 * Manages rate limiting for both users and IPs using separate token buckets.
 * Supports per-user overrides and automatic cleanup of stale buckets.
 */
export class TokenBucketRateLimiter implements RateLimiter {
  /** Token buckets for each user */
  private userBuckets: Map<string, TokenBucket> = new Map();
  
  /** Token buckets for each IP address */
  private ipBuckets: Map<string, TokenBucket> = new Map();
  
  /** Per-user rate limit overrides */
  private userLimits: Map<string, RateLimitConfig> = new Map();
  
  /** Global rate limit (default for all users/IPs) */
  private globalLimit: RateLimitConfig;
  
  /** History of rate limit violations for monitoring */
  private violations: RateLimitViolation[] = [];
  
  /** Maximum violations to keep in history */
  private readonly maxViolationHistory = 1000;

  /**
   * Create a new token bucket rate limiter
   * 
   * @param defaultLimit - Default rate limit configuration for all users/IPs
   */
  constructor(defaultLimit: RateLimitConfig) {
    this.globalLimit = defaultLimit;
  }

  /**
   * Check if a request is within rate limits
   * 
   * Checks both user-specific and IP-specific rate limits. Returns the most
   * restrictive result (if either is exceeded, request is denied).
   * 
   * @param userId - User identifier
   * @param ip - Client IP address
   * @returns Rate limit result with allowed status and retry-after time
   * 
   * @example
   * ```typescript
   * const result = await limiter.checkLimit('user123', '192.168.1.1');
   * if (!result.allowed) {
   *   res.set('Retry-After', result.retryAfter?.toString() || '60');
   *   return res.status(429).send('Rate limit exceeded');
   * }
   * ```
   */
  async checkLimit(userId: string, ip: string): Promise<RateLimitResult> {
    // Check user limit first
    const userResult = await this.checkUserLimit(userId);
    if (!userResult.allowed) {
      this.recordViolation(userId, ip, 'user');
      return userResult;
    }

    // Check IP limit second
    const ipResult = await this.checkIpLimit(ip);
    if (!ipResult.allowed) {
      this.recordViolation(userId, ip, 'ip');
      return ipResult;
    }

    // Both limits passed, return user result (more specific)
    return userResult;
  }

  /**
   * Record a request for rate limiting
   * 
   * Consumes one token from both user and IP buckets. Should be called
   * after checkLimit returns allowed=true.
   * 
   * @param userId - User identifier
   * @param ip - Client IP address
   */
  recordRequest(userId: string, ip: string): void {
    this.consumeToken(userId, 'user');
    this.consumeToken(ip, 'ip');
  }

  /**
   * Set user-specific rate limit
   * 
   * Overrides the global limit for a specific user. Updates existing bucket
   * if present, or will be used when bucket is created.
   * 
   * @param userId - User identifier
   * @param limit - Rate limit configuration for this user
   */
  setUserLimit(userId: string, limit: RateLimitConfig): void {
    this.userLimits.set(userId, limit);
    
    // Update existing bucket if present
    const bucket = this.userBuckets.get(userId);
    if (bucket) {
      bucket.capacity = limit.requestsPerMinute;
      bucket.refillRate = limit.requestsPerMinute / 60; // per second
      bucket.tokens = Math.min(bucket.tokens, bucket.capacity);
    }
  }

  /**
   * Set global rate limit
   * 
   * Updates the default rate limit for all users/IPs without specific overrides.
   * Does not affect existing buckets.
   * 
   * @param limit - Global rate limit configuration
   */
  setGlobalLimit(limit: RateLimitConfig): void {
    this.globalLimit = limit;
  }

  /**
   * Get rate limit violations within a time window
   * 
   * Returns all violations that occurred within the specified window.
   * Useful for monitoring and alerting on rate limit abuse.
   * 
   * @param window - Time window in milliseconds (e.g., 60000 for 1 minute)
   * @returns Array of violations within the window
   */
  getViolations(window: number): RateLimitViolation[] {
    const cutoff = Date.now() - window;
    return this.violations.filter(v => v.timestamp.getTime() > cutoff);
  }

  /**
   * Check user-specific rate limit
   * 
   * Refills the user's bucket based on elapsed time, then checks if a token
   * is available. Returns remaining tokens and reset time.
   * 
   * @private
   * @param userId - User identifier
   * @returns Rate limit result for this user
   */
  private async checkUserLimit(userId: string): Promise<RateLimitResult> {
    const limit = this.userLimits.get(userId) || this.globalLimit;
    const bucket = this.getOrCreateBucket(userId, 'user', limit);
    
    // Refill tokens based on elapsed time
    this.refillBucket(bucket);

    if (bucket.tokens >= 1) {
      return {
        allowed: true,
        remaining: Math.floor(bucket.tokens) - 1,
        resetAt: this.calculateResetTime(bucket),
      };
    }

    return {
      allowed: false,
      remaining: 0,
      resetAt: this.calculateResetTime(bucket),
      retryAfter: this.calculateRetryAfter(bucket),
    };
  }

  /**
   * Check IP-specific rate limit
   * 
   * Refills the IP's bucket based on elapsed time, then checks if a token
   * is available. Used for DDoS protection.
   * 
   * @private
   * @param ip - Client IP address
   * @returns Rate limit result for this IP
   */
  private async checkIpLimit(ip: string): Promise<RateLimitResult> {
    const bucket = this.getOrCreateBucket(ip, 'ip', this.globalLimit);
    
    // Refill tokens based on elapsed time
    this.refillBucket(bucket);

    if (bucket.tokens >= 1) {
      return {
        allowed: true,
        remaining: Math.floor(bucket.tokens) - 1,
        resetAt: this.calculateResetTime(bucket),
      };
    }

    return {
      allowed: false,
      remaining: 0,
      resetAt: this.calculateResetTime(bucket),
      retryAfter: this.calculateRetryAfter(bucket),
    };
  }

  /**
   * Get or create a token bucket for a user/IP
   * 
   * Initializes a new bucket with the specified limit if it doesn't exist.
   * Bucket starts with full capacity.
   * 
   * @private
   * @param key - User ID or IP address
   * @param type - Bucket type ('user' or 'ip')
   * @param limit - Rate limit configuration
   * @returns Token bucket for this key
   */
  private getOrCreateBucket(
    key: string,
    type: 'user' | 'ip',
    limit: RateLimitConfig
  ): TokenBucket {
    const buckets = type === 'user' ? this.userBuckets : this.ipBuckets;
    
    let bucket = buckets.get(key);
    if (!bucket) {
      bucket = {
        tokens: limit.requestsPerMinute,
        capacity: limit.requestsPerMinute,
        refillRate: limit.requestsPerMinute / 60, // tokens per second
        lastRefill: Date.now(),
      };
      buckets.set(key, bucket);
    }

    return bucket;
  }

  /**
   * Refill tokens in bucket based on elapsed time
   * 
   * Calculates how many tokens to add based on the time elapsed since last refill.
   * Formula: tokensToAdd = (now - lastRefill) / 1000 * refillRate
   * 
   * @private
   * @param bucket - Token bucket to refill
   */
  private refillBucket(bucket: TokenBucket): void {
    const now = Date.now();
    const elapsedSeconds = (now - bucket.lastRefill) / 1000;
    
    // Calculate tokens to add based on elapsed time and refill rate
    const tokensToAdd = elapsedSeconds * bucket.refillRate;
    
    // Add tokens, but cap at capacity to prevent overflow
    bucket.tokens = Math.min(bucket.capacity, bucket.tokens + tokensToAdd);
    bucket.lastRefill = now;
  }

  /**
   * Consume a token from the bucket
   * 
   * Decrements token count by 1 if available. Should only be called
   * after checkLimit returns allowed=true.
   * 
   * @private
   * @param key - User ID or IP address
   * @param type - Bucket type ('user' or 'ip')
   */
  private consumeToken(key: string, type: 'user' | 'ip'): void {
    const buckets = type === 'user' ? this.userBuckets : this.ipBuckets;
    const bucket = buckets.get(key);
    
    if (bucket && bucket.tokens >= 1) {
      bucket.tokens -= 1;
    }
  }

  /**
   * Calculate when the bucket will be fully refilled
   * 
   * Determines the time when all tokens will be available again.
   * Used for Retry-After header.
   * 
   * @private
   * @param bucket - Token bucket
   * @returns Date when bucket will be full
   */
  private calculateResetTime(bucket: TokenBucket): Date {
    const tokensNeeded = bucket.capacity - bucket.tokens;
    const secondsToRefill = tokensNeeded / bucket.refillRate;
    return new Date(Date.now() + secondsToRefill * 1000);
  }

  /**
   * Calculate retry-after value in seconds
   * 
   * Determines how long the client should wait before retrying.
   * Formula: retryAfter = ceil((1 - currentTokens) / refillRate)
   * 
   * @private
   * @param bucket - Token bucket
   * @returns Seconds to wait before retrying
   */
  private calculateRetryAfter(bucket: TokenBucket): number {
    // Time until one token is available
    const tokensNeeded = 1 - bucket.tokens;
    const secondsToWait = Math.max(0, tokensNeeded / bucket.refillRate);
    return Math.ceil(secondsToWait);
  }

  /**
   * Record a rate limit violation
   * 
   * Logs violations for monitoring and alerting. Maintains a history
   * of recent violations (up to maxViolationHistory).
   * 
   * @private
   * @param userId - User identifier
   * @param ip - Client IP address
   * @param type - Violation type ('user' or 'ip')
   */
  private recordViolation(userId: string, ip: string, type: 'user' | 'ip'): void {
    const limit = this.userLimits.get(userId) || this.globalLimit;
    
    const violation: RateLimitViolation = {
      userId,
      ip,
      timestamp: new Date(),
      requestCount: limit.requestsPerMinute + 1, // Exceeded by at least 1
      limit: limit.requestsPerMinute,
    };

    this.violations.push(violation);

    // Trim violation history to prevent memory growth
    if (this.violations.length > this.maxViolationHistory) {
      this.violations.shift();
    }
  }

  /**
   * Clean up old buckets to prevent memory leaks
   * 
   * Removes buckets that haven't been used for longer than maxIdleTime.
   * Should be called periodically (e.g., every 5 minutes).
   * 
   * @param maxIdleTime - Maximum idle time in milliseconds (default: 1 hour)
   */
  cleanupOldBuckets(maxIdleTime: number = 3600000): void {
    const now = Date.now();
    
    // Clean user buckets
    for (const [key, bucket] of this.userBuckets.entries()) {
      if (now - bucket.lastRefill > maxIdleTime) {
        this.userBuckets.delete(key);
      }
    }

    // Clean IP buckets
    for (const [key, bucket] of this.ipBuckets.entries()) {
      if (now - bucket.lastRefill > maxIdleTime) {
        this.ipBuckets.delete(key);
      }
    }
  }

  /**
   * Get current bucket state for debugging
   * 
   * Returns the internal state of a bucket for monitoring and troubleshooting.
   * 
   * @param key - User ID or IP address
   * @param type - Bucket type ('user' or 'ip')
   * @returns Token bucket state or undefined if not found
   */
  getBucketState(key: string, type: 'user' | 'ip'): TokenBucket | undefined {
    const buckets = type === 'user' ? this.userBuckets : this.ipBuckets;
    return buckets.get(key);
  }
}
