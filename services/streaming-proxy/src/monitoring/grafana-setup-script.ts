/**
 * Grafana Dashboard Setup Script
 * 
 * This script demonstrates how to use Grafana MCP tools to set up production
 * monitoring dashboards for the SSH WebSocket tunnel system.
 * 
 * Usage:
 * 1. Ensure Grafana is running and accessible
 * 2. Verify Prometheus datasource is configured
 * 3. Run this script to create dashboards and alerts
 * 
 * Note: This is a reference implementation. In production, use the MCP tools
 * directly through the Kiro IDE or integrate with your deployment pipeline.
 */

/**
 * Dashboard Configuration for Tunnel Health
 * 
 * This dashboard provides real-time visibility into:
 * - Active connections
 * - Request success rate
 * - Average latency
 * - Error rate
 * - Connection pool status
 */
export const TUNNEL_HEALTH_DASHBOARD = {
  title: 'Tunnel Health',
  description: 'Real-time tunnel connection health and performance monitoring',
  tags: ['tunnel', 'monitoring', 'production'],
  timezone: 'browser',
  refresh: '30s',
  time: {
    from: 'now-6h',
    to: 'now'
  },
  panels: [
    {
      id: 1,
      title: 'Active Connections',
      type: 'gauge',
      gridPos: { h: 8, w: 6, x: 0, y: 0 },
      targets: [
        {
          expr: 'tunnel_active_connections',
          refId: 'A',
          legendFormat: 'Connections'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'short',
          thresholds: {
            mode: 'absolute',
            steps: [
              { color: 'green', value: null },
              { color: 'yellow', value: 500 },
              { color: 'red', value: 1000 }
            ]
          }
        }
      }
    },
    {
      id: 2,
      title: 'Request Success Rate',
      type: 'gauge',
      gridPos: { h: 8, w: 6, x: 6, y: 0 },
      targets: [
        {
          expr: '(rate(tunnel_requests_total{status="success"}[5m]) / rate(tunnel_requests_total[5m])) * 100',
          refId: 'A',
          legendFormat: 'Success Rate'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'percent',
          min: 0,
          max: 100,
          thresholds: {
            mode: 'absolute',
            steps: [
              { color: 'red', value: null },
              { color: 'yellow', value: 95 },
              { color: 'green', value: 99 }
            ]
          }
        }
      }
    },
    {
      id: 3,
      title: 'Average Latency',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 0, y: 8 },
      targets: [
        {
          expr: 'avg(tunnel_request_latency_ms)',
          refId: 'A',
          legendFormat: 'Average Latency'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'ms',
          custom: {
            lineWidth: 2,
            fillOpacity: 10
          }
        }
      }
    },
    {
      id: 4,
      title: 'Error Rate',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 12, y: 8 },
      targets: [
        {
          expr: 'rate(tunnel_errors_total[5m])',
          refId: 'A',
          legendFormat: '{{ error_type }}'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'short',
          custom: {
            lineWidth: 2,
            fillOpacity: 10
          }
        }
      }
    },
    {
      id: 5,
      title: 'Connection Pool Status',
      type: 'table',
      gridPos: { h: 8, w: 24, x: 0, y: 16 },
      targets: [
        {
          expr: 'tunnel_connection_pool_active_connections',
          refId: 'A',
          format: 'table'
        }
      ]
    }
  ]
};

/**
 * Dashboard Configuration for Performance Metrics
 * 
 * This dashboard focuses on:
 * - P95 and P99 latency
 * - Throughput
 * - Request rate
 * - Memory and CPU usage
 */
