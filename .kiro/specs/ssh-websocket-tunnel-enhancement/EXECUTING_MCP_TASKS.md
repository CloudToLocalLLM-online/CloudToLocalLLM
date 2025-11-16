# Executing MCP Tool Tasks

This guide explains how to execute the MCP tool integration tasks (Tasks 18-20) during the SSH WebSocket Tunnel Enhancement implementation.

## Prerequisites

Before executing MCP tool tasks, ensure:

1. **Grafana is Running**: Verify Grafana is accessible at the configured URL
2. **Grafana API Key**: Ensure admin API key is configured in `.kiro/settings/mcp.json`
3. **Datasources Configured**: Prometheus and Loki datasources must be available in Grafana
4. **MCP Servers Enabled**: Verify Grafana and Context7 MCP servers are enabled in configuration
5. **Streaming Proxy Deployed**: Ensure streaming-proxy service is running and exposing metrics

## Task Execution Order

The MCP tool tasks should be executed in this order:

1. **Task 18.1-18.5**: Monitoring setup (depends on streaming-proxy metrics endpoint)
2. **Task 19.1-19.4**: Documentation (can be done in parallel with Task 18)
3. **Task 20.1-20.3**: Incident management (depends on Task 18 dashboards)

## Task 18: Set Up Grafana Monitoring Dashboards

### Task 18.1: Create Tunnel Health Dashboard

**Objective**: Create a dashboard showing real-time tunnel health metrics

**Prerequisites**:
- Streaming-proxy service running with metrics endpoint at `/api/tunnel/metrics`
- Prometheus datasource configured in Grafana
- Prometheus scraping streaming-proxy metrics

**Steps**:

1. Verify Prometheus datasource:
```typescript
const datasources = await mcp_grafana_list_datasources({ type: "prometheus" });
const prometheus = datasources.find(ds => ds.name === "Prometheus");
if (!prometheus) throw new Error("Prometheus datasource not found");
```

2. Query available metrics:
```typescript
const metrics = await mcp_grafana_list_prometheus_metric_names({
  datasourceUid: prometheus.uid,
  regex: "tunnel_.*"
});
console.log("Available metrics:", metrics);
```

3. Create dashboard:
```typescript
const dashboard = await mcp_grafana_create_dashboard({
  dashboard: {
    title: "Tunnel Health",
    description: "Real-time tunnel connection and request health metrics",
    tags: ["tunnel", "monitoring", "production"],
    timezone: "browser",
    refresh: "30s",
    panels: [
      {
        id: 1,
        title: "Active Connections",
        type: "gauge",
        targets: [{
          refId: "A",
          expr: "tunnel_active_connections",
          datasourceUid: prometheus.uid
        }],
        fieldConfig: {
          defaults: {
            max: 1000,
            min: 0,
            thresholds: {
              mode: "absolute",
              steps: [
                { color: "green", value: 0 },
                { color: "yellow", value: 500 },
                { color: "red", value: 800 }
              ]
            }
          }
        }
      },
      {
        id: 2,
        title: "Request Success Rate",
        type: "stat",
        targets: [{
          refId: "A",
          expr: "rate(tunnel_requests_total{status='success'}[5m]) / rate(tunnel_requests_total[5m])",
          datasourceUid: prometheus.uid
        }],
        fieldConfig: {
          defaults: {
            unit: "percentunit",
            thresholds: {
              mode: "absolute",
              steps: [
                { color: "red", value: 0 },
                { color: "yellow", value: 0.95 },
                { color: "green", value: 0.99 }
              ]
            }
          }
        }
      },
      {
        id: 3,
        title: "Average Latency",
        type: "graph",
        targets: [{
          refId: "A",
          expr: "avg(tunnel_request_latency_ms)",
          datasourceUid: prometheus.uid
        }],
        fieldConfig: {
          defaults: { unit: "ms" }
        }
      },
      {
        id: 4,
        title: "Error Rate",
        type: "graph",
        targets: [{
          refId: "A",
          expr: "rate(tunnel_errors_total[5m])",
          datasourceUid: prometheus.uid
        }],
        fieldConfig: {
          defaults: { unit: "short" }
        }
      }
    ]
  },
  folderUid: "tunnel-monitoring",
  overwrite: true
});

console.log("Dashboard created:", dashboard.url);
```

