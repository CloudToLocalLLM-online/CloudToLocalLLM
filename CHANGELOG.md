# Changelog

All notable changes to this project will be documented in this file.

## [7.15.2] - 2025-12-26
## v7.15.2 (2024-10-27)

### Features
*   feat: add secure secret injection to deployment pipeline (fe62dfb)
*   feat(ops): add script to fix Azure OIDC subject mismatch (b92761b)
*   feat(infra): add cloudflare tunnel configuration and service (0e9d558)

### Bug Fixes
*   fix: resolve secrets deployment failure and optimize pipeline (794c576)
*   fix: resolve ArgoCD 502 gateway and optimize cloudflared stability (7008d0c)
*   fix(ci): correctly handle optional cloudflare token in validation script (dc2beb1)
*   fix(ci): make Cloudflare DNS token optional in validation to prevent blocking (925898e)
*   fix(ci): use standard azure/login@v2 action for authentication (027ae8f)
*   fix(ci): fetch OIDC token manually for az login (4ae8ea7)
*   fix(ci): correct az login flags and set subscription separately (22f4771)
*   fix(ci): replace retry action with shell loop for az login to access OIDC token (578d2b5)
*   fix(ci): join az login command to single line to fix retry action args (d48c2d5)
*   fix(ci): fix incorrect action name for retry action (e857d69)
*   fix(ci): migrate build pipeline to standard runners and update tokens (7ba02f8)
*   fix(ci): use GITHUB_TOKEN for checkout to enable push (9fde24b)
*   fix(ci): use GITHUB_TOKEN for dispatch to resolve 403 (542f9bf)
*   fix(ci): convert gemini-cli.cjs to unix line endings (11d1c33)
*   fix(ci): restore orchestration logic with simplified json handling (cb5efae)
*   fix(ci): isolate workflow failure by removing sub-workflows (173078b)
*   fix(ci): debug workflow validity (8f8ce1d)
*   fix(ci): fallback to ubuntu-latest to debug runner issue (46c26b1)
*   fix(ci): move json cleanup to cli script and simplify workflows (640ace9)
*   fix(ci): use python for robust json extraction in workflows (8e75bb5)
*   fix(ci): stabilize workflows by standardizing gemini CLI usage and JSON parsing (f19c239)
*   fix(ci): stabilize GHA workflows and enforce fail-fast Gemini integration (6ba2703)
*   fix(scripts): ensure generate-changelog.sh is executable and LF normalized (368e6e9)
*   fix(scripts): force LF line endings for shell scripts (e06627d)
*   fix(ci): robust json extraction from gemini output in orchestrator (5e09273)

### Documentation
*   docs: archive stray task reports from codebase to docs/archive/tasks/ (5826a4c)
*   docs: restructure documentation and unify agent context (bf829f5)

### Chore
*   chore: bump version to 7.15.1 (670377e)
*   chore(deploy): promote version main-1bf90126e50ed152eab193704119cc3efceca143 [skip ci] (dfab785)
*   chore: bump version to 7.15.0 (29ea52f)
*   chore: bump version to 7.14.32 (1bf9012)
*   chore(deploy): promote version main-3053fa7d7e1391252e18d85228d57ae7de4741d1 [skip ci] (690f9bb)
*   chore: bump version to 7.14.31 (3053fa7)
*   chore: bump version to 7.14.30 (ab60407)
*   chore: bump version to 7.14.29 (6396fa9)

## [7.15.1] - 2025-12-26
## 7.15.1 (Unreleased)

### Features
*   feat: add secure secret injection to deployment pipeline (fe62dfb)
*   feat(ops): add script to fix Azure OIDC subject mismatch (b92761b)
*   feat(infra): add cloudflare tunnel configuration and service (0e9d558)

### Bug Fixes
*   fix: resolve ArgoCD 502 gateway and optimize cloudflared stability (7008d0c)
*   fix(ci): correctly handle optional cloudflare token in validation script (dc2beb1)
*   fix(ci): make Cloudflare DNS token optional in validation to prevent blocking (925898e)
*   fix(ci): use standard azure/login@v2 action for authentication (027ae8f)
*   fix(ci): fetch OIDC token manually for az login (4ae8ea7)
*   fix(ci): correct az login flags and set subscription separately (22f4771)
*   fix(ci): replace retry action with shell loop for az login to access OIDC token (578d2b5)
*   fix(ci): join az login command to single line to fix retry action args (d48c2d5)
*   fix(ci): migrate build pipeline to standard runners and update tokens (7ba02f8)
*   fix(ci): use GITHUB_TOKEN for checkout to enable push (9fde24b)
*   fix(ci): use GITHUB_TOKEN for dispatch to resolve 403 (542f9bf)
*   fix(ci): convert gemini-cli.cjs to unix line endings (11d1c33)
*   fix(ci): restore orchestration logic with simplified json handling (cb5efae)
*   fix(ci): isolate workflow failure by removing sub-workflows (173078b)
*   fix(ci): debug workflow validity (8f8ce1d)
*   fix(ci): fallback to ubuntu-latest to debug runner issue (46c26b1)
*   fix(ci): move json cleanup to cli script and simplify workflows (640ace9)
*   fix(ci): use python for robust json extraction in workflows (8e75bb5)
*   fix(ci): stabilize workflows by standardizing gemini CLI usage and JSON parsing (f19c239)
*   fix(ci): stabilize GHA workflows and enforce fail-fast Gemini integration (6ba2703)
*   fix(scripts): ensure generate-changelog.sh is executable and LF normalized (368e6e9)
*   fix(scripts): force LF line endings for shell scripts (e06627d)
*   fix(ci): robust json extraction from gemini output in orchestrator (5e09273)
*   fix(argocd): solve NOAUTH and manifestation timeouts (a86d9c3)
*   fix(gitops): de-duplicate resources between infrastructure and api-backend (e50e5c7)