export const TUNNEL_PERFORMANCE_DASHBOARD = {
  title: 'Tunnel Performance',
  description: 'Performance metrics and resource usage analysis',
  tags: ['tunnel', 'performance', 'production'],
  refresh: '30s',
  templating: {
    list: [
      {
        name: 'userTier',
        type: 'query',
        datasource: 'Prometheus',
        query: 'label_values(tunnel_requests_total, user_tier)',
        multi: true,
        includeAll: true,
        current: { text: 'All', value: '$__all' }
      }
    ]
  },
  panels: [
    {
      id: 1,
      title: 'P95 Latency',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 0, y: 0 },
      targets: [
        {
          expr: 'histogram_quantile(0.95, tunnel_request_latency_ms)',
          refId: 'A',
          legendFormat: 'P95'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'ms',
          custom: { lineWidth: 2 }
        }
      }
    },
    {
      id: 2,
      title: 'P99 Latency',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 12, y: 0 },
      targets: [
        {
          expr: 'histogram_quantile(0.99, tunnel_request_latency_ms)',
          refId: 'A',
          legendFormat: 'P99'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'ms',
          custom: { lineWidth: 2 }
        }
      }
    },
    {
      id: 3,
      title: 'Throughput (Bytes/sec)',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 0, y: 8 },
      targets: [
        {
          expr: 'rate(tunnel_throughput_bytes_total[1m])',
          refId: 'A',
          legendFormat: 'Throughput'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'Bps',
          custom: { lineWidth: 2 }
        }
      }
    },
    {
      id: 4,
      title: 'Request Rate (req/sec)',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 12, y: 8 },
      targets: [
        {
          expr: 'rate(tunnel_requests_total[1m])',
          refId: 'A',
          legendFormat: 'Requests/sec'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'short',
          custom: { lineWidth: 2 }
        }
      }
    },
    {
      id: 5,
      title: 'Memory Usage',
      type: 'gauge',
      gridPos: { h: 8, w: 12, x: 0, y: 16 },
      targets: [
        {
          expr: 'process_resident_memory_bytes / 1024 / 1024',
          refId: 'A',
          legendFormat: 'Memory'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'MB',
          thresholds: {
            mode: 'absolute',
            steps: [
              { color: 'green', value: null },
              { color: 'yellow', value: 256 },
              { color: 'red', value: 512 }
            ]
          }
        }
      }
    },
    {
      id: 6,
      title: 'CPU Usage',
      type: 'gauge',
      gridPos: { h: 8, w: 12, x: 12, y: 16 },
      targets: [
        {
          expr: 'rate(process_cpu_seconds_total[1m]) * 100',
          refId: 'A',
          legendFormat: 'CPU'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'percent',
          thresholds: {
            mode: 'absolute',
            steps: [
              { color: 'green', value: null },
              { color: 'yellow', value: 50 },
              { color: 'red', value: 80 }
            ]
          }
        }
      }
    }
  ]
};

/**
 * Dashboard Configuration for Error Tracking
 * 
 * This dashboard provides:
 * - Error rate by category
 * - Error count over time
 * - Top errors
 * - Error rate by user
 */
export const TUNNEL_ERROR_DASHBOARD = {
  title: 'Tunnel Errors',
  description: 'Error tracking and pattern analysis',
  tags: ['tunnel', 'errors', 'production'],
  refresh: '30s',
  panels: [
    {
      id: 1,
      title: 'Error Rate by Category',
      type: 'piechart',
      gridPos: { h: 8, w: 12, x: 0, y: 0 },
      targets: [
        {
          expr: 'sum by (error_category) (rate(tunnel_errors_total[5m]))',
          refId: 'A',
          legendFormat: '{{ error_category }}'
        }
      ]
    },
    {
      id: 2,
      title: 'Error Count Over Time',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 12, y: 0 },
      targets: [
        {
          expr: 'rate(tunnel_errors_total[5m])',
          refId: 'A',
          legendFormat: '{{ error_category }}'
        }
      ],
      fieldConfig: {
        defaults: {
          custom: { lineWidth: 2 }
        }
      }
    },
    {
      id: 3,
      title: 'Top Errors',
      type: 'table',
      gridPos: { h: 8, w: 24, x: 0, y: 8 },
      targets: [
        {
          expr: 'topk(10, sum by (error_code, error_message) (rate(tunnel_errors_total[5m])))',
          refId: 'A',
          format: 'table'
        }
      ]
    },
    {
      id: 4,
      title: 'Error Rate by User',
      type: 'table',
      gridPos: { h: 8, w: 24, x: 0, y: 16 },
      targets: [
        {
          expr: 'sum by (user_id) (rate(tunnel_errors_total[5m]))',
          refId: 'A',
          format: 'table'
        }
      ]
    }
  ]
};

