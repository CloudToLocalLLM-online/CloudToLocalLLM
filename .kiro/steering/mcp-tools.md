# MCP Tools

## Available Servers
- **Sequential Thinking** - Use for complex analysis (see `sequential-thinking-guidelines.md`)
- **Docker Hub** - Container repository management (`mcp_dockerhub_*`)
- **Playwright** - Browser automation (`mcp_playwright_*`)
- **Context7** - Library documentation (`mcp_context7_*`)
- **Grafana** - Monitoring and observability (`mcp_grafana_*`)

## Key Tools
- `mcp_dockerhub_listRepositoriesByNamespace()` - List repos
- `mcp_playwright_navigate()` - Browser testing
- `mcp_context7_resolve_library_id()` - Find docs
- `mcp_grafana_query_prometheus()` - Query metrics

## Configuration
All MCP servers configured in `.kiro/settings/mcp.json`
