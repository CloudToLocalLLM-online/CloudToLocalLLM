# MCP Tools Available in CloudToLocalLLM

This document describes the Model Context Protocol (MCP) tools configured for the CloudToLocalLLM project in Kiro IDE.

## Configured MCP Servers

### Git Integration (`mcp_git_*`)
**Purpose**: Complete Git repository operations and version control
**Status**: ✅ Working
**Key Functions**:
- `mcp_git_git_status`: Check repository status and working tree
- `mcp_git_git_log`: View commit history with filtering options
- `mcp_git_git_diff`: See changes between commits, staged/unstaged
- `mcp_git_git_add`: Stage files for commit
- `mcp_git_git_commit`: Create commits with conventional commit format
- `mcp_git_git_branch`: List, create, delete, and manage branches
- `mcp_git_git_checkout`: Switch branches or restore files
- `mcp_git_git_merge`: Merge branches with conflict resolution
- `mcp_git_git_push`: Push changes to remote repositories
- `mcp_git_git_pull`: Fetch and merge from remote repositories
- `mcp_git_git_stash`: Manage stashed changes
- `mcp_git_git_reset`: Reset HEAD to specific states
- `mcp_git_git_rebase`: Reapply commits on different base
- `mcp_git_git_tag`: Create and manage tags
- `mcp_git_git_remote`: Manage remote repositories
- `mcp_git_git_show`: Show Git objects (commits, tags, files)
- `mcp_git_git_cherry_pick`: Apply specific commits
- `mcp_git_git_clean`: Remove untracked files (with safety checks)
- `mcp_git_git_worktree`: Manage multiple working trees

**Usage Example**: Complete Git workflow management from staging to deployment, branch management, and collaborative development.

### SQLite Database (`mcp_sqlite_*`)
**Purpose**: Database operations for Flutter app's SQLite database
**Status**: ✅ Working
**Database Path**: `./data/app.db`
**Key Functions**:
- `mcp_sqlite_read_query`: Execute SELECT queries with full SQL support
- `mcp_sqlite_write_query`: Execute INSERT/UPDATE/DELETE queries
- `mcp_sqlite_create_table`: Create new database tables
- `mcp_sqlite_list_tables`: List all database tables
- `mcp_sqlite_describe_table`: Get detailed table schema information

**Usage Example**: Query user data, conversation history, app configuration, and manage database schema changes during development.

### Memory Management (`mcp_memory_*`)
**Purpose**: Persistent memory and knowledge graph for AI context
**Status**: ✅ Working
**Package**: `@modelcontextprotocol/server-memory`
**Key Functions**:
- `mcp_memory_create_entities`: Create knowledge entities with types and observations
- `mcp_memory_create_relations`: Link entities with typed relationships
- `mcp_memory_add_observations`: Add new information to existing entities
- `mcp_memory_search_nodes`: Search through stored knowledge by query
- `mcp_memory_open_nodes`: Retrieve specific entities by name
- `mcp_memory_read_graph`: Read the entire knowledge graph
- `mcp_memory_delete_entities`: Remove entities and their relations
- `mcp_memory_delete_observations`: Remove specific observations
- `mcp_memory_delete_relations`: Remove specific relationships

**Usage Example**: Store project knowledge, remember development decisions, track architectural patterns, and maintain context across development sessions.

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
- `mcp_playwright_browser_navigate`: Navigate to URLs with wait conditions
- `mcp_playwright_browser_navigate_back`: Go back in browser history
- `mcp_playwright_browser_navigate_forward`: Go forward in browser history
- `mcp_playwright_browser_snapshot`: Get accessibility snapshot for actions
- `mcp_playwright_browser_take_screenshot`: Take full page or element screenshots
- `mcp_playwright_browser_click`: Click elements with various options
- `mcp_playwright_browser_type`: Type text into form fields
- `mcp_playwright_browser_press_key`: Press keyboard keys
- `mcp_playwright_browser_hover`: Hover over elements
- `mcp_playwright_browser_drag`: Drag and drop between elements
- `mcp_playwright_browser_select_option`: Select dropdown options
- `mcp_playwright_browser_evaluate`: Execute JavaScript on page
- `mcp_playwright_browser_wait_for`: Wait for text/elements/time
- `mcp_playwright_browser_resize`: Resize browser window
- `mcp_playwright_browser_handle_dialog`: Handle browser dialogs
- `mcp_playwright_browser_file_upload`: Upload files to forms
- `mcp_playwright_browser_console_messages`: Get console output
- `mcp_playwright_browser_network_requests`: Monitor network traffic
- `mcp_playwright_browser_tab_*`: Manage multiple browser tabs
- `mcp_playwright_browser_close`: Close browser session

**Usage Example**: Comprehensive testing of CloudToLocalLLM web interface, automated user workflows, screenshot documentation, and performance monitoring.

