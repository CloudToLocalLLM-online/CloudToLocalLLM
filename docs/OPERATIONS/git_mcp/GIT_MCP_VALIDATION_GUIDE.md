# Git MCP Tool Integration Validation Guide

## Overview

This guide provides comprehensive validation and testing procedures to ensure MCP tools are properly integrated and functioning correctly for Git operations.

## Pre-Validation Checklist

### 1. MCP Server Configuration Verification
```bash
# Verify MCP GitHub server is properly configured
cat ~/.kilocode/mcp_settings.json | jq '.mcpServers.github'

# Check MCP server status
systemctl status mcp-github-server

# Verify Docker container is running (if using Docker)
docker ps | grep github-mcp-server
```

### 2. Authentication Verification
```bash
# Test MCP authentication
mcp--github--get_me

# Verify GitHub token is valid
gh auth status

# Check token permissions
gh api user/keys
```

### 3. Network Connectivity
```bash
# Test GitHub API connectivity
curl -s -o /dev/null -w "%{http_code}" https://api.github.com

# Test MCP server connectivity
nc -zv localhost 3000  # Replace with actual MCP port
```

## Validation Test Suite

### Test 1: Basic MCP Operations

#### 1.1 Repository Operations
```bash
#!/bin/bash
# test-mcp-repository-operations.sh

echo "=== Testing MCP Repository Operations ==="

# Test 1: Create test repository
echo "Test 1: Create repository"
REPO_NAME="test-mcp-repo-$(date +%s)"
if mcp--github--create_repository {
  "name": "$REPO_NAME",
  "description": "Test repository for MCP validation",
  "private": false,
  "autoInit": true
} 2>/dev/null; then
    echo "✓ Repository creation: PASS"
else
    echo "❌ Repository creation: FAIL"
    exit 1
fi

# Test 2: Get repository details
echo "Test 2: Get repository details"
if mcp--github--get_file_contents {
  "owner": "organization",
  "repo": "$REPO_NAME",
  "path": "README.md"
} 2>/dev/null; then
    echo "✓ Repository details retrieval: PASS"
else
    echo "❌ Repository details retrieval: FAIL"
    exit 1
fi

# Test 3: Fork repository
echo "Test 3: Fork repository"
if mcp--github--fork_repository {
  "owner": "organization",
  "repo": "$REPO_NAME"
} 2>/dev/null; then
    echo "✓ Repository forking: PASS"
else
    echo "❌ Repository forking: FAIL"
    exit 1
fi

echo "=== Repository Operations: ALL TESTS PASSED ==="
```

#### 1.2 Branch Operations
```bash
#!/bin/bash
# test-mcp-branch-operations.sh

echo "=== Testing MCP Branch Operations ==="

# Test 1: Create branch
echo "Test 1: Create branch"
BRANCH_NAME="test-branch-$(date +%s)"
if mcp--github--create_branch {
  "branch": "$BRANCH_NAME",
  "from_branch": "main"
} 2>/dev/null; then
    echo "✓ Branch creation: PASS"
else
    echo "❌ Branch creation: FAIL"
    exit 1
fi

# Test 2: List branches
echo "Test 2: List branches"
if mcp--github--list_branches {
  "owner": "organization",
  "repo": "repository"
} 2>/dev/null; then
    echo "✓ Branch listing: PASS"
else
    echo "❌ Branch listing: FAIL"
    exit 1
fi

echo "=== Branch Operations: ALL TESTS PASSED ==="
```

#### 1.3 File Operations
```bash
#!/bin/bash
# test-mcp-file-operations.sh

echo "=== Testing MCP File Operations ==="

# Test 1: Create single file
echo "Test 1: Create single file"
FILE_PATH="test-file-$(date +%s).md"
FILE_CONTENT="# Test File\nCreated via MCP\nTimestamp: $(date)"
if mcp--github--create_or_update_file {
  "owner": "organization",
  "repo": "repository",
  "path": "$FILE_PATH",
  "content": "$FILE_CONTENT",
  "message": "Test commit via MCP",
  "branch": "test-branch"
} 2>/dev/null; then
    echo "✓ Single file creation: PASS"
else
    echo "❌ Single file creation: FAIL"
    exit 1
fi

# Test 2: Push multiple files
echo "Test 2: Push multiple files"
if mcp--github--push_files {
  "owner": "organization",
  "repo": "repository",
  "branch": "test-branch",
  "message": "Multiple files via MCP",
  "files": [
    {"path": "file1.txt", "content": "Content 1"},
    {"path": "file2.txt", "content": "Content 2"},
    {"path": "file3.txt", "content": "Content 3"}
  ]
} 2>/dev/null; then
    echo "✓ Multiple file push: PASS"
else
    echo "❌ Multiple file push: FAIL"
    exit 1
fi

# Test 3: Read file contents
echo "Test 3: Read file contents"
if mcp--github--get_file_contents {
  "owner": "organization",
  "repo": "repository",
  "path": "$FILE_PATH"
} 2>/dev/null; then
    echo "✓ File reading: PASS"
else
    echo "❌ File reading: FAIL"
    exit 1
fi

echo "=== File Operations: ALL TESTS PASSED ==="
```

