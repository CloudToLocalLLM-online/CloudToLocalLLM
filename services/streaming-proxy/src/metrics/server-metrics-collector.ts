/**
 * Server Metrics Collector
 * 
 * Collects and exposes server-wide metrics for monitoring and observability.
 * 
 * ## Design Pattern: Metrics Aggregation
 * 
 * The metrics collector aggregates metrics from multiple sources:
 * 
 * ### Request Metrics
 * - Individual request latencies
 * - Success/failure rates
 * - Error categorization
 * - Slow request detection (> 5 seconds)
 * 
 * ### Connection Metrics
 * - Active connections per user
 * - Total connections
 * - Connection rate
 * - WebSocket connections
 * 
 * ### User Metrics
 * - Per-user request counts
 * - Per-user success rates
 * - Per-user data transfer
 * - Rate limit violations
 * 
 * ### System Metrics
 * - Memory usage
 * - CPU usage
 * - Uptime
 * - Percentile latencies (p95, p99)
 * 
 * ## Prometheus Integration
 * 
 * Metrics are exposed in Prometheus format via `/api/tunnel/metrics` endpoint.
 * Uses prom-client library for metric collection and formatting.
 * 
 * ### Metric Types
 * 
 * - **Counter**: Monotonically increasing values (requests_total, errors_total)
 * - **Gauge**: Point-in-time values (active_connections, memory_usage)
 * - **Histogram**: Distribution of values (request_latency_ms)
 * 
 * ## Data Retention
 * 
 * - Request history: Last 10,000 records
 * - Connection history: Last 10,000 records
 * - Retention window: 1 hour (configurable)
 * - Automatic cleanup of old records
 * 
 * ## Usage Example
 * 
 * ```typescript
 * const collector = new ServerMetricsCollector();
 * 
 * // Record request
 * const start = Date.now();
 * try {
 *   const response = await forwardRequest(request);
 *   const latency = Date.now() - start;
 *   collector.recordRequest(userId, latency, true);
 * } catch (error) {
 *   const latency = Date.now() - start;
 *   collector.recordRequest(userId, latency, false, 'network');
 * }
 * 
 * // Record connection
 * collector.recordConnection(userId, 'connect');
 * 
 * // Get metrics
 * const metrics = collector.getMetrics();
 * console.log(`Success rate: ${metrics.successRate}%`);
 * 
 * // Export for Prometheus
 * const prometheusText = collector.exportPrometheusFormat();
 * res.set('Content-Type', 'text/plain');
 * res.send(prometheusText);
 * ```
 * 
 * Requirements: 3.1, 3.2, 3.4, 3.6, 3.7, 3.10, 11.1, 11.6
 */

import {
  MetricsCollector,
  ServerMetrics,
  UserMetrics,
} from '../interfaces/metrics-collector';
import { CircuitBreakerMetricsCollector } from '../circuit-breaker/circuit-breaker-metrics';
import { SlowRequestDetector } from './slow-request-detector';
import { MetricsAggregator, RawMetricSnapshot, AggregatedMetric } from './metrics-aggregator';
import {
  tunnelRequestsTotal,
  tunnelRequestLatencyMs,
  tunnelActiveConnections,
  tunnelErrorsTotal,
  tunnelQueueSize,
  tunnelCircuitBreakerState,
  tunnelConnectionsTotal,
  tunnelRequestsSuccessTotal,
  tunnelRequestsFailedTotal,
  tunnelRequestSuccessRate,
  tunnelErrorRate,
  tunnelBytesReceivedTotal,
  tunnelBytesSentTotal,
  tunnelRequestsPerSecond,
  tunnelActiveUsers,
  tunnelMemoryUsageBytes,
  tunnelCpuUsageSeconds,
  tunnelUptimeSeconds,
  tunnelConnectionRatePerSecond,
  tunnelQueueFillPercentage,
  tunnelRateLimitViolationsTotal,
  tunnelSshConnectionTimeMs,
  tunnelWebsocketConnectionsTotal,
  tunnelWebsocketDisconnectionsTotal,
  tunnelWebsocketActiveConnections,
  tunnelAuthAttemptsTotal,
  tunnelSlowRequestsTotal,
  tunnelP95LatencyMs,
  tunnelP99LatencyMs,
  exportMetricsAsText,
  initializeMetrics,
} from '../monitoring/prometheus-metrics';

