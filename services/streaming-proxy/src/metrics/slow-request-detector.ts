/**
 * Slow Request Detector
 * 
 * Detects and logs slow requests, and alerts when slow request rate is high.
 * Integrates with metrics collector and logger.
 * 
 * Requirements: 3.8
 */

import { ConsoleLogger } from '../utils/logger';

/**
 * Slow request record
 */
interface SlowRequestRecord {
  userId: string;
  requestId: string;
  duration: number;
  endpoint?: string;
  timestamp: Date;
}

/**
 * Slow request detector configuration
 */
export interface SlowRequestDetectorConfig {
  slowThresholdMs: number; // Threshold for slow requests (default: 5000ms)
  alertThresholdRate: number; // Alert when slow request rate exceeds this (default: 0.1 = 10%)
  windowMs: number; // Time window for calculating rate (default: 300000 = 5 minutes)
  maxHistorySize: number; // Maximum number of slow requests to keep (default: 1000)
}

/**
 * Slow request detector
 */
export class SlowRequestDetector {
  private slowRequests: SlowRequestRecord[] = [];
  private totalRequests: number = 0;
  private logger: ConsoleLogger;
  private config: SlowRequestDetectorConfig;
  private lastAlertTime: Date | null = null;
  private alertCooldownMs: number = 60000; // 1 minute cooldown between alerts

  constructor(
    config?: Partial<SlowRequestDetectorConfig>,
    logger?: ConsoleLogger
  ) {
    this.config = {
      slowThresholdMs: config?.slowThresholdMs || 5000,
      alertThresholdRate: config?.alertThresholdRate || 0.1,
      windowMs: config?.windowMs || 300000,
      maxHistorySize: config?.maxHistorySize || 1000,
    };
    this.logger = logger || new ConsoleLogger('SlowRequestDetector');
  }

  /**
   * Track a request
   * 
   * @param userId - User ID
   * @param requestId - Request ID
   * @param duration - Request duration in milliseconds
   * @param endpoint - Optional endpoint name
   */
  trackRequest(
    userId: string,
    requestId: string,
    duration: number,
    endpoint?: string
  ): void {
    this.totalRequests++;

    // Check if request is slow
    if (duration >= this.config.slowThresholdMs) {
      const record: SlowRequestRecord = {
        userId,
        requestId,
        duration,
        endpoint,
        timestamp: new Date(),
      };

      this.slowRequests.push(record);

      // Trim history if needed
      if (this.slowRequests.length > this.config.maxHistorySize) {
        this.slowRequests.shift();
      }

      // Log slow request
      this.logger.warn('Slow request detected', {
        userId,
        requestId,
        duration,
        endpoint,
        threshold: this.config.slowThresholdMs,
      });

      // Check if we should alert
      this.checkAndAlert();
    }
  }

  /**
   * Get slow request rate over the configured window
   */
  getSlowRequestRate(): number {
    const now = Date.now();
    const cutoff = now - this.config.windowMs;

    // Filter to window
    const recentSlowRequests = this.slowRequests.filter(
      r => r.timestamp.getTime() > cutoff
    );

    // Calculate rate (approximate - we don't track all requests in history)
    // This is a simplified calculation
    if (this.totalRequests === 0) return 0;

    return recentSlowRequests.length / Math.max(this.totalRequests, 1);
  }

  /**
   * Get slow request count over the configured window
   */
  getSlowRequestCount(): number {
    const now = Date.now();
    const cutoff = now - this.config.windowMs;

    return this.slowRequests.filter(
      r => r.timestamp.getTime() > cutoff
    ).length;
  }

  /**
   * Get all slow requests in the window
   */
  getSlowRequests(): SlowRequestRecord[] {
    const now = Date.now();
    const cutoff = now - this.config.windowMs;

    return this.slowRequests.filter(
      r => r.timestamp.getTime() > cutoff
    );
  }

  /**
   * Get slow requests by user
   */
  getSlowRequestsByUser(userId: string): SlowRequestRecord[] {
    const now = Date.now();
    const cutoff = now - this.config.windowMs;

    return this.slowRequests.filter(
      r => r.userId === userId && r.timestamp.getTime() > cutoff
    );
  }

