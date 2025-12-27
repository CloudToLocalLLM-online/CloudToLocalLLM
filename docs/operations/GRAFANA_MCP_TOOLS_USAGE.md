# Using Grafana MCP Tools for Monitoring Setup

## Overview

This guide explains how to use Grafana MCP tools to set up production monitoring dashboards for the SSH WebSocket tunnel system.

## Prerequisites

1. **Grafana Instance**
   - URL: https://grafana.cloudtolocalllm.online
   - API Key: [Configure in environment variables]

2. **MCP Configuration**
   - Grafana MCP server configured in `.kiro/settings/mcp.json`
   - Environment variables set:
     - GRAFANA_URL: https://grafana.cloudtolocalllm.online
     - GRAFANA_API_KEY: [Set your API key in environment]

3. **Prometheus**
   - Prometheus datasource configured in Grafana
   - Streaming-proxy metrics endpoint accessible

## Available MCP Tools

### 1. mcp_grafana_list_datasources
**Purpose**: List available datasources in Grafana

**Usage**:
```
mcp_grafana_list_datasources({ type: 'prometheus' })
```

**Response**:
```json
[
  {
    "id": 1,
    "uid": "prometheus-uid",
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://prometheus:9090",
    "access": "proxy",
    "isDefault": true
  }
]
```

**Use Case**: Verify Prometheus datasource is available before creating dashboards

---

### 2. mcp_grafana_create_dashboard
**Purpose**: Create a new Grafana dashboard

**Usage**:
```
mcp_grafana_create_dashboard({
  dashboard: {
    title: 'Tunnel Health',
    description: 'Real-time tunnel health monitoring',
    tags: ['tunnel', 'monitoring', 'production'],
    timezone: 'browser',
    refresh: '30s',
    time: { from: 'now-6h', to: 'now' },
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
      }
    ]
  },
  overwrite: true
})
```

**Response**:
```json
{
  "id": 1,
  "uid": "tunnel-health",
  "title": "Tunnel Health",
  "url": "/d/tunnel-health/tunnel-health",
  "version": 1
}
```

**Use Case**: Create monitoring dashboards with custom panels and queries

---

### 3. mcp_grafana_create_alert_rule
**Purpose**: Create alert rules for monitoring

**Usage**:
```
mcp_grafana_create_alert_rule({
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
    description: 'Error rate exceeded 5% threshold'
  }
})
```

**Response**:
```json
{
  "uid": "alert-rule-uid",
  "title": "High Error Rate",
  "condition": "A",
  "data": [...],
  "noDataState": "NoData",
  "execErrState": "Alerting",
  "for": "5m"
}
```

**Use Case**: Create alert rules for critical tunnel issues

---

### 4. mcp_grafana_list_contact_points
**Purpose**: List available notification contact points

**Usage**:
```
mcp_grafana_list_contact_points()
```

**Response**:
```json
[
  {
    "uid": "email-contact",
    "name": "Email Notifications",
    "type": "email",
    "settings": {
      "addresses": ["team@example.com"]
    }
  },
  {
    "uid": "slack-contact",
    "name": "Slack Notifications",
    "type": "slack",
    "settings": {
      "url": "https://hooks.slack.com/..."
    }
  }
]
```

**Use Case**: Verify notification channels are configured for alerts

---

### 5. mcp_grafana_query_prometheus
**Purpose**: Query metrics from Prometheus

**Usage**:
```
mcp_grafana_query_prometheus({
  datasourceUid: 'prometheus-uid',
  expr: 'tunnel_active_connections',
  queryType: 'instant',
  startTime: 'now'
})
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {
          "__name__": "tunnel_active_connections"
        },
        "value": [1234567890, "42"]
      }
    ]
  }
}
```

**Use Case**: Query current metric values for verification

---

### 6. mcp_grafana_query_loki_logs
**Purpose**: Query logs from Loki

**Usage**:
```
mcp_grafana_query_loki_logs({
  datasourceUid: 'loki-uid',
  logql: '{service="streaming-proxy"} |= "error"',
  limit: 100,
  startRfc3339: '2024-01-15T00:00:00Z',
  endRfc3339: '2024-01-15T23:59:59Z'
})
```

**Response**:
```json
[
  {
    "timestamp": "2024-01-15T12:34:56Z",
    "line": "[ERROR] Authentication failed for user: user123",
    "labels": {
      "service": "streaming-proxy",
      "level": "ERROR"
    }
  }
]
```

**Use Case**: Query error logs for troubleshooting

---

### 7. mcp_grafana_find_error_pattern_logs
**Purpose**: Find error patterns in logs

**Usage**:
```
mcp_grafana_find_error_pattern_logs({
  name: 'Tunnel Error Analysis',
  labels: { service: 'streaming-proxy' },
  start: new Date(Date.now() - 30 * 60 * 1000),
  end: new Date()
})
```

