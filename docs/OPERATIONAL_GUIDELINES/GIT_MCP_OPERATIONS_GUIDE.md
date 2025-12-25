# Git Operations with MCP Tools - Operational Guidelines

## Overview

This document establishes the operational guidelines for Git-related tasks using MCP (Model Context Protocol) tools as the primary interface, with GitHub CLI (gh) as a supplementary fallback option.

## MCP-First Approach

### Priority Hierarchy

1. **Primary**: MCP GitHub Server Tools
2. **Secondary**: GitHub CLI (gh) - for unsupported operations
3. **Fallback**: Native Git commands - for emergency situations only

### MCP GitHub Server Capabilities

The MCP GitHub server provides comprehensive Git operations support:

#### Repository Management
- `mcp--github--create_repository` - Create new repositories
- `mcp--github--fork_repository` - Fork existing repositories
- `mcp--github--get_file_contents` - Read repository files
- `mcp--github--push_files` - Push multiple files in a single commit
- `mcp--github--create_or_update_file` - Create or update single files

#### Branch Operations
- `mcp--github--create_branch` - Create new branches
- `mcp--github--list_branches` - List repository branches

#### Commit Operations
- `mcp--github--get_commit` - Get commit details
- `mcp--github--list_commits` - List commits with filtering

#### Pull Request Management
- `mcp--github--create_pull_request` - Create pull requests
- `mcp--github--update_pull_request` - Update existing PRs
- `mcp--github--merge_pull_request` - Merge pull requests
- `mcp--github--pull_request_read` - Read PR information
- `mcp--github--pull_request_review_write` - Write PR reviews

#### Issue Management
- `mcp--github--create_issue` - Create issues
- `mcp--github--add_issue_comment` - Add comments to issues
- `mcp--github--issue_read` - Read issue information
- `mcp--github--issue_write` - Update issues

#### Release Management
- `mcp--github--create_release` - Create releases
- `mcp--github--get_latest_release` - Get latest release
- `mcp--github--get_release_by_tag` - Get release by tag

## Standard Git Operations

### Repository Creation

**MCP Approach:**
```bash
mcp--github--create_repository {
  "name": "new-repository",
  "description": "Repository description",
  "private": false,
  "autoInit": true
}
```

**GitHub CLI Fallback:**
```bash
gh repo create new-repository --description "Repository description" --public --enable-issues --enable-wiki
```

### Branch Management

**MCP Approach:**
```bash
# Create branch
mcp--github--create_branch {
  "branch": "feature/new-feature",
  "from_branch": "main"
}

# List branches
mcp--github--list_branches {
  "owner": "organization",
  "repo": "repository"
}
```

**GitHub CLI Fallback:**
```bash
# Create and checkout branch
gh api repos/organization/repository/git/refs -X POST -f ref="refs/heads/feature/new-feature" -f sha="$(gh api repos/organization/repository/git/refs/heads/main | jq -r .object.sha)"

# List branches
gh api repos/organization/repository/branches
```

### File Operations

**MCP Approach:**
```bash
# Create or update single file
mcp--github--create_or_update_file {
  "owner": "organization",
  "repo": "repository",
  "path": "path/to/file.md",
  "content": "File content",
  "message": "Commit message",
  "branch": "feature/branch"
}

# Push multiple files
mcp--github--push_files {
  "owner": "organization",
  "repo": "repository",
  "branch": "feature/branch",
  "message": "Commit message",
  "files": [
    {"path": "file1.js", "content": "content1"},
    {"path": "file2.js", "content": "content2"}
  ]
}
```

**GitHub CLI Fallback:**
```bash
# Create or update file
gh api repos/organization/repository/contents/path/to/file.md -X PUT -f message="Commit message" -f content="$(echo 'File content' | base64 -w 0)"

# For multiple files, use local git operations
git add .
git commit -m "Commit message"
git push origin feature/branch
```

### Pull Request Management

**MCP Approach:**
```bash
# Create PR
mcp--github--create_pull_request {
  "owner": "organization",
  "repo": "repository",
  "head": "feature/branch",
  "base": "main",
  "title": "Feature title",
  "body": "PR description",
  "draft": false
}

# Update PR
mcp--github--update_pull_request {
  "owner": "organization",
  "repo": "repository",
  "pullNumber": 123,
  "title": "Updated title",
  "body": "Updated description"
}

# Merge PR
mcp--github--merge_pull_request {
  "owner": "organization",
  "repo": "repository",
  "pullNumber": 123,
  "merge_method": "merge"
}
```

