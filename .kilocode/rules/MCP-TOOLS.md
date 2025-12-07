# MCP Tools Documentation

This document provides detailed documentation and usage guidelines for the Model Context Protocol (MCP) tools available in this environment.

## Table of Contents
- [Playwright](#playwright)
- [Context7](#context7)
- [n8n MCP](#n8n-mcp)

---

## Playwright
**Server:** `playwright`

### Description
Provides browser automation capabilities for testing, scraping, and interacting with web pages.

### Key Tools
- `browser_navigate`: Navigate to a URL.
- `browser_click`: Click an element.
- `browser_type`: Type text into an input field.
- `browser_take_screenshot`: Capture a screenshot of the page.
- `browser_evaluate`: Execute JavaScript on the page.

### Usage
Use this tool for:
- End-to-end testing of web applications.
- Verifying UI elements and interactions.
- Automating browser-based tasks.

### Example (Navigate)
```json
{
  "url": "https://example.com"
}
```

---

## Context7
**Server:** `context7`

### Description
Retrieves up-to-date documentation and code examples for libraries and frameworks.

### Key Tools
- `resolve-library-id`: Find the correct library ID for a given name.
- `get-library-docs`: Fetch documentation for a specific library.

### Usage
Use this tool when you need:
- Accurate API references.
- Code examples for specific libraries.
- To understand how to use a third-party package.

### Workflow
1. Call `resolve-library-id` with the library name.
2. Use the returned `context7CompatibleLibraryID` to call `get-library-docs`.

### Example (Get Docs)
```json
{
  "context7CompatibleLibraryID": "/vercel/next.js",
  "mode": "code",
  "topic": "routing"
}
```

---

## n8n MCP
**Server:** `n8n-mcp`

### Description
Integrates with n8n for workflow automation, allowing you to manage workflows, nodes, and executions.

### Key Tools
- `list_workflows`: List available workflows.
- `n8n_get_workflow`: Retrieve details of a specific workflow.
- `n8n_trigger_webhook_workflow`: Trigger a workflow via webhook.
- `list_nodes`: List available n8n nodes.

### Usage
Use this tool to:
- Automate complex tasks using n8n workflows.
- Manage and monitor n8n executions.
- Integrate external services via n8n nodes.

### Example (List Workflows)
```json
{
  "limit": 10,
  "active": true
}