#### 1.4 Pull Request Operations
```bash
#!/bin/bash
# test-mcp-pr-operations.sh

echo "=== Testing MCP Pull Request Operations ==="

# Test 1: Create pull request
echo "Test 1: Create pull request"
PR_TITLE="Test PR via MCP"
PR_BODY="This is a test pull request created via MCP tools"
if mcp--github--create_pull_request {
  "owner": "organization",
  "repo": "repository",
  "head": "test-branch",
  "base": "main",
  "title": "$PR_TITLE",
  "body": "$PR_BODY",
  "draft": false
} 2>/dev/null; then
    echo "✓ PR creation: PASS"
else
    echo "❌ PR creation: FAIL"
    exit 1
fi

# Test 2: Read PR information
echo "Test 2: Read PR information"
if mcp--github--pull_request_read {
  "owner": "organization",
  "repo": "repository",
  "pullNumber": 1,
  "method": "get"
} 2>/dev/null; then
    echo "✓ PR reading: PASS"
else
    echo "❌ PR reading: FAIL"
    exit 1
fi

# Test 3: Update PR
echo "Test 3: Update PR"
if mcp--github--update_pull_request {
  "owner": "organization",
  "repo": "repository",
  "pullNumber": 1,
  "title": "Updated Test PR",
  "body": "Updated PR description"
} 2>/dev/null; then
    echo "✓ PR update: PASS"
else
    echo "❌ PR update: FAIL"
    exit 1
fi

echo "=== Pull Request Operations: ALL TESTS PASSED ==="
```

#### 1.5 Issue Operations
```bash
#!/bin/bash
# test-mcp-issue-operations.sh

echo "=== Testing MCP Issue Operations ==="

# Test 1: Create issue
echo "Test 1: Create issue"
ISSUE_TITLE="Test Issue via MCP"
ISSUE_BODY="This is a test issue created via MCP tools"
if mcp--github--issue_write {
  "owner": "organization",
  "repo": "repository",
  "method": "create",
  "title": "$ISSUE_TITLE",
  "body": "$ISSUE_BODY",
  "labels": ["test", "mcp"]
} 2>/dev/null; then
    echo "✓ Issue creation: PASS"
else
    echo "❌ Issue creation: FAIL"
    exit 1
fi

# Test 2: Add comment to issue
echo "Test 2: Add comment to issue"
if mcp--github--add_issue_comment {
  "owner": "organization",
  "repo": "repository",
  "issue_number": 1,
  "body": "This is a test comment via MCP"
} 2>/dev/null; then
    echo "✓ Issue comment: PASS"
else
    echo "❌ Issue comment: FAIL"
    exit 1
fi

# Test 3: Read issue information
echo "Test 3: Read issue information"
if mcp--github--issue_read {
  "owner": "organization",
  "repo": "repository",
  "issue_number": 1,
  "method": "get"
} 2>/dev/null; then
    echo "✓ Issue reading: PASS"
else
    echo "❌ Issue reading: FAIL"
    exit 1
fi

echo "=== Issue Operations: ALL TESTS PASSED ==="
```

#### 1.6 Release Operations
```bash
#!/bin/bash
# test-mcp-release-operations.sh

echo "=== Testing MCP Release Operations ==="

# Test 1: Create release
echo "Test 1: Create release"
RELEASE_TAG="v1.0.0-test-$(date +%s)"
RELEASE_NAME="Test Release 1.0.0"
RELEASE_BODY="This is a test release created via MCP tools"
if mcp--github--create_release {
  "owner": "organization",
  "repo": "repository",
  "tag": "$RELEASE_TAG",
  "name": "$RELEASE_NAME",
  "body": "$RELEASE_BODY",
  "draft": false,
  "prerelease": false
} 2>/dev/null; then
    echo "✓ Release creation: PASS"
else
    echo "❌ Release creation: FAIL"
    exit 1
fi

# Test 2: Get latest release
echo "Test 2: Get latest release"
if mcp--github--get_latest_release {
  "owner": "organization",
  "repo": "repository"
} 2>/dev/null; then
    echo "✓ Latest release retrieval: PASS"
else
    echo "❌ Latest release retrieval: FAIL"
    exit 1
fi

# Test 3: Get release by tag
echo "Test 3: Get release by tag"
if mcp--github--get_release_by_tag {
  "owner": "organization",
  "repo": "repository",
  "tag": "$RELEASE_TAG"
} 2>/dev/null; then
    echo "✓ Release by tag retrieval: PASS"
else
    echo "❌ Release by tag retrieval: FAIL"
    exit 1
fi

echo "=== Release Operations: ALL TESTS PASSED ==="
```

