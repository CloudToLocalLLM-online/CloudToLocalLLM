# Agent Rules Standard

## MCP Tool Usage Guidelines

This section outlines the operational rules and behavioral guidelines for using Model Context Protocol (MCP) tools. These rules ensure optimal task execution, context management, and system stability.

### 1. Tool Selection Criteria

Select the appropriate tool based on the specific requirements of the task:

- **Sequential Thinking (`sequentialthinking`):** Use for dynamic and reflective problem-solving, breaking down complex problems, and planning with room for revision.
- **Playwright (`playwright`):** Use for browser automation, end-to-end testing, web scraping, and verifying UI interactions.
- **Context7 (`context7`):** Use for retrieving up-to-date documentation and code examples for libraries and frameworks. Always resolve the library ID first.
- **n8n MCP (`n8n-mcp`):** Use for workflow automation, managing n8n executions, and integrating external services via n8n nodes.

**Note:** Refer to `.gemini/rules/MCP-TOOLS.md` for detailed documentation and examples for each tool.

### 2. Function Call Syntax

- **Strict Schema Adherence:** All tool calls must strictly adhere to the defined input schema.
- **JSON Formatting:** Ensure all arguments are valid JSON.
- **Parameter Completeness:** Provide all required parameters. Do not omit mandatory fields.

### 3. Error Handling Protocols

- **Check Results:** Always verify the result of a tool call before proceeding.
- **Graceful Failure:** If a tool fails, analyze the error message and attempt a correction or alternative approach. Do not blindly retry the same failed operation.
- **Context Preservation:** If a tool call interrupts the flow, ensure the context is preserved for the next step.

### 4. Usage Hierarchy

1. **Exploration:** Use `codebase_search` and `list_files` to understand the environment.
2. **Planning:** Use `sequentialthinking` for complex planning and design.
3. **Execution:** Use specific MCP tools (`playwright`, `context7`, `n8n-mcp`) to execute the plan.
4. **Verification:** Verify the output of each step.

### 5. Context Management

- **One Tool Per Message:** Execute only one tool per message to ensure clear state management.
- **Wait for Confirmation:** Always wait for the user's response/confirmation after a tool use.