4. Generate shareable link:
```typescript
const link = await mcp_grafana_generate_deeplink({
  resourceType: "dashboard",
  dashboardUid: dashboard.uid,
  timeRange: { from: "now-1h", to: "now" }
});
console.log("Shareable link:", link);
```

**Verification**:
- Dashboard appears in Grafana UI
- All panels display data
- Refresh interval is 30 seconds
- Metrics update in real-time

### Task 18.2: Create Performance Metrics Dashboard

**Objective**: Create a dashboard for detailed performance analysis

**Prerequisites**:
- Task 18.1 completed
- Prometheus metrics available

**Steps**:

1. Create performance dashboard:
```typescript
const perfDashboard = await mcp_grafana_create_dashboard({
  dashboard: {
    title: "Tunnel Performance",
    description: "Detailed performance metrics and analysis",
    tags: ["tunnel", "performance", "production"],
    timezone: "browser",
    refresh: "30s",
    templating: {
      list: [
        {
          name: "user_tier",
          type: "query",
          datasource: prometheus.uid,
          query: "label_values(tunnel_requests_total, tier)",
          multi: true,
          includeAll: true
        }
      ]
    },
    panels: [
      {
        id: 1,
        title: "P95 Latency",
        type: "graph",
        targets: [{
          refId: "A",
          expr: "histogram_quantile(0.95, tunnel_request_latency_ms)",
          datasourceUid: prometheus.uid
        }]
      },
      {
        id: 2,
        title: "P99 Latency",
        type: "graph",
        targets: [{
          refId: "A",
          expr: "histogram_quantile(0.99, tunnel_request_latency_ms)",
          datasourceUid: prometheus.uid
        }]
      },
      {
        id: 3,
        title: "Throughput (bytes/sec)",
        type: "graph",
        targets: [{
          refId: "A",
          expr: "rate(tunnel_bytes_transferred_total[5m])",
          datasourceUid: prometheus.uid
        }]
      },
      {
        id: 4,
        title: "Request Rate",
        type: "graph",
        targets: [{
          refId: "A",
          expr: "rate(tunnel_requests_total[5m])",
          datasourceUid: prometheus.uid
        }]
      },
      {
        id: 5,
        title: "Memory Usage",
        type: "gauge",
        targets: [{
          refId: "A",
          expr: "process_resident_memory_bytes / 1024 / 1024",
          datasourceUid: prometheus.uid
        }],
        fieldConfig: {
          defaults: { unit: "MB" }
        }
      },
      {
        id: 6,
        title: "CPU Usage",
        type: "gauge",
        targets: [{
          refId: "A",
          expr: "rate(process_cpu_seconds_total[5m]) * 100",
          datasourceUid: prometheus.uid
        }],
        fieldConfig: {
          defaults: { unit: "percent" }
        }
      }
    ]
  },
  folderUid: "tunnel-monitoring",
  overwrite: true
});

console.log("Performance dashboard created:", perfDashboard.url);
```

**Verification**:
- Dashboard displays performance metrics
- Variables allow filtering by user tier
- Time range selector works
- All panels show data

### Task 18.3: Create Error Tracking Dashboard

**Objective**: Create a dashboard for error analysis and pattern detection

**Prerequisites**:
- Task 18.1 completed
- Loki datasource configured in Grafana
- Streaming-proxy logs available in Loki

**Steps**:

1. Verify Loki datasource:
```typescript
const lokiDatasources = await mcp_grafana_list_datasources({ type: "loki" });
const loki = lokiDatasources.find(ds => ds.name === "Loki");
if (!loki) throw new Error("Loki datasource not found");
```

2. Query error logs:
```typescript
const errorLogs = await mcp_grafana_query_loki_logs({
  datasourceUid: loki.uid,
  logql: '{service="streaming-proxy"} |= "error"',
  limit: 100
});
console.log("Error logs found:", errorLogs.length);
```

