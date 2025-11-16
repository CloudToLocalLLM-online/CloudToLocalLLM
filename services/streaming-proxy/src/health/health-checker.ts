/**
 * Health Checker
 * 
 * Provides comprehensive health checks for all system components.
 * Used by health check and diagnostics endpoints.
 * 
 * Requirements: 11.2, 2.7
 */

import { Logger } from '../utils/logger.js';
import { ConnectionPool } from '../interfaces/connection-pool.js';
import { CircuitBreakerMetricsCollector } from '../circuit-breaker/circuit-breaker-metrics.js';
import { ServerMetricsCollector } from '../metrics/server-metrics-collector.js';
import { RateLimiter } from '../interfaces/rate-limiter.js';

export interface ComponentHealthStatus {
  name: string;
  status: 'healthy' | 'degraded' | 'unhealthy';
  responseTime: number; // milliseconds
  details: Record<string, any>;
  lastCheck: Date;
}

export interface HealthCheckResult {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: Date;
  uptime: number;
  components: ComponentHealthStatus[];
  summary: {
    healthyComponents: number;
    degradedComponents: number;
    unhealthyComponents: number;
    totalComponents: number;
  };
}

export interface DiagnosticsResult {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: Date;
  uptime: number;
  serverInfo: {
    version: string;
    nodeVersion: string;
    platform: string;
    arch: string;
  };
  memoryUsage: {
    heapUsed: number;
    heapTotal: number;
    external: number;
    rss: number;
  };
  connectionStats: {
    activeConnections: number;
    totalConnections: number;
    connectionsByUser: Record<string, number>;
    staleConnections: number;
  };
  metricsSummary: {
    totalRequests: number;
    successfulRequests: number;
    failedRequests: number;
    successRate: number;
    averageLatency: number;
    p95Latency: number;
    p99Latency: number;
    errorsByCategory: Record<string, number>;
  };
  circuitBreakerStates: {
    totalCircuitBreakers: number;
    closedCount: number;
    openCount: number;
    halfOpenCount: number;
    circuitBreakers: Array<{
      name: string;
      state: string;
      failureCount: number;
      successCount: number;
    }>;
  };
  rateLimiterStats: {
    totalViolations: number;
    violationsInLastHour: number;
    violationsByType: Record<string, number>;
  };
  components: ComponentHealthStatus[];
}

export class HealthChecker {
  private readonly logger: Logger;
  private readonly connectionPool: ConnectionPool;
  private readonly circuitBreakerMetrics: CircuitBreakerMetricsCollector;
  private readonly metricsCollector: ServerMetricsCollector;
  private readonly rateLimiter: RateLimiter;
  private readonly startTime: Date = new Date();

  constructor(
    logger: Logger,
    connectionPool: ConnectionPool,
    circuitBreakerMetrics: CircuitBreakerMetricsCollector,
    metricsCollector: ServerMetricsCollector,
    rateLimiter: RateLimiter
  ) {
    this.logger = logger;
    this.connectionPool = connectionPool;
    this.circuitBreakerMetrics = circuitBreakerMetrics;
    this.metricsCollector = metricsCollector;
    this.rateLimiter = rateLimiter;
  }

  /**
   * Perform comprehensive health check
   * Returns overall health status and component-level details
   */
  async performHealthCheck(): Promise<HealthCheckResult> {
    this.logger.debug('Performing health check');

    const components: ComponentHealthStatus[] = [];

    // Check each component
    components.push(await this.checkWebSocketService());
    components.push(await this.checkConnectionPool());
    components.push(await this.checkCircuitBreaker());
    components.push(await this.checkMetricsCollector());
    components.push(await this.checkRateLimiter());

    // Determine overall status
    const unhealthyCount = components.filter(c => c.status === 'unhealthy').length;
    const degradedCount = components.filter(c => c.status === 'degraded').length;

    let overallStatus: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
    if (unhealthyCount > 0) {
      overallStatus = 'unhealthy';
    } else if (degradedCount > 0) {
      overallStatus = 'degraded';
    }

    const result: HealthCheckResult = {
      status: overallStatus,
      timestamp: new Date(),
      uptime: this.getUptime(),
      components,
      summary: {
        healthyComponents: components.filter(c => c.status === 'healthy').length,
        degradedComponents: degradedCount,
        unhealthyComponents: unhealthyCount,
        totalComponents: components.length,
      },
    };

    this.logger.debug(`Health check complete: ${overallStatus}`, {
      components: result.summary,
    });

    return result;
  }

