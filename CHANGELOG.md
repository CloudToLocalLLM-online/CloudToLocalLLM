# Changelog

All notable changes to this project will be documented in this file.

## [7.18.0] - 2025-12-27
# Changelog

## 7.18.0 (2024-07-03)

### Features
*   Enhanced Cloudflare API integration for tunnel diagnostics, DNS automation, and implementation plan (19cd411)
*   Add secure secret injection to deployment pipeline (fe62dfb)
*   Updated cloudflared error 1033 SOP v1.5.0 and secure diagnostic script (2823e1e)
*   Add script to fix Azure OIDC subject mismatch (b92761b)

### Bug Fixes
*   Fix ArgoCD 502 errors: enable HA deployment, remove insecure mode, fix Ingress host to cloudtolocalllm.online, add TLS configuration (8d30de3)
*   Fix ArgoCD cloudflared configuration to use HTTP instead of HTTPS (61f673c)
*   Resolve grep option error in build pipeline (485f36c)
*   Ensure actions/checkout is executed before gh commands in orchestrator (cd36420)
*   Resolve secrets deployment failure and optimize pipeline (794c576)
*   Resolve ArgoCD 502 gateway and optimize cloudflared stability (7008d0c)
*   Correctly handle optional cloudflare token in validation script (dc2beb1)
*   Make Cloudflare DNS token optional in validation to prevent blocking (925898e)
*   Use standard azure/login@v2 action for authentication (027ae8f)
*   Fetch OIDC token manually for az login (4ae8ea7)
*   Correct az login flags and set subscription separately (22f4771)
*   Replace retry action with shell loop for az login to access OIDC token (578d2b5)
*   Join az login command to single line to fix retry action args (d48c2d5)
*   Fix incorrect action name for retry action (e857d69)

### Refactoring
*   Secure refactor of cloudflared diagnostic and repair scripts, updated SOP v1.6.0 (71f00be)
*   Use jq for secure secret injection in deployment pipeline (52d5cd8)

### Documentation
*   Consolidate knowledge assets and enforce clean-root governance policy (d8a3c3e)

### Chore
*   Bump version to 7.17.1 (2891002)
*   Bump version to 7.17.0 (63e8389)
*   Bump version to 7.16.3 (9944368)
*   Bump version to 7.16.2 (65294f5)
*   Bump version to 7.16.1 (cd171a8)
*   Bump version to 7.16.0 (58b074e)
*   Bump version to 7.15.2 (c0c4fed)
*   Bump version to 7.15.1 (670377e)
*   Bump version to 7.15.0 (29ea52f)
*   Bump version to 7.14.32 (1bf9012)
*   Bump version to 7.14.31 (3053fa7)
*   Bump version to 7.14.30 (ab60407)
*   Bump version to 7.14.29 (6396fa9)
*   Bump version to 7.14.28 (d295a6a)
*   Bump version to 7.14.27 (b7e7a0e)
*   Enforce LF line endings and normalize (59dab96)
*   Align concurrency and use jq for secure secret injection (71a0a9e)
*   Remove validation workflow and add emoji to build pipeline (f70d23c)
*   Exclude dependabot from main orchestrator (9e67bef)
*   Broaden dependabot commit exclusion in main orchestrator (d8f17bf)
*   Sanitize credentials and refine sync script (db3815e)

## [7.17.1] - 2025-12-27
# Changelog

## [7.17.1] - 2024-07-18 (Date is an example)

### Features
- Enhanced Cloudflare API integration for tunnel diagnostics, DNS automation, and implementation plan.
- Added script to fix Azure OIDC subject mismatch.
- Added secure secret injection to deployment pipeline.
- Updated cloudflared error 1033 SOP v1.5.0 and secure diagnostic script.

### Bug Fixes
- Resolved ArgoCD 502 gateway and optimized cloudflared stability.
- Resolved secrets deployment failure and optimized pipeline.
- Correctly handled optional cloudflare token in validation script.
- Made Cloudflare DNS token optional in validation to prevent blocking.
- Used standard azure/login@v2 action for authentication.
- Fetched OIDC token manually for az login.
- Corrected az login flags and set subscription separately.
- Replaced retry action with shell loop for az login to access OIDC token.
- Joined az login command to single line to fix retry action args.
- Migrated build pipeline to standard runners and updated tokens.
- Used GITHUB_TOKEN for checkout to enable push.
- Resolved grep option error in build pipeline.
- Ensured actions/checkout is executed before gh commands in orchestrator.
- Fixed ArgoCD cloudflared configuration to use HTTP instead of HTTPS.
- Fixed ArgoCD 502 errors: enable HA deployment, remove insecure mode, fix Ingress host to cloudtolocalllm.online, add TLS configuration.

### Documentation
- Consolidated knowledge assets and enforce clean-root governance policy.
- Updated stabilization report with comprehensive findings.

### Refactoring
- Used jq for secure secret injection in deployment pipeline.

### Chore
- Aligned concurrency and use jq for secure secret injection.
- Enforced LF line endings and normalize.
- Removed validation workflow and added emoji to build pipeline.
- Fixed incorrect action name for retry action.
- Excluded dependabot from main orchestrator.
- Broadened dependabot commit exclusion in main orchestrator.
- Force refresh build pipeline config.
- Sanitized credentials and refine sync script.

