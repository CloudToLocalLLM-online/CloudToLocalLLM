# Repository Consolidation and Governance Plan

## Phase 1: Exploration & Audit (Completed)
- [x] Audit `docs/` directory structure.
- [x] Audit `scripts/` directory structure.
- [x] Audit root directory for misplaced files.

## Phase 2: Create Directory Structure & Migrate Docs
- [ ] Create standardized documentation subdirectories:
    - `docs/architecture/`
    - `docs/deployment/`
    - `docs/api/`
    - `docs/operations/`
    - `docs/development/`
    - `docs/governance/` (for legal, security, etc.)
- [ ] Move existing `docs/API/*` to `docs/api/`.
- [ ] Move `docs/ARCHITECTURE/*` and `docs/ARCHITECTURAL_DECISIONS/*` to `docs/architecture/`.
- [ ] Move `docs/DEPLOYMENT/*` to `docs/deployment/`.
- [ ] Move `docs/DEVELOPMENT/*` to `docs/development/`.
- [ ] Move `docs/OPERATIONS/*` and `docs/backend/ops/*` to `docs/operations/`.
- [ ] Move `docs/LEGAL/*` and `docs/SECURITY/*` to `docs/governance/`.
- [ ] Move `plans/*` to `docs/planning/` or `docs/project-management/`? *Decision: Keep `plans/` as active project management, but archive old plans to `docs/archive/plans/`.*

## Phase 3: Content Normalization (Consolidate & Refactor)
- [ ] Consolidate API documentation.
    - Check overlap between `docs/api/README.md`, `docs/api/ADMIN_API.md`, etc.
- [ ] Consolidate Deployment guides.
    - Check overlap between `docs/deployment/README.md`, `docs/deployment/DEPLOYMENT_OVERVIEW.md`, etc.
- [ ] Consolidate Operations manuals.
    - Merge `docs/operations/backend/ops/*` into main operations structure.
- [ ] Create a central `docs/README.md` (Documentation Index).

## Phase 4: Root Directory Sanitation
- [ ] Move `README_*.md` files from root to `docs/` (e.g., `README_AKS_DEPLOYMENT.md`).
- [ ] Move `DEPLOYMENT_SUMMARY.md` to `docs/deployment/`.
- [ ] Move script-related READMEs to `scripts/README.md` or `docs/development/scripts.md`.
- [ ] Ensure only critical files remain in root:
    - `README.md`
    - `LICENSE` (if applicable)
    - `Gemini.md` (or move to `.github/` or `docs/governance/`)
    - Configuration files (`.gitignore`, `pubspec.yaml`, etc.)

## Phase 5: Meta-Governance Implementation
- [ ] Update `Gemini.md` to reflect the new structure.
- [ ] Update `docs/development/CONTRIBUTING.md` with new documentation guidelines.
- [ ] Update `docs/development/MCP_WORKFLOW_AND_RULES.md` if necessary.

## Phase 6: Scripts Organization (Optional/Secondary)
- [ ] Consider organizing `scripts/` into `scripts/deploy/`, `scripts/setup/`, `scripts/maintenance/`, `scripts/test/`.
