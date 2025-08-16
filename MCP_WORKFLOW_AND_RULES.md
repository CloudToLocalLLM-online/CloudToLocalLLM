# Cline MCP Tools: Workflow and Rules

This document outlines the rules and standard operating procedures for utilizing the available Model Context Protocol (MCP) tools to enhance task execution, planning, and interaction with external services.

## I. General Principles

1.  **Prioritize MCP Tools**: When an MCP tool offers a more direct, powerful, or integrated solution compared to a standard tool, it should be the preferred choice. For example, use `mcp-webresearch` for Google searches instead of attempting to parse results via `curl`.
2.  **Atomic Operations**: Each MCP tool call is an atomic step. I will execute one tool at a time and wait for a successful response before proceeding to the next action.
3.  **Schema Adherence**: Before using any MCP tool, I will consult its input schema to ensure all required arguments are correctly formatted and provided.

---

## II. Core Workflow: Structured Task Management

For any request that requires multiple steps, changes to several files, or a sequence of dependent actions, I will use the `github.com/pashpashpash/mcp-taskmanager` server. This enforces a structured, transparent, and user-approved workflow.

### Task Management Workflow:

1.  **Planning Phase**:
    *   **Tool**: `request_planning`
    *   **Action**: I will first break down the user's request into a series of clear, sequential, and logical tasks. This plan will be registered with the task manager.

2.  **Execution Cycle (Per-Task)**:
    *   **Tool**: `get_next_task`
    *   **Action**: I will retrieve the next pending task from the queue.
    *   **Execution**: I will perform the necessary actions to complete this single task, using any other tools (standard or MCP) required.
    *   **Tool**: `mark_task_done`
    *   **Action**: Once the task is completed, I will mark it as done.

3.  **User Approval (Critical Step)**:
    *   **Action**: I will **STOP** and wait for the user to explicitly approve the completion of the task by calling `approve_task_completion`.
    *   **Rule**: I **will not** proceed to the next task (`get_next_task`) without this explicit user approval. This ensures the user is in full control of the process.

4.  **Request Completion**:
    *   **Condition**: After the final task is completed and approved.
    *   **Tool**: `approve_request_completion`
    *   **Action**: I will wait for the user to approve the completion of the entire request.

---

## III. Tool-Specific Rules & Use Cases

### A. Research & Documentation

*   **Server**: `github.com/pashpashpash/mcp-webresearch`
    *   **Use Case**: For any task requiring external information, current events, or general knowledge.
    *   **Tools**: `search_google`, `visit_page`.
*   **Server**: `github.com/upstash/context7-mcp`
    *   **Use Case**: When I need to understand how to use a specific software library, framework, or API.
    *   **Workflow**:
        1.  Call `resolve-library-id` with the library name to get the correct identifier.
        2.  Call `get-library-docs` with the resolved ID to fetch relevant documentation.

### B. Web Development & Debugging

*   **Server**: `github.com/AgentDeskAI/browser-tools-mcp`
    *   **Use Case**: For advanced debugging and quality assurance of web applications, going beyond the standard `browser_action` tool.
    *   **Rules**:
        *   When a web-related bug is reported, I will use `getConsoleErrors` and `getNetworkErrors` to diagnose the issue.
        *   When asked to improve a web page, I will use the audit tools (`runAccessibilityAudit`, `runPerformanceAudit`, `runSEOAudit`) to provide a comprehensive analysis and implement improvements.

### C. Project Management Integration (Linear)

*   **Server**: `github.com/cline/linear-mcp`
    *   **Use Case**: When a task involves project management activities like creating bug reports, feature requests, or updating project status.
    *   **Rules**:
        *   I will offer to integrate with the user's Linear workflow if the context suggests it (e.g., "file a bug report for this," "create a ticket for this feature").
        *   Before creating new items, I will use discovery tools like `linear_get_teams` and `linear_search_projects` to ensure I have the correct context (e.g., team IDs, project IDs).
        *   I can automate the creation of multiple issues from a list or a plan using `linear_create_issues` or `linear_create_project_with_issues`.

### D. Utilities

*   **Server**: `github.com/Garoth/sleep-mcp`
    *   **Use Case**: To introduce a deliberate pause in execution. This is useful when waiting for an asynchronous process to complete on a server or to respect API rate limits.

---

## IV. CLI Tools Integration

In addition to MCP servers, I will leverage powerful command-line interface (CLI) tools for direct interaction with external services.

### A. GitHub CLI (`gh`)

*   **Use Case**: For seamless integration with GitHub repositories. This includes managing pull requests, issues, gists, and repository actions directly from the command line.
*   **Workflow**:
    *   **Code Reviews**: I can check out pull requests, view diffs, and leave comments using `gh pr checkout`, `gh pr diff`, and `gh pr review`.
    *   **Issue Management**: I can create, list, and view issues using `gh issue create`, `gh issue list`, and `gh issue view`.
    *   **Automation**: I will use `gh` to script complex interactions with GitHub, such as creating a new repository and pushing code to it in a single flow.

### B. Google Cloud CLI (`gcloud`)

*   **Use Case**: For managing resources and services on Google Cloud Platform (GCP). This is essential for tasks involving cloud infrastructure, deployments, and administration.
*   **Workflow**:
    *   **Deployments**: I will use `gcloud app deploy` or `gcloud run deploy` to deploy applications to App Engine or Cloud Run.
    *   **Resource Management**: I can manage virtual machines, storage buckets, and databases using commands like `gcloud compute instances`, `gcloud storage`, and `gcloud sql`.
    *   **Authentication & Configuration**: I will ensure I am authenticated (`gcloud auth login`) and have the correct project configured (`gcloud config set project`) before performing any operations.
