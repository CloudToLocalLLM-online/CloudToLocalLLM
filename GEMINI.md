# Antigravity Agent Project Overview

This document outlines the Antigravity code assistant's understanding of the project and its plan for contributing.

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
        *   `streaming-proxy`: Tunnel-aware container for streaming (Express, WS).
    *   **Observability:** OpenTelemetry, Sentry, Prometheus.
    *   **Integrations:** Stripe (payments), Auth0 (auth), Ollama (LLM runtime).
*   **Database:** PostgreSQL (backend), SQLite (local/backend).
*   **Infrastructure:** Docker, Kubernetes (k8s), Docker Compose.
*   **CI/CD:** GitHub Actions.

## Development Environment and MCP Tools

I am operating within Antigravity and have access to dedicated MCP (Model Context Protocol) servers. These servers provide a suite of powerful, specialized tools that allow me to perform advanced tasks.

### Available MCP Servers

*   **Dart & Flutter MCP**:
    *   **Project Management**: Create, analyze, and manage Dart/Flutter projects.
    *   **Development Tools**: Connect to Dart Tooling Daemon, run tests, format code, and fix issues.
    *   **Runtime Interaction**: Hot reload/restart, inspect widget trees, and view application logs.
*   **GitHub MCP**:
    *   **Repository Operations**: Search, read, and modify repositories, branches, and files.
    *   **Issue & PR Management**: Create, list, and update issues and pull requests.
    *   **Code Search**: Advanced code search capabilities across GitHub.
*   **Sequential Thinking MCP**:
    *   **Problem Solving**: Advanced tool for dynamic and reflective problem-solving, allowing for complex thought chains and hypothesis verification.

## Development Plan

To effectively contribute to the project, I will adhere to the following plan:

1.  **Understand the Architecture:** I will respect the separation of concerns between the Flutter frontend, `api-backend`, and `streaming-proxy`.
2.  **Follow Established Practices:** I will follow the project's existing development workflow, including testing (`jest` for backend, `flutter_test` for frontend) and documentation standards.
3.  **Implement New Features:** I will implement new features as requested, ensuring they are well-tested and documented.
4.  **Fix Bugs:** I will identify and fix bugs in the existing code, providing clear and concise bug reports.
5.  **Improve Performance:** I will identify and address performance bottlenecks, particularly in the tunneling and streaming layers.
6.  **Enhance Security:** I will identify and address security vulnerabilities, focusing on user isolation and secure tunneling.

## Available Tools

Here are some of the tools I can use to help with development:

*   **`list_directory(path)`**: Lists the files and directories in a specified path.
*   **`read_file(absolute_path)`**: Reads the content of a file.
*   **`write_file(file_path, content)`**: Writes new content to a file, overwriting existing content.
*   **`replace(file_path, old_string, new_string)`**: Replaces specific text within a file.
*   **`run_shell_command(command)`**: Executes a shell command in the terminal.
*   **`search_file_content(pattern, include)`**: Searches for a specific pattern within files.
*   **`glob(pattern)`**: Finds files matching a glob pattern.
*   **`gh [COMMAND]`**: Interacts with the GitHub CLI.

## User Preferences & Rules
*   **Automation First**: Automate tasks whenever possible. Do not ask for manual user intervention unless absolutely required.
*   **Deployment**: Deployment to AKS is automated via GitHub Actions when pushing to the `main` branch.
*   **Git Operations**: Always commit and push changes to the repository after completing a task. Do not ask for permission to perform git operations. Do not leave changes uncommitted.
*   **Latest Stable Versions**: Always use the latest stable version for all dependencies, tools, and infrastructure (e.g., Kubernetes, Node.js, Flutter) unless explicitly pinned for compatibility. Avoid using older or deprecated versions.



## Lessons Learned & Project Structure Notes

*   **Kustomize Structure:** The project uses a Kustomize overlay structure (`k8s/overlays/production/`) where patch files (e.g., `web-deployment-patch.yaml`) override base configurations. When modifying deployment settings like replica counts, ensure you check both the base `k8s/` files and the environment-specific overlays to avoid conflicting configurations.
*   **File Management:** Avoid creating new files unless explicitly necessary. Modify existing files to achieve configuration changes.
*   **Communication:** Be explicit when modifying "patch" files to avoid confusion about whether a new file is being created or an existing one is being edited.

I will use these tools to carry out the development plan and assist with your requests.
