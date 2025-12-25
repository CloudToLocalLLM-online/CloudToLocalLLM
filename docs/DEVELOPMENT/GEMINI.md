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

## Core Philosophy & Workflow: The Sequential Thinking Mandate

I adhere to a strict "Think, then Act" philosophy, now reinforced by a mandatory **Sequential Thinking Protocol** for all complex tasks.

### 1. The Sequential Thinking Protocol (`sequentialthinking`)
For any task involving complexity, ambiguity, debugging, or multi-step reasoning, I **MUST** use the `sequentialthinking` tool to structure my cognitive process.

**Protocol Checklist:**
*   **Define explicit steps:** Break down the problem into granular, actionable phases.
*   **Document intermediate states:** Record the system state before and after each logical step.
*   **Validate each step:** Prove that the current step succeeded before moving to the next.
*   **Measure progress:** Track how far along the plan I am.
*   **Log outcomes:** Explicitly state the result of each action (Success/Failure/Unexpected).
*   **Iterate on findings:** If a step reveals new information, loop back and adjust the plan.
*   **Refine logic:** Continuously improve the approach based on observed reality.
*   **Prioritize clarity:** Ensure the thought process is transparent and understandable.
*   **Ensure reproducibility:** The path to the solution must be repeatable.

### 2. Deep Analysis (`codebase_investigator`)
I do not guess about the codebase. For any request that requires understanding system architecture, dependencies, or broad context, I **MUST** use `codebase_investigator`.
*   **Purpose:** To map out relevant files, symbols, and relationships.
*   **Usage:** This is my "Entry Point" for bug fixes and feature implementations.

### 3. The MCP Loop (Enhanced)
1.  **Investigate:** Use `codebase_investigator` or `search_file_content` to understand the context.
2.  **Plan:** Use `sequentialthinking` to formulate a safe and effective plan, adhering to the checklist above.
3.  **Task Tracking:** Use `write_todos` to manage complex, multi-step execution.
4.  **Implement:** Use engineering tools (`write_file`, `replace`, etc.) to make changes.
5.  **Verify:** Use `analyze_files` and `run_tests` to prove correctness.

## MCP Tool Operating Manual

This section serves as the definitive guide for using the Multi-Context Protocol (MCP) tools available to the agent.

### 1. Tool Inventory & Capability Mapping

#### System & File Operations
*   `list_directory`: Lists files/folders. *Usage: Explore directory structure.*
*   `read_file`: Reads file content. *Usage: Read single files. Respects limits.*
*   `search_file_content`: Fast regex search (ripgrep). *Usage: Find code patterns.*
*   `glob`: Find files by pattern. *Usage: Locate specific file types.*
*   `replace`: Surgical text replacement. *Usage: Edit code. Requires unique context.*
*   `write_file`: Overwrite/create files. *Usage: Create new files or full rewrites.*
*   `run_shell_command`: Execute shell commands. *Usage: Run scripts, build tools.*

#### Memory & Cognition
*   `sequentialthinking`: **(MANDATORY)** For complex logic and planning.
*   `save_memory`: Store user preferences/facts. *Usage: Long-term personalization.*
*   `delegate_to_agent`: Hand off tasks to sub-agents. *Usage: Deep analysis (`codebase_investigator`).*

#### Flutter & Dart Engineering
*   **Management:** `create_project`, `pub` (add/remove deps).
*   **Analysis:** `analyze_files` (lint), `resolve_workspace_symbol`, `hover`, `signature_help`.
*   **Refactoring:** `dart_fix` (auto-apply fixes), `dart_format`.
*   **Testing:** `run_tests` (The **ONLY** approved way to run tests).
*   **Runtime:** `launch_app`, `stop_app`, `hot_reload`, `hot_restart`, `get_app_logs`, `list_devices`.
*   **Inspection:** `get_widget_tree`, `get_selected_widget`, `flutter_driver` (integration testing).

#### GitHub Integration
*   **Code:** `get_file_contents`, `push_files` (direct commit), `create_or_update_file`, `delete_file`.
*   **PRs:** `list_pull_requests`, `create_pull_request`, `update_pull_request`, `merge_pull_request`, `pull_request_read`, `pull_request_review_write`.
*   **Issues:** `list_issues`, `issue_read`, `issue_write`, `add_issue_comment`.
*   **Search:** `search_code`, `search_issues`, `search_repositories`.

#### Web & Research
*   `google_web_search`: Live web queries.
*   `web_fetch`: Scrape/read web pages.
*   `get-library-docs` / `resolve-library-id`: Fetch specific library documentation.
*   `pub_dev_search`: Find Dart packages.

#### Browser Automation
*   **Control:** `navigate_page`, `click`, `fill`, `take_screenshot`, `evaluate_script`.
*   **Debugging:** `get_console_message`, `get_network_request`, `performance_analyze_insight`.

#### Creative & Generation
*   **Nano Banana:** `generate_image`, `edit_image`, `restore_image`, `generate_icon`, `generate_diagram`.
*   **Jules:** `start_new_jules_task` (async task offloading).

### 2. Usage Protocols & Best Practices

#### General Rules
1.  **Verify First:** Never assume file existence or content. Use `list_directory` and `read_file` before acting.
2.  **Surgical Edits:** Prefer `replace` over `write_file` for existing files to preserve context.
3.  **No Hallucinations:** If a tool fails, report it. Do not invent successful outputs.
4.  **Security:** Never output or commit API keys/secrets. Use `read_file` to check `.env` templates, not actual `.env` files if possible.

#### Testing Standards
1.  **Static Analysis:** Run `analyze_files` on modified paths *before* running tests. Fix lint errors first.
2.  **Test Execution:** ALWAYS use `run_tests`. Do not use shell `flutter test`.
3.  **Verification:** Ensure code compiles and passes tests before "completing" a task.

#### Git Operations
1.  **Tool Priority:** Use GitHub MCP tools (`create_pull_request`, `push_files`) over shell commands for remote operations.
2.  **Local Status:** Use `run_shell_command` for `git status`, `git diff` to understand local state.
3.  **Atomic Commits:** Make small, logical commits with descriptive messages.

#### Tool Constraints
*   **Shell:** Do not use `nano`, `vim`, or interactive commands.
*   **Browser:** Close pages (`close_page`) after use to free resources.
*   **Images:** Respect requested counts and styles strictly.

### 3. Workflow Integration

The standard operating loop is:
1.  **Context Loading:** `save_memory` check + `read_file` (docs/configs).
2.  **Investigation:** `delegate_to_agent` (deep) or `search_file_content` (quick).
3.  **Planning (Sequential):** Use `sequentialthinking` to Build the Plan.
    *   Define explicit steps.
    *   Prioritize clarity and reproducibility.
4.  **Action:** `write_file` / `replace` / `run_shell_command`.
5.  **Validation:** `dart_format` -> `analyze_files` -> `run_tests`.
6.  **Iteration:** Log outcomes, refine logic, and repeat if necessary.

## Lessons Learned & Project Structure Notes

*   **Kustomize Structure:** The project uses a Kustomize overlay structure (`k8s/overlays/production/`). Check both base and overlays.
*   **File Management:** Modify existing files when possible; avoid clutter.
*   **Communication:** Be explicit about file paths and changes.