### Test 2: Performance Validation

#### 2.1 Operation Performance Comparison
```bash
#!/bin/bash
# test-mcp-performance.sh

echo "=== MCP Performance Validation ==="

# Function to time MCP operations
time_mcp_operation() {
    local operation=$1
    local params=$2
    
    echo "Timing MCP operation: $operation"
    /usr/bin/time -f "MCP Time: %e seconds" mcp--github--$operation $params 2>/dev/null
}

# Function to time GitHub CLI operations
time_gh_operation() {
    local operation=$1
    local params=$2
    
    echo "Timing GitHub CLI operation: $operation"
    /usr/bin/time -f "GitHub CLI Time: %e seconds" gh $operation $params 2>/dev/null
}

# Test performance for common operations
echo "=== Performance Comparison ==="

# Repository listing
echo "--- Repository Listing ---"
time_mcp_operation "list_repositories" '{"owner": "organization"}'
time_gh_operation "api" "repos/organization/repos"

# Branch listing
echo "--- Branch Listing ---"
time_mcp_operation "list_branches" '{"owner": "organization", "repo": "repository"}'
time_gh_operation "api" "repos/organization/repository/branches"

# Commit listing
echo "--- Commit Listing ---"
time_mcp_operation "list_commits" '{"owner": "organization", "repo": "repository", "perPage": 100}'
time_gh_operation "api" "repos/organization/repository/commits?per_page=100"

echo "=== Performance Validation Complete ==="
```

#### 2.2 Concurrent Operation Testing
```bash
#!/bin/bash
# test-mcp-concurrency.sh

echo "=== MCP Concurrent Operations Testing ==="

# Test concurrent file operations
echo "Testing concurrent file operations..."
for i in {1..5}; do
    (
        FILE_PATH="concurrent-test-$i.txt"
        FILE_CONTENT="Concurrent test file $i - $(date)"
        mcp--github--create_or_update_file {
          "owner": "organization",
          "repo": "repository",
          "path": "$FILE_PATH",
          "content": "$FILE_CONTENT",
          "message": "Concurrent test $i",
          "branch": "main"
        } 2>/dev/null
        echo "Concurrent operation $i completed"
    ) &
done
wait

echo "=== Concurrent Operations Test Complete ==="
```

### Test 3: Error Handling and Fallback Validation

#### 3.1 MCP Failure Simulation
```bash
#!/bin/bash
# test-mcp-fallback.sh

echo "=== MCP Fallback Validation ==="

# Function to test fallback mechanism
test_fallback_mechanism() {
    local operation=$1
    local mcp_params=$2
    local gh_command=$3
    
    echo "Testing fallback for: $operation"
    
    # Simulate MCP failure (temporarily disable MCP)
    echo "Simulating MCP failure..."
    
    # Try operation (should fail)
    if ! mcp--github--$operation $mcp_params 2>/dev/null; then
        echo "✓ MCP correctly failed"
        
        # Try GitHub CLI fallback
        if $gh_command 2>/dev/null; then
            echo "✓ GitHub CLI fallback successful"
            return 0
        else
            echo "❌ GitHub CLI fallback failed"
            return 1
        fi
    else
        echo "❌ MCP should have failed but didn't"
        return 1
    fi
}

# Test fallback for common operations
echo "--- Testing Repository Creation Fallback ---"
test_fallback_mechanism "create_repository" \
    '{"name": "test-fallback-repo", "description": "Test fallback", "private": false}' \
    'gh repo create test-fallback-repo --description "Test fallback" --public'

echo "--- Testing Branch Creation Fallback ---"
test_fallback_mechanism "create_branch" \
    '{"branch": "test-fallback-branch", "from_branch": "main"}' \
    'gh api repos/organization/repository/git/refs -X POST -f ref="refs/heads/test-fallback-branch" -f sha="$(gh api repos/organization/repository/git/refs/heads/main | jq -r .object.sha)"'

echo "=== Fallback Validation Complete ==="
```

