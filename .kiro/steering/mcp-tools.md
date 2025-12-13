# MCP Tools Available

## CRITICAL: Sequential Thinking MCP Server

**ALWAYS USE FOR COMPLEX PROBLEMS**: The Sequential Thinking MCP server provides structured problem-solving capabilities that should be used for any complex analysis, debugging, or multi-step reasoning tasks.

### Configuration

The Sequential Thinking MCP server is configured in `.kiro/settings/mcp.json`:

```json
{
  "sequentialthinking": {
    "command": "uvx",
    "args": [
      "mcp-sequentialthinking"
    ],
    "disabled": false,
    "autoApprove": [
      "sequential_thinking"
    ]
  }
}
```

**Tools Available:** 1 powerful tool for structured reasoning

### Sequential Thinking Tool

**sequentialthinking** - Structured step-by-step problem analysis and reasoning
- Parameters: `thought` (string, required), `nextThoughtNeeded` (boolean, required), `thoughtNumber` (integer, required), `totalThoughts` (integer, required)
- Optional: `isRevision` (boolean), `revisesThought` (integer), `branchFromThought` (integer), `branchId` (string), `needsMoreThoughts` (boolean)
- Returns: Structured analysis with step-by-step reasoning that can adapt and evolve as understanding deepens

### When to Use Sequential Thinking

**MANDATORY for these scenarios:**
- **CI/CD workflow analysis and debugging** - Understanding complex deployment pipelines
- **Architecture decisions** - Evaluating system design choices
- **Multi-step troubleshooting** - Debugging complex issues with multiple potential causes
- **Infrastructure planning** - AWS/Azure deployment strategies
- **Code refactoring decisions** - Large-scale code changes
- **Performance optimization** - Analyzing bottlenecks and solutions
- **Security analysis** - Evaluating security implications
- **Migration planning** - Platform or technology migrations

**Example Usage:**
```javascript
// For complex CI/CD issues - Start with initial analysis
mcp_sequentialthinking_sequentialthinking({
  thought: "I need to analyze why CloudToLocalLLM deployment pipeline is not triggering cloud deployments for authentication changes. Let me start by understanding the expected flow: auth0-bridge.js changes should be detected by version-and-distribute.yml AI orchestrator, which should then trigger deploy-aks.yml via repository_dispatch.",
  nextThoughtNeeded: true,
  thoughtNumber: 1,
  totalThoughts: 5
})

// Continue with deeper analysis
mcp_sequentialthinking_sequentialthinking({
  thought: "Now I need to check the actual workflow execution logs to see if the AI orchestrator detected the auth changes and what decision it made about cloud deployment needs.",
  nextThoughtNeeded: true,
  thoughtNumber: 2,
  totalThoughts: 5
})

// Architecture decisions with branching thoughts
mcp_sequentialthinking_sequentialthinking({
  thought: "For the Azure to AWS migration, I need to consider multiple approaches. Let me branch into evaluating the blue-green deployment strategy first.",
  nextThoughtNeeded: true,
  thoughtNumber: 3,
  totalThoughts: 8,
  branchFromThought: 2,
  branchId: "blue-green-strategy"
})
```

### Sequential Thinking Best Practices

1. **Always start with Sequential Thinking** for complex problems before diving into specific tools
2. **Provide comprehensive context** in the problem description
3. **Include relevant constraints** (budget, time, technical limitations)
4. **Specify the desired outcome** or decision needed
5. **Use the analysis to guide subsequent tool usage**

### Integration with Other MCP Tools

Sequential Thinking should guide the use of other MCP tools:

1. **Analysis Phase**: Use Sequential Thinking to understand the problem
2. **Investigation Phase**: Use specific tools (Grafana, Docker Hub, etc.) based on the analysis
3. **Implementation Phase**: Use Sequential Thinking to plan the solution
4. **Validation Phase**: Use appropriate tools to verify the solution

## Docker Hub MCP Server

Docker Hub API access for managing container repositories.

### Configuration

The Docker Hub MCP server is configured in `.kiro/settings/mcp.json`:

