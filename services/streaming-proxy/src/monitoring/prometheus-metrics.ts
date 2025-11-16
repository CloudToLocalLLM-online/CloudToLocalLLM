/**
 * Prometheus Metrics Collection
 * 
 * Integrates prom-client for Prometheus metrics collection and export.
 * Defines all metrics used by the streaming proxy server.
 * 
 * Requirements: 3.1, 3.2, 3.4, 11.1
 */

import {
  Counter,
  Histogram,
  Gauge,
  Registry,
  collectDefaultMetrics,
} from 'prom-client';

/**
 * Prometheus metrics registry
 */
export const metricsRegistry = new Registry();

// Collect default Node.js metrics
collectDefaultMetrics({ register: metricsRegistry });

/**
 * Counter: Total tunnel requests
 * Labels: status (success, error), error_type (network, auth, server, etc.)
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelRequestsTotal = new Counter({
  name: 'tunnel_requests_total',
  help: 'Total number of tunnel requests processed',
  labelNames: ['status', 'error_type'],
  registers: [metricsRegistry],
});

/**
 * Histogram: Request latency in milliseconds
 * Buckets: 10, 50, 100, 200, 500, 1000 ms
 * 
 * Requirement: 3.1, 3.2, 3.4
 */
export const tunnelRequestLatencyMs = new Histogram({
  name: 'tunnel_request_latency_ms',
  help: 'Request latency in milliseconds',
  labelNames: ['endpoint', 'method'],
  buckets: [10, 50, 100, 200, 500, 1000],
  registers: [metricsRegistry],
});

/**
 * Gauge: Active tunnel connections
 * Labels: user_tier (free, premium, enterprise)
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelActiveConnections = new Gauge({
  name: 'tunnel_active_connections',
  help: 'Number of active tunnel connections',
  labelNames: ['user_tier'],
  registers: [metricsRegistry],
});

/**
 * Counter: Total tunnel errors
 * Labels: category (network, auth, server, protocol, unknown), code (TUNNEL_001, etc.)
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelErrorsTotal = new Counter({
  name: 'tunnel_errors_total',
  help: 'Total number of tunnel errors',
  labelNames: ['category', 'code'],
  registers: [metricsRegistry],
});

/**
 * Gauge: Request queue size
 * Labels: user_id (optional, can be high cardinality - use with caution)
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelQueueSize = new Gauge({
  name: 'tunnel_queue_size',
  help: 'Current size of request queue',
  labelNames: ['priority'],
  registers: [metricsRegistry],
});

/**
 * Gauge: Circuit breaker state
 * Labels: service (ssh_connection, websocket, rate_limiter, etc.)
 * Values: 0 = CLOSED (normal), 1 = OPEN (failing), 2 = HALF_OPEN (testing)
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelCircuitBreakerState = new Gauge({
  name: 'tunnel_circuit_breaker_state',
  help: 'Circuit breaker state (0=CLOSED, 1=OPEN, 2=HALF_OPEN)',
  labelNames: ['service'],
  registers: [metricsRegistry],
});

/**
 * Counter: Total connections established
 * 
 * Requirement: 3.1
 */
export const tunnelConnectionsTotal = new Counter({
  name: 'tunnel_connections_total',
  help: 'Total number of connections established',
  registers: [metricsRegistry],
});

/**
 * Counter: Total successful requests
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelRequestsSuccessTotal = new Counter({
  name: 'tunnel_requests_success_total',
  help: 'Total number of successful requests',
  registers: [metricsRegistry],
});

/**
 * Counter: Total failed requests
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelRequestsFailedTotal = new Counter({
  name: 'tunnel_requests_failed_total',
  help: 'Total number of failed requests',
  registers: [metricsRegistry],
});

/**
 * Gauge: Request success rate
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelRequestSuccessRate = new Gauge({
  name: 'tunnel_request_success_rate',
  help: 'Request success rate (0-1)',
  registers: [metricsRegistry],
});

/**
 * Gauge: Error rate
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelErrorRate = new Gauge({
  name: 'tunnel_error_rate',
  help: 'Error rate (0-1)',
  registers: [metricsRegistry],
});

/**
 * Counter: Total bytes received
 * 
 * Requirement: 3.1
 */