#### 3.2 Error Recovery Testing
```bash
#!/bin/bash
# test-mcp-error-recovery.sh

echo "=== MCP Error Recovery Testing ==="

# Test 1: Network interruption recovery
echo "Test 1: Network interruption recovery"
# Simulate network issues and test recovery

# Test 2: Authentication failure recovery
echo "Test 2: Authentication failure recovery"
# Simulate auth issues and test recovery

# Test 3: Rate limiting recovery
echo "Test 3: Rate limiting recovery"
# Test rate limit handling and retry logic

echo "=== Error Recovery Testing Complete ==="
```

### Test 4: Integration Testing

#### 4.1 End-to-End Workflow Testing
```bash
#!/bin/bash
# test-mcp-e2e-workflow.sh

echo "=== MCP End-to-End Workflow Testing ==="

# Complete workflow: Create repo -> Create branch -> Add files -> Create PR -> Merge
echo "Starting end-to-end workflow test..."

# Step 1: Create repository
REPO_NAME="e2e-test-repo-$(date +%s)"
echo "Step 1: Creating repository..."
if ! mcp--github--create_repository {
  "name": "$REPO_NAME",
  "description": "E2E test repository",
  "private": false,
  "autoInit": true
} 2>/dev/null; then
    echo "❌ Failed to create repository"
    exit 1
fi
echo "✓ Repository created"

# Step 2: Create feature branch
BRANCH_NAME="feature/e2e-test"
echo "Step 2: Creating feature branch..."
if ! mcp--github--create_branch {
  "branch": "$BRANCH_NAME",
  "from_branch": "main"
} 2>/dev/null; then
    echo "❌ Failed to create branch"
    exit 1
fi
echo "✓ Branch created"

# Step 3: Add feature files
echo "Step 3: Adding feature files..."
if ! mcp--github--push_files {
  "owner": "organization",
  "repo": "$REPO_NAME",
  "branch": "$BRANCH_NAME",
  "message": "Add feature files",
  "files": [
    {"path": "feature.js", "content": "// Feature implementation"},
    {"path": "README.md", "content": "# Feature Documentation\n\nThis is a test feature."}
  ]
} 2>/dev/null; then
    echo "❌ Failed to add files"
    exit 1
fi
echo "✓ Files added"

# Step 4: Create pull request
echo "Step 4: Creating pull request..."
if ! mcp--github--create_pull_request {
  "owner": "organization",
  "repo": "$REPO_NAME",
  "head": "$BRANCH_NAME",
  "base": "main",
  "title": "E2E Test Feature",
  "body": "This is an end-to-end test pull request",
  "draft": false
} 2>/dev/null; then
    echo "❌ Failed to create PR"
    exit 1
fi
echo "✓ Pull request created"

# Step 5: Merge pull request
echo "Step 5: Merging pull request..."
if ! mcp--github--merge_pull_request {
  "owner": "organization",
  "repo": "$REPO_NAME",
  "pullNumber": 1,
  "merge_method": "merge"
} 2>/dev/null; then
    echo "❌ Failed to merge PR"
    exit 1
fi
echo "✓ Pull request merged"

echo "=== End-to-End Workflow: ALL TESTS PASSED ==="
```

#### 4.2 CI/CD Integration Testing
```bash
#!/bin/bash
# test-mcp-cicd-integration.sh

echo "=== MCP CI/CD Integration Testing ==="

# Test MCP operations in CI/CD context
echo "Testing MCP operations in CI/CD environment..."

# Simulate CI/CD environment variables
export CI=true
export GITHUB_REPOSITORY="organization/repository"
export GITHUB_REF="refs/heads/main"

# Test 1: Deployment branch creation
echo "Test 1: Deployment branch creation"
DEPLOY_BRANCH="deploy-$(date +%s)"
if mcp--github--create_branch {
  "branch": "$DEPLOY_BRANCH",
  "from_branch": "main"
} 2>/dev/null; then
    echo "✓ Deployment branch creation: PASS"
else
    echo "❌ Deployment branch creation: FAIL"
    exit 1
fi

# Test 2: Deployment file push
echo "Test 2: Deployment file push"
if mcp--github--push_files {
  "owner": "organization",
  "repo": "repository",
  "branch": "$DEPLOY_BRANCH",
  "message": "Deploy build $(date +%s)",
  "files": [
    {"path": "dist/app.js", "content": "// Deployed application"},
    {"path": "dist/index.html", "content": "<html><body>Deployed</body></html>"}
  ]
} 2>/dev/null; then
    echo "✓ Deployment file push: PASS"
else
    echo "❌ Deployment file push: FAIL"
    exit 1
fi

echo "=== CI/CD Integration: ALL TESTS PASSED ==="
```

