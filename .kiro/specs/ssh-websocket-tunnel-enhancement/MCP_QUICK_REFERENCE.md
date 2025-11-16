# MCP Tools Quick Reference

Quick lookup guide for MCP tools used in the SSH WebSocket Tunnel Enhancement specification.

## Grafana MCP Tools Quick Reference

### Dashboard Creation

```typescript
// Create a new dashboard
mcp_grafana_create_dashboard({
  dashboard: {
    title: "Dashboard Title",
    tags: ["tag1", "tag2"],
    panels: [/* panel definitions */]
  },
  folderUid: "folder-uid",
  overwrite: true
})

// Update existing dashboard
mcp_grafana_update_dashboard({
  uid: "dashboard-uid",
  operations: [
    { op: "replace", path: "$.title", value: "New Title" },
    { op: "replace", path: "$.panels[0].title", value: "Panel Title" }
  ]
})

// Get dashboard details
mcp_grafana_get_dashboard_by_uid({ uid: "dashboard-uid" })

// Search dashboards
mcp_grafana_search_dashboards({ query: "tunnel" })
```

### Metrics Querying

```typescript
// Query Prometheus metrics
mcp_grafana_query_prometheus({
  datasourceUid: "prometheus-uid",
  expr: "tunnel_active_connections",
  queryType: "instant",  // or "range"
  startTime: "now-1h",
  endTime: "now",
  stepSeconds: 60
})

// List available metrics
mcp_grafana_list_prometheus_metric_names({
  datasourceUid: "prometheus-uid",
  regex: "tunnel_.*"
})

// Get metric labels
mcp_grafana_list_prometheus_label_names({
  datasourceUid: "prometheus-uid"
})

// Get label values
mcp_grafana_list_prometheus_label_values({
  datasourceUid: "prometheus-uid",
  labelName: "status"
})
```

### Log Querying

```typescript
// Query logs from Loki
mcp_grafana_query_loki_logs({
  datasourceUid: "loki-uid",
  logql: "{service=\"streaming-proxy\"} |= \"error\"",
  limit: 100,
  direction: "backward"  // newest first
})

// Get log statistics
mcp_grafana_query_loki_stats({
  datasourceUid: "loki-uid",
  logql: "{service=\"streaming-proxy\"}"
})

// Find error patterns
mcp_grafana_find_error_pattern_logs({
  name: "Error Analysis",
  labels: { service: "streaming-proxy" },
  start: "2024-01-15T00:00:00Z",
  end: "2024-01-15T23:59:59Z"
})

// List available log labels
mcp_grafana_list_loki_label_names({
  datasourceUid: "loki-uid"
})

// Get label values
mcp_grafana_list_loki_label_values({
  datasourceUid: "loki-uid",
  labelName: "level"
})
```

### Alert Management

```typescript
// Create alert rule
mcp_grafana_create_alert_rule({
  title: "Alert Title",
  ruleGroup: "tunnel-alerts",
  folderUID: "folder-uid",
  condition: "A",
  data: [{
    refId: "A",
    queryType: "range",
    model: { expr: "tunnel_errors_total > 100" }
  }],
  noDataState: "NoData",
  execErrState: "Alerting",
  for: "5m",
  orgID: 1,
  annotations: {
    description: "Alert description",
    runbook_url: "https://docs.example.com/runbook"
  },
  labels: { severity: "critical" }
})

// Update alert rule
mcp_grafana_update_alert_rule({
  uid: "alert-uid",
  title: "Updated Title",
  // ... other fields
})

// List alert rules
mcp_grafana_list_alert_rules({
  limit: 100,
  label_selectors: [{
    filters: [
      { name: "severity", type: "=", value: "critical" }
    ]
  }]
})

// Get alert rule details
mcp_grafana_get_alert_rule_by_uid({ uid: "alert-uid" })

// Delete alert rule
mcp_grafana_delete_alert_rule({ uid: "alert-uid" })
```

