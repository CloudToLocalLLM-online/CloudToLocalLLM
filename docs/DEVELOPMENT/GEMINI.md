# Antigravity Agent Project Overview

This document outlines the Antigravity code assistant's understanding of the project, its capabilities, and its operating procedures.

## Project Goal

**CloudToLocalLLM** is a platform designed to manage and run powerful Large Language Models (LLMs) locally, orchestrated via a cloud interface. The goal is to provide a seamless bridge between cloud-based management and local execution, ensuring data privacy and cost-efficiency.

## Key Technologies

The project utilizes a robust stack to achieve its goals:

*   **Frontend (Flutter):**
    *   **Platforms:** Mobile, Desktop, Web.
    *   **Core Libs:** `go_router` (navigation), `dio` (networking), `provider` (state management), `dartssh2` (tunneling).
    *   **Storage:** `sqflite` (local DB), `flutter_secure_storage` (secrets).
*   **Backend (Node.js):**
    *   **Services:**
        *   `api-backend`: Main API service (Express).
        *   **streaming-proxy**: Tunnel-aware container for streaming (Express, WS).
    *   **Observability:** OpenTelemetry, Sentry, Prometheus.
    *   **Integrations:** Stripe (payments), Supabase (auth), Ollama (LLM runtime).
*   **Database:** PostgreSQL (backend), SQLite (local/backend).
*   **Infrastructure:** Docker, Kubernetes (k8s), Docker Compose.
*   **CI/CD:** GitHub Actions.

## Core Philosophy & Workflow

I adhere to a strict "Think, then Act" philosophy to ensure safety and quality.

### 1. Cognitive Architecture (`sequentialthinking`)
For any task involving complexity, ambiguity, or multi-step reasoning, I **MUST** use the `sequentialthinking` tool.
*   **Purpose:** To break down problems, generate hypotheses, plan steps, and revise strategies dynamically.
*   **Usage:** I will use this *before* making significant code changes and *during* debugging to track my logic.

### 2. Deep Analysis (`codebase_investigator`)
I do not guess about the codebase. For any request that requires understanding system architecture, dependencies, or broad context, I **MUST** use `codebase_investigator`.
*   **Purpose:** To map out relevant files, symbols, and relationships.
*   **Usage:** This is my "Entry Point" for bug fixes and feature implementations.

### 3. The MCP Loop
1.  **Investigate:** Use `codebase_investigator` or `search_file_content` to understand the context.
2.  **Plan:** Use `sequentialthinking` to formulate a safe and effective plan.
3.  **Task Tracking:** Use `write_todos` to manage complex, multi-step execution.
4.  **Implement:** Use engineering tools (`write_file`, `replace`, etc.) to make changes.
5.  **Verify:** Use `analyze_files` and `run_tests` to prove correctness.

## Available Tools & Capabilities

I have access to a comprehensive suite of tools ("MCP Tools") to assist with development.

### Cognitive & Planning
*   **`sequentialthinking`**: **(PRIMARY)** A reflective thinking tool for dynamic problem-solving and planning.
*   **`codebase_investigator`**: **(PRIMARY)** Deep codebase analysis and architectural mapping.
*   **`write_todos`**: Manages dynamic task lists for complex requests.
*   **`save_memory`**: Persists user preferences and critical facts.

### Core Engineering & File System
*   **`search_file_content(pattern)`**: Fast, grep-like search (ripgrep) for patterns.
*   **`glob(pattern)`**: efficient file finding by pattern.
*   **`read_file(path)`**: Reads file content.
*   **`write_file(path, content)`**: Writes new content.
*   **`replace(path, old, new)`**: Precise text replacement (requires unique context).
*   **`list_directory(path)`**: Lists directory contents.
*   **`run_shell_command(command)`**: Executes shell commands (PowerShell).

### Dart & Flutter Development (MCP)
I possess specialized tools for the full Flutter lifecycle:

*   **Management:** `create_project`, `pub` (dependency management).
*   **Quality:** `analyze_files` (static analysis), `dart_fix` (auto-fixes), `dart_format`.
*   **Testing:** `run_tests` (The **ONLY** way I should run tests).
*   **Runtime:** `launch_app`, `stop_app`, `hot_reload`, `hot_restart`, `get_app_logs`.
*   **Inspection:** `get_widget_tree`, `get_selected_widget`, `flutter_driver`.

### Web, Research & Documentation
*   **`get-library-docs(id)`**: Fetches up-to-date documentation for libraries (Context7).
*   **`resolve-library-id(name)`**: Resolves library names for documentation fetching.
*   **`google_web_search`**: Searches the live web for information.
*   **`web_fetch`**: Fetches content from specific URLs.
*   **`pub_dev_search`**: Searches pub.dev for Dart packages.

### Browser Automation (Playwright)
I can launch and control a browser to interact with web applications:
*   `browser_navigate`, `browser_click`, `browser_type`, `browser_evaluate`, `browser_take_screenshot`, etc.

### GitHub Integration
I can directly interact with the repository:
*   `create_issue`, `create_pull_request`, `create_branch`, `push_files`, `search_issues`, etc.

## Testing Best Practices

Testing is mandatory for all code changes.

1.  **Static Analysis First:** ALWAYS run `analyze_files` on modified paths *before* running tests. Fix lint errors first.
2.  **Use `run_tests`:** Do not use `flutter test` in the shell. Use the `run_tests` tool which provides better output and control.
3.  **Integration Tests:** Critical paths (like Login, Payments) must be covered by integration tests (`integration_test` package).
4.  **Format & Fix:** Run `dart_format` and `dart_fix` before finalizing any task.
5.  **No "Blind" Commits:** Ensure the code compiles and passes tests before committing.

## User Preferences & Rules
*   **Automation First**: Automate tasks whenever possible.
*   **Deployment**: Automated via GitHub Actions on push to `main`.
*   **Git Operations**: Always commit changes. Use descriptive, "why"-focused messages.
*   **Latest Tech**: Use latest stable versions of Flutter, Node.js, and K8s.
*   **No Root**: Containers must run as non-root users.
*   **Sequential Thinking**: If a task seems even slightly complex, use the `sequentialthinking` tool immediately.

## Lessons Learned & Project Structure Notes

*   **Kustomize Structure:** The project uses a Kustomize overlay structure (`k8s/overlays/production/`). Check both base and overlays.
*   **File Management:** Modify existing files when possible; avoid clutter.
*   **Communication:** Be explicit about file paths and changes.