/**
 * Alert Rule Configurations
 */
export const ALERT_RULES = {
  highErrorRate: {
    title: 'High Error Rate',
    ruleGroup: 'tunnel-alerts',
    folderUID: 'tunnel-monitoring',
    condition: 'A',
    data: [
      {
        refId: 'A',
        queryType: 'range',
        model: {
          expr: '(rate(tunnel_errors_total[5m]) / rate(tunnel_requests_total[5m])) > 0.05',
          interval: '1m'
        }
      }
    ],
    noDataState: 'NoData',
    execErrState: 'Alerting',
    for: '5m',
    orgID: 1,
    labels: {
      severity: 'warning',
      team: 'platform'
    },
    annotations: {
      summary: 'High error rate detected',
      description: 'Error rate exceeded 5% threshold over 5 minutes'
    }
  },

  connectionPoolExhaustion: {
    title: 'Connection Pool Exhaustion',
    ruleGroup: 'tunnel-alerts',
    folderUID: 'tunnel-monitoring',
    condition: 'A',
    data: [
      {
        refId: 'A',
        queryType: 'range',
        model: {
          expr: '(tunnel_connection_pool_active_connections / tunnel_connection_pool_total_connections) > 0.9',
          interval: '1m'
        }
      }
    ],
    noDataState: 'NoData',
    execErrState: 'Alerting',
    for: '5m',
    orgID: 1,
    labels: {
      severity: 'warning'
    },
    annotations: {
      summary: 'Connection pool nearly exhausted',
      description: 'Connection pool usage exceeded 90%'
    }
  },

  circuitBreakerOpen: {
    title: 'Circuit Breaker Open',
    ruleGroup: 'tunnel-alerts',
    folderUID: 'tunnel-monitoring',
    condition: 'A',
    data: [
      {
        refId: 'A',
        queryType: 'instant',
        model: {
          expr: 'tunnel_circuit_breaker_state == 1'
        }
      }
    ],
    noDataState: 'NoData',
    execErrState: 'Alerting',
    for: '1m',
    orgID: 1,
    labels: {
      severity: 'critical'
    },
    annotations: {
      summary: 'Circuit breaker is open',
      description: 'Circuit breaker has opened due to failures'
    }
  },

  rateLimitViolations: {
    title: 'Rate Limit Violations Spike',
    ruleGroup: 'tunnel-alerts',
    folderUID: 'tunnel-monitoring',
    condition: 'A',
    data: [
      {
        refId: 'A',
        queryType: 'range',
        model: {
          expr: 'increase(tunnel_rate_limit_violations_total[5m]) > 100',
          interval: '1m'
        }
      }
    ],
    noDataState: 'NoData',
    execErrState: 'Alerting',
    for: '5m',
    orgID: 1,
    labels: {
      severity: 'warning'
    },
    annotations: {
      summary: 'Rate limit violations spike detected',
      description: 'Rate limit violations exceeded 100 in 5 minutes'
    }
  }
};

/**
 * Prometheus Metrics Reference
 * 
 * These are the key metrics exposed by the streaming-proxy service
 * at the /api/tunnel/metrics endpoint.
 */