3. Find error patterns:
```typescript
const patterns = await mcp_grafana_find_error_pattern_logs({
  name: "Tunnel Error Patterns",
  labels: {
    service: "streaming-proxy",
    component: "tunnel"
  },
  start: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
  end: new Date().toISOString()
});
console.log("Error patterns:", patterns);
```

4. Create error tracking dashboard:
```typescript
const errorDashboard = await mcp_grafana_create_dashboard({
  dashboard: {
    title: "Tunnel Errors",
    description: "Error tracking and pattern analysis",
    tags: ["tunnel", "errors", "production"],
    timezone: "browser",
    refresh: "1m",
    panels: [
      {
        id: 1,
        title: "Error Rate by Category",
        type: "piechart",
        targets: [{
          refId: "A",
          expr: "sum by (error_category) (rate(tunnel_errors_total[5m]))",
          datasourceUid: prometheus.uid
        }]
      },
      {
        id: 2,
        title: "Error Count Over Time",
        type: "graph",
        targets: [{
          refId: "A",
          expr: "rate(tunnel_errors_total[5m])",
          datasourceUid: prometheus.uid
        }]
      },
      {
        id: 3,
        title: "Top Errors",
        type: "table",
        targets: [{
          refId: "A",
          expr: "topk(10, sum by (error_code) (tunnel_errors_total))",
          datasourceUid: prometheus.uid
        }]
      },
      {
        id: 4,
        title: "Error Logs",
        type: "logs",
        targets: [{
          refId: "A",
          expr: '{service="streaming-proxy"} |= "error"',
          datasourceUid: loki.uid
        }]
      }
    ]
  },
  folderUid: "tunnel-monitoring",
  overwrite: true
});

console.log("Error dashboard created:", errorDashboard.url);
```

**Verification**:
- Dashboard displays error metrics
- Error patterns are identified
- Logs are queryable
- Drill-down to detailed logs works

### Task 18.4: Set Up Critical Alerts

**Objective**: Create alerts for critical tunnel failures

**Prerequisites**:
- Task 18.1-18.3 completed
- Alert notification channels configured in Grafana

**Steps**:

1. Verify notification endpoints:
```typescript
const contactPoints = await mcp_grafana_list_contact_points();
console.log("Available notification channels:", contactPoints);
```

2. Create high error rate alert:
```typescript
const errorRateAlert = await mcp_grafana_create_alert_rule({
  title: "Tunnel Error Rate High",
  ruleGroup: "tunnel-alerts",
  folderUID: "tunnel-monitoring",
  condition: "A",
  data: [{
    refId: "A",
    queryType: "range",
    model: {
      expr: "rate(tunnel_errors_total[5m]) > 0.05",
      interval: "1m"
    },
    datasourceUid: prometheus.uid
  }],
  noDataState: "NoData",
  execErrState: "Alerting",
  for: "5m",
  orgID: 1,
  annotations: {
    description: "Tunnel error rate exceeded 5% over 5 minutes",
    runbook_url: "https://docs.example.com/tunnel-errors",
    dashboard_url: "{{ grafana_dashboard_url }}"
  },
  labels: {
    severity: "critical",
    component: "tunnel"
  }
});

console.log("Error rate alert created:", errorRateAlert.uid);
```

3. Create connection pool exhaustion alert:
```typescript
const poolAlert = await mcp_grafana_create_alert_rule({
  title: "Connection Pool Exhaustion",
  ruleGroup: "tunnel-alerts",
  folderUID: "tunnel-monitoring",
  condition: "A",
  data: [{
    refId: "A",
    queryType: "instant",
    model: {
      expr: "tunnel_connection_pool_usage > 0.9",
      interval: "1m"
    },
    datasourceUid: prometheus.uid
  }],
  noDataState: "NoData",
  execErrState: "Alerting",
  for: "2m",
  orgID: 1,
  annotations: {
    description: "Connection pool usage exceeded 90%",
    runbook_url: "https://docs.example.com/connection-pool"
  },
  labels: {
    severity: "warning",
    component: "connection-pool"
  }
});

console.log("Pool alert created:", poolAlert.uid);
```

