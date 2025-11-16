# Tunnel Monitoring Setup Guide

## Overview

This guide provides comprehensive instructions for setting up production monitoring dashboards for the SSH WebSocket tunnel system using Grafana and Prometheus.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Streaming Proxy Service                  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  ServerMetricsCollector                              │  │
│  │  - Tracks active connections                         │  │
│  │  - Records request latencies                         │  │
│  │  - Counts errors by category                         │  │
│  │  - Monitors circuit breaker state                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                 │
│                           ▼                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Prometheus Metrics Endpoint (/api/tunnel/metrics)  │  │
│  │  - Exposes metrics in Prometheus text format         │  │
│  │  - Includes all key performance indicators           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Prometheus Server                        │
│                                                             │
│  - Scrapes metrics every 15 seconds                        │
│  - Stores time-series data                                │
│  - Retains data for 15 days                               │
│  - Provides query API for Grafana                         │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Grafana Server                           │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Tunnel Health Dashboard                             │  │
│  │  - Active connections gauge                          │  │
│  │  - Request success rate                              │  │
│  │  - Average latency graph                             │  │
│  │  - Error rate graph                                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Performance Metrics Dashboard                       │  │
│  │  - P95/P99 latency                                   │  │
│  │  - Throughput                                        │  │
│  │  - Memory/CPU usage                                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Error Tracking Dashboard                            │  │
│  │  - Error rate by category                            │  │
│  │  - Top errors table                                  │  │
│  │  - Error rate by user                                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Alert Rules                                         │  │
│  │  - High error rate (>5%)                             │  │
│  │  - Connection pool exhaustion (>90%)                 │  │
│  │  - Circuit breaker open                              │  │
│  │  - Rate limit violations spike                       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Notification Channels                      │
│                                                             │
│  - Email notifications                                    │
│  - Slack integration (optional)                           │
│  - PagerDuty integration (optional)                       │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Grafana Instance**
   - URL: https://grafana.cloudtolocalllm.online
   - API Key: [Configure in environment variables]
   - Admin access required

2. **Prometheus Server**
   - Must be configured as datasource in Grafana
   - Scraping interval: 15 seconds
   - Data retention: 15 days

3. **Loki Server** (optional, for log analysis)
   - Configured as datasource in Grafana
   - Receives logs from streaming-proxy

4. **Streaming Proxy Service**
   - Running and exposing metrics at `/api/tunnel/metrics`
   - Prometheus format metrics enabled
   - Structured logging enabled

## Task 18.1: Create Tunnel Health Dashboard

### Purpose
Real-time visibility into tunnel connection health, request success rates, latency, and error rates.

### Panels

#### 1. Active Connections (Gauge)
- **Metric**: `tunnel_active_connections`
- **Thresholds**: Green (0-500), Yellow (500-1000), Red (>1000)
- **Refresh**: 30 seconds
- **Purpose**: Monitor current connection load

#### 2. Request Success Rate (Gauge)
- **Metric**: `(rate(tunnel_requests_total{status="success"}[5m]) / rate(tunnel_requests_total[5m])) * 100`
- **Thresholds**: Red (<95%), Yellow (95-99%), Green (>99%)
- **Refresh**: 30 seconds
- **Purpose**: Monitor request reliability

#### 3. Average Latency (Graph)
- **Metric**: `avg(tunnel_request_latency_ms)`
- **Unit**: milliseconds
- **Refresh**: 30 seconds
- **Purpose**: Monitor request performance

#### 4. Error Rate (Graph)
- **Metric**: `rate(tunnel_errors_total[5m])`
- **Legend**: By error type
- **Refresh**: 30 seconds
- **Purpose**: Monitor error trends

#### 5. Connection Pool Status (Table)
- **Metrics**: 
  - `tunnel_connection_pool_active_connections`
  - `tunnel_connection_pool_idle_connections`
  - `tunnel_connection_pool_total_connections`
- **Refresh**: 30 seconds
- **Purpose**: Monitor connection pool utilization

### Implementation

Use Grafana MCP tools:
```
mcp_grafana_create_dashboard({
  dashboard: {
    title: 'Tunnel Health',
    tags: ['tunnel', 'monitoring', 'production'],
    refresh: '30s',
    panels: [...]
  }
})
```

## Task 18.2: Create Performance Metrics Dashboard

### Purpose
Performance analysis including latency percentiles, throughput, and resource usage.

### Panels

#### 1. P95 Latency (Graph)
- **Metric**: `histogram_quantile(0.95, tunnel_request_latency_ms)`
- **Unit**: milliseconds
- **Threshold**: >200ms is concerning