### Documentation
*   docs: archive stray task reports from codebase to docs/archive/tasks/ (5826a4c)
*   docs: restructure documentation and unify agent context (bf829f5)

### Chore
*   chore(deploy): promote version main-1bf90126e50ed152eab193704119cc3efceca143 [skip ci] (dfab785)
*   chore: bump version to 7.15.0 (29ea52f)
*   chore: bump version to 7.14.32 (1bf9012)
*   chore(deploy): promote version main-3053fa7d7e1391252e18d85228d57ae7de4741d1 [skip ci] (690f9bb)
*   chore: bump version to 7.14.31 (3053fa7)
*   chore: bump version to 7.14.30 (ab60407)
*   chore: bump version to 7.14.29 (6396fa9)
*   chore(ci): broaden dependabot commit exclusion in main orchestrator (d8f17bf)

## [7.15.0] - 2025-12-26
## v7.15.0

### Features
*   **infra:** Add cloudflare tunnel configuration and service. (0e9d558)
*   Add secure secret injection to deployment pipeline. (fe62dfb)
*   **ops:** Add script to fix Azure OIDC subject mismatch. (b92761b)

### Bug Fixes
*   **argocd:** Restore connectivity and optimize resources. (41f66c9)
*   **argocd:** Solve NOAUTH and manifestation timeouts. (a86d9c3)
*   **ci:** Correct az login flags and set subscription separately. (22f4771)
*   **ci:** Convert gemini-cli.cjs to unix line endings. (11d1c33)
*   **ci:** Fallback to ubuntu-latest to debug runner issue. (46c26b1)
*   **ci:** Fetch OIDC token manually for az login. (4ae8ea7)
*   **ci:** Fix incorrect action name for retry action. (e857d69)
*   **ci:** Isolate workflow failure by removing sub-workflows. (173078b)
*   **ci:** Join az login command to single line to fix retry action args. (d48c2d5)
*   **ci:** Make Cloudflare DNS token optional in validation to prevent blocking. (925898e)
*   **ci:** Migrate build pipeline to standard runners and update tokens. (7ba02f8)
*   **ci:** Restore orchestration logic with simplified json handling. (cb5efae)
*   **ci:** Replace retry action with shell loop for az login to access OIDC token. (578d2b5)
*   **ci:** Stabilize GHA workflows and enforce fail-fast Gemini integration. (6ba2703)
*   **ci:** Stabilize workflows by standardizing gemini CLI usage and JSON parsing. (f19c239)
*   **ci:** Use GITHUB_TOKEN for checkout to enable push. (9fde24b)
*   **ci:** Use GITHUB_TOKEN for dispatch to resolve 403. (542f9bf)
*   **ci:** Use python for robust json extraction in workflows. (8e75bb5)
*   **ci:** debug workflow validity. (8f8ce1d)
*   **ci:** correctly handle optional cloudflare token in validation script. (dc2beb1)
*   **ci:** move json cleanup to cli script and simplify workflows. (640ace9)
*   **ci:** robust json extraction from gemini output in orchestrator. (5e09273)
*   **gitops:** De-duplicate resources between infrastructure and api-backend. (e50e5c7)
*   **scripts:** Ensure generate-changelog.sh is executable and LF normalized. (368e6e9)
*   **scripts:** Force LF line endings for shell scripts. (e06627d)

### Documentation
*   Archive stray task reports from codebase to docs/archive/tasks/. (5826a4c)
*   Restructure documentation and unify agent context. (bf829f5)
*   Update operational rules and add manifests. (54b7a5b)

### Chore
*   **argocd:** Finalized resource optimizations and probe fixes. (ac24e9a)
*   **ci:** Broaden dependabot commit exclusion in main orchestrator. (d8f17bf)
*   **ci:** Exclude dependabot from main orchestrator. (9e67bef)
*   **ci:** Remove validation workflow and add emoji to build pipeline. (f70d23c)
*   **deploy:** Promote version main-3053fa7d7e1391252e18d85228d57ae7de4741d1 [skip ci]. (690f9bb)
*   **deploy:** Promote version main-368e6e984aee8d2597329f144fdd125d6d4068ab [skip ci]. (e40cfd0)
*   **deploy:** Promote version main-e06627d863c0ee86579bc0f444049