export const PROMETHEUS_METRICS = {
  // Connection Metrics
  tunnel_active_connections: 'Current number of active tunnel connections',
  tunnel_connections_total: 'Total connections established',
  tunnel_connection_duration_seconds: 'Connection duration in seconds',

  // Request Metrics
  tunnel_requests_total: 'Total requests processed',
  tunnel_request_latency_ms: 'Request latency in milliseconds',
  tunnel_request_latency_ms_p95: '95th percentile latency',
  tunnel_request_latency_ms_p99: '99th percentile latency',

  // Error Metrics
  tunnel_errors_total: 'Total errors',
  tunnel_errors_total_network: 'Network errors',
  tunnel_errors_total_auth: 'Authentication errors',
  tunnel_errors_total_server: 'Server errors',

  // Performance Metrics
  tunnel_throughput_bytes_total: 'Total bytes transferred',
  tunnel_request_rate: 'Requests per second',
  tunnel_error_rate: 'Error rate (errors/total requests)',

  // Resource Metrics
  process_resident_memory_bytes: 'Memory usage in bytes',
  process_cpu_seconds_total: 'CPU usage in seconds',
  process_open_fds: 'Open file descriptors',

  // Circuit Breaker Metrics
  tunnel_circuit_breaker_state: 'Circuit breaker state (0=closed, 1=open, 0.5=half-open)',
  tunnel_circuit_breaker_failures_total: 'Total failures',
  tunnel_circuit_breaker_successes_total: 'Total successes',

  // Rate Limiter Metrics
  tunnel_rate_limit_violations_total: 'Total rate limit violations',

  // Queue Metrics
  tunnel_queue_size: 'Current queue size',
  tunnel_queue_fill_percentage: 'Queue fill percentage',
  tunnel_queue_dropped_total: 'Total dropped requests'
};

/**
 * Loki Log Queries Reference
 * 
 * These are example LogQL queries for analyzing logs from the streaming-proxy service.
 */
export const LOKI_LOG_QUERIES = {
  errorLogs: '{service="streaming-proxy"} |= "error"',
  authErrors: '{service="streaming-proxy"} |= "auth" |= "error"',
  connectionLogs: '{service="streaming-proxy"} |= "connection"',
  slowRequests: '{service="streaming-proxy"} |= "slow" |= "request"',
  circuitBreakerEvents: '{service="streaming-proxy"} |= "circuit" |= "breaker"',
  rateLimitViolations: '{service="streaming-proxy"} |= "rate" |= "limit"',
  withCorrelationId: '{service="streaming-proxy"} | json | correlationId="..."'
};

/**
 * Implementation Notes
 * 
 * 1. Dashboard Creation:
 *    - Use mcp_grafana_create_dashboard to create each dashboard
 *    - Set appropriate refresh intervals (30s for health, 30s for performance)
 *    - Add meaningful tags for organization
 * 
 * 2. Alert Configuration:
 *    - Create alerts with appropriate severity levels
 *    - Set reasonable thresholds based on baseline metrics
 *    - Configure notification channels for each severity
 * 
 * 3. Metrics Collection:
 *    - Ensure streaming-proxy is exposing metrics at /api/tunnel/metrics
 *    - Verify Prometheus is scraping metrics every 15 seconds
 *    - Check metric retention in Prometheus (default: 15 days)
 * 
 * 4. Log Analysis:
 *    - Use Loki for detailed log analysis
 *    - Correlate logs with metrics using correlation IDs
 *    - Use error pattern detection for root cause analysis
 * 
 * 5. Documentation:
 *    - Generate deeplinks for easy dashboard sharing
 *    - Create runbooks for common alerts
 *    - Document metric meanings and thresholds
 */

export const IMPLEMENTATION_CHECKLIST = [
  '[ ] Verify Prometheus datasource is available in Grafana',
  '[ ] Create Tunnel Health Dashboard',
  '[ ] Create Performance Metrics Dashboard',
  '[ ] Create Error Tracking Dashboard',
  '[ ] Create High Error Rate alert',
  '[ ] Create Connection Pool Exhaustion alert',
  '[ ] Create Circuit Breaker Open alert',
  '[ ] Create Rate Limit Violations alert',
  '[ ] Configure notification channels',
  '[ ] Generate dashboard deeplinks',
  '[ ] Create monitoring documentation',
  '[ ] Create alert runbooks',
  '[ ] Test dashboards with real metrics',
  '[ ] Test alerts with manual triggers',
  '[ ] Verify log queries work correctly',
  '[ ] Document dashboard URLs'
];