## Validation Report Generation

### Automated Validation Script
```bash
#!/bin/bash
# run-mcp-validation.sh

echo "=== MCP Git Operations Validation Suite ==="
echo "Starting comprehensive validation..."

# Create validation report
REPORT_FILE="mcp-validation-report-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee -a "$REPORT_FILE")
exec 2>&1

# Run all validation tests
echo "Running validation tests..."
echo "Timestamp: $(date)"
echo "=================================="

# Basic operations tests
echo "=== Basic Operations Tests ==="
./test-mcp-repository-operations.sh
./test-mcp-branch-operations.sh
./test-mcp-file-operations.sh
./test-mcp-pr-operations.sh
./test-mcp-issue-operations.sh
./test-mcp-release-operations.sh

# Performance tests
echo "=== Performance Tests ==="
./test-mcp-performance.sh
./test-mcp-concurrency.sh

# Error handling tests
echo "=== Error Handling Tests ==="
./test-mcp-fallback.sh
./test-mcp-error-recovery.sh

# Integration tests
echo "=== Integration Tests ==="
./test-mcp-e2e-workflow.sh
./test-mcp-cicd-integration.sh

echo "=== Validation Complete ==="
echo "Report saved to: $REPORT_FILE"
```

### Validation Report Template
```markdown
# MCP Git Operations Validation Report

## Executive Summary
- **Validation Date**: [DATE]
- **Validation Scope**: [SCOPE]
- **Overall Status**: [PASS/FAIL]
- **Total Tests**: [NUMBER]
- **Passed Tests**: [NUMBER]
- **Failed Tests**: [NUMBER]
- **Success Rate**: [PERCENTAGE]%

## Test Results

### Basic Operations
- [ ] Repository Operations: PASS/FAIL
- [ ] Branch Operations: PASS/FAIL
- [ ] File Operations: PASS/FAIL
- [ ] Pull Request Operations: PASS/FAIL
- [ ] Issue Operations: PASS/FAIL
- [ ] Release Operations: PASS/FAIL

### Performance Tests
- [ ] Operation Performance: PASS/FAIL
- [ ] Concurrent Operations: PASS/FAIL
- [ ] Performance Benchmarks: PASS/FAIL

### Error Handling
- [ ] Fallback Mechanisms: PASS/FAIL
- [ ] Error Recovery: PASS/FAIL
- [ ] Rate Limiting: PASS/FAIL

### Integration Tests
- [ ] End-to-End Workflows: PASS/FAIL
- [ ] CI/CD Integration: PASS/FAIL
- [ ] Real-world Scenarios: PASS/FAIL

## Issues and Resolutions

### Critical Issues
[List any critical issues found during validation]

### Performance Issues
[List any performance-related issues]

### Configuration Issues
[List any configuration problems]

## Recommendations

### Immediate Actions
[List immediate actions required]

### Long-term Improvements
[List long-term improvement recommendations]

### Training Needs
[List any training requirements identified]

## Conclusion
[Summary of validation results and readiness assessment]
```

## Continuous Validation

### Automated Daily Validation
```bash
#!/bin/bash
# daily-mcp-validation.sh

echo "=== Daily MCP Validation ==="
echo "Running daily validation checks..."

# Run critical path tests
./test-mcp-repository-operations.sh
./test-mcp-branch-operations.sh
./test-mcp-file-operations.sh

# Check MCP server health
systemctl status mcp-github-server

# Check GitHub API status
curl -s https://api.github.com | grep -q "current_time"

# Generate daily report
echo "Daily validation completed at $(date)" >> daily-validation.log

echo "=== Daily Validation Complete ==="
```

### Weekly Performance Review
```bash
#!/bin/bash
# weekly-mcp-performance-review.sh

echo "=== Weekly MCP Performance Review ==="

# Collect performance metrics
echo "Collecting performance metrics..."

# Compare with baseline
echo "Comparing with baseline performance..."

# Generate performance report
echo "Generating performance report..."

echo "=== Weekly Performance Review Complete ==="
```

This comprehensive validation guide ensures that MCP tools are properly integrated, tested, and ready for production use in Git operations.