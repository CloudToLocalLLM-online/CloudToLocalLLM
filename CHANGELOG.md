# Changelog

All notable changes to this project will be documented in this file.

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