**Response**:
```json
{
  "patterns": [
    {
      "pattern": "Connection refused",
      "count": 42,
      "percentage": 35.6,
      "firstSeen": "2024-01-15T12:00:00Z",
      "lastSeen": "2024-01-15T12:30:00Z"
    },
    {
      "pattern": "Authentication failed",
      "count": 28,
      "percentage": 23.7,
      "firstSeen": "2024-01-15T12:05:00Z",
      "lastSeen": "2024-01-15T12:25:00Z"
    }
  ]
}
```

**Use Case**: Identify common error patterns for root cause analysis

---

### 8. mcp_grafana_generate_deeplink
**Purpose**: Generate shareable dashboard links

**Usage**:
```
mcp_grafana_generate_deeplink({
  resourceType: 'dashboard',
  dashboardUid: 'tunnel-health',
  timeRange: {
    from: 'now-6h',
    to: 'now'
  }
})
```

**Response**:
```
https://grafana.cloudtolocalllm.online/d/tunnel-health?from=now-6h&to=now
```

**Use Case**: Generate shareable links for dashboards

---

## Step-by-Step Implementation

### Step 1: Verify Prometheus Datasource

```
mcp_grafana_list_datasources({ type: 'prometheus' })
```

Expected output: List of Prometheus datasources with UIDs

### Step 2: Create Tunnel Health Dashboard

```
mcp_grafana_create_dashboard({
  dashboard: {
    title: 'Tunnel Health',
    tags: ['tunnel', 'monitoring', 'production'],
    refresh: '30s',
    panels: [
      // Active Connections Panel
      {
        id: 1,
        title: 'Active Connections',
        type: 'gauge',
        gridPos: { h: 8, w: 6, x: 0, y: 0 },
        targets: [
          {
            expr: 'tunnel_active_connections',
            refId: 'A'
          }
        ]
      },
      // Request Success Rate Panel
      {
        id: 2,
        title: 'Request Success Rate',
        type: 'gauge',
        gridPos: { h: 8, w: 6, x: 6, y: 0 },
        targets: [
          {
            expr: '(rate(tunnel_requests_total{status="success"}[5m]) / rate(tunnel_requests_total[5m])) * 100',
            refId: 'A'
          }
        ]
      }
      // ... more panels
    ]
  }
})
```

Expected output: Dashboard created with UID and URL

### Step 3: Create Performance Dashboard

```
mcp_grafana_create_dashboard({
  dashboard: {
    title: 'Tunnel Performance',
    tags: ['tunnel', 'performance', 'production'],
    refresh: '30s',
    panels: [
      // P95 Latency Panel
      {
        id: 1,
        title: 'P95 Latency',
        type: 'timeseries',
        targets: [
          {
            expr: 'histogram_quantile(0.95, tunnel_request_latency_ms)',
            refId: 'A'
          }
        ]
      }
      // ... more panels
    ]
  }
})
```

### Step 4: Create Error Dashboard

```
mcp_grafana_create_dashboard({
  dashboard: {
    title: 'Tunnel Errors',
    tags: ['tunnel', 'errors', 'production'],
    refresh: '30s',
    panels: [
      // Error Rate by Category Panel
      {
        id: 1,
        title: 'Error Rate by Category',
        type: 'piechart',
        targets: [
          {
            expr: 'sum by (error_category) (rate(tunnel_errors_total[5m]))',
            refId: 'A'
          }
        ]
      }
      // ... more panels
    ]
  }
})
```

### Step 5: Create Alert Rules

```
// High Error Rate Alert
mcp_grafana_create_alert_rule({
  title: 'High Error Rate',
  ruleGroup: 'tunnel-alerts',
  folderUID: 'tunnel-monitoring',
  condition: 'A',
  data: [
    {
      refId: 'A',
      queryType: 'range',
      model: {
        expr: '(rate(tunnel_errors_total[5m]) / rate(tunnel_requests_total[5m])) > 0.05'
      }
    }
  ],
  for: '5m',
  orgID: 1
})

// Connection Pool Exhaustion Alert
mcp_grafana_create_alert_rule({
  title: 'Connection Pool Exhaustion',
  ruleGroup: 'tunnel-alerts',
  folderUID: 'tunnel-monitoring',
  condition: 'A',
  data: [
    {
      refId: 'A',
      queryType: 'range',
      model: {
        expr: '(tunnel_connection_pool_active_connections / tunnel_connection_pool_total_connections) > 0.9'
      }
    }
  ],
  for: '5m',
  orgID: 1
})

// Circuit Breaker Open Alert
mcp_grafana_create_alert_rule({
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
  for: '1m',
  orgID: 1
})

// Rate Limit Violations Alert
mcp_grafana_create_alert_rule({
  title: 'Rate Limit Violations Spike',
  ruleGroup: 'tunnel-alerts',
  folderUID: 'tunnel-monitoring',
  condition: 'A',
  data: [
    {
      refId: 'A',
      queryType: 'range',
      model: {
        expr: 'increase(tunnel_rate_limit_violations_total[5m]) > 100'
      }
    }
  ],
  for: '5m',
  orgID: 1
})
```