4. Create circuit breaker open alert:
```typescript
const cbAlert = await mcp_grafana_create_alert_rule({
  title: "Circuit Breaker Open",
  ruleGroup: "tunnel-alerts",
  folderUID: "tunnel-monitoring",
  condition: "A",
  data: [{
    refId: "A",
    queryType: "instant",
    model: {
      expr: "tunnel_circuit_breaker_state == 1",  // 1 = OPEN
      interval: "30s"
    },
    datasourceUid: prometheus.uid
  }],
  noDataState: "NoData",
  execErrState: "Alerting",
  for: "1m",
  orgID: 1,
  annotations: {
    description: "Circuit breaker is open - requests are being blocked",
    runbook_url: "https://docs.example.com/circuit-breaker"
  },
  labels: {
    severity: "critical",
    component: "circuit-breaker"
  }
});

console.log("Circuit breaker alert created:", cbAlert.uid);
```

**Verification**:
- Alerts appear in Grafana UI
- Alert rules are in "Inactive" state (no violations)
- Notification channels are configured
- Alert history is available

### Task 18.5: Generate Monitoring Documentation

**Objective**: Create shareable links and documentation for monitoring

**Steps**:

1. Generate dashboard links:
```typescript
const healthLink = await mcp_grafana_generate_deeplink({
  resourceType: "dashboard",
  dashboardUid: "tunnel-health",
  timeRange: { from: "now-1h", to: "now" }
});

const perfLink = await mcp_grafana_generate_deeplink({
  resourceType: "dashboard",
  dashboardUid: "tunnel-performance",
  timeRange: { from: "now-6h", to: "now" }
});

const errorLink = await mcp_grafana_generate_deeplink({
  resourceType: "dashboard",
  dashboardUid: "tunnel-errors",
  timeRange: { from: "now-24h", to: "now" }
});

console.log("Dashboard links:");
console.log("- Health:", healthLink);
console.log("- Performance:", perfLink);
console.log("- Errors:", errorLink);
```

2. Create monitoring guide document:
```markdown
# Tunnel Monitoring Guide

## Dashboards

### Tunnel Health
Real-time tunnel connection and request health metrics.
[View Dashboard](${healthLink})

### Tunnel Performance
Detailed performance metrics and analysis.
[View Dashboard](${perfLink})

### Tunnel Errors
Error tracking and pattern analysis.
[View Dashboard](${errorLink})

## Alerts

### Critical Alerts
- **Tunnel Error Rate High**: Error rate > 5% over 5 minutes
- **Circuit Breaker Open**: Circuit breaker is open
- **Connection Pool Exhaustion**: Pool usage > 90%

## Runbooks
- [Error Rate High](https://docs.example.com/tunnel-errors)
- [Circuit Breaker Open](https://docs.example.com/circuit-breaker)
- [Connection Pool Exhaustion](https://docs.example.com/connection-pool)
```

**Verification**:
- Links are shareable and work
- Documentation is complete
- All dashboards are referenced

## Task 19: Use Context7 MCP Tools for Documentation

### Task 19.1: Resolve and Document WebSocket Library

**Steps**:

1. Resolve WebSocket library:
```typescript
const wsLibId = await mcp_context7_resolve_library_id({
  libraryName: "ws"
});
console.log("WebSocket library ID:", wsLibId);
```

2. Fetch documentation:
```typescript
const wsDocs = await mcp_context7_get_library_docs({
  context7CompatibleLibraryID: wsLibId,
  topic: "connection-management",
  tokens: 10000
});
console.log("WebSocket documentation:", wsDocs);
```

3. Reference in code:
```typescript
// services/streaming-proxy/src/websocket/websocket-handler-impl.ts

/**
 * WebSocket Connection Handler
 * 
 * Based on official ws library documentation:
 * https://github.com/websockets/ws
 * 
 * Key patterns implemented:
 * - Proper connection upgrade handling
 * - Heartbeat mechanism with ping/pong
 * - Graceful connection closure
 * - Error handling and recovery
 * 
 * See MCP_TOOLS_INTEGRATION.md for full documentation reference.
 */
```

### Task 19.2: Resolve and Document SSH Library

**Steps**:

1. Resolve SSH library:
```typescript
const sshLibId = await mcp_context7_resolve_library_id({
  libraryName: "ssh2"
});
console.log("SSH library ID:", sshLibId);
```

