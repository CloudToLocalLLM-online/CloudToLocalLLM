# MCP Tools Workflow and Best Practices

This document outlines the recommended workflow and best practices for effectively utilizing Model Context Protocol (MCP) tools within this workspace. Adhering to these guidelines ensures efficient, reliable, and secure interactions with external services and enhanced task execution.

## 1. General Principles for MCP Tool Usage

*   **Prioritization**: Always prefer an MCP tool over a standard tool or CLI command if it offers a more direct, integrated, or powerful solution for a specific task. MCP tools are designed for specialized interactions and often provide richer context and error handling.
*   **Atomic Operations**: Each `use_mcp_tool` or `access_mcp_resource` call is an atomic operation. Execute one tool call at a time and await its successful completion before initiating subsequent actions. This ensures clear progress tracking and simplifies debugging.
*   **Schema Adherence**: Before invoking any MCP tool, thoroughly review its input schema. Ensure all required parameters are provided with correct data types and formats. Incorrect parameters will lead to tool failure.
*   **Contextual Awareness**: Understand the purpose and limitations of each MCP tool. Use them in appropriate contexts to maximize their effectiveness and avoid unnecessary calls.

## 2. Discovering MCP Servers and Tools

To effectively use MCP tools, it's crucial to know which servers are connected and what capabilities they offer.

*   **Environment Details**: The `environment_details` section in each prompt provides a list of currently connected MCP servers and their available tools, along with their input schemas.
*   **`learn=true` Parameter**: For hierarchical MCP tools (like those provided by `github.com/Azure/azure-mcp`), use the `learn=true` parameter within the `arguments` JSON to discover available sub-commands and their parameters.
    *   **Example (Azure)**:
        ```xml
        <use_mcp_tool>
        <server_name>github.com/Azure/azure-mcp</server_name>
        <tool_name>azd</tool_name>
        <arguments>
        {
          "intent": "learn about azd commands",
          "learn": true
        }
        </arguments>
        </use_mcp_tool>
        ```

## 3. Using MCP Tools (`use_mcp_tool`)

The `use_mcp_tool` command is used to execute functions provided by connected MCP servers.

*   **Parameters**:
    *   `server_name`: The unique identifier of the MCP server (e.g., `github.com/Azure/azure-mcp`).
    *   `tool_name`: The specific tool/function to invoke on that server (e.g., `sequentialthinking`, `aks`, `create_issue`).
    *   `arguments`: A JSON object containing the parameters required by the `tool_name`, strictly adhering to its input schema.
*   **Workflow**:
    1.  Identify the task and the most suitable MCP tool.
    2.  Consult the tool's input schema (from `environment_details` or by using `learn=true`).
    3.  Construct the `arguments` JSON object with all necessary parameters.
    4.  Execute the `use_mcp_tool` command.
    5.  Analyze the tool's output for success, data, or error messages.

## 4. Accessing MCP Resources (`access_mcp_resource`)

The `access_mcp_resource` command is used to retrieve data or information provided by connected MCP servers.

*   **Parameters**:
    *   `server_name`: The unique identifier of the MCP server.
    *   `uri`: The URI identifying the specific resource to access (e.g., `repo://owner/repo/contents/path/to/file.txt`).
*   **Workflow**:
    1.  Identify the need for a specific resource (e.g., file content from a GitHub repository).
    2.  Determine the correct `server_name` and `uri` for the resource.
    3.  Execute the `access_mcp_resource` command.
    4.  Process the retrieved resource content.

## 5. Specific MCP Server Workflows

### A. Sequential Thinking (`github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking`)

*   **Purpose**: For dynamic, reflective problem-solving, planning, and analysis.
*   **Workflow**:
    1.  Start a `sequentialthinking` session by providing an initial `thought`, `thoughtNumber`, and `totalThoughts`.
    2.  Iteratively refine thoughts, generate hypotheses, and verify them.
    3.  Use `isRevision` and `revisesThought` to correct or update previous thoughts.
    4.  Adjust `totalThoughts` and set `nextThoughtNeeded` to `true` if more steps are required.
    5.  Conclude the session by setting `nextThoughtNeeded` to `false` when a satisfactory answer is reached.

### B. Azure Operations (`github.com/Azure/azure-mcp`)

*   **Purpose**: Interact with Azure services (e.g., `azd`, `aks`, `storage`, `documentation`).
*   **Workflow**:
    1.  Clearly define the Azure operation's `intent`.
    2.  Select the appropriate Azure sub-tool (e.g., `azd`, `aks`, `storage`).
    3.  If unsure about parameters, use `learn=true` to explore the tool's capabilities.
    4.  Construct the `arguments` JSON with the `command` and `parameters` specific to the Azure operation.
    5.  Always consider authentication and subscription context for Azure operations.

### C. GitHub Operations (`github.com/github/github-mcp-server`)

*   **Purpose**: Manage GitHub repositories, issues, pull requests, and files.
*   **Workflow**:
    1.  Always specify `owner` and `repo` for repository-specific actions.
    2.  For file modifications, use `create_or_update_file` (providing `sha` for updates) or `push_files` for multiple files.
    3.  For code reviews, use `add_comment_to_pending_review` or `pull_request_review_write`.
    4.  For issue tracking, use `issue_read` and `issue_write`.
    5.  Leverage search tools (`search_code`, `search_issues`, etc.) for efficient information retrieval across GitHub.

### D. Context7 MCP (`github.com/upstash/context7-mcp`)

*   **Purpose**: Fetch up-to-date, version-specific documentation and code examples for libraries.
*   **Workflow**:
    1.  Use `resolve-library-id` to find the Context7-compatible library ID for a given library name. This is crucial if the exact ID is not known.
    2.  Once the library ID is obtained (e.g., `/vercel/next.js`), use `get-library-docs` to retrieve documentation.
    3.  Optionally, specify a `topic` (e.g., "routing", "hooks") to narrow down the documentation results.
    4.  If the exact library ID is already known, it can be directly provided to `get-library-docs` to skip the `resolve-library-id` step.


## 6. Error Handling and Debugging MCP Tool Calls

*   **Review Output**: Carefully examine the output of each MCP tool call. Look for success messages, returned data, or explicit error messages.
*   **Schema Validation**: If a tool fails, the first step is to re-verify that the `arguments` JSON precisely matches the tool's input schema.
*   **Retry Strategy**: For transient network issues or rate limits, a retry mechanism might be implicitly handled by the system. If not, consider a brief pause before retrying.
*   **Clarification**: If an error is unclear or persistent, and the tool's documentation doesn't help, consider using `ask_followup_question` to inform the user about the issue and seek guidance.