/**
 * Request record for tracking individual requests
 * 
 * @interface RequestRecord
 * @property userId - User identifier
 * @property timestamp - When request was recorded
 * @property latency - Request latency in milliseconds
 * @property success - Whether request succeeded
 * @property errorType - Error type if failed
 * @property bytesReceived - Bytes received from client
 * @property bytesSent - Bytes sent to client
 */
interface RequestRecord {
  /** User identifier */
  userId: string;
  
  /** When request was recorded */
  timestamp: Date;
  
  /** Request latency in milliseconds */
  latency: number;
  
  /** Whether request succeeded */
  success: boolean;
  
  /** Error type if failed (e.g., 'network', 'timeout') */
  errorType?: string;
  
  /** Bytes received from client */
  bytesReceived?: number;
  
  /** Bytes sent to client */
  bytesSent?: number;
}

/**
 * Connection record for tracking connection events
 * 
 * @interface ConnectionRecord
 * @property userId - User identifier
 * @property timestamp - When event occurred
 * @property event - Connection event type
 */
interface ConnectionRecord {
  /** User identifier */
  userId: string;
  
  /** When event occurred */
  timestamp: Date;
  
  /** Connection event type */
  event: 'connect' | 'disconnect';
}

/**
 * User metrics tracking data
 * 
 * @interface UserMetricsData
 * @property userId - User identifier
 * @property connectionCount - Number of connections
 * @property requestCount - Total requests
 * @property successCount - Successful requests
 * @property totalLatency - Sum of all latencies
 * @property bytesReceived - Total bytes received
 * @property bytesSent - Total bytes sent
 * @property rateLimitViolations - Rate limit violations
 * @property lastActivity - Last activity timestamp
 * @property errors - Error counts by type
 */
interface UserMetricsData {
  /** User identifier */
  userId: string;
  
  /** Number of active connections */
  connectionCount: number;
  
  /** Total requests from this user */
  requestCount: number;
  
  /** Successful requests */
  successCount: number;
  
  /** Sum of all request latencies */
  totalLatency: number;
  
  /** Total bytes received from user */
  bytesReceived: number;
  
  /** Total bytes sent to user */
  bytesSent: number;
  
  /** Rate limit violations */
  rateLimitViolations: number;
  
  /** Last activity timestamp */
  lastActivity: Date;
  
  /** Error counts by type */
  errors: Record<string, number>;
}

/**
 * Server-side metrics collector implementation
 * 
 * Collects and aggregates metrics from all tunnel operations.
 */
export class ServerMetricsCollector implements MetricsCollector {
  /** History of request records (FIFO queue) */
  private requestHistory: RequestRecord[] = [];
  
  /** History of connection events (FIFO queue) */
  private connectionHistory: ConnectionRecord[] = [];
  
  /** Per-user metrics tracking */
  private userMetricsMap: Map<string, UserMetricsData> = new Map();
  
  /** Set of currently active user connections */
  private activeConnections: Set<string> = new Set();
  
  /** Total connections since server start */
  private totalConnections: number = 0;
  
  /** Server start time for uptime calculation */
  private startTime: Date = new Date();
  
  // Configuration
  private readonly maxHistorySize: number;
  private readonly retentionWindow: number; // milliseconds
  
  // Optional circuit breaker metrics integration
  private circuitBreakerMetrics?: CircuitBreakerMetricsCollector;
  
