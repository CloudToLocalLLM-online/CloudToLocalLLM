/**
 * @fileoverview Rate limit metrics collection service
 * Collects and exposes Prometheus metrics for rate limiting
 */

import { Counter, Gauge, Histogram } from 'prom-client';
import { TunnelLogger } from '../utils/logger.js';

/**
 * Rate limit metrics service
 */
export class RateLimitMetricsService {
  constructor() {
    this.logger = new TunnelLogger('rate-limit-metrics');

    // Initialize Prometheus metrics
    this.initializeMetrics();

    this.logger.info('Rate limit metrics service initialized');
  }

  /**
   * Initialize Prometheus metrics
   */
  initializeMetrics() {
    // Rate limit violations counter
    this.rateLimitViolations = new Counter({
      name: 'rate_limit_violations_total',
      help: 'Total number of rate limit violations',
      labelNames: ['violation_type', 'user_tier'],
      registers: [],
    });

    // Rate limit violations by type
    this.rateLimitViolationsByType = new Counter({
      name: 'rate_limit_violations_by_type_total',
      help: 'Rate limit violations by type',
      labelNames: ['violation_type'],
      registers: [],
    });

    // Active rate limited users
    this.activeRateLimitedUsers = new Gauge({
      name: 'rate_limited_users_active',
      help: 'Number of currently rate limited users',
      registers: [],
    });

    // Rate limit exemptions
    this.rateLimitExemptions = new Counter({
      name: 'rate_limit_exemptions_total',
      help: 'Total number of rate limit exemptions granted',
      labelNames: ['exemption_type'],
      registers: [],
    });

    // Requests allowed by rate limiter
    this.requestsAllowed = new Counter({
      name: 'rate_limit_requests_allowed_total',
      help: 'Total requests allowed by rate limiter',
      labelNames: ['user_tier'],
      registers: [],
    });

    // Requests blocked by rate limiter
    this.requestsBlocked = new Counter({
      name: 'rate_limit_requests_blocked_total',
      help: 'Total requests blocked by rate limiter',
      labelNames: ['violation_type', 'user_tier'],
      registers: [],
    });

    // Rate limit window usage
    this.rateLimitWindowUsage = new Gauge({
      name: 'rate_limit_window_usage_percent',
      help: 'Current rate limit window usage percentage',
      labelNames: ['user_id'],
      registers: [],
    });

    // Rate limit burst usage
    this.rateLimitBurstUsage = new Gauge({
      name: 'rate_limit_burst_usage_percent',
      help: 'Current rate limit burst usage percentage',
      labelNames: ['user_id'],
      registers: [],
    });

    // Concurrent requests per user
    this.concurrentRequests = new Gauge({
      name: 'rate_limit_concurrent_requests',
      help: 'Current concurrent requests per user',
      labelNames: ['user_id'],
      registers: [],
    });

    // Rate limit check duration
    this.rateLimitCheckDuration = new Histogram({
      name: 'rate_limit_check_duration_seconds',
      help: 'Duration of rate limit checks',
      buckets: [0.001, 0.005, 0.01, 0.05, 0.1],
      registers: [],
    });

    // Top violators tracking
    this.topViolators = new Map();
    this.topViolatorsByIp = new Map();

    this.logger.debug('Prometheus metrics initialized');
  }

  /**
   * Record a rate limit violation
   * @param {Object} violation - Violation details
   */
  recordViolation(violation) {
    const { violationType, userTier = 'unknown' } = violation;

    try {
      // Increment violation counters
      this.rateLimitViolations.inc({
        violation_type: violationType,
        user_tier: userTier,
      });

      this.rateLimitViolationsByType.inc({
        violation_type: violationType,
      });

      // Track top violators
      if (violation.userId) {
        const count = (this.topViolators.get(violation.userId) || 0) + 1;
        this.topViolators.set(violation.userId, count);
      }

      if (violation.ipAddress) {
        const count = (this.topViolatorsByIp.get(violation.ipAddress) || 0) + 1;
        this.topViolatorsByIp.set(violation.ipAddress, count);
      }

      this.logger.debug('Rate limit violation recorded', {
        violationType,
        userTier,
        userId: violation.userId,
      });
    } catch (error) {
      this.logger.error('Failed to record rate limit violation', {
        error: error.message,
        violationType,
      });
    }
  }

  /**
   * Record a rate limit exemption
   * @param {Object} exemption - Exemption details
   */
  recordExemption(exemption) {
    const { exemptionType = 'unknown' } = exemption;

    try {
      this.rateLimitExemptions.inc({
        exemption_type: exemptionType,
      });

      this.logger.debug('Rate limit exemption recorded', {
        exemptionType,
        userId: exemption.userId,
      });
    } catch (error) {
      this.logger.error('Failed to record rate limit exemption', {
        error: error.message,
        exemptionType,
      });
    }
  }

