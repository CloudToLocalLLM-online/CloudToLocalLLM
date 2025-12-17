# Git Workflow Hook

## Automatic Git Sync

A hook is configured to automatically manage git operations on file changes:

**Hook ID**: `git-pull-add-sync`

### Behavior
- **Trigger**: When any file is edited
- **Actions**:
  1. Pull latest changes from remote (`git pull`)
  2. Stage all modified files (`git add -A`)
  3. Display current status (`git status`)

### Purpose
- Keep repository synchronized with remote
- Automatically stage changes without manual `git add`
- Prevent temporary files from being tracked (via .gitignore)

### Important Notes
- **Environment**: All git commands and hooks run natively in the **WSL Ubuntu** terminal.
- **Git Hooks**: Managed via standard Linux git hooks in `.git/hooks/`.
- Ensure `.gitignore` is properly configured to exclude temp files.
- The hook runs automatically - no manual intervention needed.
- Review `git status` output to verify staged changes.
- Commit changes manually when ready: `git commit -m "message"`

### Temp Files to Exclude
Add these patterns to `.gitignore` if not already present:
```
*.tmp
*.temp
*.log
.DS_Store
Thumbs.db
*.swp
*.swo
*~
```