```json
{
  "dockerhub": {
    "command": "docker",
    "args": [
      "mcp",
      "gateway",
      "run",
      "--servers",
      "dockerhub"
    ],
    "env": {
      "LOCALAPPDATA": "C:\\Users\\rightguy\\AppData\\Local",
      "ProgramData": "C:\\ProgramData",
      "ProgramFiles": "C:\\Program Files"
    },
    "disabled": false,
    "autoApprove": [
      "checkRepository",
      "checkRepositoryTag",
      "createRepository",
      "dockerHardenedImages",
      "getPersonalNamespace",
      "getRepositoryInfo",
      "getRepositoryTag",
      "listAllNamespacesMemberOf",
      "listNamespaces",
      "listRepositoriesByNamespace",
      "listRepositoryTags",
      "search",
      "updateRepositoryInfo"
    ]
  }
}
```

**Tools Available:** 13 tools for Docker Hub repository management

### Docker Hub Tools (13 Tools)

The `dockerhub` server provides Docker Hub API access:

1. **checkRepository** - Check if a repository exists in a namespace
   - Parameters: `namespace` (string), `repository` (string)

2. **checkRepositoryTag** - Check if a tag exists in a repository
   - Parameters: `namespace` (string), `repository` (string), `tag` (string)

3. **createRepository** - Create new repository in namespace (requires user confirmation)
   - Parameters: `namespace` (string, required), `name` (string, required), `description` (string, optional), `full_description` (string, optional), `is_private` (boolean, optional), `registry` (string, optional)

4. **dockerHardenedImages** - List Docker Hardened Images available in user organizations
   - Parameters: `organisation` (string)
   - Note: Call `listNamespaces` first to get available organizations

5. **getPersonalNamespace** - Get the personal namespace name
   - Parameters: None

6. **getRepositoryInfo** - Get detailed repository information
   - Parameters: `namespace` (string, required), `repository` (string, required)
   - Note: Use `library` namespace for official images

7. **getRepositoryTag** - Get details of a specific tag
   - Parameters: `namespace` (string), `repository` (string), `tag` (string)

8. **listAllNamespacesMemberOf** - List all namespaces user is a member of
   - Parameters: None

9. **listNamespaces** - List paginated namespaces
   - Parameters: `page` (number, optional), `page_size` (number, optional)

10. **listRepositoriesByNamespace** - List repositories in a namespace
    - Parameters: `namespace` (string, required), `page` (number, optional), `page_size` (number, optional), `ordering` (string, optional: "last_updated", "-last_updated", "name", "-name", "pull_count", "-pull_count"), `content_types` (string, optional), `media_types` (string, optional)

11. **listRepositoryTags** - List tags for a repository
    - Parameters: `repository` (string, required), `namespace` (string, optional), `page` (number, optional), `page_size` (number, optional), `architecture` (string, optional), `os` (string, optional)

12. **search** - Search Docker Hub repositories
    - Parameters: `query` (string, required), `from` (number, optional), `size` (number, optional), `sort` (string, optional), `order` (string, optional: "asc", "desc"), `architectures` (array, optional), `operating_systems` (array, optional), `badges` (array, optional: "official", "verified_publisher", "open_source"), `categories` (array, optional), `type` (string, optional), `extension_reviewed` (boolean, optional)

13. **updateRepositoryInfo** - Update repository details (description, overview, status)
    - Parameters: `namespace` (string, required), `repository` (string, required), `description` (string, optional), `full_description` (string, optional), `status` (string, optional: "active" or "inactive" - requires explicit user confirmation)

### Using Docker Hub Tools

Docker Hub tools are accessed with the `mcp_dockerhub_` prefix:

## Playwright MCP Server

Browser automation and end-to-end testing capabilities.

### Configuration

The Playwright MCP server is configured in `.kiro/settings/mcp.json`:

```json
{
  "playwright": {
    "command": "npx",
    "args": [
      "-y",
      "@executeautomation/playwright-mcp-server"
    ],
    "env": {
      "PLAYWRIGHT_HEADLESS": "true"
    },
    "disabled": false,
    "autoApprove": [
      "playwright_navigate",
      "playwright_screenshot",
      "playwright_click",
      "playwright_fill",
      "playwright_select",
      "playwright_hover",
      "playwright_evaluate",
      "playwright_close",
      "playwright_custom_user_agent",
      "playwright_get_visible_text",
      "playwright_console_logs",
      "playwright_get_visible_html"
    ]
  }
}
```

