#!/bin/bash
set -e

# Script to analyze commits and determine version bump using Gemini AI
# Outputs: new_version and bump_type to GITHUB_OUTPUT

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Analyzing Commits with Gemini AI"
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

# Prepare prompt for Gemini
PROMPT="You are a semantic versioning expert. Analyze these git commits and determine the appropriate version bump.

Current version: $CURRENT_VERSION

Commits:
$COMMITS

Rules:
- BREAKING CHANGE or breaking: → MAJOR bump (x.0.0)
- feat: or feature: → MINOR bump (0.x.0)
- fix: or bugfix: → PATCH bump (0.0.x)
- chore:, docs:, style:, refactor:, test: → PATCH bump (0.0.x)
- If multiple types, use the highest priority (MAJOR > MINOR > PATCH)

Respond with ONLY a JSON object:
{
  \"bump_type\": \"major|minor|patch\",
  \"new_version\": \"x.y.z\",
  \"reasoning\": \"brief explanation\"
}

Do not include any other text, markdown, or formatting. Only the JSON object."

# Call Gemini
echo "Calling Gemini AI to analyze commits..."

if [ -z "$GEMINI_API_KEY" ]; then
    echo "⚠️  GEMINI_API_KEY not set, falling back to patch bump"
    # Parse current version
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
    PATCH=$((PATCH + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
    BUMP_TYPE="patch"
else
    RESPONSE=$(gemini-cli "$PROMPT" 2>/dev/null || echo '{"bump_type":"patch","new_version":"'$CURRENT_VERSION'","reasoning":"Gemini call failed, defaulting to patch"}')
    
    # Extract values from JSON response
    BUMP_TYPE=$(echo "$RESPONSE" | jq -r '.bump_type // "patch"')
    NEW_VERSION=$(echo "$RESPONSE" | jq -r '.new_version // "'$CURRENT_VERSION'"')
    REASONING=$(echo "$RESPONSE" | jq -r '.reasoning // "Auto-generated"')
    
    echo ""
    echo "Gemini Analysis:"
    echo "  Bump type: $BUMP_TYPE"
    echo "  New version: $NEW_VERSION"
    echo "  Reasoning: $REASONING"
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

