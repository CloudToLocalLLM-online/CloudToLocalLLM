# MCP Tools Integration Guide

This document explains how Model Context Protocol (MCP) tools are integrated into the SSH WebSocket Tunnel Enhancement specification.

## Overview

The specification leverages two primary MCP tool servers:
1. **Grafana MCP Server** - For monitoring, dashboards, and incident management
2. **Context7 MCP Server** - For library documentation and best practices

## Grafana MCP Tools

### Available Tools

The Grafana MCP server provides the following tools for tunnel monitoring:

#### Dashboard Management
- `mcp_grafana_create_dashboard` - Create monitoring dashboards programmatically
- `mcp_grafana_update_dashboard` - Update existing dashboards
- `mcp_grafana_get_dashboard_by_uid` - Retrieve dashboard configuration
- `mcp_grafana_search_dashboards` - Search for existing dashboards

#### Metrics Querying
- `mcp_grafana_query_prometheus` - Query Prometheus metrics for tunnel performance
- `mcp_grafana_list_prometheus_label_names` - Discover available metric labels
- `mcp_grafana_list_prometheus_label_values` - Get label values for filtering

#### Log Analysis
- `mcp_grafana_query_loki_logs` - Query tunnel logs from Loki
- `mcp_grafana_find_error_pattern_logs` - Identify error patterns in logs
- `mcp_grafana_list_loki_label_names` - Discover available log labels
- `mcp_grafana_list_loki_label_values` - Get log label values

#### Alert Management
- `mcp_grafana_create_alert_rule` - Create alert rules for tunnel failures
- `mcp_grafana_update_alert_rule` - Update existing alert rules
- `mcp_grafana_list_alert_rules` - List all configured alert rules
- `mcp_grafana_delete_alert_rule` - Remove alert rules

#### Incident Management
- `mcp_grafana_create_incident` - Create incidents for critical tunnel issues
- `mcp_grafana_get_incident` - Retrieve incident details
- `mcp_grafana_list_incidents` - List active and resolved incidents
- `mcp_grafana_add_activity_to_incident` - Add notes and context to incidents

#### Datasource Management
- `mcp_grafana_list_datasources` - Verify Prometheus and Loki datasources
- `mcp_grafana_get_datasource_by_uid` - Get datasource configuration
- `mcp_grafana_get_datasource_by_name` - Look up datasource by name

#### Utility Functions
- `mcp_grafana_generate_deeplink` - Create shareable dashboard links
- `mcp_grafana_list_contact_points` - Verify alert notification endpoints

### Usage Examples

#### Creating a Tunnel Health Dashboard

```typescript
// Task 18.1: Create tunnel health dashboard
const dashboard = await mcp_grafana_create_dashboard({
  dashboard: {
    title: "Tunnel Health",
    tags: ["tunnel", "monitoring", "production"],
    panels: [
      {
        title: "Active Connections",
        targets: [{
          expr: "tunnel_active_connections",
          datasourceUid: "prometheus-uid"
        }]
      },
      {
        title: "Request Success Rate",
        targets: [{
          expr: "rate(tunnel_requests_total{status='success'}[5m]) / rate(tunnel_requests_total[5m])",
          datasourceUid: "prometheus-uid"
        }]
      }
    ]
  }
});
```

#### Querying Tunnel Metrics

```typescript
// Task 18.1: Query tunnel metrics
const metrics = await mcp_grafana_query_prometheus({
  datasourceUid: "prometheus-uid",
  expr: "tunnel_request_latency_ms",
  queryType: "range",
  startTime: "now-1h",
  endTime: "now",
  stepSeconds: 60
});
```

#### Creating Critical Alerts

```typescript
// Task 18.4: Create alert for high error rate
const alert = await mcp_grafana_create_alert_rule({
  title: "Tunnel Error Rate High",
  ruleGroup: "tunnel-alerts",
  folderUID: "tunnel-folder",
  condition: "A",
  data: [{
    refId: "A",
    queryType: "range",
    model: {
      expr: "rate(tunnel_errors_total[5m]) > 0.05"
    }
  }],
  noDataState: "NoData",
  execErrState: "Alerting",
  for: "5m",
  orgID: 1,
  annotations: {
    description: "Tunnel error rate exceeded 5%",
    runbook_url: "https://docs.example.com/tunnel-errors"
  }
});
```