  // Slow request detector
  private slowRequestDetector: SlowRequestDetector;
  
  // Metrics aggregator for time-series data
  private metricsAggregator: MetricsAggregator;

  constructor(
    maxHistorySize: number = 10000,
    retentionWindow: number = 3600000, // 1 hour default
    circuitBreakerMetrics?: CircuitBreakerMetricsCollector
  ) {
    this.maxHistorySize = maxHistorySize;
    this.retentionWindow = retentionWindow;
    this.circuitBreakerMetrics = circuitBreakerMetrics;
    this.slowRequestDetector = new SlowRequestDetector();
    this.metricsAggregator = new MetricsAggregator(maxHistorySize);
    
    // Initialize Prometheus metrics
    initializeMetrics();
    
    // Start cleanup task
    this.startCleanupTask();
    
    // Start metric snapshot task (record metrics every minute)
    this.startMetricSnapshotTask();
  }

  /**
   * Record a request
   */
  recordRequest(
    userId: string,
    latency: number,
    success: boolean,
    errorType?: string,
    bytesReceived?: number,
    bytesSent?: number,
    requestId?: string,
    endpoint?: string
  ): void {
    const record: RequestRecord = {
      userId,
      timestamp: new Date(),
      latency,
      success,
      errorType,
      bytesReceived,
      bytesSent,
    };

    this.requestHistory.push(record);

    // Trim history if needed
    if (this.requestHistory.length > this.maxHistorySize) {
      this.requestHistory.shift();
    }

    // Update user metrics
    this.updateUserMetrics(userId, record);
    
    // Track slow requests
    if (requestId) {
      this.slowRequestDetector.trackRequest(userId, requestId, latency, endpoint);
    }

    // Update Prometheus metrics
    this.updatePrometheusMetrics(userId, latency, success, errorType, bytesReceived, bytesSent, endpoint);
  }

  /**
   * Record connection event
   */
  recordConnection(userId: string, event: 'connect' | 'disconnect'): void {
    const record: ConnectionRecord = {
      userId,
      timestamp: new Date(),
      event,
    };

    this.connectionHistory.push(record);

    // Trim history if needed
    if (this.connectionHistory.length > this.maxHistorySize) {
      this.connectionHistory.shift();
    }

    // Update active connections
    if (event === 'connect') {
      this.activeConnections.add(userId);
      this.totalConnections++;
      
      // Update Prometheus metrics
      tunnelConnectionsTotal.inc();
      tunnelWebsocketConnectionsTotal.inc();
      tunnelWebsocketActiveConnections.inc();
      tunnelActiveConnections.labels('free').inc(); // Default to free tier
    } else {
      this.activeConnections.delete(userId);
      
      // Update Prometheus metrics
      tunnelWebsocketDisconnectionsTotal.labels('normal').inc();
      tunnelWebsocketActiveConnections.dec();
      tunnelActiveConnections.labels('free').dec(); // Default to free tier
    }

    // Update user metrics
    const userMetrics = this.getUserMetricsData(userId);
    if (event === 'connect') {
      userMetrics.connectionCount++;
    }
    userMetrics.lastActivity = new Date();
  }

  /**
   * Record rate limit violation
   */
  recordRateLimitViolation(userId: string): void {
    const userMetrics = this.getUserMetricsData(userId);
    userMetrics.rateLimitViolations++;
    userMetrics.lastActivity = new Date();

    // Update Prometheus metrics
    tunnelRateLimitViolationsTotal.labels('free').inc(); // Default to free tier
  }