  /**
   * Record a request allowed by rate limiter
   * @param {Object} request - Request details
   */
  recordRequestAllowed(request) {
    const { userTier = 'unknown' } = request;

    try {
      this.requestsAllowed.inc({
        user_tier: userTier,
      });

      this.logger.debug('Request allowed by rate limiter', {
        userTier,
        userId: request.userId,
      });
    } catch (error) {
      this.logger.error('Failed to record allowed request', {
        error: error.message,
      });
    }
  }

  /**
   * Record a request blocked by rate limiter
   * @param {Object} request - Request details
   */
  recordRequestBlocked(request) {
    const { violationType = 'unknown', userTier = 'unknown' } = request;

    try {
      this.requestsBlocked.inc({
        violation_type: violationType,
        user_tier: userTier,
      });

      this.logger.debug('Request blocked by rate limiter', {
        violationType,
        userTier,
        userId: request.userId,
      });
    } catch (error) {
      this.logger.error('Failed to record blocked request', {
        error: error.message,
      });
    }
  }

  /**
   * Update rate limit window usage
   * @param {string} userId - User ID
   * @param {number} current - Current requests in window
   * @param {number} max - Max requests in window
   */
  updateWindowUsage(userId, current, max) {
    try {
      const percentage = max > 0 ? (current / max) * 100 : 0;
      this.rateLimitWindowUsage.set({ user_id: userId }, percentage);
    } catch (error) {
      this.logger.error('Failed to update window usage', {
        error: error.message,
        userId,
      });
    }
  }

  /**
   * Update rate limit burst usage
   * @param {string} userId - User ID
   * @param {number} current - Current requests in burst window
   * @param {number} max - Max requests in burst window
   */
  updateBurstUsage(userId, current, max) {
    try {
      const percentage = max > 0 ? (current / max) * 100 : 0;
      this.rateLimitBurstUsage.set({ user_id: userId }, percentage);
    } catch (error) {
      this.logger.error('Failed to update burst usage', {
        error: error.message,
        userId,
      });
    }
  }

  /**
   * Update concurrent requests
   * @param {string} userId - User ID
   * @param {number} count - Current concurrent requests
   */
  updateConcurrentRequests(userId, count) {
    try {
      this.concurrentRequests.set({ user_id: userId }, count);
    } catch (error) {
      this.logger.error('Failed to update concurrent requests', {
        error: error.message,
        userId,
      });
    }
  }

  /**
   * Record rate limit check duration
   * @param {number} duration - Duration in seconds
   */
  recordCheckDuration(duration) {
    try {
      this.rateLimitCheckDuration.observe(duration);
    } catch (error) {
      this.logger.error('Failed to record check duration', {
        error: error.message,
      });
    }
  }

  /**
   * Update active rate limited users count
   * @param {number} count - Number of active rate limited users
   */
  updateActiveRateLimitedUsers(count) {
    try {
      this.activeRateLimitedUsers.set(count);
    } catch (error) {
      this.logger.error('Failed to update active rate limited users', {
        error: error.message,
      });
    }
  }

  /**
   * Get top violators
   * @param {number} limit - Number of top violators to return
   * @returns {Array} Top violators
   */
  getTopViolators(limit = 10) {
    const sorted = Array.from(this.topViolators.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([userId, count]) => ({
        userId,
        violationCount: count,
      }));

    return sorted;
  }

  /**
   * Get top violating IPs
   * @param {number} limit - Number of top IPs to return
   * @returns {Array} Top violating IPs
   */
  getTopViolatingIps(limit = 10) {
    const sorted = Array.from(this.topViolatorsByIp.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([ipAddress, count]) => ({
        ipAddress,
        violationCount: count,
      }));

    return sorted;
  }

  /**
   * Get metrics summary
   * @returns {Object} Metrics summary
   */
  getMetricsSummary() {
    return {
      timestamp: new Date().toISOString(),
      topViolators: this.getTopViolators(10),
      topViolatingIps: this.getTopViolatingIps(10),
      totalViolators: this.topViolators.size,
      totalViolatingIps: this.topViolatorsByIp.size,
    };
  }

  /**
   * Reset metrics (for testing)
   */
  reset() {
    this.topViolators.clear();
    this.topViolatorsByIp.clear();
    this.logger.info('Rate limit metrics reset');
  }
}

// Export singleton instance
export const rateLimitMetricsService = new RateLimitMetricsService();

export default RateLimitMetricsService;