#### Analyzing Error Patterns

```typescript
// Task 18.3: Find error patterns in logs
const patterns = await mcp_grafana_find_error_pattern_logs({
  name: "Tunnel Error Analysis",
  labels: {
    service: "streaming-proxy",
    component: "tunnel"
  },
  start: "2024-01-15T00:00:00Z",
  end: "2024-01-15T23:59:59Z"
});
```

#### Creating Incidents

```typescript
// Task 20.1: Create incident for circuit breaker open
const incident = await mcp_grafana_create_incident({
  title: "Tunnel Circuit Breaker Open",
  severity: "critical",
  roomPrefix: "tunnel",
  labels: [
    { key: "component", label: "circuit-breaker" },
    { key: "severity", label: "critical" }
  ],
  attachUrl: "https://grafana.example.com/d/tunnel-health",
  attachCaption: "Tunnel Health Dashboard"
});
```

#### Adding Incident Context

```typescript
// Task 20.2: Add diagnostic information to incident
await mcp_grafana_add_activity_to_incident({
  incidentId: incident.id,
  body: "Circuit breaker opened due to 10 consecutive failures. Error rate: 15%. Affected users: 42. See dashboard for details: https://grafana.example.com/d/tunnel-health"
});
```

## Context7 MCP Tools

### Available Tools

The Context7 MCP server provides documentation for key libraries:

#### Library Resolution
- `mcp_context7_resolve_library_id` - Resolve package name to Context7 library ID
- `mcp_context7_get_library_docs` - Fetch up-to-date documentation for a library

### Usage Examples

#### Resolving WebSocket Library

```typescript
// Task 19.1: Resolve WebSocket library
const wsLibId = await mcp_context7_resolve_library_id({
  libraryName: "ws"
});

// Fetch WebSocket documentation
const wsDocs = await mcp_context7_get_library_docs({
  context7CompatibleLibraryID: wsLibId,
  topic: "connection-management",
  tokens: 10000
});
```

#### Resolving SSH Library

```typescript
// Task 19.2: Resolve SSH library
const sshLibId = await mcp_context7_resolve_library_id({
  libraryName: "ssh2"
});

// Fetch SSH documentation
const sshDocs = await mcp_context7_get_library_docs({
  context7CompatibleLibraryID: sshLibId,
  topic: "authentication",
  tokens: 10000
});
```

#### Resolving Monitoring Libraries

```typescript
// Task 19.3: Resolve Prometheus client library
const promLibId = await mcp_context7_resolve_library_id({
  libraryName: "prom-client"
});

const promDocs = await mcp_context7_get_library_docs({
  context7CompatibleLibraryID: promLibId,
  topic: "metrics-collection",
  tokens: 10000
});

// Resolve OpenTelemetry library
const otelLibId = await mcp_context7_resolve_library_id({
  libraryName: "@opentelemetry/sdk-node"
});

const otelDocs = await mcp_context7_get_library_docs({
  context7CompatibleLibraryID: otelLibId,
  topic: "tracing",
  tokens: 10000
});
```

## Integration Points

### Monitoring Tasks (Tasks 18-20)

These tasks use Grafana MCP tools to create production-ready monitoring:

1. **Task 18.1**: Create tunnel health dashboard
   - Uses `mcp_grafana_create_dashboard`
   - Queries metrics with `mcp_grafana_query_prometheus`

2. **Task 18.2**: Create performance metrics dashboard
   - Uses `mcp_grafana_create_dashboard`
   - Queries performance metrics with `mcp_grafana_query_prometheus`

3. **Task 18.3**: Create error tracking dashboard
   - Uses `mcp_grafana_create_dashboard`
   - Queries logs with `mcp_grafana_query_loki_logs`
   - Finds error patterns with `mcp_grafana_find_error_pattern_logs`

4. **Task 18.4**: Set up critical alerts
   - Uses `mcp_grafana_create_alert_rule` for each alert
   - Verifies notification endpoints with `mcp_grafana_list_contact_points`

5. **Task 18.5**: Generate monitoring documentation
   - Uses `mcp_grafana_generate_deeplink` for shareable links

