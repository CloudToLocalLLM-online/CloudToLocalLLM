# Git Operations Migration Guide - MCP First Approach

## Overview

This guide provides step-by-step instructions for migrating existing Git workflows from GitHub CLI (gh) and native Git commands to the MCP-first approach.

## Pre-Migration Checklist

### 1. Verify MCP Configuration
```bash
# Check MCP GitHub server is configured
cat ~/.kilocode/mcp_settings.json | grep -A 20 '"github"'

# Test MCP authentication
mcp--github--get_me

# Verify required permissions
mcp--github--get_me
```

### 2. Audit Existing Workflows
```bash
# Find all scripts using GitHub CLI
find scripts/ -name "*.sh" -exec grep -l "gh " {} \;

# Find all scripts using native git
find scripts/ -name "*.sh" -exec grep -l "git " {} \;

# Identify CI/CD workflows
find .github/ -name "*.yml" -o -name "*.yaml" | xargs grep -l "gh\|git"
```

### 3. Backup Current Configuration
```bash
# Backup current MCP settings
cp ~/.kilocode/mcp_settings.json ~/.kilocode/mcp_settings.json.backup

# Backup existing scripts
tar -czf scripts_backup_$(date +%Y%m%d).tar.gz scripts/

# Document current workflow dependencies
find scripts/ -name "*.sh" -exec echo "=== {} ===" \; -exec head -20 {} \;
```

## Migration Process

### Phase 1: Update MCP Configuration

#### 1.1 Verify GitHub Server Configuration
The GitHub MCP server should already be configured with:
- GitHub Personal Access Token
- Proper permissions (read/write)
- All required tools enabled

#### 1.2 Update MCP Settings if Needed
```json
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-e",
        "GITHUB_PERSONAL_ACCESS_TOKEN",
        "-e",
        "GITHUB_TOOLSETS",
        "-e",
        "GITHUB_READ_ONLY",
        "ghcr.io/github/github-mcp-server"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your-token-here",
        "GITHUB_TOOLSETS": "",
        "GITHUB_READ_ONLY": "0"
      }
    }
  }
}
```

### Phase 2: Script Migration

#### 2.1 Repository Operations Migration

**Before (GitHub CLI):**
```bash
#!/bin/bash
# scripts/create-repo.sh
gh repo create "$REPO_NAME" \
  --description "$DESCRIPTION" \
  --public \
  --enable-issues \
  --enable-wiki
```

**After (MCP First):**
```bash
#!/bin/bash
# scripts/create-repo.sh

create_repository_mcp() {
    local repo_name=$1
    local description=$2
    
    echo "Creating repository $repo_name using MCP..."
    
    # Try MCP first
    if mcp--github--create_repository {
        "name": "$repo_name",
        "description": "$description",
        "private": false,
        "autoInit": true
    } 2>/dev/null; then
        echo "✓ Repository created successfully with MCP"
        return 0
    fi
    
    # Fallback to GitHub CLI
    echo "⚠ MCP failed, falling back to GitHub CLI"
    if gh repo create "$repo_name" \
        --description "$description" \
        --public \
        --enable-issues \
        --enable-wiki 2>/dev/null; then
        echo "✓ Repository created successfully with GitHub CLI"
        return 0
    fi
    
    echo "❌ Failed to create repository"
    return 1
}

# Usage
create_repository_mcp "$REPO_NAME" "$DESCRIPTION"
```

#### 2.2 Branch Operations Migration

**Before (GitHub CLI):**
```bash
#!/bin/bash
# scripts/create-branch.sh
gh api repos/organization/repository/git/refs -X POST \
  -f ref="refs/heads/$BRANCH_NAME" \
  -f sha="$(gh api repos/organization/repository/git/refs/heads/main | jq -r .object.sha)"
```

**After (MCP First):**
```bash
#!/bin/bash
# scripts/create-branch.sh

create_branch_mcp() {
    local branch_name=$1
    local from_branch=${2:-main}
    
    echo "Creating branch $branch_name from $from_branch using MCP..."
    
    # Try MCP first
    if mcp--github--create_branch {
        "branch": "$branch_name",
        "from_branch": "$from_branch"
    } 2>/dev/null; then
        echo "✓ Branch created successfully with MCP"
        return 0
    fi
    
    # Fallback to GitHub CLI
    echo "⚠ MCP failed, falling back to GitHub CLI"
    if gh api repos/organization/repository/git/refs -X POST \
        -f ref="refs/heads/$branch_name" \
        -f sha="$(gh api repos/organization/repository/git/refs/heads/$from_branch | jq -r .object.sha)" 2>/dev/null; then
        echo "✓ Branch created successfully with GitHub CLI"
        return 0
    fi
    
    echo "❌ Failed to create branch"
    return 1
}

# Usage
create_branch_mcp "$BRANCH_NAME" "$FROM_BRANCH"
```

