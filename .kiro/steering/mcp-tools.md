# MCP Tools Available in CloudToLocalLLM

This document describes the Model Context Protocol (MCP) tools configured for the CloudToLocalLLM project in Kiro IDE.

## Configured MCP Servers

### Git Integration (`mcp_git_*`)
**Purpose**: Git repository operations and version control
**Status**: ✅ Working
**Key Functions**:
- `mcp_git_git_status`: Check repository status
- `mcp_git_git_log`: View commit history  
- `mcp_git_git_diff_unstaged`: See unstaged changes
- `mcp_git_git_add`: Stage files for commit
- `mcp_git_git_commit`: Create commits

**Usage Example**: Use for tracking changes, reviewing history, and managing version control during development.

### SQLite Database (`mcp_sqlite_*`)
**Purpose**: Database operations for Flutter app's SQLite database
**Status**: ✅ Working
**Database Path**: `./data/app.db`
**Key Functions**:
- `mcp_sqlite_read_query`: Execute SELECT queries
- `mcp_sqlite_list_tables`: List all database tables
- `mcp_sqlite_describe_table`: Get table schema information
- `mcp_sqlite_write_query`: Execute INSERT/UPDATE/DELETE queries

**Usage Example**: Query user data, conversation history, and app configuration stored in SQLite.

### Memory Management (`mcp_memory_*`)
**Purpose**: Persistent memory and knowledge graph for AI context
**Status**: ✅ Working
**Package**: `@modelcontextprotocol/server-memory`
**Key Functions**:
- `mcp_memory_create_entities`: Create knowledge entities
- `mcp_memory_search_nodes`: Search through stored knowledge
- `mcp_memory_add_observations`: Add information to entities
- `mcp_memory_create_relations`: Link entities together

**Usage Example**: Store project knowledge, remember development decisions, and maintain context across sessions.

### Context7 Documentation (`mcp_context7_*`)
**Purpose**: Access up-to-date documentation for libraries and frameworks
**Status**: ✅ Working
**Package**: `@upstash/context7-mcp`
**Key Functions**:
- `mcp_context7_resolve_library_id`: Find library documentation
- `mcp_context7_get_library_docs`: Retrieve specific documentation
- Search for Flutter, Dart, and other framework documentation

**Usage Example**: Get current Flutter documentation, API references, and code examples during development.

### Playwright Browser Automation (`mcp_playwright_*`)
**Purpose**: Web browser automation and testing
**Status**: ✅ Working
**Package**: `@playwright/mcp` (official Microsoft Playwright MCP server)
**Key Functions**:
- `mcp_playwright_browser_navigate`: Navigate to URLs
- `mcp_playwright_browser_take_screenshot`: Take screenshots
- `mcp_playwright_browser_click`: Click elements
- `mcp_playwright_browser_fill`: Fill form inputs
- `mcp_playwright_browser_snapshot`: Get page accessibility snapshot

**Usage Example**: Test the CloudToLocalLLM web interface, automate browser interactions, take screenshots for documentation.

### Auth0 Management (`mcp_auth0_*`)
**Purpose**: Auth0 tenant management and configuration
**Status**: ✅ Working (limited scope)
**Package**: `@auth0/auth0-mcp-server`
**Key Functions**:
- `mcp_auth0_auth0_list_resource_servers`: List API resources ✅
- `mcp_auth0_auth0_get_application`: Get app configuration (requires additional scopes)
- `mcp_auth0_auth0_create_application`: Create new applications (requires additional scopes)

**Current Capabilities**: Can list resource servers for CloudToLocalLLM tenant. Additional functions require expanded OAuth scopes.
**Usage Example**: View Auth0 API resources, monitor CloudToLocalLLM authentication configuration.

## Development Workflow Integration

### Code Development
1. **Use Git MCP** to track changes and manage branches
2. **Use Memory MCP** to store architectural decisions and patterns
3. **Use Context7 MCP** to get Flutter/Dart documentation
4. **Use SQLite MCP** to query app database during debugging

### Testing & QA
1. **Use Playwright MCP** to automate web interface testing
2. **Use Git MCP** to manage test branches and releases
3. **Use Memory MCP** to track test results and issues

### Authentication & Security
1. **Use Auth0 MCP** to manage authentication configuration
2. **Use Memory MCP** to document security decisions
3. **Use SQLite MCP** to verify user data handling

## Best Practices

### Memory Management
- Create entities for major architectural components
- Link related concepts with relations
- Store important decisions and their rationale
- Use observations to track evolution of ideas

### Documentation Access
- Use Context7 for current Flutter/Dart API references
- Resolve library IDs before getting documentation
- Focus searches on specific topics when possible

### Database Operations
- Always use read queries for data exploration
- Be cautious with write operations on production data
- Use describe_table to understand schema before queries

### Version Control
- Check status before making changes
- Use descriptive commit messages
- Review diffs before committing changes

## Troubleshooting

### Common Issues
1. **SQLite database not found**: Check if `./data/app.db` exists or create it
2. **Memory server connection issues**: Restart MCP servers in Kiro
3. **Context7 library not found**: Use `resolve_library_id` before `get_library_docs`
4. **Auth0 insufficient permissions**: Some functions require additional OAuth scopes

### MCP Server Status
✅ **All servers working**: Git, SQLite, Memory, Context7, Playwright, Auth0
- Check MCP server logs in Kiro IDE to diagnose any connection issues
- Servers automatically reconnect when configuration changes are detected
- Use the MCP Server view in Kiro feature panel to monitor status

### Performance Tips
- **Playwright**: Screenshots are saved to temp directory, use for testing/documentation
- **Memory**: Create entities for major components, use relations to link concepts
- **Context7**: Search specific topics rather than broad queries for better results
- **Git**: Check status before making changes to avoid conflicts