**Tools Available:** 11+ tools for browser automation

### Playwright Tools

1. **playwright_navigate** - Navigate to a URL
2. **playwright_screenshot** - Take page screenshots
3. **playwright_click** - Click elements
4. **playwright_fill** - Fill form inputs
5. **playwright_select** - Select dropdown options
6. **playwright_hover** - Hover over elements
7. **playwright_evaluate** - Execute JavaScript
8. **playwright_close** - Close browser
9. **playwright_custom_user_agent** - Set custom user agent
10. **playwright_get_visible_text** - Extract page text
11. **playwright_console_logs** - Get browser console logs
12. **playwright_get_visible_html** - Get page HTML

### Using Playwright Tools

Primary test URL: https://app.cloudtolocalllm.online

```javascript
// Navigate to application
mcp_playwright_playwright_navigate({ url: "https://app.cloudtolocalllm.online" })

// Take screenshot for verification
mcp_playwright_playwright_screenshot({ name: "homepage" })

// Click elements and fill forms
mcp_playwright_playwright_click({ selector: "#login-button" })
mcp_playwright_playwright_fill({ selector: "#email", value: "test@example.com" })

// Get page content
mcp_playwright_playwright_get_visible_text()
mcp_playwright_playwright_get_visible_html()

// Close browser when done
mcp_playwright_playwright_close()
```

## Context7 MCP Server

Up-to-date code documentation for libraries and frameworks.

### Configuration

The Context7 MCP server is configured in `.kiro/settings/mcp.json`:

```json
{
  "context7": {
    "command": "docker",
    "args": [
      "mcp",
      "gateway",
      "run",
      "--servers",
      "context7"
    ],
    "env": {
      "LOCALAPPDATA": "C:\\Users\\rightguy\\AppData\\Local",
      "ProgramData": "C:\\ProgramData",
      "ProgramFiles": "C:\\Program Files"
    },
    "disabled": false,
    "autoApprove": [
      "get-library-docs",
      "resolve-library-id"
    ]
  }
}
```

**Tools Available:** 2 tools for library documentation

### Context7 Tools (2 Tools)

1. **resolve-library-id** - Resolve package name to Context7 library ID
   - Parameters: `libraryName` (string, required)
   - Returns: Context7-compatible library ID

2. **get-library-docs** - Fetch documentation for a library
   - Parameters: `context7CompatibleLibraryID` (string, required), `topic` (string, optional), `tokens` (number, optional)
   - Returns: Up-to-date documentation for the library

### Using Context7 Tools

Context7 tools are accessed with the `mcp_context7_` prefix:

```javascript
// Check if repository exists
mcp_dockerhub_checkRepository({ 
  namespace: "cloudtolocalllm", 
  repository: "cloudtolocalllm-web" 
})

// List repositories in namespace
mcp_dockerhub_listRepositoriesByNamespace({ 
  namespace: "cloudtolocalllm",
  ordering: "-last_updated"
})

// Get repository details
mcp_dockerhub_getRepositoryInfo({ 
  namespace: "cloudtolocalllm", 
  repository: "cloudtolocalllm-web" 
})

// List repository tags
mcp_dockerhub_listRepositoryTags({
  repository: "cloudtolocalllm-web",
  namespace: "cloudtolocalllm"
})

// Search Docker Hub
mcp_dockerhub_search({ 
  query: "nginx",
  badges: ["official"]
})

// Get personal namespace
mcp_dockerhub_getPersonalNamespace()

// List all namespaces user is member of
mcp_dockerhub_listAllNamespacesMemberOf()

// Create repository (requires user confirmation)
mcp_dockerhub_createRepository({
  namespace: "cloudtolocalllm",
  name: "new-repo",
  description: "My new repository",
  is_private: false
})

// Update repository info
mcp_dockerhub_updateRepositoryInfo({
  namespace: "cloudtolocalllm",
  repository: "cloudtolocalllm-web",
  description: "Updated description"
})
```