#### 2.3 File Operations Migration

**Before (GitHub CLI):**
```bash
#!/bin/bash
# scripts/update-file.sh
gh api repos/organization/repository/contents/$FILE_PATH -X PUT \
  -f message="$COMMIT_MESSAGE" \
  -f content="$(echo "$FILE_CONTENT" | base64 -w 0)" \
  -f branch="$BRANCH"
```

**After (MCP First):**
```bash
#!/bin/bash
# scripts/update-file.sh

update_file_mcp() {
    local file_path=$1
    local file_content=$2
    local commit_message=$3
    local branch=$4
    
    echo "Updating file $file_path using MCP..."
    
    # Try MCP first
    if mcp--github--create_or_update_file {
        "owner": "organization",
        "repo": "repository",
        "path": "$file_path",
        "content": "$file_content",
        "message": "$commit_message",
        "branch": "$branch"
    } 2>/dev/null; then
        echo "✓ File updated successfully with MCP"
        return 0
    fi
    
    # Fallback to GitHub CLI
    echo "⚠ MCP failed, falling back to GitHub CLI"
    if gh api repos/organization/repository/contents/$file_path -X PUT \
        -f message="$commit_message" \
        -f content="$(echo "$file_content" | base64 -w 0)" \
        -f branch="$branch" 2>/dev/null; then
        echo "✓ File updated successfully with GitHub CLI"
        return 0
    fi
    
    echo "❌ Failed to update file"
    return 1
}

# Usage
update_file_mcp "$FILE_PATH" "$FILE_CONTENT" "$COMMIT_MESSAGE" "$BRANCH"
```

#### 2.4 Pull Request Operations Migration

**Before (GitHub CLI):**
```bash
#!/bin/bash
# scripts/create-pr.sh
gh pr create \
  --title "$PR_TITLE" \
  --body "$PR_BODY" \
  --head "$HEAD_BRANCH" \
  --base "$BASE_BRANCH"
```

**After (MCP First):**
```bash
#!/bin/bash
# scripts/create-pr.sh

create_pr_mcp() {
    local title=$1
    local body=$2
    local head_branch=$3
    local base_branch=${4:-main}
    
    echo "Creating PR '$title' using MCP..."
    
    # Try MCP first
    if mcp--github--create_pull_request {
        "owner": "organization",
        "repo": "repository",
        "head": "$head_branch",
        "base": "$base_branch",
        "title": "$title",
        "body": "$body",
        "draft": false
    } 2>/dev/null; then
        echo "✓ PR created successfully with MCP"
        return 0
    fi
    
    # Fallback to GitHub CLI
    echo "⚠ MCP failed, falling back to GitHub CLI"
    if gh pr create \
        --title "$title" \
        --body "$body" \
        --head "$head_branch" \
        --base "$base_branch" 2>/dev/null; then
        echo "✓ PR created successfully with GitHub CLI"
        return 0
    fi
    
    echo "❌ Failed to create PR"
    return 1
}

# Usage
create_pr_mcp "$PR_TITLE" "$PR_BODY" "$HEAD_BRANCH" "$BASE_BRANCH"
```

### Phase 3: CI/CD Workflow Migration

#### 3.1 GitHub Actions Migration

**Before (.github/workflows/deploy.yml):**
```yaml
name: Deploy
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Create deployment branch
        run: |
          gh api repos/organization/repository/git/refs -X POST \
            -f ref="refs/heads/deploy-${{ github.run_number }}" \
            -f sha="$(gh api repos/organization/repository/git/refs/heads/main | jq -r .object.sha)"
```

**After (.github/workflows/deploy.yml):**
```yaml
name: Deploy
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Create deployment branch using MCP
        run: |
          # Try MCP first
          if mcp--github--create_branch {
            "branch": "deploy-${{ github.run_number }}",
            "from_branch": "main"
          } 2>/dev/null; then
            echo "✓ Branch created successfully with MCP"
          else
            # Fallback to GitHub CLI
            echo "⚠ MCP failed, falling back to GitHub CLI"
            gh api repos/organization/repository/git/refs -X POST \
              -f ref="refs/heads/deploy-${{ github.run_number }}" \
              -f sha="$(gh api repos/organization/repository/git/refs/heads/main | jq -r .object.sha)"
          fi
```

#### 3.2 PowerShell Script Migration