  /**
   * Update Prometheus metrics based on request
   */
  private updatePrometheusMetrics(
    userId: string,
    latency: number,
    success: boolean,
    errorType?: string,
    bytesReceived?: number,
    bytesSent?: number,
    endpoint?: string
  ): void {
    // Update request counters
    if (success) {
      tunnelRequestsTotal.labels('success', '').inc();
      tunnelRequestsSuccessTotal.inc();
    } else {
      tunnelRequestsTotal.labels('error', errorType || 'unknown').inc();
      tunnelRequestsFailedTotal.inc();
      
      // Update error counters by category
      if (errorType) {
        tunnelErrorsTotal.labels(this.categorizeError(errorType), errorType).inc();
      }
    }

    // Update latency histogram
    tunnelRequestLatencyMs.labels(endpoint || 'unknown', 'POST').observe(latency);

    // Update throughput metrics
    if (bytesReceived) {
      tunnelBytesReceivedTotal.inc(bytesReceived);
    }
    if (bytesSent) {
      tunnelBytesSentTotal.inc(bytesSent);
    }

    // Track slow requests
    if (latency > 5000) {
      tunnelSlowRequestsTotal.inc();
    }
  }

  /**
   * Categorize error type into error category
   */
  private categorizeError(errorType: string): string {
    if (errorType.includes('network') || errorType.includes('timeout') || errorType.includes('refused')) {
      return 'network';
    }
    if (errorType.includes('auth') || errorType.includes('token') || errorType.includes('unauthorized')) {
      return 'auth';
    }
    if (errorType.includes('server') || errorType.includes('500') || errorType.includes('unavailable')) {
      return 'server';
    }
    if (errorType.includes('protocol') || errorType.includes('websocket') || errorType.includes('ssh')) {
      return 'protocol';
    }
    return 'unknown';
  }

  /**
   * Get server-wide metrics
   */
  getServerMetrics(window?: number): ServerMetrics {
    const now = Date.now();
    const windowMs = window || this.retentionWindow;
    const cutoff = now - windowMs;

    // Filter to window
    const recentRequests = this.requestHistory.filter(
      r => r.timestamp.getTime() > cutoff
    );
    const recentConnections = this.connectionHistory.filter(
      c => c.timestamp.getTime() > cutoff
    );

    // Calculate request metrics
    const requestCount = recentRequests.length;
    const successCount = recentRequests.filter(r => r.success).length;
    const errorCount = requestCount - successCount;
    const successRate = requestCount > 0 ? successCount / requestCount : 0;

    // Calculate latency metrics
    const latencies = recentRequests.map(r => r.latency).sort((a, b) => a - b);
    const averageLatency = this.calculateAverage(latencies);
    const p50Latency = this.calculatePercentile(latencies, 0.5);
    const p95Latency = this.calculatePercentile(latencies, 0.95);
    const p99Latency = this.calculatePercentile(latencies, 0.99);

    // Calculate throughput metrics
    const bytesReceived = recentRequests.reduce(
      (sum, r) => sum + (r.bytesReceived || 0),
      0
    );
    const bytesSent = recentRequests.reduce(
      (sum, r) => sum + (r.bytesSent || 0),
      0
    );
    const requestsPerSecond = requestCount / (windowMs / 1000);

    // Calculate error metrics
    const errorsByCategory: Record<string, number> = {};
    for (const request of recentRequests) {
      if (request.errorType) {
        errorsByCategory[request.errorType] =
          (errorsByCategory[request.errorType] || 0) + 1;
      }
    }
    const errorRate = requestCount > 0 ? errorCount / requestCount : 0;

    // Calculate connection metrics
    const connectionRate = recentConnections.length / (windowMs / 1000);

    // Calculate user metrics
    const activeUsers = this.activeConnections.size;
    const requestsByUser: Record<string, number> = {};
    for (const request of recentRequests) {
      requestsByUser[request.userId] =
        (requestsByUser[request.userId] || 0) + 1;
    }

    // System metrics (basic)
    const memoryUsage = process.memoryUsage().heapUsed;
    const cpuUsage = process.cpuUsage().user / 1000000; // Convert to seconds
    const uptime = Date.now() - this.startTime.getTime();

    return {
      activeConnections: this.activeConnections.size,
      totalConnections: this.totalConnections,
      connectionRate,
      requestCount,
      successCount,
      errorCount,
      successRate,
      averageLatency,
      p50Latency,
      p95Latency,
      p99Latency,
      bytesReceived,
      bytesSent,
      requestsPerSecond,
      errorsByCategory,
      errorRate,
      activeUsers,
      requestsByUser,
      memoryUsage,
      cpuUsage,
      uptime,
      timestamp: new Date(),
      window: windowMs,
    };
  }