```javascript
// Resolve library ID first
mcp_context7_resolve_library_id({ libraryName: "react" })

// Get library documentation
mcp_context7_get_library_docs({ 
  context7CompatibleLibraryID: "/facebook/react",
  topic: "hooks",
  tokens: 10000
})
```



## Grafana Integration

Grafana is configured for monitoring and observability of the CloudToLocalLLM system via Docker MCP gateway.

### Grafana API Configuration

**API Key:** Set via `GRAFANA_API_KEY` environment variable
- **Permissions**: Admin access
- **Setup**: Configured in Docker MCP gateway (mcp/grafana server)
- **Purpose**: Programmatic access to Grafana dashboards, datasources, and alerts
- **Access Method**: Docker MCP gateway with `grafana` server enabled

### Grafana Access

- **URL**: https://grafana.cloudtolocalllm.online (when deployed)
- **Local Development**: http://localhost:3000 (if running locally)
- **Default Credentials**: Check deployment documentation

### Using Grafana API

The Grafana API can be used to:
- Query metrics and time-series data
- Create and manage dashboards
- Configure datasources (Prometheus, etc.)
- Set up alerts and notifications
- Manage users and permissions

### Grafana Datasources

Common datasources configured:
- **Prometheus**: Metrics collection and querying
- **Loki**: Log aggregation
- **Jaeger**: Distributed tracing (if enabled)

### Monitoring Dashboards

Key dashboards for CloudToLocalLLM:
- **System Health**: Overall system status and uptime
- **SSH Connections**: SSH tunnel metrics and performance
- **WebSocket Performance**: Real-time connection metrics
- **Error Rates**: Error tracking and categorization
- **Resource Usage**: CPU, memory, and network metrics

### Grafana MCP Server Tools

Available tools through the Grafana MCP server (100+ tools):
- **Dashboards**: `search_dashboards`, `get_dashboard_by_uid`, `get_dashboard_summary`, `update_dashboard`, `get_dashboard_panel_queries`
- **Datasources**: `list_datasources`, `get_datasource_by_uid`, `get_datasource_by_name`
- **Prometheus**: `query_prometheus`, `list_prometheus_metric_names`, `list_prometheus_label_names`, `list_prometheus_label_values`
- **Loki**: `query_loki_logs`, `query_loki_stats`, `list_loki_label_names`, `list_loki_label_values`
- **Alerts**: `list_alert_rules`, `get_alert_rule_by_uid`, `create_alert_rule`, `update_alert_rule`, `delete_alert_rule`
- **Annotations**: `get_annotations`, `create_annotation`, `update_annotation`, `patch_annotation`
- **OnCall**: `list_oncall_schedules`, `get_current_oncall_users`, `list_oncall_teams`, `list_alert_groups`
- **Incidents**: `list_incidents`, `get_incident`, `create_incident`, `add_activity_to_incident`
- **Teams**: `list_teams`, `list_users_by_org`
- **Monitoring**: `find_slow_requests`, `find_error_pattern_logs`, `get_assertions`

### Using Grafana Tools

Grafana tools are accessed with the `mcp_grafana_` prefix:

```javascript
// Query Prometheus metrics
mcp_grafana_query_prometheus({
  datasourceUid: "prometheus-uid",
  expr: "up",
  queryType: "instant",
  startTime: "now-1h"
})

// Search dashboards
mcp_grafana_search_dashboards({ query: "CloudToLocalLLM" })

// Get dashboard details
mcp_grafana_get_dashboard_by_uid({ uid: "dashboard-uid" })

// Query Loki logs
mcp_grafana_query_loki_logs({
  datasourceUid: "loki-uid",
  logql: '{app="cloudtolocalllm"}',
  limit: 100
})

// List alert rules
mcp_grafana_list_alert_rules({ limit: 50 })

// Create incident
mcp_grafana_create_incident({
  title: "Service Outage",
  severity: "high",
  roomPrefix: "incident"
})
```

### Best Practices

- Use Docker Hub MCP tools to manage container repositories
- Use Grafana for real-time monitoring and alerting
- Regularly review Grafana dashboards for system health
- Configure alerts for critical metrics and thresholds
- Keep MCP servers updated and monitor their status