### Documentation Tasks (Tasks 19-20)

These tasks use Context7 MCP tools to reference best practices:

1. **Task 19.1**: Resolve and document WebSocket library
   - Uses `mcp_context7_resolve_library_id` and `mcp_context7_get_library_docs`
   - References in WebSocket handler implementation

2. **Task 19.2**: Resolve and document SSH library
   - Uses `mcp_context7_resolve_library_id` and `mcp_context7_get_library_docs`
   - References in SSH tunnel manager implementation

3. **Task 19.3**: Resolve and document monitoring libraries
   - Uses `mcp_context7_resolve_library_id` and `mcp_context7_get_library_docs`
   - References in metrics collector implementation

4. **Task 19.4**: Document error handling patterns
   - Uses `mcp_context7_resolve_library_id` and `mcp_context7_get_library_docs`
   - References in error handling implementation

### Incident Management Tasks (Task 20)

These tasks use Grafana incident management:

1. **Task 20.1**: Create incidents for critical failures
   - Uses `mcp_grafana_create_incident` when circuit breaker opens
   - Attaches dashboard links with `mcp_grafana_generate_deeplink`

2. **Task 20.2**: Add incident context
   - Uses `mcp_grafana_add_activity_to_incident` for diagnostic information
   - Includes logs and metrics from Grafana queries

3. **Task 20.3**: Auto-resolve incidents
   - Monitors circuit breaker state with `mcp_grafana_query_prometheus`
   - Auto-resolves when circuit breaker closes

## Configuration

### Grafana MCP Server

The Grafana MCP server is configured in `.kiro/settings/mcp.json`:

```json
{
  "grafana": {
    "command": "docker",
    "args": ["mcp", "gateway", "run", "--servers", "grafana"],
    "disabled": false,
    "autoApprove": [
      "create_dashboard",
      "query_prometheus",
      "create_alert_rule",
      "query_loki_logs",
      "create_incident"
    ]
  }
}
```

### Context7 MCP Server

The Context7 MCP server is configured in `.kiro/settings/mcp.json`:

```json
{
  "context7": {
    "command": "docker",
    "args": ["mcp", "gateway", "run", "--servers", "context7"],
    "disabled": false,
    "autoApprove": [
      "resolve-library-id",
      "get-library-docs"
    ]
  }
}
```

## Best Practices

### When Using Grafana MCP Tools

1. **Verify Datasources First**: Always use `mcp_grafana_list_datasources` to verify Prometheus and Loki are available
2. **Use Meaningful Names**: Dashboard and alert names should clearly indicate their purpose
3. **Add Documentation**: Include descriptions and runbook URLs in alerts
4. **Link Resources**: Use `mcp_grafana_generate_deeplink` to create shareable links
5. **Monitor Alerts**: Regularly review alert rules to ensure they're still relevant

### When Using Context7 MCP Tools

1. **Resolve Before Fetching**: Always use `resolve_library_id` before `get_library_docs`
2. **Specify Topics**: Use the `topic` parameter to focus documentation on relevant areas
3. **Reference in Code**: Include library documentation references in code comments
4. **Keep Updated**: Periodically refresh documentation to stay current with library updates
5. **Document Decisions**: Record why specific libraries or patterns were chosen

## Troubleshooting

### Grafana MCP Tool Issues

- **Datasource Not Found**: Verify Prometheus and Loki are configured in Grafana
- **Authentication Failed**: Check Grafana API key is valid and has admin permissions
- **Dashboard Creation Failed**: Verify folder UID exists and user has write permissions
- **Alert Rule Failed**: Check condition syntax and datasource UID are correct

### Context7 MCP Tool Issues

- **Library Not Found**: Try alternative library names or check if library is supported
- **Documentation Empty**: Some libraries may have limited documentation; try different topics
- **Timeout**: Large documentation requests may timeout; reduce token limit

## References

- Grafana MCP Server Documentation: See `.kiro/steering/mcp-tools.md`
- Context7 MCP Server Documentation: See `.kiro/steering/mcp-tools.md`
- Grafana API Documentation: https://grafana.com/docs/grafana/latest/developers/http_api/
- OpenTelemetry Documentation: https://opentelemetry.io/docs/