## [7.14.32] - 2025-12-26
# Changelog

## 7.14.32 (2024-11-02)

### Features
*   **(ops):** Add script to fix Azure OIDC subject mismatch (b92761b)
*   **(infra):** Add cloudflare tunnel configuration and service (0e9d558)

### Bug Fixes
*   Sanitize credentials and refine sync script (db3815e)
*   **(ci):** Correctly handle optional cloudflare token in validation script (dc2beb1)
*   **(ci):** Make Cloudflare DNS token optional in validation to prevent blocking (925898e)
*   **(ci):** Use standard azure/login@v2 action for authentication (027ae8f)
*   **(ci):** Fetch OIDC token manually for az login (4ae8ea7)
*   **(ci):** Correct az login flags and set subscription separately (22f4771)
*   **(ci):** Replace retry action with shell loop for az login to access OIDC token (578d2b5)
*   **(ci):** Join az login command to single line to fix retry action args (d48c2d5)
*   **(ci):** Migrate build pipeline to standard runners and update tokens (7ba02f8)
*   **(ci):** Use GITHUB_TOKEN for checkout to enable push (9fde24b)
*   **(ci):** Use GITHUB_TOKEN for dispatch to resolve 403 (542f9bf)
*   **(ci):** Convert gemini-cli.cjs to unix line endings (11d1c33)
*   **(ci):** Restore orchestration logic with simplified json handling (cb5efae)
*   **(ci):** Isolate workflow failure by removing sub-workflows (173078b)
*   **(ci):** Debug workflow validity (8f8ce1d)
*   **(ci):** Fallback to ubuntu-latest to debug runner issue (46c26b1)
*   **(ci):** Move json cleanup to cli script and simplify workflows (640ace9)
*   **(ci):** Use python for robust json extraction in workflows (8e75bb5)
*   **(ci):** Stabilize workflows by standardizing gemini CLI usage and JSON parsing (f19c239)
*   **(ci):** Stabilize GHA workflows and enforce fail-fast Gemini integration (6ba2703)
*   **(scripts):** Ensure generate-changelog.sh is executable and LF normalized (368e6e9)
*   **(scripts):** Force LF line endings for shell scripts (e06627d)
*   **(ci):** Robust json extraction from gemini output in orchestrator (5e09273)
*   **(argocd):** Solve NOAUTH and manifestation timeouts (a86d9c3)
*   **(gitops):** De-duplicate resources between infrastructure and api-backend (e50e5c7)
*   **(argocd):** Restore connectivity and optimize resources (41f66c9)
*   Fix gemini-1.5-flash (ccf2cd3)
*   Fix (e635c16)

### Documentation
*   Archive stray task reports from codebase to docs/archive/tasks/ (5826a4c)
*   Restructure documentation and unify agent context (bf829f5)
*   Update operational rules and add manifests (54b7a5b)

