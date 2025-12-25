#!/bin/bash

# Script to properly push changes to cloud branch for AKS deployment
# Ensures cloud branch has all changes from main including version bumps

set -e

if [ -z "$1" ]; then
    echo "âŒ Error: Version required"
    echo "Usage: $0 <version>"
    exit 1
fi

NEW_VERSION="$1"
SHORT_SHA=$(git rev-parse --short HEAD)

echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "Pushing v$NEW_VERSION to cloud branch"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"

# Ensure we're on main and have the latest changes
echo "Ensuring we're on main branch with latest changes..."
git checkout main
git pull origin main

# Create or update cloud branch from main
echo "Creating/updating cloud branch from main..."
if git show-ref --verify --quiet refs/heads/cloud; then
    # Cloud branch exists, reset it to main
    git branch -D cloud
fi

# Create fresh cloud branch from main
git checkout -b cloud

# Verify the cloud branch has the expected version
CURRENT_VERSION=$(jq -r '.version' assets/version.json)
if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
    echo "âŒ Error: Cloud branch version ($CURRENT_VERSION) doesn't match expected version ($NEW_VERSION)"
    echo "This suggests the version bump wasn't properly committed to main"
    exit 1
fi

echo "âœ… Cloud branch created with version $NEW_VERSION"
echo "âœ… Cloud branch created with version $NEW_VERSION"

# Configure git to use PAT for push operations if provided
if [ -n "$CLOUD_PUSH_PAT" ]; then
    echo "ðŸ” Using PAT for authenticated cloud branch push..."
    git remote set-url origin "https://x-access-token:$CLOUD_PUSH_PAT@github.com/CloudToLocalLLM-online/CloudToLocalLLM.git"
    echo "âœ… Remote URL configured with PAT authentication"
else
    echo "âš ï¸  No CLOUD_PUSH_PAT provided, using default authentication"
fi

# Push the cloud branch

# Push the cloud branch
echo "Pushing cloud branch to origin..."
git push -f origin cloud

# Create and push version tag
echo "Creating version tag: ${NEW_VERSION}-cloud-${SHORT_SHA}"
git tag "${NEW_VERSION}-cloud-${SHORT_SHA}" -f
git push origin "${NEW_VERSION}-cloud-${SHORT_SHA}" -f

# Return to main
git checkout main

echo "âœ… Successfully pushed v$NEW_VERSION to cloud branch"
echo "   Branch: cloud"
echo "   Tag: ${NEW_VERSION}-cloud-${SHORT_SHA}"
echo "   This should trigger the deploy-aks workflow"