#### 2. P99 Latency (Graph)
- **Metric**: `histogram_quantile(0.99, tunnel_request_latency_ms)`
- **Unit**: milliseconds
- **Threshold**: >500ms is concerning

#### 3. Throughput (Graph)
- **Metric**: `rate(tunnel_throughput_bytes_total[1m])`
- **Unit**: Bytes/second
- **Purpose**: Monitor data transfer rate

#### 4. Request Rate (Graph)
- **Metric**: `rate(tunnel_requests_total[1m])`
- **Unit**: requests/second
- **Purpose**: Monitor request volume

#### 5. Memory Usage (Gauge)
- **Metric**: `process_resident_memory_bytes / 1024 / 1024`
- **Unit**: MB
- **Thresholds**: Green (<256MB), Yellow (256-512MB), Red (>512MB)

#### 6. CPU Usage (Gauge)
- **Metric**: `rate(process_cpu_seconds_total[1m]) * 100`
- **Unit**: percent
- **Thresholds**: Green (<50%), Yellow (50-80%), Red (>80%)

### Variables

- **User Tier**: Filter by free, premium, enterprise
- **Time Range**: 1h, 6h, 24h, 7d

## Task 18.3: Create Error Tracking Dashboard

### Purpose
Error analysis and pattern detection using Prometheus and Loki.

### Panels

#### 1. Error Rate by Category (Pie Chart)
- **Metric**: `sum by (error_category) (rate(tunnel_errors_total[5m]))`
- **Purpose**: Visualize error distribution

#### 2. Error Count Over Time (Graph)
- **Metric**: `rate(tunnel_errors_total[5m])`
- **Legend**: By error category
- **Purpose**: Monitor error trends

#### 3. Top Errors (Table)
- **Metric**: `topk(10, sum by (error_code, error_message) (rate(tunnel_errors_total[5m])))`
- **Purpose**: Identify most common errors

#### 4. Error Rate by User (Table)
- **Metric**: `sum by (user_id) (rate(tunnel_errors_total[5m]))`
- **Purpose**: Identify users with high error rates

### Log Queries

Use Loki for detailed error analysis:
```
{service="streaming-proxy"} |= "error"
{service="streaming-proxy"} |= "auth" |= "error"
{service="streaming-proxy"} |= "circuit" |= "breaker"
```

## Task 18.4: Set up Critical Alerts

### Alert 1: High Error Rate

**Condition**: Error rate > 5% over 5 minutes
**Severity**: Warning
**Action**: Notify team

```
(rate(tunnel_errors_total[5m]) / rate(tunnel_requests_total[5m])) > 0.05
```

### Alert 2: Connection Pool Exhaustion

**Condition**: Connection pool > 90% capacity
**Severity**: Warning
**Action**: Scale up or investigate

```
(tunnel_connection_pool_active_connections / tunnel_connection_pool_total_connections) > 0.9
```

### Alert 3: Circuit Breaker Open

**Condition**: Circuit breaker state = 1 (open)
**Severity**: Critical
**Action**: Immediate investigation

```
tunnel_circuit_breaker_state == 1
```

### Alert 4: Rate Limit Violations Spike

**Condition**: Rate limit violations > 100 in 5 minutes
**Severity**: Warning
**Action**: Investigate traffic patterns

```
increase(tunnel_rate_limit_violations_total[5m]) > 100
```

## Task 18.5: Generate Monitoring Documentation

### Dashboard Links

Generate shareable links using Grafana MCP tools:

```
mcp_grafana_generate_deeplink({
  resourceType: 'dashboard',
  dashboardUid: 'tunnel-health',
  timeRange: { from: 'now-6h', to: 'now' }
})
```

### Monitoring Guide

Create `docs/OPERATIONS/TUNNEL_MONITORING_GUIDE.md` with:
- Dashboard descriptions
- Metric meanings
- Alert thresholds
- Troubleshooting procedures

### Alert Runbooks

Create `docs/OPERATIONS/TUNNEL_ALERT_RUNBOOKS.md` with:
- Alert descriptions
- Investigation steps
- Resolution procedures
- Escalation paths

## Metrics Reference

### Connection Metrics
- `tunnel_active_connections`: Current active connections
- `tunnel_connections_total`: Total connections established
- `tunnel_connection_duration_seconds`: Connection duration

### Request Metrics
- `tunnel_requests_total`: Total requests processed
- `tunnel_request_latency_ms`: Request latency
- `tunnel_request_latency_ms{quantile="0.95"}`: P95 latency
- `tunnel_request_latency_ms{quantile="0.99"}`: P99 latency