2. Fetch documentation:
```typescript
const sshDocs = await mcp_context7_get_library_docs({
  context7CompatibleLibraryID: sshLibId,
  topic: "authentication",
  tokens: 10000
});
console.log("SSH documentation:", sshDocs);
```

3. Reference in code:
```typescript
// services/streaming-proxy/src/connection-pool/ssh-connection-impl.ts

/**
 * SSH Connection Manager
 * 
 * Based on official ssh2 library documentation:
 * https://github.com/mscdex/ssh2
 * 
 * Key patterns implemented:
 * - SSH protocol version 2 only
 * - Modern key exchange algorithms (curve25519-sha256)
 * - AES-256-GCM encryption
 * - SSH keep-alive messages
 * - Connection multiplexing
 * 
 * See MCP_TOOLS_INTEGRATION.md for full documentation reference.
 */
```

### Task 19.3: Resolve and Document Monitoring Libraries

**Steps**:

1. Resolve Prometheus client:
```typescript
const promLibId = await mcp_context7_resolve_library_id({
  libraryName: "prom-client"
});

const promDocs = await mcp_context7_get_library_docs({
  context7CompatibleLibraryID: promLibId,
  topic: "metrics-collection",
  tokens: 10000
});
```

2. Resolve OpenTelemetry:
```typescript
const otelLibId = await mcp_context7_resolve_library_id({
  libraryName: "@opentelemetry/sdk-node"
});

const otelDocs = await mcp_context7_get_library_docs({
  context7CompatibleLibraryID: otelLibId,
  topic: "tracing",
  tokens: 10000
});
```

3. Reference in code:
```typescript
// services/streaming-proxy/src/metrics/server-metrics-collector.ts

/**
 * Server Metrics Collector
 * 
 * Based on official prom-client documentation:
 * https://github.com/siimon/prom-client
 * 
 * And OpenTelemetry documentation:
 * https://opentelemetry.io/docs/
 * 
 * Key patterns implemented:
 * - Prometheus metric types (Counter, Gauge, Histogram)
 * - Metric labels for dimensionality
 * - Histogram buckets for latency tracking
 * - OpenTelemetry span instrumentation
 * 
 * See MCP_TOOLS_INTEGRATION.md for full documentation reference.
 */
```

### Task 19.4: Document Error Handling Patterns

**Steps**:

1. Resolve error handling libraries:
```typescript
const zodLibId = await mcp_context7_resolve_library_id({
  libraryName: "zod"
});

const zodDocs = await mcp_context7_get_library_docs({
  context7CompatibleLibraryID: zodLibId,
  topic: "validation",
  tokens: 10000
});
```

2. Reference in code:
```typescript
// lib/services/tunnel/error_categorization.dart

/**
 * Error Categorization System
 * 
 * Implements error categorization based on best practices:
 * - Network errors: Connection, DNS, timeout
 * - Authentication errors: Invalid token, expired token
 * - Configuration errors: Invalid settings
 * - Server errors: Unavailable, overloaded
 * - Protocol errors: SSH, WebSocket
 * 
 * Each error includes:
 * - Error code for tracking
 * - User-friendly message
 * - Actionable suggestions
 * - Retry recommendations
 * 
 * See MCP_TOOLS_INTEGRATION.md for full documentation reference.
 */
```

## Task 20: Integrate Grafana Incident Management

### Task 20.1: Create Incident for Critical Failures

**Objective**: Automatically create incidents when circuit breaker opens

**Implementation**:

```typescript
// In circuit-breaker-impl.ts, when circuit opens:

async onCircuitOpen() {
  // Create incident
  const incident = await mcp_grafana_create_incident({
    title: "Tunnel Circuit Breaker Open",
    severity: "critical",
    roomPrefix: "tunnel",
    status: "active",
    labels: [
      { key: "component", label: "circuit-breaker" },
      { key: "severity", label: "critical" },
      { key: "auto-created", label: "true" }
    ],
    attachUrl: "https://grafana.example.com/d/tunnel-health",
    attachCaption: "Tunnel Health Dashboard"
  });

  logger.error("Circuit breaker opened, incident created", {
    incidentId: incident.id,
    failureCount: this.failureCount,
    timestamp: new Date().toISOString()
  });

  return incident;
}
```