  /**
   * Perform comprehensive diagnostics
   * Returns detailed information about system state and performance
   */
  async performDiagnostics(): Promise<DiagnosticsResult> {
    this.logger.debug('Performing diagnostics');

    // Get health check first
    const healthCheck = await this.performHealthCheck();

    // Get metrics
    const metrics = this.metricsCollector.getServerMetrics(3600000); // Last hour
    const connectionStats = this.connectionPool.getPoolStats();

    // Get circuit breaker info
    const circuitBreakerMetrics = this.circuitBreakerMetrics.getAllMetrics();
    const circuitBreakerSummary = this.circuitBreakerMetrics.getSummary();

    // Get rate limiter violations
    const violations = this.rateLimiter.getViolations(3600000); // Last hour
    const violationsByType: Record<string, number> = {
      user: violations.filter(v => v.userId).length,
      ip: violations.filter(v => v.ip).length,
    };

    // Determine overall status
    let overallStatus: 'healthy' | 'degraded' | 'unhealthy' = healthCheck.status;

    const result: DiagnosticsResult = {
      status: overallStatus,
      timestamp: new Date(),
      uptime: this.getUptime(),
      serverInfo: {
        version: process.env.APP_VERSION || 'unknown',
        nodeVersion: process.version,
        platform: process.platform,
        arch: process.arch,
      },
      memoryUsage: process.memoryUsage(),
      connectionStats: {
        activeConnections: connectionStats.totalConnections,
        totalConnections: connectionStats.totalConnections,
        connectionsByUser: connectionStats.connectionsByUser,
        staleConnections: 0, // Would need to track separately
      },
      metricsSummary: {
        totalRequests: metrics.requestCount,
        successfulRequests: metrics.successCount,
        failedRequests: metrics.errorCount,
        successRate: metrics.successRate,
        averageLatency: metrics.averageLatency,
        p95Latency: metrics.p95Latency,
        p99Latency: metrics.p99Latency,
        errorsByCategory: metrics.errorsByCategory || {},
      },
      circuitBreakerStates: {
        totalCircuitBreakers: circuitBreakerSummary.totalCircuitBreakers,
        closedCount: circuitBreakerSummary.closedCircuits,
        openCount: circuitBreakerSummary.openCircuits,
        halfOpenCount: circuitBreakerSummary.halfOpenCircuits,
        circuitBreakers: circuitBreakerMetrics.map(cb => ({
          name: cb.name,
          state: cb.state,
          failureCount: cb.failureCount,
          successCount: cb.successCount,
        })),
      },
      rateLimiterStats: {
        totalViolations: violations.length,
        violationsInLastHour: violations.length,
        violationsByType,
      },
      components: healthCheck.components,
    };

    this.logger.debug('Diagnostics complete', {
      status: result.status,
      components: healthCheck.summary,
    });

    return result;
  }

  /**
   * Check WebSocket service health
   */
  private async checkWebSocketService(): Promise<ComponentHealthStatus> {
    const start = Date.now();

    try {
      // WebSocket service is considered healthy if we can get metrics
      const metrics = this.metricsCollector.getServerMetrics(60000);
      const responseTime = Date.now() - start;

      const status: ComponentHealthStatus = {
        name: 'WebSocket Service',
        status: 'healthy',
        responseTime,
        details: {
          activeConnections: metrics.activeConnections,
          requestsPerSecond: metrics.requestsPerSecond,
          successRate: metrics.successRate,
        },
        lastCheck: new Date(),
      };

      return status;
    } catch (error) {
      this.logger.error('WebSocket service health check failed:', error);

      return {
        name: 'WebSocket Service',
        status: 'unhealthy',
        responseTime: Date.now() - start,
        details: {
          error: error instanceof Error ? error.message : 'Unknown error',
        },
        lastCheck: new Date(),
      };
    }
  }

