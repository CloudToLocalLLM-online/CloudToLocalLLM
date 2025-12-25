# CloudToLocalLLM - Agent Context & Operating Manual

This document provides the context, architectural understanding, and operational guidelines for the Gemini CLI agent working on the **CloudToLocalLLM** project.

## 1. Project Overview

**CloudToLocalLLM** is a privacy-first platform that bridges local Large Language Model (LLM) execution with cloud-based management. It allows users to run models like Llama 3 locally via Ollama while optionally relaying control or data through a secure cloud interface.

*   **Goal:** Secure, private, local AI with cloud convenience.
*   **Status:** Active Development (Early Access).

## 2. Technical Architecture

### Frontend (Flutter)
*   **Path:** `lib/`
*   **Platforms:** Windows, Linux, Web (macOS pending).
*   **Key Libraries:**
    *   `go_router`: Navigation.
    *   `provider`: State management.
    *   `dio`: HTTP client (enhanced for streaming).
    *   `sqflite`: Local database storage.
    *   `dartssh2`: SSH tunneling.
    *   `langchain_dart`: AI integration.

### Backend (Node.js)
*   **Path:** `services/`
*   **Services:**
    *   `api-backend`: Main REST API (Express.js) & WebSocket Tunnel.
    *   `streaming-proxy`: Specialized proxy for handling streaming responses.
*   **Database:**
    *   **PostgreSQL:** Two instances (App Data & Auth Data) used in Docker/Production.
    *   **SQLite:** Used for local-only storage on client devices.
*   **Auth:** Auth0 integration, Supabase (legacy/alternative).

### Infrastructure
*   **Local Dev:** `docker-compose.production.yml` (simulates prod).
*   **Production:** Kubernetes (`k8s/`) on Azure AKS.
*   **Networking:** Nginx reverse proxy, Cloudflare Tunnels.

## 3. Directory Structure Map

| Directory | Description |
| :--- | :--- |
| `lib/` | **Flutter Source Code**. Main entry points: `main.dart`, `main_privacy_enhanced.dart`. |
| `services/` | **Backend Services**. `api-backend/`, `streaming-proxy/`. |
| `config/` | **Configuration**. Docker, Nginx, Kubernetes, Grafana configs. |
| `docs/` | **Documentation**. Detailed guides for Users, Devs, Security, and Ops. |
| `k8s/` | **Kubernetes Manifests**. Helm-free, Kustomize-based structure. |
| `test/` | **Tests**. Flutter unit and widget tests. |
| `infra/` | **Infrastructure as Code**. Terraform scripts. |

## 4. Environment & Toolchain (WSL Native)

The project runs in a native **WSL 2 (Ubuntu 24.04)** environment. All development tools are native to Linux except where host interop is required.

| Tool | Type | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Node.js** | Linux (NVM) | ✅ Ready | v22+. Use native `npm` / `node`. |
| **Git** | Linux | ✅ Ready | v2.43+. Native bash hooks active. |
| **Auth0 CLI** | Linux | ✅ Ready | v1.25.0. Tenant connected. |
| **Sentry CLI**| Linux | ✅ Ready | v2.58.2. |
| **Docker** | WSL Integration | ✅ Ready | Docker Desktop interop enabled. |
| **Ollama** | Windows Host | ✅ Ready | Host service proxied via `localhost`. |
| **Flutter** | Linux Native | ✅ Ready | Linux SDK installed. Use native `flutter` command. |

## 5. Operational Guidelines

### Core Philosophy: "Think, then Act"
1.  **Investigate:** Do not guess. Use `list_directory`, `read_file`, or `search_file_content` to confirm file locations and contents.
2.  **Plan (Sequential Thinking):** For any complex task, you **MUST** use the `sequentialthinking` tool. Refer to the **Sequential Thinking Mandate** in `docs/DEVELOPMENT/GEMINI.md` for the explicit protocol (Define steps, Validate, Measure, Log, Iterate).
3.  **Execute:** Use `write_file` or `replace` to modify code. **Always** prefer `replace` for surgical edits to avoid overwriting unrelated code.
4.  **Verify:** Run tests or static analysis if applicable.

### WSL & PowerShell Integration (Enhanced)
*   **Direct Execution**: Execute complex shell scripts or Linux-native tools directly via WSL from PowerShell using `wsl -d Ubuntu-24.04 bash -c "command"`.
*   **Tool Integration**: Use Linux utilities (sed, jq, grep, find) to supplement PowerShell for tasks like line-ending normalization (`sed -i 's/\r$//'`) or complex JSON processing.
*   **Path Translation**: Use `wslpath` for translating between Windows and Linux file paths when passing arguments to WSL commands.
*   **Consistent Environment**: Ensure environment variables (like `GEMINI_API_KEY`) are correctly exported or passed into the WSL environment for consistent tool behavior.
*   **Cross-Platform Builds**: Use WSL-native `flutter` and `npm` for builds to ensure binary compatibility and standard line endings (LF).

### Git & Deployment Workflow (CRITICAL)
*   **Git Rule:** **ALWAYS** `git pull --rebase` before creating a commit. This minimizes merge conflicts and maintains a clean history.
*   **GitOps / Argo CD:**
    *   The cluster state is managed by **Argo CD** using the "App of Apps" pattern.
    *   **Source:** `k8s/overlays/managed` (Prod) or `k8s/overlays/local` (Dev/Local) on the `main` branch.
    *   **Sync:** Automated (Self-heal & Prune enabled).
    *   **Implication:** Changes to `k8s/` manifests in the `main` branch are automatically deployed. Ensure manifests are valid before pushing.

### Development Standards
*   **Conventions:** Match existing code style (linting, variable naming, file structure).
*   **Tests:** Do not delete tests. Update them if logic changes.
*   **Security:**
    *   Never commit secrets/keys.
    *   **CRITICAL:** Be extremely careful with SQL queries regarding the `conversations` table due to the known isolation issue.
*   **Flutter:**
    *   Use `flutter pub get` to update dependencies.
    *   Run `dart fix --apply` if you encounter simple lint errors.
*   **Backend:**
    *   Node.js services use `package.json` scripts (`npm start`, `npm run dev`).

## 6. Common Commands

| Task | Command |
| :--- | :--- |
| **Backend: Start API** | `cd services/api-backend && npm run dev` |
| **Docker: Start All** | `docker-compose -f docker-compose.production.yml up -d` |
| **Sentry: Check Login** | `sentry-cli info` |
| **Auth0: Login** | `auth0 login` (if token expires) |

## 7. How to Use This Context
When asked to perform a task:
1.  Refer to this file to understand where you are in the stack (Frontend vs. Backend).
2.  Check for relevant documentation in `docs/`.
3.  **WSL Awareness:** Remember you are in Linux. Windows tools (`.exe`) are reachable but may behave differently.
4.  If modifying the database, **STOP** and verify you are addressing the user isolation requirement.