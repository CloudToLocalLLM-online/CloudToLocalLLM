---
inclusion: always
---

# MCP Tools Usage Guidelines for CloudToLocalLLM

## Core Principle: Proactive Tool Usage
Always use MCP tools to gather context before making recommendations. Never ask users for information that tools can provide directly.

## Memory Management - Knowledge Persistence

Create entities for Flutter/Dart components, Node.js services, Docker containers, and deployment configurations. Track relationships between services, dependencies, and architectural patterns specific to this multi-tenant LLM proxy system.

### CloudToLocalLLM Entity Types
- **Services**: `api-backend`, `streaming-proxy`, `flutter-app`, `nginx-proxy`
- **Components**: Auth0 integration, WebSocket handlers, container orchestration
- **Infrastructure**: Docker containers, SSL certificates, deployment scripts
- **Models**: `TunnelMessage`, user sessions, proxy configurations

## Filesystem Operations - Project Structure Awareness

### CloudToLocalLLM File Priorities
- **Flutter**: `lib/` directory structure, `pubspec.yaml`, platform configs
- **Backend**: `api-backend/`, `streaming-proxy/` services and configs
- **Docker**: `docker-compose.yml`, Dockerfiles, container configurations
- **Scripts**: `scripts/deploy/`, build automation, version management
- **Config**: SSL certificates, nginx configs, systemd services

### Essential Patterns
```bash
# Always start with structure understanding
mcp_filesystem_list_allowed_directories
mcp_filesystem_directory_tree

# Read related files together for context
mcp_filesystem_read_multiple_files(['pubspec.yaml', 'docker-compose.yml'])

# Search for specific patterns
mcp_filesystem_search_files(pattern='*.dart', path='lib/')
```

## Git Operations - Version Control Context

### CloudToLocalLLM Git Workflow
Always check repository state before code changes. This project uses semantic versioning and automated deployment pipelines that require clean git state.

```bash
# Essential git context gathering
mcp_git_git_status    # Check for uncommitted changes
mcp_git_git_log       # Review recent development activity
mcp_git_git_diff_unstaged  # See pending modifications

# Before deployment recommendations
mcp_git_git_diff_staged    # Verify staged changes
mcp_git_git_show          # Examine specific commits
```

## Internet Access - Research and Dependencies

Use fetch tools for Flutter/Dart package updates, Node.js dependency checks, and researching deployment issues. Essential for maintaining current versions in this rapidly evolving stack.

```bash
# Check Flutter/Dart package versions
mcp_fetch_fetch('https://pub.dev/api/packages/go_router')

# Research Docker deployment patterns
mcp_fetch_fetch('https://docs.docker.com/compose/')

# Investigate Auth0 integration issues
mcp_fetch_fetch('https://auth0.com/docs/quickstart/spa/flutter')
```

## CloudToLocalLLM Specific Workflows

### Flutter Development Analysis
1. `mcp_git_git_status` - Check for uncommitted Dart/Flutter changes
2. `mcp_filesystem_read_multiple_files(['pubspec.yaml', 'lib/main.dart'])` - Core app structure
3. `mcp_filesystem_search_files(pattern='*.dart', path='lib/services')` - Service layer analysis
4. `mcp_memory_create_entities` - Document Flutter components and state management

### Docker Deployment Investigation
1. `mcp_filesystem_read_file('docker-compose.yml')` - Container orchestration
2. `mcp_filesystem_read_multiple_files(['api-backend/package.json', 'streaming-proxy/package.json'])` - Service dependencies
3. `mcp_git_git_log(max_count=5)` - Recent deployment changes
4. `mcp_memory_create_relations` - Map service dependencies and container relationships

### Auth0 Integration Debugging
1. `mcp_filesystem_search_files(pattern='auth', path='lib/')` - Find auth-related files
2. `mcp_fetch_fetch('https://auth0.com/docs/quickstart/spa/flutter')` - Latest Auth0 Flutter docs
3. `mcp_git_git_diff_unstaged` - Check for auth configuration changes
4. `mcp_memory_add_observations` - Document auth flow and token handling

## Performance and Efficiency

### Parallel Operations
Execute multiple MCP tools simultaneously for faster context gathering:
- Combine `mcp_git_git_status` + `mcp_filesystem_directory_tree`
- Read multiple config files: `pubspec.yaml`, `docker-compose.yml`, `package.json`
- Fetch documentation while analyzing local code structure

### CloudToLocalLLM Optimization
- Use `head` parameter for large log files in `scripts/` directory
- Cache Docker container relationships in memory entities
- Batch read Flutter widget files for UI analysis

## Mandatory Usage Rules

**NEVER** ask users to provide:
- File contents (use `mcp_filesystem_read_file`)
- Directory structure (use `mcp_filesystem_list_directory`)
- Git status (use `mcp_git_git_status`)
- Current time for deployments (use `mcp_time_get_current_time`)

**ALWAYS** gather context first:
- Check git state before code recommendations
- Read related configuration files together
- Document discoveries in memory for future reference
- Use internet access for dependency and documentation research