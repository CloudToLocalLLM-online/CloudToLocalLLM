# CI/CD Guidelines

## System
- `deploy.yml` - Unified deployment (main → Azure AKS)
- Archived workflows in `.github/workflows/archive/`

## Rules
1. Check status: `gh run list --workflow="deploy.yml" --limit 3`
2. Auth changes ALWAYS deploy: `auth0-bridge.js`, `auth_service.dart`
3. Manual trigger: `gh workflow run deploy.yml`
4. Don't create separate workflows - use unified approach