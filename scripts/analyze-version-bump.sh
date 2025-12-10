#!/bin/bash
set -e
set -o pipefail

# Script to analyze commits and determine version bump using Copilot AI
# Outputs: new_version and bump_type to GITHUB_OUTPUT

# Enable error tracing
trap 'echo "Error on line $LINENO"' ERR

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Analyzing Commits with Copilot AI"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get current version
CURRENT_VERSION=$(jq -r '.version' assets/version.json)
echo "Current version: $CURRENT_VERSION"

# Get commits since last version tag
LAST_TAG=$(git describe --tags --abbrev=0 --match="*-cloud-*" 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
    # No previous tag, get all commits
    COMMITS=$(git log --oneline --no-merges -20)
else
    # Get commits since last tag
    COMMITS=$(git log --oneline --no-merges ${LAST_TAG}..HEAD)
fi

echo ""
echo "Commits to analyze:"
echo "$COMMITS"
echo ""

# Prepare prompt for Copilot (escape special characters for JSON)
COMMITS_ESCAPED=$(echo "$COMMITS" | sed 's/"/\"/g' | tr '\n' ' ')

PROMPT="You are a semantic versioning expert. Analyze these git commits and determine the appropriate version bump. Current version: $CURRENT_VERSION. Commits: $COMMITS_ESCAPED. Rules: BREAKING CHANGE or breaking: means MAJOR bump (x.0.0). feat: or feature: means MINOR bump (0.x.0) ONLY if it adds significant NEW user-facing functionality. Backend improvements, infrastructure changes, provider swaps (e.g., changing auth provider), enabling work, or fixes (even if labeled feat) should be PATCH (0.0.x) if they do not change the user experience. fix: or bugfix: means PATCH bump (0.0.x). chore:, docs:, style:, refactor:, test: means PATCH bump (0.0.x). If multiple types, use the highest priority (MAJOR > MINOR > PATCH). Respond with ONLY a JSON object with this exact format: {\"bump_type\": \"major or minor or patch\", \"new_version\": \"x.y.z\", \"reasoning\": \"brief explanation\"}. Do not include any other text, markdown, code blocks, or formatting. Only the raw JSON object."

# Call Gemini
echo "Calling Gemini AI to analyze commits..."

# Check for GEMINI_API_KEY
API_KEY="$GEMINI_API_KEY"

if [ -z "$API_KEY" ]; then
    echo "⚠️  GEMINI_API_KEY not set, falling back to patch bump"
    # Parse current version
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
    PATCH=$((PATCH + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
    BUMP_TYPE="patch"
else
    # Call Gemini and capture both stdout and stderr
    set +e  # Temporarily disable exit on error
    
    # Try to find gemini-cli in PATH or use local script
    if command -v gemini-cli >/dev/null 2>&1; then
        RESPONSE=$(gemini-cli "$PROMPT" 2>&1)
    else
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        RESPONSE=$("${SCRIPT_DIR}/gemini-cli.cjs" "$PROMPT" 2>&1)
    fi
    
    EXIT_CODE=$?
    set -e  # Re-enable exit on error
    
    echo "Gemini CLI exit code: $EXIT_CODE"
    echo "Gemini response (first 500 chars): ${RESPONSE:0:500}"
    
    if [ $EXIT_CODE -ne 0 ] || [ -z "$RESPONSE" ]; then
        echo "⚠️  Gemini CLI failed with exit code: $EXIT_CODE"
        echo "Falling back to patch bump"
        
        # Parse current version
        IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
        PATCH=$((PATCH + 1))
        NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
        BUMP_TYPE="patch"
        REASONING="Gemini call failed, defaulting to patch"
    else
        # Try to extract JSON from response (Gemini might add extra text)
        JSON_RESPONSE=$(echo "$RESPONSE" | grep -o '{.*}' | head -1 || echo "$RESPONSE")
        
        # Extract values from JSON response
        BUMP_TYPE=$(echo "$JSON_RESPONSE" | jq -r '.bump_type // "patch"' 2>/dev/null || echo "patch")
        NEW_VERSION=$(echo "$JSON_RESPONSE" | jq -r '.new_version // "'$CURRENT_VERSION'"' 2>/dev/null || echo "$CURRENT_VERSION")
        REASONING=$(echo "$JSON_RESPONSE" | jq -r '.reasoning // "Auto-generated"' 2>/dev/null || echo "Auto-generated")
        
        echo ""
        echo "✅ Gemini Analysis:"
        echo "  Bump type: $BUMP_TYPE"
        echo "  New version: $NEW_VERSION"
        echo "  Reasoning: $REASONING"
    fi
fi

# Validate and fallback if Gemini gave invalid version
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "⚠️  Invalid version from Gemini: $NEW_VERSION"
    echo "Calculating fallback..."
    
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
    
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
        *)
            PATCH=$((PATCH + 1))
            ;;
    esac
    
    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
fi

echo ""
echo "✅ Version Decision:"
echo "  Current: $CURRENT_VERSION"
echo "  New:     $NEW_VERSION"
echo "  Type:    $BUMP_TYPE"

# Output for GitHub Actions
echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT
echo "bump_type=$BUMP_TYPE" >> $GITHUB_OUTPUT
echo "current_version=$CURRENT_VERSION" >> $GITHUB_OUTPUT