  /**
   * Get user-specific metrics
   */
  getUserMetrics(userId: string): UserMetrics {
    const data = this.userMetricsMap.get(userId);
    
    if (!data) {
      return {
        userId,
        connectionCount: 0,
        requestCount: 0,
        successRate: 0,
        averageLatency: 0,
        dataTransferred: 0,
        rateLimitViolations: 0,
        lastActivity: new Date(),
      };
    }

    const successRate = data.requestCount > 0
      ? data.successCount / data.requestCount
      : 0;
    const averageLatency = data.requestCount > 0
      ? data.totalLatency / data.requestCount
      : 0;
    const dataTransferred = data.bytesReceived + data.bytesSent;

    return {
      userId,
      connectionCount: data.connectionCount,
      requestCount: data.requestCount,
      successRate,
      averageLatency,
      dataTransferred,
      rateLimitViolations: data.rateLimitViolations,
      lastActivity: data.lastActivity,
    };
  }

  /**
   * Export metrics in Prometheus format
   * Uses prom-client to export all registered metrics
   */
  exportPrometheusFormat(): Promise<string> {
    return (async () => {
      const metrics = this.getServerMetrics();
      
      // Update gauge metrics with current values
      tunnelRequestSuccessRate.set(metrics.successRate);
      tunnelErrorRate.set(metrics.errorRate);
      tunnelRequestsPerSecond.set(metrics.requestsPerSecond);
      tunnelActiveUsers.set(metrics.activeUsers);
      tunnelMemoryUsageBytes.set(metrics.memoryUsage);
      tunnelCpuUsageSeconds.inc(metrics.cpuUsage);
      tunnelUptimeSeconds.inc(metrics.uptime / 1000);
      tunnelConnectionRatePerSecond.set(metrics.connectionRate);
      tunnelP95LatencyMs.set(metrics.p95Latency);
      tunnelP99LatencyMs.set(metrics.p99Latency);

      // Export all metrics from prom-client registry
      return await exportMetricsAsText();
    })();
  }

  /**
   * Export metrics in JSON format
   */
  exportJson(): Record<string, any> {
    const serverMetrics = this.getServerMetrics();
    const userMetrics: Record<string, UserMetrics> = {};
    
    for (const userId of this.userMetricsMap.keys()) {
      userMetrics[userId] = this.getUserMetrics(userId);
    }

    const result: Record<string, any> = {
      timestamp: new Date().toISOString(),
      server: serverMetrics,
      users: userMetrics,
    };

    // Add circuit breaker metrics if available
    if (this.circuitBreakerMetrics) {
      result.circuitBreakers = this.circuitBreakerMetrics.exportJsonMetrics();
    }

    return result;
  }

  /**
   * Get or create user metrics data
   */
  private getUserMetricsData(userId: string): UserMetricsData {
    let data = this.userMetricsMap.get(userId);
    
    if (!data) {
      data = {
        userId,
        connectionCount: 0,
        requestCount: 0,
        successCount: 0,
        totalLatency: 0,
        bytesReceived: 0,
        bytesSent: 0,
        rateLimitViolations: 0,
        lastActivity: new Date(),
        errors: {},
      };
      this.userMetricsMap.set(userId, data);
    }
    
    return data;
  }