  /**
   * Get slow request statistics
   */
  getStatistics(): {
    totalSlowRequests: number;
    slowRequestRate: number;
    averageDuration: number;
    maxDuration: number;
    slowestRequest: SlowRequestRecord | null;
    slowRequestsByUser: Record<string, number>;
  } {
    const slowRequests = this.getSlowRequests();

    if (slowRequests.length === 0) {
      return {
        totalSlowRequests: 0,
        slowRequestRate: 0,
        averageDuration: 0,
        maxDuration: 0,
        slowestRequest: null,
        slowRequestsByUser: {},
      };
    }

    const durations = slowRequests.map(r => r.duration);
    const averageDuration = durations.reduce((sum, d) => sum + d, 0) / durations.length;
    const maxDuration = Math.max(...durations);
    const slowestRequest = slowRequests.reduce((slowest, current) =>
      current.duration > slowest.duration ? current : slowest
    );

    const slowRequestsByUser: Record<string, number> = {};
    for (const request of slowRequests) {
      slowRequestsByUser[request.userId] =
        (slowRequestsByUser[request.userId] || 0) + 1;
    }

    return {
      totalSlowRequests: slowRequests.length,
      slowRequestRate: this.getSlowRequestRate(),
      averageDuration,
      maxDuration,
      slowestRequest,
      slowRequestsByUser,
    };
  }

  /**
   * Check if we should alert and send alert if needed
   */
  private checkAndAlert(): void {
    const rate = this.getSlowRequestRate();

    // Check if rate exceeds threshold
    if (rate > this.config.alertThresholdRate) {
      // Check cooldown
      const now = Date.now();
      if (
        this.lastAlertTime &&
        now - this.lastAlertTime.getTime() < this.alertCooldownMs
      ) {
        return; // Still in cooldown
      }

      // Send alert
      const stats = this.getStatistics();
      this.logger.warn('High slow request rate detected!', {
        slowRequestRate: rate,
        threshold: this.config.alertThresholdRate,
        totalSlowRequests: stats.totalSlowRequests,
        averageDuration: stats.averageDuration,
        maxDuration: stats.maxDuration,
        windowMinutes: this.config.windowMs / 60000,
      });

      this.lastAlertTime = new Date();
    }
  }

  /**
   * Export metrics in Prometheus format
   */
  exportPrometheusMetrics(): string {
    const stats = this.getStatistics();
    const lines: string[] = [];

    // Slow requests total
    lines.push('# HELP tunnel_slow_requests_total Total number of slow requests');
    lines.push('# TYPE tunnel_slow_requests_total counter');
    lines.push(`tunnel_slow_requests_total ${stats.totalSlowRequests}`);

    // Slow request rate
    lines.push('# HELP tunnel_slow_request_rate Rate of slow requests');
    lines.push('# TYPE tunnel_slow_request_rate gauge');
    lines.push(`tunnel_slow_request_rate ${stats.slowRequestRate.toFixed(4)}`);

    // Average slow request duration
    lines.push('# HELP tunnel_slow_request_duration_avg_ms Average duration of slow requests');
    lines.push('# TYPE tunnel_slow_request_duration_avg_ms gauge');
    lines.push(`tunnel_slow_request_duration_avg_ms ${stats.averageDuration.toFixed(2)}`);

    // Max slow request duration
    lines.push('# HELP tunnel_slow_request_duration_max_ms Maximum duration of slow requests');
    lines.push('# TYPE tunnel_slow_request_duration_max_ms gauge');
    lines.push(`tunnel_slow_request_duration_max_ms ${stats.maxDuration.toFixed(2)}`);

    // Slow requests by user
    lines.push('# HELP tunnel_slow_requests_by_user_total Slow requests by user');
    lines.push('# TYPE tunnel_slow_requests_by_user_total counter');
    for (const [userId, count] of Object.entries(stats.slowRequestsByUser)) {
      lines.push(`tunnel_slow_requests_by_user_total{user_id="${userId}"} ${count}`);
    }

    return lines.join('\n');
  }

  /**
   * Reset statistics
   */
  reset(): void {
    this.slowRequests = [];
    this.totalRequests = 0;
    this.lastAlertTime = null;
  }

  /**
   * Clean up old records
   */
  cleanup(): void {
    const now = Date.now();
    const cutoff = now - this.config.windowMs;

    this.slowRequests = this.slowRequests.filter(
      r => r.timestamp.getTime() > cutoff
    );
  }
}