### Step 6: Verify Notification Channels

```
mcp_grafana_list_contact_points()
```

Expected output: List of configured notification channels

### Step 7: Query Metrics

```
mcp_grafana_query_prometheus({
  datasourceUid: 'prometheus-uid',
  expr: 'tunnel_active_connections',
  queryType: 'instant',
  startTime: 'now'
})
```

Expected output: Current active connections value

### Step 8: Query Error Logs

```
mcp_grafana_query_loki_logs({
  datasourceUid: 'loki-uid',
  logql: '{service="streaming-proxy"} |= "error"',
  limit: 100
})
```

Expected output: List of error logs

### Step 9: Find Error Patterns

```
mcp_grafana_find_error_pattern_logs({
  name: 'Tunnel Error Analysis',
  labels: { service: 'streaming-proxy' },
  start: new Date(Date.now() - 30 * 60 * 1000),
  end: new Date()
})
```

Expected output: List of error patterns with counts

### Step 10: Generate Dashboard Links

```
mcp_grafana_generate_deeplink({
  resourceType: 'dashboard',
  dashboardUid: 'tunnel-health',
  timeRange: { from: 'now-6h', to: 'now' }
})

mcp_grafana_generate_deeplink({
  resourceType: 'dashboard',
  dashboardUid: 'tunnel-performance',
  timeRange: { from: 'now-24h', to: 'now' }
})

mcp_grafana_generate_deeplink({
  resourceType: 'dashboard',
  dashboardUid: 'tunnel-errors',
  timeRange: { from: 'now-7d', to: 'now' }
})
```

Expected output: Shareable dashboard URLs

## Common Queries

### Prometheus Queries

```
# Active connections
tunnel_active_connections

# Request success rate
(rate(tunnel_requests_total{status="success"}[5m]) / rate(tunnel_requests_total[5m])) * 100

# Average latency
avg(tunnel_request_latency_ms)

# P95 latency
histogram_quantile(0.95, tunnel_request_latency_ms)

# P99 latency
histogram_quantile(0.99, tunnel_request_latency_ms)

# Error rate
rate(tunnel_errors_total[5m])

# Throughput
rate(tunnel_throughput_bytes_total[1m])

# Memory usage
process_resident_memory_bytes / 1024 / 1024

# CPU usage
rate(process_cpu_seconds_total[1m]) * 100

# Circuit breaker state
tunnel_circuit_breaker_state

# Rate limit violations
increase(tunnel_rate_limit_violations_total[5m])
```

### Loki Queries

```
# Error logs
{service="streaming-proxy"} |= "error"

# Authentication errors
{service="streaming-proxy"} |= "auth" |= "error"

# Connection logs
{service="streaming-proxy"} |= "connection"

# Slow requests
{service="streaming-proxy"} |= "slow" |= "request"

# Circuit breaker events
{service="streaming-proxy"} |= "circuit" |= "breaker"

# Rate limit violations
{service="streaming-proxy"} |= "rate" |= "limit"

# With correlation ID
{service="streaming-proxy"} | json | correlationId="..."
```

## Troubleshooting

### Datasource Not Found
- Verify Prometheus is running
- Check Grafana datasource configuration
- Verify API key has appropriate permissions

### Metrics Not Appearing
- Verify streaming-proxy is running
- Check `/api/tunnel/metrics` endpoint
- Verify Prometheus is scraping metrics

### Alerts Not Firing
- Check alert rule configuration
- Verify notification channels are configured
- Test with manual alert trigger

## Dashboard Setup Guide

For a comprehensive guide on setting up production monitoring dashboards, see:
- **Grafana Dashboard Setup**: `services/streaming-proxy/src/monitoring/grafana-dashboard-setup.ts`
- **Setup Instructions**: `services/streaming-proxy/src/monitoring/setup-grafana-dashboards.md`
- **Implementation Script**: `services/streaming-proxy/src/monitoring/grafana-setup-script.ts`

These files provide:
- Complete dashboard configurations
- Alert rule definitions
- Prometheus metrics reference
- Loki log queries reference
- Implementation checklist
- Best practices and troubleshooting

## References

- Grafana Documentation: https://grafana.com/docs/
- Prometheus Documentation: https://prometheus.io/docs/
- Loki Documentation: https://grafana.com/docs/loki/
- MCP Tools Configuration: `.kiro/settings/mcp.json`
- Monitoring Setup Guide: `docs/OPERATIONS/TUNNEL_MONITORING_SETUP.md`
- Dashboard Setup Guide: `services/streaming-proxy/src/monitoring/grafana-dashboard-setup.ts`
