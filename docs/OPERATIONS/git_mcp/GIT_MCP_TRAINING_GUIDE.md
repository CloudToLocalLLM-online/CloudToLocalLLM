# Git MCP Operations Training Guide

## Overview

This training guide provides comprehensive instruction for team members on using MCP tools for Git operations instead of GitHub CLI and native Git commands.

## Training Objectives

By the end of this training, participants will be able to:

1. Understand the MCP-first approach for Git operations
2. Use MCP GitHub tools for common Git tasks
3. Implement proper fallback procedures
4. Troubleshoot common MCP issues
5. Integrate MCP tools into existing workflows

## Training Modules

### Module 1: Introduction to MCP Git Operations

#### 1.1 What is MCP?
- **Model Context Protocol (MCP)**: A protocol for integrating AI tools with development workflows
- **MCP GitHub Server**: Provides Git operations through AI-powered tools
- **Benefits**: Consistency, automation, error handling, and integration capabilities

#### 1.2 Why MCP-First Approach?
- **Consistency**: Standardized operations across the team
- **Automation**: Reduced manual errors and improved efficiency
- **Integration**: Better integration with AI tools and workflows
- **Monitoring**: Enhanced logging and monitoring capabilities
- **Security**: Centralized credential management

#### 1.3 MCP vs GitHub CLI Comparison

| Operation | MCP Command | GitHub CLI Command | Benefits |
|-----------|-------------|-------------------|----------|
| Create Repository | `mcp--github--create_repository` | `gh repo create` | Better error handling, logging |
| Create Branch | `mcp--github--create_branch` | `gh api repos/.../git/refs` | Simplified syntax, validation |
| Create PR | `mcp--github--create_pull_request` | `gh pr create` | Enhanced metadata, validation |
| File Operations | `mcp--github--push_files` | Multiple commands | Atomic operations, better error handling |

### Module 2: MCP Tool Fundamentals

#### 2.1 MCP Command Structure
```bash
mcp--github--[operation] {
  "parameter1": "value1",
  "parameter2": "value2",
  ...
}
```

#### 2.2 Common Parameters
- **owner**: Repository owner/organization
- **repo**: Repository name
- **branch**: Branch name
- **message**: Commit message
- **content**: File content

#### 2.3 Error Handling Pattern
```bash
# Always implement fallback
if mcp--github--[operation] {...} 2>/dev/null; then
    echo "✓ Operation successful with MCP"
else
    echo "⚠ MCP failed, falling back to GitHub CLI"
    # GitHub CLI fallback
fi
```

### Module 3: Hands-On Exercises

#### Exercise 1: Repository Operations
**Objective**: Create and manage repositories using MCP tools

**Steps**:
1. Create a test repository
2. Verify repository creation
3. List repository contents
4. Clean up test repository

**Commands**:
```bash
# Create repository
mcp--github--create_repository {
  "name": "test-mcp-training",
  "description": "Repository for MCP training",
  "private": false,
  "autoInit": true
}

# List files in repository
mcp--github--get_file_contents {
  "owner": "your-username",
  "repo": "test-mcp-training",
  "path": ""
}
```

**Expected Outcome**: Successfully create and verify repository using MCP tools

#### Exercise 2: Branch Management
**Objective**: Create and manage branches using MCP tools

**Steps**:
1. Create a new feature branch
2. List all branches in repository
3. Verify branch creation

**Commands**:
```bash
# Create branch
mcp--github--create_branch {
  "branch": "feature/mcp-training",
  "from_branch": "main"
}

# List branches
mcp--github--list_branches {
  "owner": "your-username",
  "repo": "test-mcp-training"
}
```

**Expected Outcome**: Successfully create and verify branch using MCP tools

#### Exercise 3: File Operations
**Objective**: Create, update, and manage files using MCP tools

**Steps**:
1. Create a new file
2. Update existing file
3. Push multiple files at once
4. Verify file operations

**Commands**:
```bash
# Create single file
mcp--github--create_or_update_file {
  "owner": "your-username",
  "repo": "test-mcp-training",
  "path": "README.md",
  "content": "# MCP Training Repository\n\nThis repository was created using MCP tools.",
  "message": "Initial commit via MCP",
  "branch": "feature/mcp-training"
}

# Push multiple files
mcp--github--push_files {
  "owner": "your-username",
  "repo": "test-mcp-training",
  "branch": "feature/mcp-training",
  "message": "Multiple files via MCP",
  "files": [
    {"path": "src/app.js", "content": "// Application code"},
    {"path": "docs/README.md", "content": "# Documentation"}
  ]
}
```

**Expected Outcome**: Successfully create and manage files using MCP tools

#### Exercise 4: Pull Request Management
**Objective**: Create and manage pull requests using MCP tools

**Steps**:
1. Create a pull request
2. Update pull request details
3. Read pull request information