**GitHub CLI Fallback:**
```bash
# Create PR
gh pr create --title "Feature title" --body "PR description" --head feature/branch --base main

# Update PR
gh api repos/organization/repository/pulls/123 -X PATCH -f title="Updated title" -f body="Updated description"

# Merge PR
gh api repos/organization/repository/pulls/123/merge -X PUT -f commit_title="Merge message"
```

### Issue Management

**MCP Approach:**
```bash
# Create issue
mcp--github--issue_write {
  "owner": "organization",
  "repo": "repository",
  "method": "create",
  "title": "Issue title",
  "body": "Issue description",
  "labels": ["bug", "high-priority"]
}

# Add comment
mcp--github--add_issue_comment {
  "owner": "organization",
  "repo": "repository",
  "issue_number": 456,
  "body": "Comment text"
}
```

**GitHub CLI Fallback:**
```bash
# Create issue
gh issue create --title "Issue title" --body "Issue description" --label "bug,high-priority"

# Add comment
gh api repos/organization/repository/issues/456/comments -X POST -f body="Comment text"
```

### Release Management

**MCP Approach:**
```bash
# Create release
mcp--github--create_release {
  "owner": "organization",
  "repo": "repository",
  "tag": "v1.0.0",
  "name": "Release 1.0.0",
  "body": "Release notes",
  "draft": false,
  "prerelease": false
}

# Get latest release
mcp--github--get_latest_release {
  "owner": "organization",
  "repo": "repository"
}
```

**GitHub CLI Fallback:**
```bash
# Create release
gh release create v1.0.0 --title "Release 1.0.0" --notes "Release notes"

# Get latest release
gh api repos/organization/repository/releases/latest
```

## Workflow Integration

### CI/CD Pipeline Updates

Update existing CI/CD workflows to prioritize MCP tools:

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Use MCP for Git operations
        run: |
          # Create deployment branch using MCP
          mcp--github--create_branch {
            "branch": "deploy/${{ github.run_number }}",
            "from_branch": "main"
          }
          
          # Push deployment files
          mcp--github--push_files {
            "branch": "deploy/${{ github.run_number }}",
            "message": "Deploy build ${{ github.run_number }}",
            "files": [
              {"path": "dist/", "content": "${{ steps.build.outputs.artifacts }}"}
            ]
          }
```

### Script Migration

Migrate existing scripts to use MCP-first approach:

```bash
#!/bin/bash
# scripts/deploy.sh - Updated to use MCP-first approach

# Function to create deployment branch
create_deployment_branch() {
    local branch_name=$1
    local source_branch=${2:-main}
    
    echo "Creating deployment branch $branch_name using MCP..."
    
    # Try MCP first
    if mcp--github--create_branch {
        "branch": "$branch_name",
        "from_branch": "$source_branch"
    } 2>/dev/null; then
        echo "✓ Branch created successfully with MCP"
        return 0
    fi
    
    # Fallback to GitHub CLI
    echo "⚠ MCP failed, falling back to GitHub CLI"
    if gh api repos/organization/repository/git/refs -X POST \
        -f ref="refs/heads/$branch_name" \
        -f sha="$(gh api repos/organization/repository/git/refs/heads/$source_branch | jq -r .object.sha)" 2>/dev/null; then
        echo "✓ Branch created successfully with GitHub CLI"
        return 0
    fi
    
    # Final fallback to native git
    echo "⚠ GitHub CLI failed, using native git"
    git checkout -b "$branch_name" "$source_branch"
    git push origin "$branch_name"
    echo "✓ Branch created successfully with native git"
}

# Function to push deployment files
push_deployment_files() {
    local branch_name=$1
    local commit_message=$2
    
    echo "Pushing deployment files using MCP..."
    
    # Try MCP first
    if mcp--github--push_files {
        "branch": "$branch_name",
        "message": "$commit_message",
        "files": [
            {"path": "dist/", "content": "$(cat dist.tar.gz | base64 -w 0)"}
        ]
    } 2>/dev/null; then
        echo "✓ Files pushed successfully with MCP"
        return 0
    fi
    
    # Fallback to GitHub CLI
    echo "⚠ MCP failed, falling back to GitHub CLI"
    if gh api repos/organization/repository/contents/dist.tar.gz -X PUT \
        -f message="$commit_message" \
        -f content="$(cat dist.tar.gz | base64 -w 0)" \
        -f branch="$branch_name" 2>/dev/null; then
        echo "✓ Files pushed successfully with GitHub CLI"
        return 0
    fi
    
    # Final fallback to native git
    echo "⚠ GitHub CLI failed, using native git"
    git add dist/
    git commit -m "$commit_message"
    git push origin "$branch_name"
    echo "✓ Files pushed successfully with native git"
}
```

## Error Handling and Troubleshooting

### MCP Tool Failures

When MCP tools fail, follow this troubleshooting sequence:

1. **Check MCP Server Status**
   ```bash
   # Verify MCP server is running
   mcp--github--get_me
   ```

2. **Check Authentication**
   ```bash
   # Verify GitHub authentication
   mcp--github--get_me
   ```

3. **Check Permissions**
   ```bash
   # Verify required permissions
   mcp--github--get_me
   ```

4. **Fallback to GitHub CLI**
   ```bash
   # Use GitHub CLI as fallback
   gh auth status
   ```

### Common Issues and Solutions

#### Issue: MCP Server Not Responding
**Solution:**
```bash
# Check MCP server status
systemctl status mcp-github-server

