# Changelog

All notable changes to this project will be documented in this file.

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