**Commands**:
```bash
# Create PR
mcp--github--create_pull_request {
  "owner": "your-username",
  "repo": "test-mcp-training",
  "head": "feature/mcp-training",
  "base": "main",
  "title": "MCP Training PR",
  "body": "This PR was created using MCP tools for training purposes.",
  "draft": false
}

# Update PR
mcp--github--update_pull_request {
  "owner": "your-username",
  "repo": "test-mcp-training",
  "pullNumber": 1,
  "title": "Updated MCP Training PR",
  "body": "Updated PR description"
}
```

**Expected Outcome**: Successfully create and manage pull requests using MCP tools

#### Exercise 5: Issue Management
**Objective**: Create and manage issues using MCP tools

**Steps**:
1. Create a new issue
2. Add comments to issue
3. Read issue information

**Commands**:
```bash
# Create issue
mcp--github--issue_write {
  "owner": "your-username",
  "repo": "test-mcp-training",
  "method": "create",
  "title": "MCP Training Issue",
  "body": "This issue was created using MCP tools for training purposes.",
  "labels": ["training", "mcp"]
}

# Add comment
mcp--github--add_issue_comment {
  "owner": "your-username",
  "repo": "test-mcp-training",
  "issue_number": 1,
  "body": "This is a test comment added via MCP tools."
}
```

**Expected Outcome**: Successfully create and manage issues using MCP tools

### Module 4: Advanced MCP Operations

#### 4.1 Batch Operations
```bash
# Create multiple files in a single operation
mcp--github--push_files {
  "owner": "organization",
  "repo": "repository",
  "branch": "feature/batch-operation",
  "message": "Batch file creation",
  "files": [
    {"path": "src/main.js", "content": "// Main application"},
    {"path": "src/utils.js", "content": "// Utility functions"},
    {"path": "src/config.js", "content": "// Configuration"},
    {"path": "package.json", "content": "{\"name\": \"app\", \"version\": \"1.0.0\"}"}
  ]
}
```

#### 4.2 Conditional Operations
```bash
# Check if branch exists before creating
if ! mcp--github--list_branches {
  "owner": "organization",
  "repo": "repository"
} | grep -q "feature/existing-branch"; then
    mcp--github--create_branch {
      "branch": "feature/existing-branch",
      "from_branch": "main"
    }
fi
```

#### 4.3 Error Recovery
```bash
# Implement retry logic
retry_operation() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if mcp--github--create_repository {
            "name": "retry-test",
            "description": "Test repository"
        } 2>/dev/null; then
            echo "✓ Operation successful on attempt $attempt"
            return 0
        fi
        
        echo "Attempt $attempt failed, retrying..."
        sleep 2
        ((attempt++))
    done
    
    echo "❌ Operation failed after $max_attempts attempts"
    return 1
}
```

### Module 5: Troubleshooting and Best Practices

#### 5.1 Common Issues and Solutions

**Issue**: MCP server not responding
```bash
# Check MCP server status
systemctl status mcp-github-server

# Restart if needed
systemctl restart mcp-github-server

# Check logs
journalctl -u mcp-github-server -f
```

**Issue**: Authentication failures
```bash
# Check MCP configuration
cat ~/.kilocode/mcp_settings.json | grep -A 5 '"github"'

# Verify GitHub token
gh auth status

# Test authentication
mcp--github--get_me
```

**Issue**: Rate limiting
```bash
# Check rate limit status
gh api rate_limit

# Implement delays between operations
sleep 1
```

#### 5.2 Best Practices

**1. Always Implement Fallback**
```bash
# Good practice
if mcp--github--create_repository {...} 2>/dev/null; then
    echo "✓ Created with MCP"
else
    echo "⚠ Falling back to GitHub CLI"
    gh repo create ...
fi
```

**2. Use Structured Logging**
```bash
# Log all operations
echo "$(date): Creating repository test-repo" >> mcp-operations.log
if mcp--github--create_repository {...} 2>&1 | tee -a mcp-operations.log; then
    echo "$(date): ✓ Repository created successfully" >> mcp-operations.log
else
    echo "$(date): ❌ Repository creation failed" >> mcp-operations.log
fi
```

**3. Validate Parameters**
```bash
# Validate input before operation
validate_repository_name() {
    local name=$1
    if [[ ! $name =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "❌ Invalid repository name: $name"
        return 1
    fi
    return 0
}

if validate_repository_name "$REPO_NAME"; then
    mcp--github--create_repository {
        "name": "$REPO_NAME",
        "description": "Test repository"
    }
fi
```

**4. Handle Errors Gracefully**
```bash
# Capture and handle errors
create_repository_with_error_handling() {
    local repo_name=$1
    local result
    
    result=$(mcp--github--create_repository {
        "name": "$repo_name",
        "description": "Test repository"
    } 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "✓ Repository created successfully"
        return 0
    else
        echo "❌ Repository creation failed:"
        echo "$result"
        return 1
    fi
}
```

