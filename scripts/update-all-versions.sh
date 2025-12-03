#!/bin/bash
set -e

# Script to update all version references across the project
# Usage: ./update-all-versions.sh <new-version> <commit-sha>

NEW_VERSION="$1"
COMMIT_SHA="$2"
SHORT_SHA="${COMMIT_SHA:0:8}"
BUILD_NUMBER=$(date +%Y%m%d%H%M)
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

if [ -z "$NEW_VERSION" ]; then
    echo "❌ Usage: $0 <new-version> <commit-sha>"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Updating All Version References"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "New version: $NEW_VERSION"
echo "Commit SHA: $SHORT_SHA"
echo ""

# 1. Update assets/version.json
echo "1. Updating assets/version.json..."
jq -n \
  --arg version "$NEW_VERSION" \
  --arg build_number "$BUILD_NUMBER" \
  --arg build_date "$BUILD_DATE" \
  --arg git_commit "$SHORT_SHA" \
  --arg buildTimestamp "$BUILD_TIMESTAMP" \
  '{
    version: $version,
    build_number: $build_number,
    build_date: $build_date,
    git_commit: $git_commit,
    buildTimestamp: $buildTimestamp
  }' > assets/version.json

# 2. Update assets/component-versions.json
echo "2. Updating assets/component-versions.json..."
jq -n \
  --arg web "$NEW_VERSION" \
  --arg api "$NEW_VERSION-api" \
  --arg postgres "$NEW_VERSION-postgres" \
  --arg streaming_proxy "$NEW_VERSION-proxy" \
  --arg base "$NEW_VERSION-base" \
  --arg last_updated "$BUILD_DATE" \
  '{
    web: $web,
    api: $api,
    postgres: $postgres,
    streaming_proxy: $streaming_proxy,
    base: $base,
    last_updated: $last_updated
  }' > assets/component-versions.json

# 3. Update pubspec.yaml
echo "3. Updating pubspec.yaml..."
# Flutter uses version+build format (e.g., 4.5.0+202512031420)
sed -i "s/^version: .*/version: ${NEW_VERSION}+${BUILD_NUMBER}/" pubspec.yaml

# 4. Update services/api-backend/package.json
echo "4. Updating services/api-backend/package.json..."
if [ -f "services/api-backend/package.json" ]; then
    jq --arg version "$NEW_VERSION" '.version = $version' services/api-backend/package.json > /tmp/api-package.json
    mv /tmp/api-package.json services/api-backend/package.json
fi

# 5. Update services/streaming-proxy/package.json
echo "5. Updating services/streaming-proxy/package.json..."
if [ -f "services/streaming-proxy/package.json" ]; then
    jq --arg version "$NEW_VERSION" '.version = $version' services/streaming-proxy/package.json > /tmp/proxy-package.json
    mv /tmp/proxy-package.json services/streaming-proxy/package.json
fi

# 6. Update README.md version badges (if they exist)
echo "6. Updating README.md..."
if [ -f "README.md" ]; then
    sed -i "s/v[0-9]\+\.[0-9]\+\.[0-9]\+-/v${NEW_VERSION}-/g" README.md || true
fi

# 7. Update any documentation with version references
echo "7. Updating documentation..."
if [ -f "docs/VERSIONING.md" ]; then
    # Update example versions in documentation
    sed -i "s/4\.[0-9]\+\.[0-9]\+/${NEW_VERSION}/g" docs/VERSIONING.md || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All Version References Updated"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Files updated:"
echo "  ✅ assets/version.json → $NEW_VERSION"
echo "  ✅ assets/component-versions.json → all services"
echo "  ✅ pubspec.yaml → ${NEW_VERSION}+${BUILD_NUMBER}"
echo "  ✅ services/api-backend/package.json → $NEW_VERSION"
echo "  ✅ services/streaming-proxy/package.json → $NEW_VERSION"
echo "  ✅ README.md → updated badges"
echo "  ✅ docs/VERSIONING.md → updated examples"
echo ""