  /**
   * Update user metrics with request data
   */
  private updateUserMetrics(userId: string, record: RequestRecord): void {
    const data = this.getUserMetricsData(userId);
    
    data.requestCount++;
    if (record.success) {
      data.successCount++;
    }
    data.totalLatency += record.latency;
    data.bytesReceived += record.bytesReceived || 0;
    data.bytesSent += record.bytesSent || 0;
    data.lastActivity = record.timestamp;
    
    if (record.errorType) {
      data.errors[record.errorType] = (data.errors[record.errorType] || 0) + 1;
    }
  }

  /**
   * Calculate average of numbers
   */
  private calculateAverage(values: number[]): number {
    if (values.length === 0) return 0;
    const sum = values.reduce((acc, val) => acc + val, 0);
    return sum / values.length;
  }

  /**
   * Calculate percentile
   */
  private calculatePercentile(sorted: number[], percentile: number): number {
    if (sorted.length === 0) return 0;
    const index = Math.ceil(sorted.length * percentile) - 1;
    return sorted[Math.max(0, Math.min(index, sorted.length - 1))];
  }

  /**
   * Start metric snapshot task (records metrics every minute)
   */
  private startMetricSnapshotTask(): void {
    setInterval(() => {
      const metrics = this.getServerMetrics(60000); // Last minute
      
      const snapshot: RawMetricSnapshot = {
        timestamp: new Date(),
        activeConnections: metrics.activeConnections,
        requestCount: metrics.requestCount,
        successCount: metrics.successCount,
        errorCount: metrics.errorCount,
        averageLatency: metrics.averageLatency,
        p95Latency: metrics.p95Latency,
        p99Latency: metrics.p99Latency,
        bytesReceived: metrics.bytesReceived,
        bytesSent: metrics.bytesSent,
        requestsPerSecond: metrics.requestsPerSecond,
        errorRate: metrics.errorRate,
        activeUsers: metrics.activeUsers,
        memoryUsage: metrics.memoryUsage,
        cpuUsage: metrics.cpuUsage,
      };
      
      this.metricsAggregator.recordMetric(snapshot);
    }, 60000); // Every minute
  }

  /**
   * Get historical metrics for a time window
   */
  getHistoricalMetrics(
    windowMs: number = 3600000,
    aggregationLevel: 'raw' | 'hourly' | 'daily' = 'raw'
  ): (RawMetricSnapshot | AggregatedMetric)[] {
    return this.metricsAggregator.getMetrics(windowMs, aggregationLevel);
  }

  /**
   * Get historical statistics
   */
  getHistoricalStatistics(
    windowMs: number = 3600000,
    aggregationLevel: 'raw' | 'hourly' | 'daily' = 'raw'
  ): Record<string, any> {
    return this.metricsAggregator.getStatistics(windowMs, aggregationLevel);
  }

  /**
   * Start cleanup task to remove old data
   */
  private startCleanupTask(): void {
    setInterval(() => {
      this.cleanup();
    }, 3600000); // Run every hour
  }

  /**
   * Clean up old data beyond retention window
   */
  private cleanup(): void {
    const now = Date.now();
    const cutoff = now - this.retentionWindow;

    // Clean request history
    this.requestHistory = this.requestHistory.filter(
      r => r.timestamp.getTime() > cutoff
    );

    // Clean connection history
    this.connectionHistory = this.connectionHistory.filter(
      c => c.timestamp.getTime() > cutoff
    );

    // Clean inactive user metrics (no activity for 24 hours)
    const inactivityThreshold = now - 86400000; // 24 hours
    for (const [userId, data] of this.userMetricsMap.entries()) {
      if (data.lastActivity.getTime() < inactivityThreshold) {
        this.userMetricsMap.delete(userId);
      }
    }
  }

  /**
   * Reset all metrics
   */
  reset(): void {
    this.requestHistory = [];
    this.connectionHistory = [];
    this.userMetricsMap.clear();
    this.activeConnections.clear();
    this.totalConnections = 0;
    this.startTime = new Date();
  }
}

