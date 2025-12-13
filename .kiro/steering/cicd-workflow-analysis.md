# CI/CD Workflow Analysis Guidelines

## CRITICAL: Always Analyze the COMPLETE CI/CD System

### Rule 1: NEVER Touch Individual Workflows Without Understanding the System

Before modifying ANY GitHub Actions workflow:

1. **Read ALL workflows** in `.github/workflows/`
2. **Understand the complete flow** from code push to deployment
3. **Identify the orchestration workflow** that manages the entire process
4. **Check for version management workflows** that handle semantic versioning
5. **Look for dispatch mechanisms** that trigger deployments

### Rule 2: Understand CloudToLocalLLM's CI/CD Architecture

The CloudToLocalLLM project uses a **sophisticated multi-workflow system**:

#### Primary Workflows:
- `version-and-distribute.yml` - **ORCHESTRATOR** (runs on main branch pushes)
- `deploy-aks.yml` - **DEPLOYMENT** (triggered by repository_dispatch)
- `build-release.yml` - **DESKTOP RELEASES** (triggered by version tags)

#### Flow:
```
Push to main
    ↓
version-and-distribute.yml (ORCHESTRATOR)
    ├─ Analyzes changes with Kilocode CLI
    ├─ Bumps version automatically
    ├─ Pushes to platform branches (cloud, desktop, mobile)
    ├─ Creates platform-specific tags
    └─ Triggers deploy-aks.yml via repository_dispatch
        ↓
    deploy-aks.yml (DEPLOYMENT)
        ├─ Builds Docker images
        ├─ Deploys to Azure AKS
        ├─ Verifies deployment
        └─ Purges Cloudflare cache
```

### Rule 3: NEVER Assume Simple Trigger Patterns

**WRONG ASSUMPTION**: "Just add main branch to deploy-aks.yml triggers"
**CORRECT APPROACH**: "Understand that version-and-distribute.yml orchestrates everything"

The deployment workflow (`deploy-aks.yml`) is intentionally NOT triggered directly by main branch pushes. It's triggered by the orchestrator workflow via `repository_dispatch` events.

### Rule 4: Check Workflow Status Before Making Changes

Always run these commands to understand current state:
```bash
# List recent workflow runs
gh run list --limit 10

# Check specific workflow runs
gh run list --workflow="version-and-distribute.yml" --limit 3
gh run list --workflow="deploy-aks.yml" --limit 3

# View workflow details
gh run view <run-id>
```

### Rule 5: Understand the Project's Migration Context

CloudToLocalLLM is migrating from Azure AKS to AWS EKS:
- Current deployment still uses Azure AKS (`deploy-aks.yml`)
- AWS CloudFormation templates exist in `config/cloudformation/`
- AWS EKS deployment workflow doesn't exist yet
- Don't break the current working system during migration

### Rule 6: When Deployment Issues Occur

1. **Check if version-and-distribute.yml ran successfully**
2. **Check if it triggered deploy-aks.yml via repository_dispatch**
3. **Check deploy-aks.yml execution status**
4. **Only then consider workflow modifications**

### Rule 7: NEVER TRIGGER WORKFLOWS MANUALLY

**CRITICAL**: NEVER use `gh workflow run` or manual triggers. Always fix the automatic triggering system.

If deployment doesn't trigger automatically:
1. **Identify why the automatic trigger failed**
2. **Fix the workflow logic or conditions**
3. **Ensure the orchestration system works properly**
4. **Test with a new commit if needed**

Manual triggers are a band-aid that hide the real problem and prevent proper CI/CD automation.

## Example: Correct Analysis Process

When user reports "login loop not deployed":

1. ✅ Check if version-and-distribute.yml ran: `gh run list --workflow="version-and-distribute.yml"`
2. ✅ Check if it triggered deployment: Look for repository_dispatch events
3. ✅ Check deployment status: `gh run list --workflow="deploy-aks.yml"`
4. ✅ If deployment didn't trigger, manually trigger it: `gh workflow run deploy-aks.yml`
5. ❌ DON'T modify workflow triggers without understanding the system

## What I Did Wrong

1. **Focused on one file** instead of understanding the complete system
2. **Made assumptions** about trigger patterns without reading all workflows
3. **Modified triggers** without understanding the orchestration system
4. **Ignored the version management** workflow that handles everything
5. **Didn't check current workflow status** before making changes

## Never Do This Again

- Never modify workflow triggers without understanding the complete CI/CD flow
- Never assume simple patterns in complex projects
- Always read ALL workflows before making changes
- Always check current status before assuming something is broken
- Always understand the project's architecture and migration context