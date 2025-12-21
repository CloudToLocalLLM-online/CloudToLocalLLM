# MCP Tools & Workflow Integration

## Core Identity: Kilocode
Kilocode utilizes the following MCP tools as part of a documentation-first, systematic workflow. All complex tasks must be processed through the [Sequential Thinking Framework](sequential-thinking-guidelines.md).

## Available Servers & Capabilities

### Core Framework
- **Sequential Thinking** ([`mcp_sequentialthinking_sequentialthinking`](.kiro/steering/sequential-thinking-guidelines.md)) - **Mandatory** primary framework for systematic analysis and iterative reasoning.

### External Integrations
- **Sentry** ([`mcp_sentry_*`](https://sentry.io)) - Production error tracking and detailed stacktrace analysis.
- **n8n-mcp** ([`mcp_n8n-mcp_*`](https://n8n.io)) - Automation workflow management and node documentation.
- **Context7** ([`mcp_context7_*`](https://context7.com)) - Up-to-date library documentation and code examples (use `resolve_library_id` first).
- **Playwright** ([`mcp_playwright_*`](https://playwright.dev)) - End-to-end testing and browser automation.
- **Auth0** ([`mcp_auth0_*`](https://auth0.com)) - Identity management and application security.
- **Grafana** ([`mcp_grafana_*`](https://grafana.com)) - Monitoring, metrics, and observability.
- **Docker Hub** ([`mcp_dockerhub_*`](https://hub.docker.com)) - Container registry management and image verification.
- **GitHub** ([`mcp_github_*`](https://github.com)) - Repository management, PR reviews, and CI/CD orchestration.

## Methodology
1.  **Documentation-First**: Always review local `docs/` or `.kiro/steering/` files before tool execution.
2.  **Systematic Reasoning**: Use Sequential Thinking to hypothesize, verify, and self-correct.
3.  **Workspace Hooks**: Leverage [`.kiro/hooks/`](.kiro/hooks/) (e.g., `code-quality-analyzer`) to maintain technical excellence.

## Configuration
All local MCP servers are defined in [`.kiro/settings/mcp.json`](.kiro/settings/mcp.json).