### Task 20.2: Add Incident Context and Analysis

**Objective**: Add diagnostic information to incidents

**Implementation**:

```typescript
// Add diagnostic information to incident

async addDiagnosticContext(incidentId: string) {
  // Query recent error metrics
  const errorMetrics = await mcp_grafana_query_prometheus({
    datasourceUid: prometheus.uid,
    expr: "rate(tunnel_errors_total[5m])",
    queryType: "instant"
  });

  // Query error logs
  const errorLogs = await mcp_grafana_query_loki_logs({
    datasourceUid: loki.uid,
    logql: '{service="streaming-proxy"} |= "error"',
    limit: 10
  });

  // Find error patterns
  const patterns = await mcp_grafana_find_error_pattern_logs({
    name: "Incident Analysis",
    labels: { service: "streaming-proxy" },
    start: new Date(Date.now() - 30 * 60 * 1000).toISOString(),
    end: new Date().toISOString()
  });

  // Add activity to incident
  await mcp_grafana_add_activity_to_incident({
    incidentId: incidentId,
    body: `
Circuit breaker opened due to cascading failures.

**Metrics:**
- Error rate: ${errorMetrics.value}
- Affected connections: ${this.failureCount}

**Error Patterns:**
${patterns.map(p => `- ${p}`).join('\n')}

**Recent Errors:**
${errorLogs.map(log => `- ${log.line}`).join('\n')}

**Dashboard:** https://grafana.example.com/d/tunnel-health
**Runbook:** https://docs.example.com/circuit-breaker
    `,
    eventTime: new Date().toISOString()
  });
}
```

### Task 20.3: Implement Incident Auto-Resolution

**Objective**: Automatically resolve incidents when circuit breaker closes

**Implementation**:

```typescript
// In circuit-breaker-impl.ts, when circuit closes:

async onCircuitClosed() {
  // Find open incident
  const incidents = await mcp_grafana_list_incidents({
    status: "active",
    limit: 10
  });

  const cbIncident = incidents.find(i => 
    i.title.includes("Circuit Breaker") && 
    i.labels.some(l => l.key === "component" && l.value === "circuit-breaker")
  );

  if (cbIncident) {
    // Add resolution note
    await mcp_grafana_add_activity_to_incident({
      incidentId: cbIncident.id,
      body: `
Circuit breaker has recovered and closed.

**Recovery Details:**
- Closed at: ${new Date().toISOString()}
- Successful requests: ${this.successCount}
- Recovery time: ${this.recoveryTime}ms

**Status:** Resolved
      `,
      eventTime: new Date().toISOString()
    });

    logger.info("Circuit breaker closed, incident resolved", {
      incidentId: cbIncident.id,
      recoveryTime: this.recoveryTime
    });
  }
}
```

## Troubleshooting MCP Tool Execution

### Common Issues

**Issue**: Datasource not found
```
Solution: Run mcp_grafana_list_datasources() to verify datasources exist
```

**Issue**: Authentication failed
```
Solution: Check Grafana API key in .kiro/settings/mcp.json
```

**Issue**: Dashboard creation failed
```
Solution: Verify folder UID exists and user has write permissions
```

**Issue**: Library not found
```
Solution: Try alternative library names or check Context7 support
```

## Verification Checklist

- [ ] All Grafana dashboards created and displaying data
- [ ] All alerts configured and in "Inactive" state
- [ ] Notification channels verified
- [ ] Shareable dashboard links generated
- [ ] Library documentation resolved and referenced
- [ ] Incident management tested with manual incident creation
- [ ] Auto-resolution logic verified
- [ ] Monitoring documentation complete

## Next Steps

After completing MCP tool tasks:

1. **Test Monitoring**: Trigger test failures to verify alerts work
2. **Document Runbooks**: Create runbooks for each alert
3. **Train Team**: Ensure team knows how to use dashboards
4. **Monitor Production**: Deploy and monitor in production
5. **Iterate**: Refine dashboards and alerts based on real data