export const tunnelBytesReceivedTotal = new Counter({
  name: 'tunnel_bytes_received_total',
  help: 'Total bytes received',
  registers: [metricsRegistry],
});

/**
 * Counter: Total bytes sent
 * 
 * Requirement: 3.1
 */
export const tunnelBytesSentTotal = new Counter({
  name: 'tunnel_bytes_sent_total',
  help: 'Total bytes sent',
  registers: [metricsRegistry],
});

/**
 * Gauge: Requests per second
 * 
 * Requirement: 3.1, 3.4
 */
export const tunnelRequestsPerSecond = new Gauge({
  name: 'tunnel_requests_per_second',
  help: 'Request throughput (requests per second)',
  registers: [metricsRegistry],
});

/**
 * Gauge: Active users
 * 
 * Requirement: 3.1
 */
export const tunnelActiveUsers = new Gauge({
  name: 'tunnel_active_users',
  help: 'Number of active users',
  registers: [metricsRegistry],
});

/**
 * Gauge: Memory usage in bytes
 * 
 * Requirement: 3.1
 */
export const tunnelMemoryUsageBytes = new Gauge({
  name: 'tunnel_memory_usage_bytes',
  help: 'Memory usage in bytes',
  registers: [metricsRegistry],
});

/**
 * Counter: CPU usage in seconds
 * 
 * Requirement: 3.1
 */
export const tunnelCpuUsageSeconds = new Counter({
  name: 'tunnel_cpu_usage_seconds',
  help: 'CPU usage in seconds',
  registers: [metricsRegistry],
});

/**
 * Counter: Server uptime in seconds
 * 
 * Requirement: 3.1
 */
export const tunnelUptimeSeconds = new Counter({
  name: 'tunnel_uptime_seconds',
  help: 'Server uptime in seconds',
  registers: [metricsRegistry],
});

/**
 * Gauge: Connection rate per second
 * 
 * Requirement: 3.1
 */
export const tunnelConnectionRatePerSecond = new Gauge({
  name: 'tunnel_connection_rate_per_second',
  help: 'Connection rate (connections per second)',
  registers: [metricsRegistry],
});

/**
 * Gauge: Queue fill percentage
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelQueueFillPercentage = new Gauge({
  name: 'tunnel_queue_fill_percentage',
  help: 'Queue fill percentage (0-100)',
  labelNames: ['priority'],
  registers: [metricsRegistry],
});

/**
 * Counter: Rate limit violations
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelRateLimitViolationsTotal = new Counter({
  name: 'tunnel_rate_limit_violations_total',
  help: 'Total rate limit violations',
  labelNames: ['user_tier'],
  registers: [metricsRegistry],
});

/**
 * Histogram: SSH connection establishment time
 * 
 * Requirement: 3.1, 3.4
 */
export const tunnelSshConnectionTimeMs = new Histogram({
  name: 'tunnel_ssh_connection_time_ms',
  help: 'SSH connection establishment time in milliseconds',
  buckets: [10, 50, 100, 200, 500, 1000, 2000],
  registers: [metricsRegistry],
});

/**
 * Counter: WebSocket connections
 * 
 * Requirement: 3.1
 */
export const tunnelWebsocketConnectionsTotal = new Counter({
  name: 'tunnel_websocket_connections_total',
  help: 'Total WebSocket connections',
  registers: [metricsRegistry],
});

/**
 * Counter: WebSocket disconnections
 * 
 * Requirement: 3.1
 */
export const tunnelWebsocketDisconnectionsTotal = new Counter({
  name: 'tunnel_websocket_disconnections_total',
  help: 'Total WebSocket disconnections',
  labelNames: ['reason'],
  registers: [metricsRegistry],
});

/**
 * Gauge: Active WebSocket connections
 * 
 * Requirement: 3.1
 */