### Chore
*   Bump version to 7.14.31 (3053fa7)
*   Bump version to 7.14.30 (ab60407)
*   Bump version to 7.14.29 (6396fa9)
*   **(ci):** Broaden dependabot commit exclusion in main orchestrator (d8f17bf)
*   Enforce LF line endings and normalize (59dab96)
*   Bump version to 7.14.28 (d295a6a)
*   Bump version to 7.14.27 (b7e7a0e)
*   **(ci):** Remove validation workflow and add emoji to build pipeline (f70d23c)
*   **(ci):** Fix incorrect action name for retry action (e857d6

## [7.14.31] - 2025-12-26
## 7.14.31 (2024-02-29)

### Features

*   **(infra):** Add cloudflare tunnel configuration and service ([0e9d558](https://github.com/your-repo/your-project/commit/0e9d558))
*   **(ops):** Add script to fix Azure OIDC subject mismatch ([b92761b](https://github.com/your-repo/your-project/commit/b92761b))

### Bug Fixes

*   Fix various issues related to Gemini 1.5 Flash and other unspecified problems. ([e635c16](https://github.com/your-repo/your-project/commit/e635c16), [ccf2cd3](https://github.com/your-repo/your-project/commit/ccf2cd3), [03092e7](https://github.com/your-repo/your-project/commit/03092e7), [302d62f](https://github.com/your-repo/your-project/commit/302d62f))
*   **(argocd):** Restore connectivity and optimize resources ([41f66c9](https://github.com/your-repo/your-project/commit/41f66c9))
*   **(argocd):** Solve NOAUTH and manifestation timeouts ([a86d9c3](https://github.com/your-repo/your-project/commit/a86d9c3))
*   **(ci):** Correct az login flags and set subscription separately ([22f4771](https://github.com/your-repo/your-project/commit/22f4771))
*   **(ci):** Convert gemini-cli.cjs to unix line endings ([11d1c33](https://github.com/your-repo/your-project/commit/11d1c33))
*   **(ci):** Fallback to ubuntu-latest to debug runner issue ([46c26b1](https://github.com/your-repo/your-project/commit/46c26b1))
*   **(ci):** Fetch OIDC token manually for az login ([4ae8ea7](https://github.com/your-repo/your-project/commit/4ae8ea7))
*   **(ci):** Isolate workflow failure by removing sub-workflows ([173078b](https://github.com/your-repo/your-project/commit/173078b))
*   **(ci):** Join az login command to single line to fix retry action args ([d48c2d5](https://github.com/your-repo/your-project/commit/d48c2d5))
*   **(ci):** Make Cloudflare DNS token optional in validation to prevent blocking ([925898e](https://github.com/your-repo/your-project/commit/925898e))
*   **(ci):** Migrate build pipeline to standard runners and update tokens ([7ba02f8](https://github.com/your-repo/your-project/commit/7ba02f8))
*   **(ci):** Restore orchestration logic with simplified json handling ([cb5efae](https://github.com/your-repo/your-project/commit/cb5efae))
*   **(ci):** Stabilize GHA workflows and enforce fail-fast Gemini integration ([6ba2703](https://github.com/your-repo/your-project/commit/6ba2703))
*   **(ci):** Stabilize workflows by standardizing gemini CLI usage and JSON parsing ([f19c239](https://github.com/your-repo/your-project/commit/f19c239))
*   **(ci):** Use GITHUB_TOKEN for checkout to enable push ([9fde24b](https://github.com/your-repo/your-project/commit/9fde24b))
*   **(ci):** Use GITHUB_TOKEN for dispatch to resolve 403 ([542f9bf](https://github.com/your-repo/your-project/commit/542f9bf))
*   **(ci):** Use python for robust json extraction in workflows ([8e75bb5

## [7.14.30] - 2025-12-26
## v7.14.30 (2024-10-27)

### Features

*   Add cloudflare tunnel configuration and service ([0e9d558](https://github.com/example/example/commit/0e9d558))
*   Add script to fix Azure OIDC subject mismatch ([b92761b](https://github.com/example/example/commit/b92761b))
*   (464e7d9) gemini-1.5-flash

### Bug Fixes

*   Correct az login flags and set subscription separately ([22f4771](https://github.com/example/example/commit/22f4771))
*   Convert gemini-cli.cjs to unix line endings ([11d1c33](https://github.com/example/example/commit/11d1c33))
*   Debug workflow validity ([8f8ce1d](https://github.com/example/example/commit/8f8ce1d))
*   Ensure generate-changelog.sh is executable and LF normalized ([368e6e9](https://github.com/example/example/commit/368e6e9))
*   Fallback to ubuntu-latest to debug runner issue ([46c26b1](https://github.com/example/example/commit/46c26b1))
*   Fetch OIDC token manually for az login ([4ae8ea7](https://github.com/example/example/commit/4ae8ea7))
*   Force LF line endings for shell scripts ([e06627d](https://github.com/example/example/commit/e06627d))
*   Isolate workflow failure by removing sub-workflows ([173078b](https://github.com/example/example/commit/173078b))
*   Join az login command to single line to fix retry action args ([d48c2d5](https://github.com/example/example/commit/d48c2d5))
*   Make Cloudflare DNS token optional in validation to prevent blocking ([925898e](https://github.com/example/example/commit/925898e))
*   Migrate build pipeline to standard runners and update tokens ([7ba02f8](https://github.com/example/example/commit/7ba02f8))
*   Move json cleanup to cli script and simplify workflows ([640ace9](https://github.com/example/example/commit/640ace9))
*   Replace retry action with shell loop for az login to access OIDC token ([578d2b5](https://github.com/example/example/commit/578d2b5))
*   Restore connectivity and optimize resources ([41f66c9](https://github.com/example/example/commit/41f66c9))
*   Restore orchestration logic with simplified json handling ([cb5efae](https://github.com/example/example/commit/cb5efae))
*   Robust json extraction from gemini output in orchestrator ([5e09273](https://github.com/example/example/commit/5e09273))
*   Solve NOAUTH and manifestation timeouts ([a86d9c3](https://github.com/example/example/commit/a86d9c3))
*   Stabilize GHA workflows and enforce fail-fast Gemini integration ([6ba2703](https://github.com/example/example/commit/6ba2703))
*   Stabilize workflows by standardizing gemini CLI usage and JSON parsing ([f19c239](https://github.com/example/example/commit/f19c239))
*   Use GITHUB_TOKEN for checkout to enable push ([9fde24b](https://github.com/example/example/commit/9fde24b))
*   Use GITHUB_TOKEN for dispatch to resolve 403 ([542f9bf](https://github.com/example/example/commit/542f9bf))
*   Use python for robust json extraction in workflows ([8e75bb5](https://github.com/example/example/commit/8e75bb5))
*   Use standard azure/login@v

## [7.14.29] - 2025-12-26
## v7.14.29 (2024-10-27)

### Features
*   **(infra):** Add cloudflare tunnel configuration and service (0e9d558)
*   **(ops):** Add script to fix Azure OIDC subject mismatch (b92761b)
*   Add domain routing diagnostics & fixes (fe469ba)
*   (464e7d9)

### Bug Fixes
*   **(argocd):** Restore connectivity and optimize resources (41f66c9)
*   **(argocd):** Solve NOAUTH and manifestation timeouts (a86d9c3)
*   **(ci):** Convert gemini-cli.cjs to unix line endings (11d1c33)
*   **(ci):** Correct az login flags and set subscription separately (22f4771)
*   **(ci):** Debug workflow validity (8f8ce1d)
*   **(ci):** Fallback to ubuntu-latest to debug runner issue (46c26b1)
*   **(ci):** Fetch OIDC token manually for az login (4ae8ea7)
*   **(ci):** Isolate workflow failure by removing sub-workflows (173078b)
*   **(ci):** Join az login command to single line to fix retry action args (d48c2d5)
*   **(ci):** Migrate build pipeline to standard runners and update tokens (7ba02f8)
*   **(ci):** Move json cleanup to cli script and simplify workflows (640ace9)
*   **(ci):** Replace retry action with shell loop for az login to access OIDC token (578d2b5)
*   **(ci):** Restore orchestration logic with simplified json handling (cb5efae)
*   **(ci):** Robust json extraction from gemini output in orchestrator (5e09273)
*   **(ci):** Stabilize GHA workflows and enforce fail-fast Gemini integration (6ba2703)
*   **(ci):** Stabilize workflows by standardizing gemini CLI usage and JSON parsing (f19c239)
*   **(ci):** Use GITHUB_TOKEN for checkout to enable push (9fde24b)
*   **(ci):** Use GITHUB_TOKEN for dispatch to resolve 403 (542f9bf)
*   **(ci):** Use python for robust json extraction in workflows (8e75bb5)
*   **(ci):** Use standard azure/login@v2 action for authentication (027ae8f)
*   **(gitops):** De-duplicate resources between infrastructure and api-backend (e50e5c7)
*   **(scripts):** Ensure generate-changelog.sh is executable and LF normalized (368e6e9)
*   **(scripts):** Force LF line endings for shell scripts (e06627d)
*   (03092e7)
*   (302d62f)
*   (ccf2cd3)
*   (e635c16)
*   (eadf45b)

### Documentation
*   Archive stray task reports from codebase to docs/archive/tasks/ (5826a4c)
*   Enforce Sequential Thinking Mandate and update MCP tool manual (89d31fe)
*   Restructure documentation and unify agent context (bf829f5)
*   Update operational rules and add manifests (54b7a5b)

### Chore
*   **(argocd):** Finalized resource optimizations and probe fixes (ac24e9a)
*   **(ci):** Broaden dependabot commit exclusion in main orchestrator (d8f17bf)
*   **(ci):** Exclude dependabot from main orchestrator (9e67bef)
*   **(ci):** Fix incorrect action name for retry action (e857d69)
*   **(ci):** Remove validation workflow and add emoji to build pipeline (f70d23c)
*   **(deploy):** Promote version main-302d62faf8af552e9be2d890b0f852231fb3e957 [skip ci] (1a32ea5)
*   **(deploy):** Promote version main-368e6e984a

## [7.14.28] - 2025-12-26
## v7.14.28 (2024-10-27)

### Features
* **infra:** Add cloudflare tunnel configuration and service. (0e9d558)
* Enhance ArgoCD stabilization with ROBUST testing and error handling. (5396e7f)
* Implement comprehensive ArgoCD stabilization plan for CloudToLocalLLM. (a6801e7)
* (464e7d9)
* CRITICAL FIX: ADD DOMAIN ROUTING DIAGNOSTICS & FIXES (fe469ba)

### Bug Fixes
* **argocd:** Solve NOAUTH and manifestation timeouts. (a86d9c3)
* **argocd:** Restore connectivity and optimize resources. (41f66c9)
* **ci:** Correct az login flags and set subscription separately. (22f4771)
* **ci:** Replace retry action with shell loop for az login to access OIDC token. (578d2b5)
* **ci:** Join az login command to single line to fix retry action args. (d48c2d5)
* **ci:** Migrate build pipeline to standard runners and update tokens. (7ba02f8)
* **ci:** Use GITHUB_TOKEN for checkout to enable push. (9fde24b)
* **ci:** Use GITHUB_TOKEN for dispatch to resolve 403. (542f9bf)
* **ci:** Convert gemini-cli.cjs to unix line endings. (11d1c33)
* **ci:** Restore orchestration logic with simplified json handling. (cb5efae)
* **ci:** Isolate workflow failure by removing sub-workflows. (173078b)
* **ci:** Debug workflow validity. (8f8ce1d)
* **ci:** Fallback to ubuntu-latest to debug runner issue. (46c26b1)
* **ci:** Move json cleanup to cli script and simplify workflows. (640ace9)
* **ci:** Use python for robust json extraction in workflows. (8e75bb5)
* **ci:** Stabilize workflows by standardizing gemini CLI usage and JSON parsing. (f19c239)
* **ci:** Stabilize GHA workflows and enforce fail-fast Gemini integration. (6ba2703)
* **ci:** Robust json extraction from gemini output in orchestrator. (5e09273)
* **gitops:** De-duplicate resources between infrastructure and api-backend. (e50e5c7)
* **scripts:** Ensure generate-changelog.sh is executable and LF normalized. (368e6e9)
* **scripts:** Force LF line endings for shell scripts. (e06627d)
* Update web-frontend kustomization to reference correct file paths (f0583c2)
* Remove shared RBAC role from web-frontend kustomization to resolve resource conflict (ff970b8)
* Remove shared network policies from web-frontend kustomization to resolve resource conflict (3cc279e)
* Remove shared namespace from web-frontend kustomization to resolve resource conflict (941f28f)
* (e635c16)
* (ccf2cd3)
* (03092e7)
* (302d62f)
* (eadf45b)

### Documentation
* Archive stray task reports from codebase to docs/archive/tasks/. (5826a4c)
* Restructure documentation and unify agent context. (bf829f5)
* Update operational rules and add manifests. (54b7a5b)
* Enforce Sequential Thinking Mandate and update MCP tool manual. (89d31fe)

### Chore
* Bump version to 7.14.27 (b7e7a0e)
* Remove validation workflow and add emoji to build pipeline. (f70d23c)
* Fix incorrect action name for retry action. (e857d69)
* Exclude dependabot from main orchestrator. (9e67bef)
* Force refresh build pipeline config. (eeb8221)
* Update all repository references to GitHub Enterprise. (7d6188e)
* Promote version main-368e6e984aee8d2597329f144

## [7.14.27] - 2025-12-26
## v7.14.27

### Features

*   **(infra):** Add cloudflare tunnel configuration and service. (0e9d558)
*   Enhance ArgoCD stabilization with ROBUST testing and error handling. (5396e7f)
*   Implement comprehensive ArgoCD stabilization plan for CloudToLocalLLM. (a6801e7)
*   Add domain routing diagnostics & fixes. (fe469ba)
*   (464e7d9)

### Bug Fixes

*   **(ci):** Replace retry action with shell loop for az login to access OIDC token. (578d2b5)
*   **(ci):** Join az login command to single line to fix retry action args. (d48c2d5)
*   **(ci):** Migrate build pipeline to standard runners and update tokens. (7ba02f8)
*   **(ci):** Use GITHUB_TOKEN for checkout to enable push. (9fde24b)
*   **(ci):** Use GITHUB_TOKEN for dispatch to resolve 403. (542f9bf)
*   **(ci):** Convert gemini-cli.cjs to unix line endings. (11d1c33)
*   **(ci):** Restore orchestration logic with simplified json handling. (cb5efae)
*   **(ci):** Isolate workflow failure by removing sub-workflows. (173078b)
*   **(ci):** Debug workflow validity. (8f8ce1d)
*   **(ci):** Fallback to ubuntu-latest to debug runner issue. (46c26b1)
*   **(ci):** Move json cleanup to cli script and simplify workflows. (640ace9)
*   **(ci):** Use python for robust json extraction in workflows. (8e75bb5)
*   **(ci):** Stabilize workflows by standardizing gemini CLI usage and JSON parsing. (f19c239)
*   **(ci):** Stabilize GHA workflows and enforce fail-fast Gemini integration. (6ba2703)
*   **(scripts):** Ensure generate-changelog.sh is executable and LF normalized. (368e6e9)
*   **(scripts):** Force LF line endings for shell scripts. (e06627d)
*   **(ci):** Robust json extraction from gemini output in orchestrator. (5e09273)
*   **(argocd):** Solve NOAUTH and manifestation timeouts. (a86d9c3)
*   **(gitops):** De-duplicate resources between infrastructure and api-backend. (e50e5c7)
*   **(argocd):** Restore connectivity and optimize resources. (41f66c9)
*   Update web-frontend kustomization to reference correct file paths. (f0583c2)
*   Remove shared RBAC role from web-frontend kustomization to resolve resource conflict. (ff970b8)
*   Remove shared network policies from web-frontend kustomization to resolve resource conflict. (3cc279e)
*   Remove shared namespace from web-frontend kustomization to resolve resource conflict. (941f28f)
*   Remove shared configmap from web-frontend kustomization to resolve resource conflict. (8e301e4)
*   Remove invalid patchesStrategicMerge from api-backend kustomization. (85dd22d)
*   (e635c16)
*   (ccf2cd3)
*   (03092e7)
*   (302d62f)
*   (eadf45b)

### Documentation

*   Archive stray task reports from codebase to docs/archive/tasks/. (5826a4c)
*   Restructure documentation and unify agent context. (bf829f5)
*   Update operational rules and add manifests. (54b7a5b)
*   Enforce Sequential Thinking Mandate and update MCP tool manual. (89d31fe)

### Chore

*   **(ci):** Remove validation workflow and add emoji to build pipeline. (f70d23c)
*   **(ci):** Fix incorrect action name for retry action. (e857d69)
*   **(ci):** Exclude dependabot from main orchestrator. (9e67bef)

## [7.14.26] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.25] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.24] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.23] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.22] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.21] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.20] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.19] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.18] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.17] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.16] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.15] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.14] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.13] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.12] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.11] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.10] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.9] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.8] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.7] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.6] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.5] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.4] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.14.3] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.13.3] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.13.2] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.13.1] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.15] - 2025-12-23
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.14] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.13] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.12] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.11] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.10] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.9] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.8] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.7] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.6] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.5] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.4] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.3] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.2] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.1] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.1] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.1] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.1] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.1] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.1] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.1] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.81] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.80] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.79] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.78] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.77] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.76] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.75] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.74] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.73] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.72] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.71] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.70] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.69] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.68] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.67] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.66] - 2025-12-22
### Features
* feat: re-enable AI workflows with AI Agent Gateway
* feat: update AI Agent CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use AI Agent CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to AI Agent workflows
* refactor: update all workflow environment variables and API calls

## [7.0.65] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.64] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.63] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.62] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.61] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.60] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.59] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.58] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.57] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.56] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.55] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.54] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.53] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.52] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.51] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.50] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.49] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.48] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.47] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.46] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.45] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.44] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.43] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.42] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.41] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.40] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.39] - 2025-12-22
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.38] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.37] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.36] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.35] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.34] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.33] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.32] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.31] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.30] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.29] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.28] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.27] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.26] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.25] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.24] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.23] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.22] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.21] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.20] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.19] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.18] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.17] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.16] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.15] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.14] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.13] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.12] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.11] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.10] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.9] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.8] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.7] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.6] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.5] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.4] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.3] - 2025-12-21
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.2] - 2025-12-20
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.1] - 2025-12-20
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.0] - 2025-12-20
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.0] - 2025-12-20
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.0.0] - 2025-12-20
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [4.5.1] - 2025-12-20
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [4.5.1] - 2025-12-20
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [4.5.1] - 2025-12-20
### Features
* feat: re-enable AI workflows with KiloCode Gateway
* feat: update KiloCode CLI to return proper JSON format

### Bug Fixes
* fix: update generate-changelog.sh to use KiloCode CLI instead of Gemini

### Refactoring
* refactor: rename Gemini workflows to KiloCode workflows
* refactor: update all workflow environment variables and API calls

## [7.15.0] - 2025-12-20
# Changelog for v7.15.0

This release focuses on significant CI/CD enhancements, Kubernetes configuration improvements, and robust testing additions. Key features include the integration of `ingress-cloudflared` for local development and a new automated test suite for Auth0 user management.

## Features

- **(k8s)** Add `ingress-cloudflared` to the local development profile for easier and more secure local testing (7ef0705).
- **(test)** Implement an automated Auth0 test user suite to improve authentication reliability and fix a redirect URI issue (5de36fd).

## Bug Fixes

- **(ci)** Repaired and enhanced numerous GitHub Actions workflows, resolving issues with matrix syntax, conditional logic, and Gemini CLI integration. This includes fixes for YAML validation, environment variable propagation, and robust error handling during triage and deployment (593f833, 8e2b466, b5554d3, 454245b, 8f663ea, 6fb2495, 1d871ed, ff14ae9, 80e16d1, c2e4cd3, b167c43, 55c52c0, 2e91e3f, 18d8176, 4deb995, 0e78968, c17036b, c61f910, a34854a, 4b5b29b, 673433f, 762452b, 8875a14).
- **(docker)** Corrected Dockerfile scripts for the `streaming-proxy` by disabling variable interpolation in heredocs and using the `COPY <<EOF` syntax for inline scripts (447e994, 422bc31).
- **(k8s)** Rolled back the web image to a stable version to address a missing image issue and updated the web deployment to resolve a critical loading problem (94969b0, f5258e9).
- **(k8s)** Removed duplicate resources from the base `kustomization.yaml` to clean up the Kubernetes configuration (ebcc87f).

## Refactoring

- **(k8s)** Split the monolithic `argo-apps.yaml` into individual application manifests for better maintainability and clarity within the GitOps structure (a5d5407).

## Chore

- **(ops)** Unified the dispatch entry point for workflows and refactored orchestrator analysis to use `curl` for improved reliability (c83ef10).
- **(ops)** Addressed and fixed failures in the Acknowledge step for `push` events (f6fd3d4).
- **(ci)** Consolidated service builds into a single matrix job and ensured the base image build runs first, streamlining the CI pipeline (ef050df, 92db73a).
- **(ci)** Improved safety guards, concurrency logic, and error parsing for various workflow dispatches to prevent startup failures (9d60926, 83b87c1, 6ccea5a, a2ad36e, 3dd988f, eb1048c, e4b5b3b).

## [7.14.4] - 2025-12-20
# Changelog for v7.14.4

## Features
* **(test)**: Added an automated test suite for Auth0 user management and corrected the Auth0 redirect URI to enhance authentication reliability. (5de36fd)

## Bug Fixes
* **(ci)**: Repaired and stabilized multiple GitHub Actions workflows by addressing issues with Gemini CLI versions, API key propagation, YAML validation, conditional logic, and deployment triage. This includes standardizing the CLI version, ensuring correct permissions, and improving the robustness of triage loops. (8875a14, 673433f, 762452b, 4b5b29b, a34854a, c61f910, c17036b, 0e78968, 4deb995, 18d8176, 2e91e3f, 55c52c0, b167c43, c2e4cd3, 80e16d1, ff14ae9, 1d871ed, 6fb2495)
* **(ci)**: Fixed build matrix logic by reverting to separate jobs, correcting conditional expressions, and resolving context issues with build arguments. (593f833, 8e2b466, b5554d3, 454245b, 8f663ea, 6c8d15a, 76f34b6)
* **(docker)**: Resolved an issue with variable interpolation in heredocs for the `streaming-proxy` by disabling it and using `COPY <<EOF` syntax for inline scripts. (447e994, 422bc31)
* **(k8s)**: Updated the web deployment to v7.14.0, resolving a critical loading issue. Also removed duplicate resources from the base `kustomization.yaml` and temporarily reverted a web image due to a missing build. (f5258e9, ebcc87f, 94969b0)

## Refactoring
* **(k8s)**: Split the monolithic `argo-apps.yaml` into individual application manifests for better organization and management within Argo CD. (a5d5407)

## Chore
* **(ops)**: Consolidated the deployment process into a unified `gemini-dispatch` workflow, deleting the redundant `deploy-aks.yml`. (ff9d394)
* **(ops)**: Improved the resilience of the workflow orchestrator with better error logging and refactored analysis steps. (1304183, c83ef10)
* **(ci)**: Enhanced CI job organization by consolidating service builds into a single matrix job and adding descriptive naming. (ef050df, 29b9f68)
* **(ci)**: Added safety guards and simplified logic for workflow dispatch to prevent startup failures. (a2ad36e, 6ccea5a, 83b87c1, 9d60926, 3dd988f)

## [7.14.3] - 2025-12-20
# Changelog

## [7.14.3] - 2025-12-20

### Features
- **(test)** Add automated Auth0 test user suite and fix redirect URI. (5de36fd)
- **(gemini)** Enable manual platform selection for builds. (ef980c8)

### Bug Fixes
- **(ci)** A series of fixes to improve the robustness and reliability of GitHub Actions workflows, including resolving matrix syntax issues, simplifying conditional logic, fixing Gemini CLI versioning and API key propagation, and repairing deployment and triage processes. (593f833, 8e2b466, b5554d3, 454245b, 8f663ea, 76f34b6, 6c8d15a, 6fb2495, 1d871ed, ff14ae9, 80e16d1, c2e4cd3, b167c43, 55c52c0, 2e91e3f, 18d8176, 4deb995, 0e78968, c17036b, c61f910, a34854a, 4b5b29b, 673433f, 762452b, 8875a14)
- **(docker)** Disable variable interpolation in heredocs and update `COPY` syntax for inline scripts in the streaming-proxy to prevent unintended expansions. (447e994, 422bc31)
- **(k8s)** Update web deployment to v7.14.0, remove duplicate resources in base kustomization, and temporarily roll back the web image to resolve loading issues. (f5258e9, ebcc87f, 94969b0)

### Chore
- **(ops)** Transition to a pure GitOps model with manual triggers, unifying the dispatch entry point and consolidating deployment workflows for improved resilience and maintainability. (1e4aef8, c83ef10, 1304183, ff9d394, f6fd3d4)
- **(ci)** Improve CI configuration by adding descriptive names to matrix jobs, ensuring base builds run first, and consolidating service builds. (29b9f68, 92db73a, ef050df)
- A series of fixes to address Gemini CLI safety parser rejections, model 404 errors, and workflow startup failures, including adding safety guards and cleaning up temporary files. (e4b5b3b, 3dd988f, eb1048c, a2ad36e, 6ccea5a, 83b87c1, 9d60926)

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