**Before (scripts/deploy.ps1):**
```powershell
# Create deployment branch
$branchName = "deploy-$env:BUILD_NUMBER"
gh api repos/organization/repository/git/refs -X POST `
  -f ref="refs/heads/$branchName" `
  -f sha="$(gh api repos/organization/repository/git/refs/heads/main | ConvertFrom-Json).object.sha"
```

**After (scripts/deploy.ps1):**
```powershell
# Create deployment branch using MCP
function Create-DeploymentBranch {
    param(
        [string]$BranchName,
        [string]$FromBranch = "main"
    )
    
    Write-Host "Creating deployment branch $BranchName using MCP..."
    
    # Try MCP first
    try {
        $mcpResult = mcp--github--create_branch @{
            branch = $BranchName
            from_branch = $FromBranch
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Branch created successfully with MCP"
            return $true
        }
    } catch {
        Write-Warning "MCP failed, falling back to GitHub CLI"
    }
    
    # Fallback to GitHub CLI
    try {
        $sha = (gh api "repos/organization/repository/git/refs/heads/$FromBranch" | ConvertFrom-Json).object.sha
        gh api "repos/organization/repository/git/refs" -X POST `
            -f ref="refs/heads/$BranchName" -f sha=$sha | Out-Null
        
        Write-Host "✓ Branch created successfully with GitHub CLI"
        return $true
    } catch {
        Write-Error "Failed to create branch"
        return $false
    }
}

# Usage
$branchName = "deploy-$env:BUILD_NUMBER"
Create-DeploymentBranch -BranchName $branchName
```

### Phase 4: Testing and Validation

#### 4.1 Test MCP Operations
```bash
# Test repository operations
mcp--github--create_repository {
  "name": "test-mcp-repo",
  "description": "Test repository for MCP migration",
  "private": false,
  "autoInit": true
}

# Test branch operations
mcp--github--create_branch {
  "branch": "test-mcp-branch",
  "from_branch": "main"
}

# Test file operations
mcp--github--create_or_update_file {
  "owner": "organization",
  "repo": "test-mcp-repo",
  "path": "test-file.md",
  "content": "# Test file created via MCP",
  "message": "Test commit via MCP",
  "branch": "test-mcp-branch"
}

# Test PR operations
mcp--github--create_pull_request {
  "owner": "organization",
  "repo": "test-mcp-repo",
  "head": "test-mcp-branch",
  "base": "main",
  "title": "Test PR via MCP",
  "body": "This is a test PR created via MCP tools",
  "draft": false
}
```

#### 4.2 Test Fallback Operations
```bash
# Simulate MCP failure and test fallback
# Temporarily disable MCP server or use invalid credentials
# Then run the same operations to verify fallback works
```

#### 4.3 Performance Testing
```bash
# Compare performance between MCP and GitHub CLI
echo "Testing MCP performance..."
time mcp--github--list_commits {
  "owner": "organization",
  "repo": "repository",
  "perPage": 100
}

echo "Testing GitHub CLI performance..."
time gh api repos/organization/repository/commits?per_page=100
```

### Phase 5: Rollback Procedures

#### 5.1 Rollback Script
```bash
#!/bin/bash
# scripts/rollback-git-migration.sh

rollback_migration() {
    echo "Rolling back Git operations migration..."
    
    # Restore original scripts
    if [ -f "scripts_backup_$(date +%Y%m%d).tar.gz" ]; then
        echo "Restoring original scripts..."
        tar -xzf scripts_backup_$(date +%Y%m%d).tar.gz
        echo "✓ Original scripts restored"
    else
        echo "❌ Backup not found, manual rollback required"
        return 1
    fi
    
    # Restore original MCP configuration
    if [ -f "~/.kilocode/mcp_settings.json.backup" ]; then
        echo "Restoring original MCP configuration..."
        cp ~/.kilocode/mcp_settings.json.backup ~/.kilocode/mcp_settings.json
        echo "✓ MCP configuration restored"
    else
        echo "❌ MCP backup not found"
        return 1
    fi
    
    echo "✓ Rollback completed successfully"
    return 0
}

# Usage
rollback_migration
```

#### 5.2 Emergency Procedures
```bash
#!/bin/bash
# scripts/emergency-git-operations.sh

emergency_git_operation() {
    local operation=$1
    shift
    local args="$@"
    
    echo "⚠ Emergency: Using native git for $operation"
    
    case $operation in
        "create-branch")
            git checkout -b "$args"
            git push origin "$args"
            ;;
        "create-pr")
            git push origin HEAD:refs/heads/"$args"
            gh pr create --title "Emergency PR: $args"
            ;;
        "update-file")
            echo "$args" > emergency_file.txt
            git add emergency_file.txt
            git commit -m "Emergency update"
            git push origin main
            ;;
        *)
            echo "❌ Unknown emergency operation: $operation"
            return 1
            ;;
    esac
    
    echo "✓ Emergency operation completed"
}

