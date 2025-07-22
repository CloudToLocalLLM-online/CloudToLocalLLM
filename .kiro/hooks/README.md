# CloudToLocalLLM Deployment Hooks

This directory contains Kiro hooks for automating the CloudToLocalLLM deployment workflow.

## Available Hooks

### Deploy to VPS
- **File**: `deploy-to-vps.json`
- **Description**: Deploy CloudToLocalLLM to production VPS
- **Trigger**: Manual
- **Action**: Executes the full deployment workflow to production environment

### Deploy to Staging
- **File**: `deploy-to-staging.json`
- **Description**: Deploy CloudToLocalLLM to staging environment
- **Trigger**: Manual
- **Action**: Executes the full deployment workflow to staging environment

### Deployment Dry Run
- **File**: `deployment-dry-run.json`
- **Description**: Preview deployment actions without executing
- **Trigger**: Manual
- **Action**: Shows what would happen during deployment without making changes

## Usage Instructions

1. Open the Kiro Explorer view in VS Code
2. Navigate to the "Agent Hooks" section
3. Click on the desired hook to execute it
4. Monitor the output in the Kiro terminal

## Hook Parameters

The deployment hooks use the following parameters:

- **Environment**: Target deployment environment (Production/Staging)
- **Force**: Skip confirmation prompts
- **KiroHookMode**: Enable Kiro-compatible output formatting
- **DryRun**: Preview actions without executing (for dry run hook only)
- **Verbose**: Enable detailed logging (for dry run hook only)

## Customizing Hooks

To customize these hooks, edit the JSON files in this directory. Available parameters:

```powershell
-Environment <Local|Staging|Production>  # Target environment
-VersionIncrement <build|patch|minor|major>  # Version increment type
-SkipBuild  # Skip Flutter build process
-SkipVerification  # Skip post-deployment verification
-SkipVersionUpdate  # Skip version management
-Force  # Force deployment without confirmations
-AutoRollback  # Enable automatic rollback on failure
-CreateGitHubRelease  # Create GitHub release after successful deployment
-DryRun  # Show what would be done without executing
-KiroHookMode  # Enable Kiro hook execution mode
-Verbose  # Enable verbose logging
```

For more information, see the deployment documentation in `docs/DEPLOYMENT/` or run:
```powershell
./scripts/powershell/Deploy-CloudToLocalLLM.ps1 -Help
```