### Auth0 Management (`mcp_auth0_*`)
**Purpose**: Auth0 tenant management and configuration
**Status**: ✅ Working
**Package**: `@auth0/auth0-mcp-server`
**Key Functions**:
- `mcp_auth0_auth0_list_applications`: List all applications in tenant
- `mcp_auth0_auth0_get_application`: Get specific application details
- `mcp_auth0_auth0_create_application`: Create new applications
- `mcp_auth0_auth0_update_application`: Update existing applications
- `mcp_auth0_auth0_list_resource_servers`: List API resources
- `mcp_auth0_auth0_get_resource_server`: Get specific API details
- `mcp_auth0_auth0_create_resource_server`: Create new APIs
- `mcp_auth0_auth0_update_resource_server`: Update existing APIs
- `mcp_auth0_auth0_list_actions`: List Auth0 Actions
- `mcp_auth0_auth0_get_action`: Get specific Action details
- `mcp_auth0_auth0_create_action`: Create new Actions
- `mcp_auth0_auth0_update_action`: Update existing Actions
- `mcp_auth0_auth0_deploy_action`: Deploy Actions to production
- `mcp_auth0_auth0_list_logs`: Query Auth0 logs with filters
- `mcp_auth0_auth0_get_log`: Get specific log entry details
- `mcp_auth0_auth0_list_forms`: List custom forms
- `mcp_auth0_auth0_get_form`: Get form configuration
- `mcp_auth0_auth0_create_form`: Create custom forms
- `mcp_auth0_auth0_update_form`: Update form configurations

**Usage Example**: Complete Auth0 tenant management, application configuration, API setup, custom Actions deployment, and security monitoring through logs.

## Development Workflow Integration

### Code Development
1. **Use Git MCP** for complete version control workflow (branching, merging, tagging)
2. **Use Memory MCP** to store architectural decisions, patterns, and project knowledge
3. **Use Context7 MCP** to get current Flutter/Dart documentation and API references
4. **Use SQLite MCP** to query app database, manage schema, and debug data issues

### Testing & QA
1. **Use Playwright MCP** for comprehensive web interface testing and automation
2. **Use Git MCP** to manage feature branches, releases, and hotfixes
3. **Use Memory MCP** to track test results, known issues, and testing strategies
4. **Use Auth0 MCP** to verify authentication flows and security configurations

### Authentication & Security
1. **Use Auth0 MCP** for complete tenant management and security monitoring
2. **Use Memory MCP** to document security decisions and compliance requirements
3. **Use SQLite MCP** to verify user data handling and privacy compliance
4. **Use Git MCP** to track security-related changes and audit trails

### DevOps & Deployment
1. **Use Git MCP** for release management, tagging, and deployment tracking
2. **Use Playwright MCP** for automated deployment verification and smoke testing
3. **Use Auth0 MCP** to manage production authentication configurations
4. **Use Memory MCP** to document deployment procedures and rollback strategies

## Best Practices

### Memory Management
- Create entities for major architectural components, features, and decisions
- Use typed relations to link related concepts (implements, depends_on, extends)
- Store important decisions with rationale and context in observations
- Track evolution of ideas and architectural changes over time
- Use search to find existing knowledge before creating duplicates

### Documentation Access
- Always use `resolve_library_id` before `get_library_docs` for Context7
- Focus searches on specific topics rather than broad queries
- Specify token limits based on context needs (default: 10000)
- Cache frequently accessed documentation in Memory MCP

### Database Operations
- Use `describe_table` to understand schema before complex queries
- Always use read queries for data exploration and debugging
- Be cautious with write operations, especially on production data
- Use transactions for multi-step database operations when possible
- Regularly backup database before schema changes

### Version Control
- Always check `git_status` before making changes
- Use conventional commit format: `type(scope): description`
- Review diffs with `git_diff` before committing
- Create feature branches for significant changes
- Use `git_stash` to temporarily save work when switching contexts
- Tag releases with semantic versioning

### Browser Automation
- Always take `browser_snapshot` before interacting with elements
- Use element references from snapshots for reliable automation
- Handle dialogs and popups appropriately with `handle_dialog`
- Monitor network requests for API testing and debugging
- Take screenshots for documentation and issue reporting

### Auth0 Management
- Use logs to monitor authentication issues and security events
- Test Actions in development before deploying to production
- Keep application configurations synchronized across environments
- Monitor resource server scopes and permissions regularly
- Document custom forms and their integration points

## Troubleshooting

### Common Issues
1. **SQLite database not found**: Check if `./data/app.db` exists or create with `create_table`
2. **Memory server connection issues**: Restart MCP servers in Kiro IDE
3. **Context7 library not found**: Always use `resolve_library_id` before `get_library_docs`
4. **Git merge conflicts**: Use `git_status` and `git_diff` to understand conflicts before resolving
5. **Playwright element not found**: Take fresh `browser_snapshot` to get current element references
6. **Auth0 rate limiting**: Space out API calls and use pagination for large datasets

