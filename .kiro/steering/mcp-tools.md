# MCP Tools Available

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

Available tools through the Grafana MCP server:
- `query_datasource` - Query metrics from datasources
- `list_dashboards` - List all dashboards
- `get_dashboard` - Get dashboard details
- `create_dashboard` - Create new dashboard
- `update_dashboard` - Update existing dashboard
- `delete_dashboard` - Delete dashboard
- `list_datasources` - List configured datasources
- `get_datasource` - Get datasource details
- `create_datasource` - Add new datasource
- `update_datasource` - Update datasource configuration
- `delete_datasource` - Remove datasource
- `list_alerts` - List configured alerts
- `get_alert` - Get alert details
- `create_alert` - Create new alert
- `update_alert` - Update alert configuration
- `delete_alert` - Delete alert

### Best Practices

- Use Docker Hub MCP tools to manage container repositories
- Use Grafana for real-time monitoring and alerting
- Regularly review Grafana dashboards for system health
- Configure alerts for critical metrics and thresholds
- Keep MCP servers updated and monitor their status