### Incident Management

```typescript
// Create incident
mcp_grafana_create_incident({
  title: "Incident Title",
  severity: "critical",
  roomPrefix: "tunnel",
  status: "active",
  labels: [
    { key: "component", label: "circuit-breaker" },
    { key: "severity", label: "critical" }
  ],
  attachUrl: "https://grafana.example.com/d/dashboard-uid",
  attachCaption: "Dashboard Link"
})

// Get incident details
mcp_grafana_get_incident({ id: "incident-id" })

// List incidents
mcp_grafana_list_incidents({
  status: "active",  // or "resolved"
  limit: 50
})

// Add activity to incident
mcp_grafana_add_activity_to_incident({
  incidentId: "incident-id",
  body: "Activity description with optional URLs",
  eventTime: "2024-01-15T12:00:00Z"
})
```

### Datasource Management

```typescript
// List datasources
mcp_grafana_list_datasources({
  type: "prometheus"  // or "loki", "tempo", etc.
})

// Get datasource by UID
mcp_grafana_get_datasource_by_uid({ uid: "datasource-uid" })

// Get datasource by name
mcp_grafana_get_datasource_by_name({ name: "Prometheus" })

// List contact points (notification endpoints)
mcp_grafana_list_contact_points({
  name: "email-alerts",
  limit: 100
})
```

### Utility Functions

```typescript
// Generate shareable dashboard link
mcp_grafana_generate_deeplink({
  resourceType: "dashboard",  // or "panel", "explore"
  dashboardUid: "dashboard-uid",
  panelId: 1,
  timeRange: {
    from: "now-1h",
    to: "now"
  },
  queryParams: {
    var-user: "john"
  }
})

// Get dashboard summary
mcp_grafana_get_dashboard_summary({ uid: "dashboard-uid" })

// Get specific dashboard property
mcp_grafana_get_dashboard_property({
  uid: "dashboard-uid",
  jsonPath: "$.panels[*].title"
})
```

## Context7 MCP Tools Quick Reference

### Library Documentation

```typescript
// Resolve library ID
mcp_context7_resolve_library_id({
  libraryName: "ws"  // or "ssh2", "prom-client", etc.
})

// Get library documentation
mcp_context7_get_library_docs({
  context7CompatibleLibraryID: "/npm/ws",
  topic: "connection-management",  // optional
  tokens: 10000  // optional, default 10000
})
```

### Common Library IDs

```
WebSocket:
  - /npm/ws
  - /npm/websocket

SSH:
  - /npm/ssh2
  - /npm/node-ssh

Monitoring:
  - /npm/prom-client
  - /npm/@opentelemetry/sdk-node
  - /npm/@opentelemetry/auto-instrumentations-node

Error Handling:
  - /npm/joi (validation)
  - /npm/zod (validation)
```

## Task-to-Tool Mapping

| Task | Primary Tools | Purpose |
|------|---------------|---------|
| 18.1 | `create_dashboard`, `query_prometheus` | Create tunnel health dashboard |
| 18.2 | `create_dashboard`, `query_prometheus` | Create performance dashboard |
| 18.3 | `create_dashboard`, `query_loki_logs`, `find_error_pattern_logs` | Create error tracking dashboard |
| 18.4 | `create_alert_rule`, `list_contact_points` | Set up critical alerts |
| 18.5 | `generate_deeplink` | Generate monitoring documentation |
| 19.1 | `resolve_library_id`, `get_library_docs` | Document WebSocket library |
| 19.2 | `resolve_library_id`, `get_library_docs` | Document SSH library |
| 19.3 | `resolve_library_id`, `get_library_docs` | Document monitoring libraries |
| 19.4 | `resolve_library_id`, `get_library_docs` | Document error handling patterns |
| 20.1 | `create_incident`, `generate_deeplink` | Create incidents for failures |
| 20.2 | `add_activity_to_incident`, `query_loki_logs`, `query_prometheus` | Add incident context |
| 20.3 | `query_prometheus` | Monitor circuit breaker state |