### Error Metrics
- `tunnel_errors_total`: Total errors
- `tunnel_errors_total{category="network"}`: Network errors
- `tunnel_errors_total{category="auth"}`: Auth errors
- `tunnel_errors_total{category="server"}`: Server errors

### Performance Metrics
- `tunnel_throughput_bytes_total`: Total bytes transferred
- `tunnel_request_rate`: Requests per second
- `tunnel_error_rate`: Error rate

### Resource Metrics
- `process_resident_memory_bytes`: Memory usage
- `process_cpu_seconds_total`: CPU usage
- `process_open_fds`: Open file descriptors

### Circuit Breaker Metrics
- `tunnel_circuit_breaker_state`: State (0=closed, 1=open, 0.5=half-open)
- `tunnel_circuit_breaker_failures_total`: Total failures
- `tunnel_circuit_breaker_successes_total`: Total successes

### Rate Limiter Metrics
- `tunnel_rate_limit_violations_total`: Total violations

### Queue Metrics
- `tunnel_queue_size`: Current queue size
- `tunnel_queue_fill_percentage`: Queue fill percentage
- `tunnel_queue_dropped_total`: Total dropped requests

## Monitoring Best Practices

1. **Set Appropriate Thresholds**
   - Error rate: >5% is concerning
   - Latency P95: >200ms is concerning
   - Connection pool: >90% is concerning
   - Memory: >512MB is concerning
   - CPU: >80% is concerning

2. **Use Correlation IDs**
   - All logs include X-Correlation-ID header
   - Use for tracing requests through system
   - Correlate logs with metrics

3. **Regular Review**
   - Review dashboards daily
   - Adjust thresholds based on baseline
   - Update runbooks as needed

4. **Alert Fatigue Prevention**
   - Set appropriate alert durations (5-10 minutes)
   - Use severity levels appropriately
   - Avoid alerting on transient issues

5. **Documentation**
   - Document dashboard purposes
   - Explain metric meanings
   - Provide troubleshooting guides

## Troubleshooting

### Datasource Not Found
- Verify Prometheus is running
- Check Grafana datasource configuration
- Verify API key has appropriate permissions

### Metrics Not Appearing
- Verify streaming-proxy is running
- Check `/api/tunnel/metrics` endpoint
- Verify Prometheus is scraping metrics
- Check Prometheus targets page

### Alerts Not Firing
- Check alert rule configuration
- Verify notification channels are configured
- Test with manual alert trigger
- Check Grafana logs for errors

### Dashboard Slow
- Reduce time range
- Simplify queries
- Increase Prometheus retention
- Check Prometheus performance

## Implementation Checklist

- [ ] Verify Prometheus datasource is available
- [ ] Create Tunnel Health Dashboard
- [ ] Create Performance Metrics Dashboard
- [ ] Create Error Tracking Dashboard
- [ ] Create High Error Rate alert
- [ ] Create Connection Pool Exhaustion alert
- [ ] Create Circuit Breaker Open alert
- [ ] Create Rate Limit Violations alert
- [ ] Configure notification channels
- [ ] Generate dashboard deeplinks
- [ ] Create monitoring documentation
- [ ] Create alert runbooks
- [ ] Test dashboards with real metrics
- [ ] Test alerts with manual triggers
- [ ] Verify log queries work correctly
- [ ] Document dashboard URLs

## Dashboard Setup Implementation

For detailed implementation guidance, see:
- **Grafana Dashboard Setup Guide**: `services/streaming-proxy/src/monitoring/grafana-dashboard-setup.ts`
  - Complete dashboard configurations
  - Alert rule definitions
  - Prometheus metrics reference
  - Loki log queries reference
  - Implementation notes and best practices

- **Setup Instructions**: `services/streaming-proxy/src/monitoring/setup-grafana-dashboards.md`
  - Step-by-step implementation guide
  - Code examples for MCP tool usage
  - Metrics reference
  - Verification checklist
  - Troubleshooting guide

- **Implementation Script**: `services/streaming-proxy/src/monitoring/grafana-setup-script.ts`
  - Practical implementation script
  - Dashboard configurations (JSON)
  - Alert rule configurations
  - Implementation checklist

## References

- Grafana Documentation: https://grafana.com/docs/
- Prometheus Documentation: https://prometheus.io/docs/
- Loki Documentation: https://grafana.com/docs/loki/
- MCP Grafana Tools: `.kiro/steering/mcp-tools.md`
- Streaming Proxy Metrics: `services/streaming-proxy/src/metrics/server-metrics-collector.ts`
- Grafana MCP Tools Usage: `docs/OPERATIONS/GRAFANA_MCP_TOOLS_USAGE.md`
