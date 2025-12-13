# CI/CD Workflow Analysis Guidelines

## CRITICAL: Always Analyze the COMPLETE CI/CD System

### Rule 1: NEVER Touch Individual Workflows Without Understanding the System

Before modifying ANY GitHub Actions workflow:

1. **Read ALL workflows** in `.github/workflows/`
2. **Understand the complete flow** from code push to deployment
3. **Identify the orchestration workflow** that manages the entire process
4. **Check for version management workflows** that handle semantic versioning
5. **Look for dispatch mechanisms** that trigger deployments

### Rule 2: Understand CloudToLocalLLM's AI-Powered CI/CD Architecture

The CloudToLocalLLM project uses a **sophisticated AI-powered orchestration system**:

#### Primary Workflows:
- `version-and-distribute.yml` - **AI ORCHESTRATOR** (runs on main branch pushes)
- `deploy-aks.yml` - **CLOUD DEPLOYMENT** (triggered by repository_dispatch)
- `build-release.yml` - **DESKTOP RELEASES** (triggered by version tags)

#### AI-Powered Flow:
```
Push to main
    ↓
version-and-distribute.yml (AI ORCHESTRATOR)
    ├─ Analyzes changes with Kilocode AI (Gemini 2.0 Flash)
    ├─ Determines semantic version bump (patch/minor/major)
    ├─ Calculates platform needs (cloud/desktop/mobile)
    ├─ Updates version files automatically
    ├─ Pushes to platform branches (cloud, desktop, mobile)
    ├─ Creates platform-specific tags
    └─ Triggers deploy-aks.yml via repository_dispatch (if needs_cloud=true)
        ↓
    deploy-aks.yml (CLOUD DEPLOYMENT)
        ├─ Builds Docker images
        ├─ Deploys to Azure AKS
        ├─ Verifies deployment
        └─ Purges Cloudflare cache
```

#### Enhanced Platform Detection Rules:
The AI system uses **strict rules** for platform detection:

**Cloud Deployment** (`needs_cloud=true`):
- Changes to `web/`, `lib/`, `services/`, `k8s/`, `config/`
- Updates to `auth0-bridge.js`, `router.dart`, authentication providers
- **CRITICAL**: Auth0, authentication, login, web interface changes ALWAYS need cloud deployment
- **Default**: When in doubt about web changes, set `needs_cloud=true`

**Desktop/Mobile Deployment**:
- Platform-specific directory changes (`windows/`, `linux/`, `android/`, `ios/`)
- Platform-specific code or dependency modifications

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

### Rule 5: Understand the Project's Infrastructure Context

CloudToLocalLLM currently runs on Azure AKS with provider-agnostic design:
- Current production deployment uses Azure AKS via unified `deploy.yml` workflow
- Legacy `deploy-aks.yml` workflow has been replaced by unified workflow
- AWS CloudFormation templates exist in `config/cloudformation/` as future deployment option
- Platform-agnostic design allows deployment to any Kubernetes cluster

### Rule 6: When Deployment Issues Occur

1. **Check if version-and-distribute.yml ran successfully**
2. **Check if it triggered deploy-aks.yml via repository_dispatch**
3. **Check deploy-aks.yml execution status**
4. **Only then consider workflow modifications**

### Rule 7: UNDERSTAND AI DECISION MAKING

**CRITICAL**: The AI system makes deployment decisions based on intelligent analysis. Always understand WHY the AI made a decision before overriding it.

**AI Analysis Debugging**:
```bash
# Check AI analysis output
gh run view <run-id> --log | grep -A 10 "Kilocode Analysis"

# Look for AI reasoning
grep "reasoning" <workflow-log>

# Test AI locally
./scripts/analyze-platforms.sh
```

**When AI Decisions Seem Wrong**:
1. **Review AI reasoning** in workflow logs
2. **Check changed files** that AI analyzed
3. **Verify detection rules** match the changes
4. **Consider if rules need updating** (not workflow triggers)

**Manual Triggers** (use sparingly):
- Only when AI system fails completely
- Always investigate and fix the root cause
- Document why manual intervention was needed
- Manual triggers are a last resort, not a solution

### Rule 8: AUTHENTICATION CHANGES ARE CRITICAL

**SPECIAL RULE**: Authentication-related changes have the highest priority for cloud deployment.

**Always Triggers Cloud Deployment**:
- Changes to `auth0-bridge.js`
- Modifications to `lib/services/auth_service.dart`
- Updates to authentication providers
- Login flow modifications
- JWT token handling changes

**Why This Matters**:
- Authentication bugs can lock out all users
- Login issues affect the entire web application
- Auth changes often require immediate deployment
- The AI system is programmed to be conservative with auth changes

## Example: Correct Analysis Process

When user reports "login loop not deployed":

1. ✅ **Check AI Orchestrator**: `gh run list --workflow="version-and-distribute.yml"`
   - Verify the orchestrator ran successfully
   - Check AI analysis output in logs: `gh run view <run-id> --log | grep "Kilocode Analysis"`

2. ✅ **Verify AI Decision**: Look for AI reasoning in workflow logs
   - Check if AI detected authentication changes: `needs_cloud=true`
   - Verify version bump was calculated correctly
   - Confirm platform detection logic worked

3. ✅ **Check Repository Dispatch**: Look for repository_dispatch events
   - Verify orchestrator triggered deployment workflow
   - Check event payload: `{"event_type":"cloud-deploy-X.Y.Z"}`

4. ✅ **Check Deployment Status**: `gh run list --workflow="deploy-aks.yml"`
   - Verify deployment workflow executed
   - Check deployment logs for errors

5. ✅ **If AI Failed to Detect**: 
   - Review changed files: `git diff --name-only HEAD~5..HEAD`
   - Check if `auth0-bridge.js`, `router.dart`, or auth files changed
   - **Authentication changes should ALWAYS trigger cloud deployment**

6. ✅ **Manual Override** (if AI missed critical changes):
   ```bash
   # Trigger deployment manually with specific version
   gh workflow run deploy-aks.yml -f version_tag=4.5.1-cloud-abc123
   ```

7. ❌ **DON'T**: Modify workflow triggers without understanding the AI system
8. ❌ **DON'T**: Bypass the orchestrator unless absolutely necessary

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