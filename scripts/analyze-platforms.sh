#!/bin/bash
set -e
# Load nvm if available
[ -s "/home/rightguy/.nvm/nvm.sh" ] && source "/home/rightguy/.nvm/nvm.sh"

# Analyze which platforms need updates using Kilocode AI
# Outputs: new_version, needs_cloud, needs_desktop, needs_mobile

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Analyzing Platform Changes with Kilocode AI"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get current version
CURRENT_VERSION=$(jq -r '.version' assets/version.json)
echo "Current version: $CURRENT_VERSION"

# Get recent commits
COMMITS=$(git log --oneline --no-merges -10)
echo ""
echo "Recent commits:"
echo "$COMMITS"
echo ""

# Get changed files
CHANGED_FILES=$(git diff --name-only HEAD~5..HEAD 2>/dev/null || git log --name-only --oneline -5 | grep -v "^[a-f0-9]" || echo "")
echo "Changed files (last 5 commits):"
echo "$CHANGED_FILES"
echo ""

# Prepare prompt for Kilocode
COMMITS_ESCAPED=$(echo "$COMMITS" | sed 's/"/\"/g' | tr '\n' ' ')
FILES_ESCAPED=$(echo "$CHANGED_FILES" | sed 's/"/\"/g' | tr '\n' ' ')

PROMPT="ACT AS A JSON GENERATOR. Analyze changes. Current: $CURRENT_VERSION. Commits: $COMMITS_ESCAPED. Files: $FILES_ESCAPED. Rules: BREAKING=MAJOR(x.0.0), Feat=MINOR(0.x.0), Fix=PATCH(0.0.x). Cloud triggers: services/k8s/web/lib. OUTPUT STRICT JSON ONLY. NO MARKDOWN. NO TEXT. START WITH { END WITH }. Format: {\"bump_type\": \"major/minor/patch\", \"new_version\": \"x.y.z\", \"needs_cloud\": bool, \"needs_desktop\": bool, \"needs_mobile\": bool, \"reasoning\": \"txt\"}."

echo "DEBUG: Kilocode prompt includes version requirement: 'The new version MUST be higher than $CURRENT_VERSION'"

# Get response from Kilocode
set +e
# Try to find kilocode-cli in PATH or use local script
if command -v kilocode-cli >/dev/null 2>&1; then
    RESPONSE=$(kilocode-cli "$PROMPT" 2>&1)
    EXIT_CODE=$?
else
    # Use local script path
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    RESPONSE=$("${SCRIPT_DIR}/kilocode-cli.cjs" "$PROMPT" 2>&1)
    EXIT_CODE=$?
fi
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ ERROR: Kilocode analysis failed"
    echo "$RESPONSE"
    exit 1
fi

echo "DEBUG: Kilocode response length: ${#RESPONSE}"
echo "DEBUG: Kilocode response (first 1000 chars):"
echo "${RESPONSE:0:1000}"

# Extract JSON from response (Kilocode returns JSON directly)
# Flatten response to single line and remove non-JSON text
ONE_LINE=$(echo "$RESPONSE" | tr '\n' ' ' | sed 's/```json//g' | sed 's/```//g')
# Extract content between first { and last }
JSON_RESPONSE=$(echo "$ONE_LINE" | sed 's/^[^\{]*//' | sed 's/[^\}]*$//')

# Fix specific hallucination of double closing quotes (common issue)
JSON_RESPONSE=$(echo "$JSON_RESPONSE" | sed 's/""}/"}/g')

# Basic repair for truncated JSON (missing closing brace)
if [[ "$JSON_RESPONSE" != *"}" ]]; then
    echo "DEBUG: JSON appears truncated, appending closing brace"
    JSON_RESPONSE="${JSON_RESPONSE}}"
