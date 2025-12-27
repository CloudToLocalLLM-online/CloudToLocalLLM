# Gemini Protocol & Repository Governance

This document defines the mandatory operational protocols for AI Agents (Gemini, Kilocode, etc.) interacting with this repository.

## 1. 🛡️ Root Directory Preservation Protocol (RDPP)

**Status:** MANDATORY / ZERO TOLERANCE

To maintain repository integrity and reduce cognitive load, a strict "clean-root" policy is enforced.

### Prohibited Actions
- **DO NOT** create new files in the repository root (`/`).
- **DO NOT** create new directories in the repository root without explicit architectural approval.
- **DO NOT** leave temporary files, logs, or "orphan" markdown files in the root.

### Permitted Files (Whitelist)
Only the following files are permitted to reside in the repository root:
- **Essential Toolchain Configurations:** `.gitignore`, `.gitattributes`, `LICENSE`, `package.json`, `pubspec.yaml`, `Makefile`, `docker-compose.yml`, `playwright.config.js`.
- **Project Entry Points:** `README.md`, `CHANGELOG.md`.
- **Agent Instructions:** `Gemini.md`, `.kiro/` (steering), `.cursor/` (rules).

### Migration Directive
If an operation generates a file that would normally reside in the root, it **MUST** be redirected to an appropriate subdirectory:
- **Documentation:** `docs/` (following the domain-driven taxonomy).
- **Configurations:** `config/` or `infra/`.
- **Scripts:** `scripts/`.
- **Binaries/Tools:** `build-tools/` or `bin/`.

## 2. 📚 Single Source of Truth (SSOT)

- All documentation must be centralized in the `docs/` directory.
- Avoid duplicate documentation. Merge overlapping content into the most relevant authoritative file.
- Use relative cross-linking between documents to maintain a navigable knowledge graph.

## 3. Project Overview

**CloudToLocalLLM** is a privacy-first platform that bridges local Large Language Model (LLM) execution with cloud-based management. It allows users to run models like Llama 3 locally via Ollama while optionally relaying control or data through a secure cloud interface.

*   **Goal:** Secure, private, local AI with cloud convenience.
*   **Status:** Active Development (Early Access).

## 4. Technical Architecture

### Frontend (Flutter)
*   **Path:** `lib/`
*   **Platforms:** Windows, Linux, Web.
*   **Key Libraries:** `go_router`, `provider`, `dio` (enhanced for streaming), `sqflite`, `dartssh2`, `langchain_dart`.

### Backend (Node.js)
*   **Path:** `services/`
*   **Services:**
    *   `api-backend`: Main REST API (Express.js) & WebSocket Tunnel.
    *   `streaming-proxy`: Specialized proxy for handling streaming responses.
*   **Database:** PostgreSQL (Production), SQLite (Local Storage).
*   **Auth:** Auth0 integration, Supabase (legacy/alternative), Microsoft Entra (Experimental).

### Infrastructure
*   **Local Dev:** `docker-compose.production.yml` (simulates prod).
*   **Production:** Kubernetes (`k8s/`) on Azure AKS.
*   **Networking:** Nginx reverse proxy, Cloudflare Tunnels via `cloudflared`.

## 5. Directory Structure Map

| Directory | Description |
| :--- | :--- |
| `lib/` | **Flutter Source Code**. Main entry points: `main.dart`, `main_privacy_enhanced.dart`. |
| `services/` | **Backend Services**. `api-backend/`, `streaming-proxy/`. |
| `config/` | **Configuration**. Docker, Nginx, Kubernetes, Grafana configs. |
| `docs/` | **Documentation**. Organized into `api/`, `architecture/`, `deployment/`, `development/`, `governance/`, `operations/`, and `user-guide/`. |
| `k8s/` | **Kubernetes Manifests**. Helm-free, Kustomize-based structure. |
| `test/` | **Tests**. Flutter unit and widget tests. |
| `infra/` | **Infrastructure as Code**. Terraform scripts. |

## 6. Environment & Toolchain (WSL Native & PowerShell)

The development environment is a hybrid of **WSL 2 (Ubuntu 24.04)** and **Windows PowerShell**.

> [!NOTE]
> PowerShell is configured with **Oh My Posh** for a rich, informative prompt.

### Tools Matrix

| Tool | Environment | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Node.js** | WSL (NVM) | ✅ Ready | v22+. Managed via `nvm`. Use native `npm`. |
| **Git** | WSL / Win | ✅ Ready | v2.43+. Native bash hooks active. |
| **GH CLI** | WSL | ✅ Ready | v2.40+. GitHub CLI for PRs/Issues. |
| **Auth0 CLI** | WSL | ✅ Ready | v1.25.0+. |
| **Sentry CLI**| WSL | ✅ Ready | v2.58.2+. |
| **Docker** | Win/WSL | ✅ Ready | Docker Desktop interop enabled. |
| **Ollama** | Win Host | ✅ Ready | Host service proxied via `localhost`. |
| **Flutter** | WSL Native| ✅ Ready | Linux SDK installed. |