# Usage
emergency_git_operation "create-branch" "emergency-fix"
```

## Post-Migration Tasks

### 1. Update Documentation
```bash
# Update README files
sed -i 's/gh /mcp--github--/g' README.md
sed -i 's/GitHub CLI/MCP GitHub tools/g' README.md

# Update internal documentation
find docs/ -name "*.md" -exec sed -i 's/gh /mcp--github--/g' {} \;
```

### 2. Team Training
```bash
# Create training materials
cat > docs/training/mcp-git-operations.md << 'EOF'
# MCP Git Operations Training

## Overview
This training covers using MCP tools for Git operations instead of GitHub CLI.

## Hands-On Exercises
1. Create a test repository using MCP
2. Create branches and make commits
3. Create and merge pull requests
4. Handle fallback scenarios

## Best Practices
- Always try MCP first
- Implement proper error handling
- Use structured logging
- Monitor performance
EOF
```

### 3. Monitoring Setup
```bash
# Set up monitoring for MCP operations
cat > monitoring/mcp-git-operations.sh << 'EOF'
#!/bin/bash
# Monitor MCP Git operations performance

LOG_FILE="/var/log/mcp_git_operations.log"

# Monitor operation success rate
monitor_success_rate() {
    local success_count=$(grep "✓.*successfully with MCP" $LOG_FILE | wc -l)
    local total_count=$(grep "MCP.*operation" $LOG_FILE | wc -l)
    
    if [ $total_count -gt 0 ]; then
        local success_rate=$((success_count * 100 / total_count))
        echo "MCP Success Rate: $success_rate%"
        
        if [ $success_rate -lt 95 ]; then
            echo "⚠ Warning: MCP success rate below 95%"
        fi
    fi
}

# Monitor operation performance
monitor_performance() {
    local avg_time=$(grep "MCP operation completed" $LOG_FILE | awk '{print $NF}' | awk '{sum+=$1} END {print sum/NR}')
    echo "Average MCP operation time: ${avg_time}s"
}

# Run monitoring
monitor_success_rate
monitor_performance
EOF
```

## Migration Validation Checklist

### Pre-Migration
- [ ] MCP GitHub server configured and tested
- [ ] All required permissions verified
- [ ] Existing workflows audited
- [ ] Backup created

### During Migration
- [ ] Scripts updated with MCP-first approach
- [ ] Fallback procedures implemented
- [ ] CI/CD workflows updated
- [ ] PowerShell scripts migrated

### Post-Migration
- [ ] All operations tested with MCP
- [ ] Fallback procedures tested
- [ ] Performance validated
- [ ] Documentation updated
- [ ] Team trained
- [ ] Monitoring configured

### Ongoing
- [ ] Regular performance monitoring
- [ ] Error rate tracking
- [ ] Team feedback collection
- [ ] Procedure updates as needed

## Troubleshooting Common Issues

### Issue: MCP Server Not Responding
**Symptoms:** All MCP operations fail immediately
**Solution:**
1. Check MCP server status
2. Verify network connectivity
3. Check authentication
4. Use GitHub CLI fallback

### Issue: Authentication Failures
**Symptoms:** MCP operations fail with auth errors
**Solution:**
1. Verify GitHub token in MCP config
2. Check token permissions
3. Re-authenticate if needed
4. Use GitHub CLI with valid credentials

### Issue: Performance Degradation
**Symptoms:** MCP operations slower than GitHub CLI
**Solution:**
1. Check network latency
2. Verify MCP server resources
3. Compare with GitHub CLI performance
4. Optimize MCP configuration

### Issue: Incomplete Operations
**Symptoms:** Operations start but don't complete
**Solution:**
1. Check MCP server logs
2. Verify GitHub API rate limits
3. Implement retry logic
4. Use GitHub CLI for critical operations

## Success Metrics

### Operational Metrics
- **MCP Success Rate:** >95% of operations succeed with MCP
- **Performance:** MCP operations within 20% of GitHub CLI performance
- **Fallback Usage:** <5% of operations require fallback

### Team Metrics
- **Training Completion:** 100% of team members trained on MCP tools
- **Documentation Quality:** All procedures documented and up-to-date
- **Feedback Score:** Team satisfaction >8/10 with new workflow

### Technical Metrics
- **Error Rate:** <1% of Git operations result in errors
- **Recovery Time:** <5 minutes to recover from MCP failures
- **Monitoring Coverage:** 100% of critical operations monitored

This migration guide ensures a smooth transition to the MCP-first approach while maintaining operational reliability and team productivity.