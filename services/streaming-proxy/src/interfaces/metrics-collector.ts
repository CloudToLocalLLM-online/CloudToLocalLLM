/**
 * Metrics Collector Interface
 * Collects and exposes server-side metrics
 */

export interface ServerMetrics {
  // Connection Metrics
  activeConnections: number;
  totalConnections: number;
  connectionRate: number;

  // Request Metrics
  requestCount: number;
  successCount: number;
  errorCount: number;
  successRate: number;

  // Performance Metrics
  averageLatency: number;
  p50Latency: number;
  p95Latency: number;
  p99Latency: number;

  // Throughput Metrics
  bytesReceived: number;
  bytesSent: number;
  requestsPerSecond: number;

  // Error Metrics
  errorsByCategory: Record<string, number>;
  errorRate: number;

  // User Metrics
  activeUsers: number;
  requestsByUser: Record<string, number>;

  // System Metrics
  memoryUsage: number;
  cpuUsage: number;
  uptime: number;

  // Timestamp
  timestamp: Date;
  window: number;
}

export interface UserMetrics {
  userId: string;
  connectionCount: number;
  requestCount: number;
  successRate: number;
  averageLatency: number;
  dataTransferred: number;
  rateLimitViolations: number;
  lastActivity: Date;
}

export interface MetricsCollector {
  /**
   * Record a request
   */
  recordRequest(userId: string, latency: number, success: boolean, errorType?: string): void;

  /**
   * Record connection event
   */
  recordConnection(userId: string, event: 'connect' | 'disconnect'): void;

  /**
   * Get server-wide metrics
   */
  getServerMetrics(): ServerMetrics;

  /**
   * Get user-specific metrics
   */
  getUserMetrics(userId: string): UserMetrics;

  /**
   * Export metrics in Prometheus format
   * Can be async to support prom-client registry export
   */
  exportPrometheusFormat(): string | Promise<string>;

  /**
   * Export metrics in JSON format
   */
  exportJson(): Record<string, any>;
}
