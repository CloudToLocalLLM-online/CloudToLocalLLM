# Changelog

All notable changes to this project will be documented in this file.

## [7.13.3] - 2025-12-19
### 7.13.3 - 2025-12-19

#### Bug Fixes
*   **k8s:** Resolved invalid `targetPort` in Prometheus service.
*   **CI:** Passed `GEMINI_API_KEY` to logic execution and updated changelog generator.

#### Refactoring
*   **CI:** Enforced strict error handling and removed fallbacks in Gemini workflows.

## [7.13.2+202512191357] - 2025-12-19
## v7.13.2+202512191357

### Bug Fixes

*   **ci:** Grant write permissions to invoke job in dispatch workflow (7b861e5)

## [7.13.2+202512191356] - 2025-12-19
## v7.13.2+202512191356

### Bug Fixes

*   **ci:** Resolve permission and config issues in gemini workflows (a0953ee)

## [7.13.2+202512191352] - 2025-12-19
## v7.13.2+202512191352

### Bug Fixes

*   Correct `actions/checkout` versions in Gemini workflows. (99e9b06)

## [7.13.2+202512191329] - 2025-12-19

## v7.13.2+202512191329 (2025-12-19)

### Chore
*   ci: disable auto-deploy to aks on push (3c521f8)

## [7.13.2+202512191326] - 2025-12-19

## v7.13.2+202512191326 (2025-12-19)

### Chore
*   Remove unused mcp server directories (cd02585)

## [7.13.2+202512191317] - 2025-12-19

## 7.13.2+202512191317

### Refactoring

*   Removed SQLite dependency and migrated to PostgreSQL-only. This change simplifies the codebase and improves maintainability.

### Chore

*   Fixed CI versioning to ensure accurate version reporting during builds.

## [7.13.1+202512191252] - 2025-12-19

## 7.13.1+202512191252 (2025-12-19)

### Bug Fixes

*   **ci:** Trigger AKS deployment on main branch pushes (597c8eb)

## [7.13.1+202512191249] - 2025-12-19
## v7.13.1+202512191249 (2025-12-19)

### Bug Fixes

*   **ci:** Handle build metadata in version verification ([`3ba8d79`](https://example.com/commit/3ba8d79))
*   **ci:** Re-enable AKS deployment triggers and fix dispatch authentication ([`8c1e955`](https://example.com/commit/8c1e955))

## [7.13.1+202512191246] - 2025-12-19
## v7.13.1+202512191246

### Bug Fixes
*   **ci:** Allow semantic version increment during tag conflict resolution.
*   **ci:** Inject `GEMINI_API_KEY` into versioning workflow steps.

### Documentation
*   Update WSL guidelines and add DNS fix script.