## Common Patterns

### Creating a Complete Monitoring Setup

```typescript
// 1. Verify datasources exist
const datasources = await mcp_grafana_list_datasources();
const prometheus = datasources.find(ds => ds.type === 'prometheus');
const loki = datasources.find(ds => ds.type === 'loki');

// 2. Create dashboards
const healthDash = await mcp_grafana_create_dashboard({
  dashboard: { title: "Tunnel Health", /* ... */ }
});

const perfDash = await mcp_grafana_create_dashboard({
  dashboard: { title: "Tunnel Performance", /* ... */ }
});

// 3. Create alerts
await mcp_grafana_create_alert_rule({
  title: "High Error Rate",
  /* ... */
});

// 4. Generate documentation links
const healthLink = await mcp_grafana_generate_deeplink({
  resourceType: "dashboard",
  dashboardUid: healthDash.uid
});
```

### Investigating an Incident

```typescript
// 1. Query metrics to understand the issue
const metrics = await mcp_grafana_query_prometheus({
  datasourceUid: prometheus.uid,
  expr: "rate(tunnel_errors_total[5m])",
  queryType: "range",
  startTime: "now-1h",
  endTime: "now"
});

// 2. Query logs for error details
const logs = await mcp_grafana_query_loki_logs({
  datasourceUid: loki.uid,
  logql: "{service=\"streaming-proxy\"} |= \"error\"",
  limit: 100
});

// 3. Find error patterns
const patterns = await mcp_grafana_find_error_pattern_logs({
  name: "Error Investigation",
  labels: { service: "streaming-proxy" }
});

// 4. Create incident with findings
const incident = await mcp_grafana_create_incident({
  title: "Tunnel Error Spike",
  severity: "critical",
  roomPrefix: "tunnel"
});

// 5. Add analysis to incident
await mcp_grafana_add_activity_to_incident({
  incidentId: incident.id,
  body: `Error rate spike detected. Patterns: ${patterns.join(', ')}`
});
```

### Documenting Implementation with Library References

```typescript
// 1. Resolve library ID
const wsLibId = await mcp_context7_resolve_library_id({
  libraryName: "ws"
});

// 2. Get documentation
const wsDocs = await mcp_context7_get_library_docs({
  context7CompatibleLibraryID: wsLibId,
  topic: "connection-management"
});

// 3. Reference in code comments
/*
 * WebSocket Connection Management
 * 
 * Based on official ws library documentation:
 * [Reference from wsDocs]
 * 
 * Best practices:
 * - Implement heartbeat mechanism
 * - Handle connection upgrades gracefully
 * - Implement proper close handshake
 */
```

## Error Handling

### Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| Datasource not found | Prometheus/Loki not configured | Run `list_datasources` to verify |
| Authentication failed | Invalid API key | Check Grafana API key in config |
| Dashboard creation failed | Invalid folder UID | Verify folder exists in Grafana |
| Alert rule failed | Invalid condition syntax | Check PromQL expression syntax |
| Library not found | Library name incorrect | Try alternative names or check support |
| Documentation empty | Limited library support | Try different topic or library |

## Performance Tips

1. **Limit Query Results**: Use `limit` parameter to reduce data transfer
2. **Use Time Ranges**: Specify `startTime` and `endTime` to limit data scope
3. **Filter by Labels**: Use label matchers to reduce query scope
4. **Cache Results**: Store frequently accessed documentation locally
5. **Batch Operations**: Group multiple dashboard updates into single call

## Security Considerations

1. **API Key Management**: Store Grafana API key securely
2. **Incident Sensitivity**: Don't include sensitive data in incident descriptions
3. **Log Filtering**: Filter logs to exclude sensitive information
4. **Access Control**: Use Grafana RBAC to limit tool access
5. **Audit Logging**: Enable audit logging for all MCP tool operations
