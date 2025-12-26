# Documentation Restructuring Plan

**Date:** 2025-12-25
**Status:** Draft (Updated after Code Review Agent Scan)

## 1. Audit Findings

### 1.1 Root Directory Clutter
The project root contains numerous markdown files and folders that should be categorized within the `docs/` directory to maintain a clean workspace.
- **Reports/Logs:** `ARGOCD_*.md`, `REMEDIATION_*.md`, `STEERING_*.md`, `PROJECT_STATUS_REPORT.md`
- **Architecture:** `GEMINI_CLI_INTEGRATION_ARCHITECTURE.md`
- **Setup:** `GRAFANA_CLOUD_SETUP.md`
- **Agent Context:** `GEMINI.md` (conflicts/overlaps with `docs/DEVELOPMENT/GEMINI.md`)
- **Folders:** `plans/` directory in root.

### 1.2 Overlapping & Fragmented Categories
- **Agent Context:** Fragmented across `GEMINI.md`, `docs/DEVELOPMENT/GEMINI.md`, and hidden configuration directories (`.cursor/rules`, `.gemini/rules`, `.kiro/steering`).
- **Operations:** `docs/OPERATIONAL_GUIDELINES` (Git MCP guides) vs `docs/OPERATIONS` (general infrastructure).
- **API Documentation:** `docs/API` (reference) vs `docs/backend/api` (policies).

### 1.3 Outdated Information & Broken Links
- **Zrok Cleanup:** Multiple references to `zrok` remain (e.g., in `docs/README.md`) despite the architecture's shift to Cloudflare Tunnels.
- **Broken Links:** `docs/README.md` contains links to non-existent files such as `TUNNEL_ARCHITECTURE.md`.

## 2. Restructuring Actions

### 2.1 Clean Up Root Directory
Move files and folders to `docs/` subdirectories:

| Source | Destination |
| :--- | :--- |
| `ARGOCD_*.md` | `docs/reports/` (New) |
| `REMEDIATION_*.md` | `docs/reports/` |
| `STEERING_*.md` | `docs/reports/` |
| `GITOPS_*.md` | `docs/reports/` |
| `PROJECT_STATUS_REPORT.md` | `docs/reports/` |
| `GEMINI_CLI_INTEGRATION_ARCHITECTURE.md` | `docs/ARCHITECTURE/` |
| `GRAFANA_CLOUD_SETUP.md` | `docs/OPERATIONS/grafana/` |
| `REFACTOR_AUTH0_PLAN.md` | `docs/plans/` |
| `plans/` (folder) | `docs/plans/` (Merge contents) |

### 2.2 Unify Agent Context
1.  **Consolidate:** Merge content of `GEMINI.md` (root) and `docs/DEVELOPMENT/GEMINI.md`.
2.  **Authoritative Source:** Create `docs/DEVELOPMENT/AGENT_CONTEXT.md` as the single source of truth for all AI agents.
3.  **Reference Guide:** Update `.cursor/rules`, `.gemini/rules`, and `.kiro/steering` to point to or inherit from this central document.

### 2.3 Consolidate Operations
1.  Move contents of `docs/OPERATIONAL_GUIDELINES/*` to `docs/OPERATIONS/git_mcp/`.
2.  Delete `docs/OPERATIONAL_GUIDELINES` directory.

### 2.4 Unify API Documentation
1.  Move contents of `docs/backend/api/*` to `docs/API/policies/`.
2.  Update `docs/API/README.md` to include the new Policies section.
3.  Remove `docs/backend/api` directory.

### 2.5 Tech Debt & Quality Fixes
1.  **Zrok Removal:** Globally search and replace/remove zrok-specific documentation that is no longer applicable.
2.  **Link Audit:** Repair all broken links in `docs/README.md` and ensure it references the "Unified Flutter-Native Architecture" correctly.
3.  **Tunnel Architecture:** Redirect references of `TUNNEL_ARCHITECTURE.md` to the authoritative `docs/ARCHITECTURE/TUNNEL_SYSTEM.md`.

## 3. Execution Steps

1.  **Create Directories:**
    - `mkdir docs/reports`
    - `mkdir docs/plans`
    - `mkdir docs/OPERATIONS/grafana`
    - `mkdir docs/OPERATIONS/git_mcp`
    - `mkdir docs/API/policies`

2.  **Move Files:**
    - Execute `git mv` commands for all identified files.
    - Move root `plans/*.md` to `docs/plans/`.

3.  **Merge & Update:**
    - Manually merge agent context into `docs/DEVELOPMENT/AGENT_CONTEXT.md`.
    - Perform zrok -> cloudflare documentation cleanup.
    - Update `docs/README.md` navigation and links.

## 4. Verification
- Run a link checker or manually verify `docs/README.md`.
- Verify no critical agent instructions were lost during the context merge.