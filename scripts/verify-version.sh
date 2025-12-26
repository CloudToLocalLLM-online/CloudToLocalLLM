#!/bin/bash
set -e

# Verify version consistency across files
# Usage: ./verify-version.sh

echo "ðŸ” Verifying version consistency..."

# Get version from assets/version.json
ASSETS_VERSION=$(jq -r '.version' assets/version.json)
# Extract semantic part
SEMANTIC_ASSETS=$(echo "$ASSETS_VERSION" | cut -d'+' -f1)

# Get version from pubspec.yaml
PUBSPEC_VERSION=$(grep "^version: " pubspec.yaml | cut -d' ' -f2)
SEMANTIC_PUBSPEC=$(echo "$PUBSPEC_VERSION" | cut -d'+' -f1)

# Get version from api-backend package.json
API_VERSION_RAW=$(jq -r '.version' services/api-backend/package.json)
API_VERSION=$(echo "$API_VERSION_RAW" | cut -d'+' -f1)

echo "  assets/version.json: $ASSETS_VERSION"
echo "  pubspec.yaml:        $PUBSPEC_VERSION"
echo "  api-backend:         $API_VERSION_RAW (semantic: $API_VERSION)"

# Compare semantic parts
if [ "$SEMANTIC_ASSETS" != "$SEMANTIC_PUBSPEC" ]; then
    echo "âŒ ERROR: Semantic version mismatch between assets/version.json and pubspec.yaml"
    exit 1
fi

if [ "$SEMANTIC_ASSETS" != "$API_VERSION" ]; then
    echo "âŒ ERROR: Semantic version mismatch between assets/version.json and api-backend/package.json"
    exit 1
fi

echo "âœ… Version consistency verified"
