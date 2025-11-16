/**
 * Rate Limit Middleware
 * 
 * Express middleware for rate limiting HTTP requests.
 * Checks limits before processing requests and returns 429 for exceeded limits.
 * 
 * Requirements: 4.3
 */

import { Request, Response, NextFunction } from 'express';
import { PerUserRateLimiter } from './per-user-rate-limiter';
import { PerIpRateLimiter } from './per-ip-rate-limiter';
import { UserTier } from '../interfaces/auth-middleware';

export interface RateLimitMiddlewareOptions {
  enableUserLimits?: boolean;
  enableIpLimits?: boolean;
  skipSuccessfulRequests?: boolean;
  skipFailedRequests?: boolean;
  keyGenerator?: (req: Request) => string;
  handler?: (req: Request, res: Response) => void;
}

export interface RequestWithUser extends Request {
  user?: {
    userId: string;
    tier: UserTier;
  };
}

export class RateLimitMiddleware {
  private userLimiter: PerUserRateLimiter;
  private ipLimiter: PerIpRateLimiter;
  private options: Required<RateLimitMiddlewareOptions>;

  constructor(options: RateLimitMiddlewareOptions = {}) {
    this.userLimiter = new PerUserRateLimiter();
    this.ipLimiter = new PerIpRateLimiter();
    
    this.options = {
      enableUserLimits: options.enableUserLimits ?? true,
      enableIpLimits: options.enableIpLimits ?? true,
      skipSuccessfulRequests: options.skipSuccessfulRequests ?? false,
      skipFailedRequests: options.skipFailedRequests ?? false,
      keyGenerator: options.keyGenerator ?? this.defaultKeyGenerator,
      handler: options.handler ?? this.defaultHandler,
    };
  }

  /**
   * Express middleware function
   * Checks limits before processing requests
   */
  middleware() {
    return async (req: RequestWithUser, res: Response, next: NextFunction): Promise<void> => {
      try {
        const ip = this.getClientIp(req);
        const userId = req.user?.userId;
        const tier = req.user?.tier;

        // Check IP limit first (DDoS protection)
        if (this.options.enableIpLimits) {
          const ipResult = await this.ipLimiter.checkIpLimit(ip, userId);
          
          if (!ipResult.allowed) {
            this.handleRateLimitExceeded(req, res, ipResult, 'ip');
            this.ipLimiter.logViolation(ip, userId);
            return;
          }
        }

        // Check user limit if authenticated
        if (this.options.enableUserLimits && userId) {
          const userResult = await this.userLimiter.checkUserLimit(userId, ip, tier);
          
          if (!userResult.allowed) {
            this.handleRateLimitExceeded(req, res, userResult, 'user');
            return;
          }

          // Add rate limit headers to response
          const limit = tier ? this.userLimiter['rateLimiter']['userLimits'].get(userId) : undefined;
          if (limit) {
            const headers = this.userLimiter.getRateLimitHeaders(userResult, limit);
            Object.entries(headers).forEach(([key, value]) => {
              res.setHeader(key, value);
            });
          }
        }

        // Record request after successful check
        if (!this.options.skipSuccessfulRequests) {
          this.recordRequest(req, res, next);
        } else {
          next();
        }
      } catch (error) {
        console.error('[RateLimitMiddleware] Error:', error);
        next(error);
      }
    };
  }

  /**
   * Handle rate limit exceeded
   * Returns 429 status with retry information
   */
  private handleRateLimitExceeded(
    req: RequestWithUser,
    res: Response,
    result: any,
    limitType: 'user' | 'ip'
  ): void {
    const userId = req.user?.userId || 'anonymous';
    const ip = this.getClientIp(req);

    // Log violation
    this.logViolation(userId, ip, limitType);

    // Set retry-after header
    if (result.retryAfter) {
      res.setHeader('Retry-After', result.retryAfter.toString());
    }

    // Set rate limit headers
    res.setHeader('X-RateLimit-Limit', '0');
    res.setHeader('X-RateLimit-Remaining', '0');
    res.setHeader('X-RateLimit-Reset', Math.floor(result.resetAt.getTime() / 1000).toString());

    // Return 429 response
    res.status(429).json({
      error: 'Too Many Requests',
      message: 'Rate limit exceeded. Please try again later.',
      retryAfter: result.retryAfter || 60,
      resetAt: result.resetAt.toISOString(),
      limitType,
    });
  }