export const tunnelWebsocketActiveConnections = new Gauge({
  name: 'tunnel_websocket_active_connections',
  help: 'Number of active WebSocket connections',
  registers: [metricsRegistry],
});

/**
 * Counter: Authentication attempts
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelAuthAttemptsTotal = new Counter({
  name: 'tunnel_auth_attempts_total',
  help: 'Total authentication attempts',
  labelNames: ['result'],
  registers: [metricsRegistry],
});

/**
 * Counter: Slow requests (>5 seconds)
 * 
 * Requirement: 3.1, 3.2
 */
export const tunnelSlowRequestsTotal = new Counter({
  name: 'tunnel_slow_requests_total',
  help: 'Total slow requests (>5 seconds)',
  registers: [metricsRegistry],
});

/**
 * Histogram: P95 latency
 * 
 * Requirement: 3.1, 3.4
 */
export const tunnelP95LatencyMs = new Gauge({
  name: 'tunnel_p95_latency_ms',
  help: '95th percentile latency in milliseconds',
  registers: [metricsRegistry],
});

/**
 * Histogram: P99 latency
 * 
 * Requirement: 3.1, 3.4
 */
export const tunnelP99LatencyMs = new Gauge({
  name: 'tunnel_p99_latency_ms',
  help: '99th percentile latency in milliseconds',
  registers: [metricsRegistry],
});

/**
 * Export metrics in Prometheus text format
 * 
 * Requirement: 11.1
 */
export async function exportMetricsAsText(): Promise<string> {
  return metricsRegistry.metrics();
}

/**
 * Get metrics registry
 */
export function getMetricsRegistry(): Registry {
  return metricsRegistry;
}

/**
 * Initialize all metrics with zero values for label combinations
 * This ensures all metrics are exported even if they haven't been used yet
 * 
 * Requirement: 3.1, 3.2
 */
export function initializeMetrics(): void {
  // Initialize active connections gauge with user tiers
  const userTiers = ['free', 'premium', 'enterprise'];
  for (const tier of userTiers) {
    tunnelActiveConnections.labels(tier).set(0);
  }

  // Initialize queue size gauge with priorities
  const priorities = ['high', 'normal', 'low'];
  for (const priority of priorities) {
    tunnelQueueSize.labels(priority).set(0);
    tunnelQueueFillPercentage.labels(priority).set(0);
  }

  // Initialize circuit breaker state gauge with services
  const services = ['ssh_connection', 'websocket', 'rate_limiter', 'auth'];
  for (const service of services) {
    tunnelCircuitBreakerState.labels(service).set(0); // CLOSED
  }

  // Initialize error counters with categories
  const errorCategories = ['network', 'auth', 'server', 'protocol', 'unknown'];
  const errorCodes = ['TUNNEL_001', 'TUNNEL_002', 'TUNNEL_003', 'TUNNEL_004', 'TUNNEL_005'];
  for (const category of errorCategories) {
    for (const code of errorCodes) {
      tunnelErrorsTotal.labels(category, code).inc(0);
    }
  }

  // Initialize request counters
  tunnelRequestsTotal.labels('success', '').inc(0);
  tunnelRequestsTotal.labels('error', 'network').inc(0);
  tunnelRequestsTotal.labels('error', 'auth').inc(0);
  tunnelRequestsTotal.labels('error', 'server').inc(0);

  // Initialize auth attempts
  tunnelAuthAttemptsTotal.labels('success').inc(0);
  tunnelAuthAttemptsTotal.labels('failed').inc(0);

  // Initialize rate limit violations
  for (const tier of userTiers) {
    tunnelRateLimitViolationsTotal.labels(tier).inc(0);
  }

  // Initialize WebSocket disconnection reasons
  const disconnectReasons = ['normal', 'error', 'timeout', 'auth_failed'];
  for (const reason of disconnectReasons) {
    tunnelWebsocketDisconnectionsTotal.labels(reason).inc(0);
  }
}
