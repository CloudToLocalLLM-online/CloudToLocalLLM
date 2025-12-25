#!/bin/bash
set -e

# Script to bump version for Docker images
# Usage: ./bump-version.sh [major|minor|patch]

VERSION_FILE="assets/version.json"
BUMP_TYPE="${1:-patch}"  # Default to patch bump

if [ ! -f "$VERSION_FILE" ]; then
    echo "âŒ Version file not found: $VERSION_FILE"
    exit 1
fi

# Read current version
CURRENT_VERSION=$(jq -r '.version' "$VERSION_FILE")
echo "Current version: $CURRENT_VERSION"

# Split version into components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Bump version based on type
case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "âŒ Invalid bump type: $BUMP_TYPE (must be: major, minor, or patch)"
        exit 1
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
BUILD_NUMBER=$(date +%Y%m%d%H%M)
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "New version: $NEW_VERSION"
echo "Build number: $BUILD_NUMBER"
echo "Git commit: $GIT_COMMIT"

# Update version.json
cat > "$VERSION_FILE" <<EOF
{
  "version": "$NEW_VERSION",
  "build_number": "$BUILD_NUMBER",
  "build_date": "$BUILD_DATE",
  "git_commit": "$GIT_COMMIT",
  "buildTimestamp": "$BUILD_TIMESTAMP"
}
EOF

echo "âœ… Version bumped to $NEW_VERSION"
echo ""
echo "Version file updated: $VERSION_FILE"
echo ""
echo "Export for GitHub Actions:"
echo "APP_VERSION=$NEW_VERSION"
echo "BUILD_NUMBER=$BUILD_NUMBER"
echo "GIT_COMMIT=$GIT_COMMIT"