## 7. Repository Governance & Philosophy

### The Sequential Thinking Mandate
We adhere to a strict "Think, then Act" philosophy, reinforced by a mandatory **Sequential Thinking Protocol** for all complex tasks.

#### The Sequential Thinking Protocol (`sequentialthinking`)
For any task involving complexity, ambiguity, debugging, or multi-step reasoning, agents **MUST** use the `sequentialthinking` tool to structure their cognitive process.

**Protocol Checklist:**
- **Define explicit steps:** Break down the problem into granular, actionable phases.
- **Document intermediate states:** Record the system state before and after each logical step.
- **Validate each step:** Prove that the current step succeeded before moving to the next.
- **Measure progress:** Track how far along the plan I am.
- **Iterate on findings:** If a step reveals new information, loop back and adjust the plan.

#### Deep Analysis (`codebase_investigator`)
Do not guess about the codebase. For requests requiring broad context, **MUST** use `codebase_investigator` as the entry point.

## 8. CLI & Shell Strategy (WSL & PowerShell)

*   **Prioritize WSL:** Execute Linux-native tools (`git`, `gh`, `npm`, `flutter`, `sentry-cli`, `auth0`) via `wsl -d Ubuntu-24.04 bash -c '...'`.
*   **Path Translation:** Use `wslpath` for cross-OS path translation when passing Windows paths to WSL tools.
*   **PowerShell for Host:** Use PowerShell for host-level tools or when specifically requested.
*   **No Placeholders:** Never use placeholders for secrets. If a secret is missing, verify its existence in external infra before replacement.

## 9. Operational Guidelines (CRITICAL)

### Secret Management & Recovery
- **Exhaustive Verification:** Before creating new resources (tunnels, DBs), check if a "missing" local secret corresponds to an existing live resource.
- **Prefer Recovery:** Always attempt to recover credentials via CLI/APIs before generating new ones.
- **Cloudflare Credentials:** The Cloudflare Global API credentials (Email and Key) are stored in `E:\dev\Cloudflare Global API Key.txt`. The primary email is `cmaltais@cloudtolocalllm.online`.

### Git & Deployment Workflow
- **Git Hygiene:** **ALWAYS** `git pull --rebase` before creating a commit.
- **Argo CD Sync:** Changes to `k8s/` in the `main` branch are automatically deployed via Argo CD (managed by the "App of Apps" pattern).

### Security
- **Data Isolation:** Be extremely careful with SQL queries regarding the `conversations` table; ensure proper user isolation.
- **No committed secrets:** Never commit `.env` files or API keys.

### Development Standards
*   **Conventions:** Match existing code style (linting, variable naming, file structure).
*   **Tests:** Do not delete tests. Update them if logic changes.
*   **Flutter:**
    *   Use `flutter pub get` to update dependencies.
    *   Run `dart fix --apply` if you encounter simple lint errors.
*   **Backend:**
    *   Node.js services use `package.json` scripts (`npm start`, `npm run dev`).

## 10. Critical Development Patterns

### Dependency Injection (Flutter)
- Services are registered in `lib/di/locator.dart`.
- Use `setupCoreServices()` for pre-auth and `setupAuthenticatedServices()` for post-auth dependencies.

### Docker & Containers
- **User Permissions:** NEVER run Flutter as root. Switch to `USER 1000:1000` before any `flutter` command. Node.js should use UID 1001.
- **Layer Caching:** Copy `pubspec.yaml`/`pubspec.lock` first, run `flutter pub get`, then copy source.

### Testing
- **Node.js:** Jest tests are in `test/`. Run single tests with: `node --experimental-vm-modules ./node_modules/jest/bin/jest.js <test-file>`.
- **Property Testing:** Use `fast-check` for complex business logic.

### Web Compatibility
- Use `package:web/web.dart` and `dart:js_interop` instead of the deprecated `js` package for Flutter Web.

## 11. Coding Style & Naming Conventions
- **Dart/Flutter:**
    - 2-space indent.
    - `PascalCase` for classes/widgets.
    - `snake_case` for files.
    - Prefer `const` widgets and typed services.
    - Document public APIs when behavior is non-obvious.
- **JavaScript (Backend):**
    - ES modules (`import`/`export`).
    - `camelCase` for functions.
    - `SCREAMING_SNAKE_CASE` for environment variables.
    - Keep middleware ordering explicit.
- **Configuration:**
    - Use `.env` (copy `env.template`).
    - **Never** commit secrets or generated binaries.
