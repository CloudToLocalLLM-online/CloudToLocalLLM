# Changelog

All notable changes to this project will be documented in this file.

## [7.14.2] - 2025-12-20
# 7.14.2

### Features

*   **(gemini)** Enable manual platform selection for builds in CI workflows. (ef980c8)
*   **(gemini)** Standardize Gemini CLI output to JSON in GitHub workflows for better parsing and reliability. (59c1422)

### Bug Fixes

*   **(ci)** Repaired numerous GitHub Actions workflows to resolve cascading failures in triage, deployment, and Gemini CLI integration. This includes fixing YAML validation, environment variable propagation, permissions, and command invocation logic. (8875a14, 6fb2495, 1d871ed, ff14ae9, 80e16d1, c2e4cd3, b167c43, 55c52c0, 2e91e3f, 18d8176, 4deb995, 0e78968, c17036b, 4b5b29b, 762452b, 76f34b6, 6c8d15a)
*   **(gemini)** Addressed multiple issues with Gemini CLI integration, including reverting to more stable model versions (gemini-1.5-flash), correcting JSON syntax, and removing problematic tool configurations to prevent command errors. (02187f5, 4b8f943, ee2e5ce, a33eaa9, 62286fc)
*   **(k8s)** Updated the web deployment to v7.14.0 to resolve a critical container loading issue. (f5258e9)
*   **(k8s)** Rolled back the web image temporarily to mitigate a missing image error during deployment. (94969b0)
*   **(k8s)** Removed duplicate resources in the base `kustomization.yaml` to prevent validation errors. (ebcc87f)
*   **(docker)** Correctly implemented `COPY <<EOF` syntax for inline scripts within the streaming-proxy Dockerfile to ensure proper execution. (422bc31)

### Refactoring

*   **(ci)** Consolidated all backend service builds into a single, efficient matrix job in the CI pipeline. (ef050df)
*   **(ci)** Standardized and simplified Gemini CLI workflow configurations for improved readability and maintenance. (673433f)
*   **(ops)** Unified all deployment logic into a central `gemini-dispatch` workflow, deleting the redundant `deploy-aks.yml` and transitioning to a pure GitOps model with manual triggers. (ff9d394, 1e4aef8)
*   **(ci)** Refactored CI workflows to improve Kustomize integration and create a more robust versioning strategy. (befa4af)

### Chore

*   Numerous improvements to CI/CD pipeline stability, including fixes for safety parser rejections, enhanced logging, and more resilient workflow dispatching logic. (e4b5b3b, 83b87c1, 3dd988f, 1304183, c83ef10, f6fd3d4, eb1048c, a2ad36e, 6ccea5a, 9d60926, 92db73a, 0937968)
*   Bump version to 7.14.1. (ff6d1ac)

## [7.14.1] - 2025-12-20
# Changelog - v7.14.1

## Features
*   **Gemini:** Enable manual platform selection for builds, providing more control over the CI process (ef980c8).
*   **Gemini:** Standardize Gemini CLI output to JSON in GitHub workflows to improve parsing and reliability (59c1422).

## Bug Fixes
*   **CI:** Repaired multiple GitHub Actions workflows for deployment and triage, addressing issues with Gemini CLI versions, API key propagation, and command execution (8875a14, 6fb2495, 1d871ed).
*   **CI:** Improved the robustness of the issue triage workflow with a one-by-one processing loop, stricter prompts for the model, and better error handling (ff14ae9, 80e16d1, c2e4cd3, b167c43, 55c52c0).
*   **CI:** Stabilized Gemini CLI interactions by resolving YAML validation errors, managing API key settings, and pinning to specific versions to avoid safety blocks and API errors (0e78968, c17036b, 4b5b29b, 4deb995).
*   **CI:** Granted necessary write permissions to the `gemini-invoke` workflow to allow it to comment on issues (762452b).
*   **K8s:** Updated the web deployment to `v7.14.0` to resolve a critical loading issue (f5258e9).
*   **K8s:** Rolled back the web image to a previous version as a hotfix for a missing container image, ensuring service availability (94969b0).
*   **K8s:** Removed duplicate resources from the base `kustomization.yaml` to prevent validation errors (ebcc87f).
*   **Gemini:** Corrected various workflow issues, including JSON syntax errors, tool configuration problems, and reverted to more stable models like `gemini-1.5-flash` where necessary (ee2e5ce, a33eaa9, 4b8f943).
*   **Gemini:** Enabled verbose logging and error report capture for easier debugging of workflow failures (022e899).

## Refactoring
*   **Chore:** Refactored GitHub workflows to improve Kustomize integration and implement more robust versioning logic (befa4af).

## Chore
*   **Ops:** Consolidated deployment logic into a unified `gemini-dispatch` workflow, removing the redundant `deploy-aks.yml` (ff9d394).
*   **Ops:** Transitioned to a pure GitOps model and enabled manual triggers for deployment workflows (1e4aef8).
*   **Ops:** Improved the resilience and error logging of the CI orchestrator script (1304183).
*   **CI:** Addressed multiple causes of workflow startup failures and Gemini CLI safety parser rejections (e4b5b3b, 3dd988f, 83b87c1).
*   **CI:** Simplified workflow dispatch logic and added safety guards for inputs to prevent unexpected behavior (9d60926, a2ad36e, 6ccea5a).

## [7.14.0] - 2025-12-19

## 7.14.0 - 2025-12-19

### Features
* **k8s:** Separated workloads into individual Argo CD applications.

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