### Module 6: Integration with Existing Workflows

#### 6.1 CI/CD Integration
```yaml
# .github/workflows/deploy.yml
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
          if mcp--github--create_branch {
            "branch": "deploy-${{ github.run_number }}",
            "from_branch": "main"
          } 2>/dev/null; then
            echo "✓ Branch created with MCP"
          else
            echo "⚠ MCP failed, using GitHub CLI"
            gh api repos/organization/repository/git/refs -X POST \
              -f ref="refs/heads/deploy-${{ github.run_number }}" \
              -f sha="$(gh api repos/organization/repository/git/refs/heads/main | jq -r .object.sha)"
          fi
```

#### 6.2 Script Integration
```bash
#!/bin/bash
# scripts/deploy.sh - Updated for MCP-first approach

# Function to create deployment
deploy_with_mcp() {
    local version=$1
    local branch="deploy-$version"
    
    echo "Starting deployment for version $version"
    
    # Create deployment branch
    if ! mcp--github--create_branch {
        "branch": "$branch",
        "from_branch": "main"
    } 2>/dev/null; then
        echo "❌ Failed to create deployment branch"
        return 1
    fi
    
    # Push deployment files
    if ! mcp--github--push_files {
        "owner": "organization",
        "repo": "repository",
        "branch": "$branch",
        "message": "Deploy version $version",
        "files": [
            {"path": "dist/", "content": "$(cat dist.tar.gz | base64 -w 0)"}
        ]
    } 2>/dev/null; then
        echo "❌ Failed to push deployment files"
        return 1
    fi
    
    # Create deployment PR
    if ! mcp--github--create_pull_request {
        "owner": "organization",
        "repo": "repository",
        "head": "$branch",
        "base": "main",
        "title": "Deploy version $version",
        "body": "Deployment for version $version",
        "draft": false
    } 2>/dev/null; then
        echo "❌ Failed to create deployment PR"
        return 1
    fi
    
    echo "✓ Deployment completed successfully"
    return 0
}

# Usage
deploy_with_mcp "$1"
```

### Module 7: Assessment and Certification

#### 7.1 Knowledge Assessment
**Multiple Choice Questions**:
1. What is the primary benefit of using MCP tools for Git operations?
   A) Faster execution
   B) Better error handling and logging
   C) Reduced functionality
   D) Increased complexity

2. Which command should you use to create a pull request using MCP?
   A) `mcp--github--create_pr`
   B) `mcp--github--create_pull_request`
   C) `gh pr create`
   D) `git push origin`

3. What is the correct fallback pattern for MCP operations?
   A) Always use GitHub CLI
   B) Try MCP first, fallback to GitHub CLI if needed
   C) Use native Git commands only
   D) Skip operations if MCP fails

#### 7.2 Practical Assessment
**Task**: Complete the following using MCP tools:
1. Create a test repository
2. Create a feature branch
3. Add multiple files
4. Create a pull request
5. Add an issue with labels
6. Implement proper error handling and logging

**Evaluation Criteria**:
- [ ] All operations completed successfully
- [ ] Proper error handling implemented
- [ ] Fallback procedures documented
- [ ] Operations logged appropriately

#### 7.3 Certification Requirements
To be certified in MCP Git operations, participants must:
- [ ] Complete all training modules
- [ ] Pass the knowledge assessment (80% or higher)
- [ ] Complete the practical assessment successfully
- [ ] Demonstrate understanding of best practices

## Additional Resources

### Documentation
- [MCP Operations Guide](GIT_MCP_OPERATIONS_GUIDE.md)
- [Migration Guide](GIT_MIGRATION_GUIDE.md)
- [Validation Guide](GIT_MCP_VALIDATION_GUIDE.md)

### Reference Materials
- [MCP GitHub Tools API Reference](https://docs.mcp.tools/github)
- [GitHub CLI Documentation](https://cli.github.com/)
- [Git Best Practices](https://git-scm.com/book/en/v2)

### Support and Help
- **Internal Documentation**: [Company Wiki](https://wiki.company.com/mcp)
- **Support Channel**: #mcp-support on Slack
- **Training Videos**: [Internal Training Portal](https://training.company.com/mcp)

## Continuous Learning

### Advanced Topics
1. **Custom MCP Tools**: Creating custom MCP tools for specific workflows
2. **Integration with AI**: Using MCP with AI tools for enhanced automation
3. **Performance Optimization**: Optimizing MCP operations for large-scale usage
4. **Security Best Practices**: Advanced security considerations for MCP usage

### Community and Updates
- **MCP Community**: Join the MCP user community
- **Release Notes**: Stay updated with MCP tool releases
- **Feedback**: Provide feedback for MCP tool improvements

This training guide provides a comprehensive foundation for using MCP tools in Git operations. Regular practice and staying updated with new MCP capabilities will ensure continued proficiency and efficiency.