  /**
   * Record request after response is sent
   */
  private recordRequest(req: RequestWithUser, res: Response, next: NextFunction): void {
    const ip = this.getClientIp(req);
    const userId = req.user?.userId;

    // Record after response is sent
    res.on('finish', () => {
      const shouldSkip = 
        (this.options.skipSuccessfulRequests && res.statusCode < 400) ||
        (this.options.skipFailedRequests && res.statusCode >= 400);

      if (!shouldSkip) {
        if (this.options.enableIpLimits) {
          this.ipLimiter.recordIpRequest(ip, userId);
        }

        if (this.options.enableUserLimits && userId) {
          this.userLimiter.recordUserRequest(userId, ip);
        }
      }
    });

    next();
  }

  /**
   * Get client IP address from request
   */
  private getClientIp(req: Request): string {
    // Check X-Forwarded-For header (for proxies/load balancers)
    const forwarded = req.headers['x-forwarded-for'];
    if (forwarded) {
      const ips = Array.isArray(forwarded) ? forwarded[0] : forwarded;
      return ips.split(',')[0].trim();
    }

    // Check X-Real-IP header
    const realIp = req.headers['x-real-ip'];
    if (realIp) {
      return Array.isArray(realIp) ? realIp[0] : realIp;
    }

    // Fallback to socket address
    return req.socket.remoteAddress || 'unknown';
  }

  /**
   * Default key generator for rate limiting
   */
  private defaultKeyGenerator(req: RequestWithUser): string {
    return req.user?.userId || this.getClientIp(req);
  }

  /**
   * Default handler for rate limit exceeded
   */
  private defaultHandler(req: Request, res: Response): void {
    res.status(429).json({
      error: 'Too Many Requests',
      message: 'Rate limit exceeded. Please try again later.',
    });
  }

  /**
   * Log rate limit violation
   */
  private logViolation(userId: string, ip: string, limitType: 'user' | 'ip'): void {
    const violation = {
      timestamp: new Date().toISOString(),
      userId,
      ip,
      limitType,
    };

    console.log('[RateLimitViolation]', JSON.stringify(violation));
  }

  /**
   * Get rate limiter statistics
   */
  getStats(): {
    user: any;
    ip: any;
  } {
    return {
      user: this.userLimiter.getStats(),
      ip: this.ipLimiter.getStats(),
    };
  }

  /**
   * Block an IP address
   */
  blockIp(ip: string, reason?: string): void {
    this.ipLimiter.blockIp(ip, reason);
  }

  /**
   * Unblock an IP address
   */
  unblockIp(ip: string): void {
    this.ipLimiter.unblockIp(ip);
  }

  /**
   * Get blocked IPs
   */
  getBlockedIps(): string[] {
    return this.ipLimiter.getBlockedIps();
  }

  /**
   * Set custom user tier
   */
  setUserTier(userId: string, tier: UserTier): void {
    this.userLimiter.setUserTier(userId, tier);
  }

  /**
   * Check for DDoS attack
   */
  async checkDDoS(): Promise<boolean> {
    const detection = this.ipLimiter.detectDDoS();
    
    if (detection.isDDoS) {
      await this.ipLimiter.activateDDoSProtection();
      return true;
    }
    
    return false;
  }

  /**
   * Clean up old data periodically
   */
  startCleanupTask(interval: number = 3600000): NodeJS.Timeout {
    return setInterval(() => {
      this.userLimiter.cleanup();
      this.ipLimiter.cleanup();
    }, interval);
  }
}

/**
 * Create rate limit middleware with default options
 */
export function createRateLimitMiddleware(options?: RateLimitMiddlewareOptions): RateLimitMiddleware {
  return new RateLimitMiddleware(options);
}

/**
 * Express middleware factory
 */
export function rateLimitMiddleware(options?: RateLimitMiddlewareOptions) {
  const middleware = new RateLimitMiddleware(options);
  return middleware.middleware();
}