fi        
echo "DEBUG: Extracted JSON:"
echo "$JSON_RESPONSE"
echo ""

        # Parse with fallbacks
        NEW_VERSION=$(echo "$JSON_RESPONSE" | jq -r '.new_version // empty' 2>/dev/null || echo "")
        NEEDS_CLOUD=$(echo "$JSON_RESPONSE" | jq -r '.needs_cloud // empty' 2>/dev/null || echo "")
        NEEDS_DESKTOP=$(echo "$JSON_RESPONSE" | jq -r '.needs_desktop // empty' 2>/dev/null || echo "")
        NEEDS_MOBILE=$(echo "$JSON_RESPONSE" | jq -r '.needs_mobile // empty' 2>/dev/null || echo "")
        REASONING=$(echo "$JSON_RESPONSE" | jq -r '.reasoning // empty' 2>/dev/null || echo "")

        # Strict validation - Fail if parsing fails
        if [ -z "$NEW_VERSION" ] || [ -z "$NEEDS_CLOUD" ]; then
            echo "❌ ERROR: Failed to parse Kilocode response"
            echo "Extracted JSON: $JSON_RESPONSE"
            echo "Response (first 500 chars): ${RESPONSE:0:500}"
            echo "Version bump REQUIRES valid Kilocode analysis"
            exit 1
        fi

        echo "✅ Kilocode Analysis:"
        echo "  New version: $NEW_VERSION"
        echo "  Cloud: $NEEDS_CLOUD"
        echo "  Desktop: $NEEDS_DESKTOP"
        echo "  Mobile: $NEEDS_MOBILE"
        echo "  Reasoning: $REASONING"

# Validate version format
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ ERROR: Invalid version format from Kilocode: $NEW_VERSION"
    echo "Expected format: x.y.z (e.g., 4.5.0)"
    exit 1
fi

# Validate version is higher than current version
echo "DEBUG: Validating version increment: $CURRENT_VERSION → $NEW_VERSION"

# Function to compare semantic versions
version_compare() {
    local v1=$1
    local v2=$2

    # Extract version components using cut (safer than IFS manipulation)
    local MAJOR1=$(echo "$v1" | cut -d. -f1)
    local MINOR1=$(echo "$v1" | cut -d. -f2)
    local PATCH1=$(echo "$v1" | cut -d. -f3)
    local MAJOR2=$(echo "$v2" | cut -d. -f1)
    local MINOR2=$(echo "$v2" | cut -d. -f2)
    local PATCH2=$(echo "$v2" | cut -d. -f3)

    # Compare major version
    if [ "$MAJOR1" -gt "$MAJOR2" ]; then
        return 1  # v1 > v2
    elif [ "$MAJOR1" -lt "$MAJOR2" ]; then
        return 2  # v1 < v2
    fi

    # Compare minor version
    if [ "$MINOR1" -gt "$MINOR2" ]; then
        return 1  # v1 > v2
    elif [ "$MINOR1" -lt "$MINOR2" ]; then
        return 2  # v1 < v2
    fi

    # Compare patch version
    if [ "$PATCH1" -gt "$PATCH2" ]; then
        return 1  # v1 > v2
    elif [ "$PATCH1" -lt "$PATCH2" ]; then
        return 2  # v1 < v2
    fi

    return 0  # v1 == v2
}

version_compare "$NEW_VERSION" "$CURRENT_VERSION"
COMPARE_RESULT=$?

if [ $COMPARE_RESULT -eq 2 ]; then
    echo "❌ ERROR: New version ($NEW_VERSION) is NOT higher than current version ($CURRENT_VERSION)"
    echo "Kilocode AI violated the requirement: 'The new version MUST be higher than $CURRENT_VERSION'"
    echo "This indicates the AI prompt needs further refinement or the AI model has limitations"
    exit 1
elif [ $COMPARE_RESULT -eq 0 ]; then
    echo "❌ ERROR: New version ($NEW_VERSION) is the SAME as current version ($CURRENT_VERSION)"
    echo "Versions must always increase - this is a violation of semantic versioning"
    exit 1
else
    echo "✅ Version validation passed: $CURRENT_VERSION → $NEW_VERSION"
fi

echo ""
echo "✅ Final Decision:"
echo "  Version: $CURRENT_VERSION → $NEW_VERSION"
echo "  Cloud: $NEEDS_CLOUD"
echo "  Desktop: $NEEDS_DESKTOP"
echo "  Mobile: $NEEDS_MOBILE"

# Output for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT
    echo "needs_cloud=$NEEDS_CLOUD" >> $GITHUB_OUTPUT
    echo "needs_desktop=$NEEDS_DESKTOP" >> $GITHUB_OUTPUT
    echo "needs_mobile=$NEEDS_MOBILE" >> $GITHUB_OUTPUT
else
    echo "Running locally - GITHUB_OUTPUT not set"
    echo "new_version=$NEW_VERSION"
    echo "needs_cloud=$NEEDS_CLOUD"
    echo "needs_desktop=$NEEDS_DESKTOP"
    echo "needs_mobile=$NEEDS_MOBILE"
fi