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
    *   **Integrations:** Stripe (payments), Supabase (auth), Ollama (LLM runtime).
*   **Database:** PostgreSQL (backend), SQLite (local/backend).
*   **Infrastructure:** Docker, Kubernetes (k8s), Docker Compose.
*   **CI/CD:** GitHub Actions.

## Available Tools & Capabilities

I have access to a wide range of specialized tools to assist with development, analysis, and creative tasks.

### Core File System & Shell
*   **`list_directory(path)`**: Lists files and directories.
*   **`read_file(path)`**: Reads file content.
*   **`write_file(path, content)`**: Writes new content to a file.
*   **`replace(path, old_string, new_string)`**: Performs precise text replacement within a file.
*   **`search_file_content(pattern)`**: fast, grep-like search for patterns in files.
*   **`glob(pattern)`**: Finds files matching a glob pattern.
*   **`run_shell_command(command)`**: Executes shell commands. **Includes access to the GitHub CLI (`gh`)** for repository, issue, and PR management.

### Planning & Knowledge
*   **`codebase_investigator(objective)`**: Performs deep analysis of the codebase structure, architecture, and dependencies. Use this for complex inquiries.
*   **`write_todos(todos)`**: Manages a dynamic task list to track progress on complex, multi-step operations.
*   **`save_memory(fact)`**: Persists user preferences and important project facts across sessions.

### Web & Research
*   **`web_fetch(prompt)`**: Fetches and processes content from URLs (including localhost).
*   **`google_web_search(query)`**: Performs Google searches for external documentation and solutions.
*   **`pub_dev_search(query)`**: Searches for Dart/Flutter packages on pub.dev.

### Dart & Flutter Development (MCP)
I have access to a suite of powerful tools for Dart and Flutter development, enabling a seamless "Multi-platform Code Production" (MCP) workflow. These tools allow me to build, analyze, test, and interact with your applications in real-time.

*   **Project & Dependency Management:**
    *   `create_project`: Scaffolds new Dart/Flutter projects.
    *   `pub`: Manages package dependencies (add, remove, get, upgrade).
*   **Code Analysis & Quality:**
    *   `analyze_files`: Runs static analysis.
    *   `dart_fix`: Applies automated code fixes.
    *   `dart_format`: Formats code to standard.
    *   `run_tests`: Executes tests with advanced reporting.
*   **Development Intelligence:**
    *   `resolve_workspace_symbol`: symbol search.
    *   `signature_help`, `hover`: Code introspection.
    *   `get_active_location`: Retrieves the current cursor position in the connected editor.
*   **Runtime Interaction (requires running app):**
    *   `launch_app`, `stop_app`: Manages application lifecycle.
    *   `hot_reload`, `hot_restart`: Applies changes to running apps.
    *   `connect_dart_tooling_daemon`: Connects to the Dart tooling daemon.
    *   `get_app_logs`: Retrieves application logs.
    *   `get_runtime_errors`: Checks for active runtime errors.
*   **UI Inspection & Automation:**
    *   `get_widget_tree`, `get_selected_widget`: Inspects the UI hierarchy.
    *   `set_widget_selection_mode`: Enables interactive widget selection.
    *   `flutter_driver`: Drives UI automation tests.
*   **Device Management:**
    *   `list_devices`: Shows available targets.
    *   `list_running_apps`: Shows active sessions.

### Image Generation & Editing (Nano Banana)
*   **`generate_image`**: Generates images from text prompts with style control.
*   **`edit_image`**: Modifies existing images based on text instructions.
*   **`restore_image`**: Restores and enhances images (e.g., removing artifacts).
*   **`generate_icon`**: Generates app icons, favicons, and UI elements.
*   **`generate_pattern`**: Generates seamless patterns and textures.
*   **`generate_story`**: Creates sequential visual stories or process guides.
*   **`generate_diagram`**: Generates technical diagrams and flowcharts.

## User Preferences & Rules
*   **Automation First**: Automate tasks whenever possible. Do not ask for manual user intervention unless absolutely required.
*   **Deployment**: Deployment to AKS is automated via GitHub Actions when pushing to the `main` branch.
*   **Git Operations**: Always commit and push changes to the repository after completing a task. Do not ask for permission to perform git operations. Do not leave changes uncommitted.
*   **Latest Stable Versions**: Always use the latest stable version for all dependencies, tools, and infrastructure (e.g., Kubernetes, Node.js, Flutter) unless explicitly pinned for compatibility. Avoid using older or deprecated versions.
*   **Latest Tech Stack**: Always use the latest major versions of GitHub Actions, libraries, and tools. Deprecated versions are strictly forbidden. If a tool is deprecated, upgrade immediately.
*   **NO ROOT EVER**: Containers must NEVER run as root. Always create and use a custom user (e.g., `cloudtolocalllm`). Root should only be used for package installation during the build phase.
*   **Minimal Containers**: Use minimal, Fedora-based base images for all containers. Install only what is strictly necessary.



## Lessons Learned & Project Structure Notes

*   **Kustomize Structure:** The project uses a Kustomize overlay structure (`k8s/overlays/production/`) where patch files (e.g., `web-deployment-patch.yaml`) override base configurations. When modifying deployment settings like replica counts, ensure you check both the base `k8s/` files and the environment-specific overlays to avoid conflicting configurations.
*   **File Management:** Avoid creating new files unless explicitly necessary. Modify existing files to achieve configuration changes.
*   **Communication:** Be explicit when modifying "patch" files to avoid confusion about whether a new file is being created or an existing one is being edited.

I will use these tools to carry out the development plan and assist with your requests.