  /**
   * Check connection pool health
   */
  private async checkConnectionPool(): Promise<ComponentHealthStatus> {
    const start = Date.now();

    try {
      const stats = this.connectionPool.getPoolStats();
      const responseTime = Date.now() - start;

      // Connection pool is healthy if we can get stats
      // Degraded if too many connections
      let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
      if (stats.totalConnections > 100) {
        status = 'degraded';
      }

      const result: ComponentHealthStatus = {
        name: 'Connection Pool',
        status,
        responseTime,
        details: {
          totalConnections: stats.totalConnections,
          userCount: stats.userCount,
          connectionsByUser: stats.connectionsByUser,
        },
        lastCheck: new Date(),
      };

      return result;
    } catch (error) {
      this.logger.error('Connection pool health check failed:', error);

      return {
        name: 'Connection Pool',
        status: 'unhealthy',
        responseTime: Date.now() - start,
        details: {
          error: error instanceof Error ? error.message : 'Unknown error',
        },
        lastCheck: new Date(),
      };
    }
  }

  /**
   * Check circuit breaker health
   */
  private async checkCircuitBreaker(): Promise<ComponentHealthStatus> {
    const start = Date.now();

    try {
      const summary = this.circuitBreakerMetrics.getSummary();
      const responseTime = Date.now() - start;

      // Circuit breaker is degraded if any are open
      let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
      if (summary.openCircuits > 0) {
        status = 'degraded';
      }

      const result: ComponentHealthStatus = {
        name: 'Circuit Breaker',
        status,
        responseTime,
        details: {
          closedCount: summary.closedCircuits,
          openCount: summary.openCircuits,
          halfOpenCount: summary.halfOpenCircuits,
        },
        lastCheck: new Date(),
      };

      return result;
    } catch (error) {
      this.logger.error('Circuit breaker health check failed:', error);

      return {
        name: 'Circuit Breaker',
        status: 'unhealthy',
        responseTime: Date.now() - start,
        details: {
          error: error instanceof Error ? error.message : 'Unknown error',
        },
        lastCheck: new Date(),
      };
    }
  }

  /**
   * Check metrics collector health
   */
  private async checkMetricsCollector(): Promise<ComponentHealthStatus> {
    const start = Date.now();

    try {
      const metrics = this.metricsCollector.getServerMetrics(60000);
      const responseTime = Date.now() - start;

      // Metrics collector is healthy if we can get metrics
      const status: ComponentHealthStatus = {
        name: 'Metrics Collector',
        status: 'healthy',
        responseTime,
        details: {
          metricsCollected: true,
          requestCount: metrics.requestCount,
          errorCount: metrics.errorCount,
        },
        lastCheck: new Date(),
      };

      return status;
    } catch (error) {
      this.logger.error('Metrics collector health check failed:', error);

      return {
        name: 'Metrics Collector',
        status: 'unhealthy',
        responseTime: Date.now() - start,
        details: {
          error: error instanceof Error ? error.message : 'Unknown error',
        },
        lastCheck: new Date(),
      };
    }
  }

  /**
   * Check rate limiter health
   */
  private async checkRateLimiter(): Promise<ComponentHealthStatus> {
    const start = Date.now();

    try {
      const violations = this.rateLimiter.getViolations(60000); // Last minute
      const responseTime = Date.now() - start;

      // Rate limiter is degraded if there are many violations
      let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
      if (violations.length > 100) {
        status = 'degraded';
      }

      const result: ComponentHealthStatus = {
        name: 'Rate Limiter',
        status,
        responseTime,
        details: {
          violationsInLastMinute: violations.length,
        },
        lastCheck: new Date(),
      };

      return result;
    } catch (error) {
      this.logger.error('Rate limiter health check failed:', error);

      return {
        name: 'Rate Limiter',
        status: 'unhealthy',
        responseTime: Date.now() - start,
        details: {
          error: error instanceof Error ? error.message : 'Unknown error',
        },
        lastCheck: new Date(),
      };
    }
  }

  /**
   * Get server uptime in milliseconds
   */
  private getUptime(): number {
    return Date.now() - this.startTime.getTime();
  }
}