### MCP Server Status
✅ **All servers working**: Git, SQLite, Memory, Context7, Playwright, Auth0
- Check MCP server logs in Kiro IDE to diagnose connection issues
- Servers automatically reconnect when configuration changes are detected
- Use the MCP Server view in Kiro feature panel to monitor status
- Restart individual servers if they become unresponsive

### Restarting MCP Tools When They Fail

#### Method 1: Kiro IDE Interface (Recommended)
1. **Open MCP Server View**: 
   - Go to Kiro feature panel → MCP Server view
   - Or use Command Palette (Ctrl+Shift+P) → "MCP: Show Server Status"

2. **Individual Server Restart**:
   - Find the failing server in the list
   - Click the restart button next to the server name
   - Wait for status to change from "Disconnected" to "Connected"

3. **Restart All Servers**:
   - Use Command Palette → "MCP: Restart All Servers"
   - This restarts all configured MCP servers simultaneously

#### Method 2: Configuration File Changes
1. **Edit MCP Configuration**:
   - Open `.kiro/settings/mcp.json` (workspace) or `~/.kiro/settings/mcp.json` (user)
   - Make a minor change (add/remove a comment or space)
   - Save the file - servers will automatically reconnect

2. **Toggle Server Disabled Status**:
   ```json
   {
     "mcpServers": {
       "memory": {
         "disabled": true,  // Set to true, save, then set to false and save again
         "command": "uvx",
         "args": ["@modelcontextprotocol/server-memory"]
       }
     }
   }
   ```

#### Method 3: Command Palette Options
- **"MCP: Reconnect Server"** - Reconnect specific server
- **"MCP: Restart Server"** - Full restart of specific server
- **"MCP: Reload Configuration"** - Reload MCP config without restart
- **"MCP: Show Server Logs"** - View detailed server logs for debugging

#### Method 4: Kiro IDE Restart (Last Resort)
If multiple servers are failing or the MCP system is unresponsive:
1. Save all work
2. Close Kiro IDE completely
3. Reopen Kiro IDE
4. MCP servers will automatically start with the IDE

#### Troubleshooting Specific Server Types

**Git MCP Server Issues**:
- Ensure you're in a valid Git repository
- Check if Git is installed and accessible in PATH
- Verify repository permissions

**SQLite MCP Server Issues**:
- Verify database file exists at `./data/app.db`
- Check file permissions for read/write access
- Ensure SQLite is not locked by another process

**Memory MCP Server Issues**:
- Check if `uvx` and `uv` are properly installed
- Verify network connectivity for package downloads
- Clear uvx cache: `uvx --clear-cache`

**Context7 MCP Server Issues**:
- Verify internet connectivity for documentation access
- Check if API rate limits are being hit
- Restart with fresh session

**Playwright MCP Server Issues**:
- Ensure browser dependencies are installed
- Run `mcp_playwright_browser_install` if browser missing
- Check system permissions for browser automation

**Auth0 MCP Server Issues**:
- Verify Auth0 credentials and permissions
- Check network connectivity to Auth0 APIs
- Validate tenant configuration

#### Prevention Tips
1. **Regular Health Checks**: Periodically check MCP Server view for status
2. **Monitor Logs**: Watch for error patterns in server logs
3. **Update Dependencies**: Keep `uv` and `uvx` updated for package-based servers
4. **Resource Management**: Close unused browser sessions in Playwright
5. **Configuration Validation**: Test MCP config changes in development first

#### Emergency Recovery
If all MCP servers fail to start:
1. **Backup current config**: Copy `.kiro/settings/mcp.json`
2. **Reset to minimal config**:
   ```json
   {
     "mcpServers": {
       "memory": {
         "command": "uvx",
         "args": ["@modelcontextprotocol/server-memory"],
         "disabled": false
       }
     }
   }
   ```
3. **Test single server**: Verify one server works before adding others
4. **Gradually restore**: Add servers one by one to identify problematic configurations

### Performance Tips
- **Git**: Use `git_log` with `maxCount` parameter for large repositories
- **SQLite**: Use indexed columns in WHERE clauses for faster queries
- **Memory**: Batch entity creation and relation updates when possible
- **Context7**: Specify focused topics and reasonable token limits
- **Playwright**: Use `wait_for` conditions instead of fixed delays
- **Auth0**: Use pagination and filtering to reduce API response sizes

### Security Considerations
- **SQLite**: Never expose database queries directly to user input
- **Git**: Review sensitive data before committing (use `git_diff`)
- **Auth0**: Monitor logs for suspicious authentication patterns
- **Playwright**: Be cautious when automating actions on production systems
- **Memory**: Don't store sensitive information in knowledge graph observations

### Debugging Workflow
1. **Check MCP server connectivity** in Kiro IDE
2. **Use appropriate read operations** before write operations
3. **Review logs and status** before troubleshooting complex issues
4. **Test with minimal examples** to isolate problems
5. **Document solutions** in Memory MCP for future reference