# Restart if needed
systemctl restart mcp-github-server

# Fallback to GitHub CLI
gh auth login
```

#### Issue: Authentication Failures
**Solution:**
```bash
# Check MCP authentication
mcp--github--get_me

# Re-authenticate if needed
gh auth login

# Update MCP configuration
# Edit ~/.kilocode/mcp_settings.json
```

#### Issue: Rate Limiting
**Solution:**
```bash
# Check rate limit status
gh api rate_limit

# Implement retry logic in scripts
# Use exponential backoff
```

## Monitoring and Logging

### MCP Operations Logging

Enable comprehensive logging for all MCP operations:

```bash
# Enable MCP logging
export MCP_LOG_LEVEL=debug
export MCP_LOG_FILE=/var/log/mcp_operations.log

# Log all operations
mcp--github--create_pull_request {
  "owner": "organization",
  "repo": "repository",
  "head": "feature/branch",
  "base": "main",
  "title": "Feature title",
  "body": "PR description"
} 2>&1 | tee -a /var/log/mcp_operations.log
```

### Performance Monitoring

Monitor MCP operation performance:

```bash
# Time MCP operations
time mcp--github--list_commits {
  "owner": "organization",
  "repo": "repository",
  "perPage": 100
}

# Compare with GitHub CLI
time gh api repos/organization/repository/commits?per_page=100
```

## Security Considerations

### Credential Management

1. **MCP Configuration Security**
   - Store GitHub tokens securely in MCP configuration
   - Use environment variables for sensitive data
   - Implement proper access controls

2. **Audit Logging**
   - Log all Git operations for audit purposes
   - Monitor for unauthorized access attempts
   - Implement alerting for suspicious activities

3. **Permission Management**
   - Use principle of least privilege
   - Regularly review and update permissions
   - Implement role-based access control

### Best Practices

1. **Always use MCP tools first**
2. **Document fallback procedures**
3. **Monitor operation performance**
4. **Implement proper error handling**
5. **Maintain security and audit logs**
6. **Regularly update and test procedures**

## Training and Documentation

### Team Training

1. **MCP Tool Familiarization**
   - Hands-on training with MCP GitHub tools
   - Practice common Git operations
   - Understand fallback procedures

2. **Troubleshooting Skills**
   - Identify MCP vs GitHub CLI issues
   - Implement effective fallback strategies
   - Use monitoring and logging tools

3. **Security Awareness**
   - Understand credential management
   - Follow security best practices
   - Recognize potential security issues

### Documentation Maintenance

1. **Keep Guidelines Updated**
   - Review and update procedures regularly
   - Document new MCP capabilities
   - Update fallback procedures as needed

2. **Share Knowledge**
   - Document lessons learned
   - Share troubleshooting experiences
   - Maintain team knowledge base

## Implementation Timeline

### Phase 1: Foundation (Week 1-2)
- [ ] Update MCP configuration
- [ ] Create comprehensive guidelines
- [ ] Train team on MCP tools

### Phase 2: Migration (Week 3-4)
- [ ] Migrate existing scripts
- [ ] Update CI/CD workflows
- [ ] Test fallback procedures

### Phase 3: Optimization (Week 5-6)
- [ ] Monitor performance
- [ ] Optimize operations
- [ ] Document lessons learned

### Phase 4: Maintenance (Ongoing)
- [ ] Regular updates and reviews
- [ ] Continuous improvement
- [ ] Team training and support

## Conclusion

This MCP-first approach for Git operations provides a robust, scalable, and secure foundation for managing Git workflows. By prioritizing MCP tools while maintaining GitHub CLI as a fallback, the team gains the benefits of modern tooling while ensuring operational continuity.

Regular review and updates to these guidelines will ensure they remain effective and relevant as the MCP ecosystem evolves and new capabilities become available.