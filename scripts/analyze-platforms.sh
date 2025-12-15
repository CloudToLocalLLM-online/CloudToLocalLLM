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

# Get recent commits (limit to 3 for faster processing)
COMMITS=$(git log --oneline --no-merges -3)
echo ""
echo "Recent commits:"
echo "$COMMITS"
echo ""

# Get changed files
CHANGED_FILES=$(git diff --name-only HEAD~5..HEAD 2>/dev/null || git log --name-only --oneline -5 | grep -v "^[a-f0-9]" || echo "")
echo "Changed files (last 5 commits):"
echo "$CHANGED_FILES"
echo ""

# Pre-analyze files to force cloud deployment for web-related changes
FORCE_CLOUD=false
if echo "$CHANGED_FILES" | grep -qE "(web/|lib/.*auth|lib/.*router|lib/config/|services/|k8s/|auth0-bridge|\.github/workflows/deploy-aks\.yml)"; then
    FORCE_CLOUD=true
    echo "🌐 DETECTED WEB-RELATED CHANGES - Cloud deployment will be forced"
fi

# Prepare prompt for Kilocode - properly escape for JSON
COMMITS_ESCAPED=$(echo "$COMMITS" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g' | tr '\n' ' ')
FILES_ESCAPED=$(echo "$CHANGED_FILES" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g' | tr '\n' ' ')

# Get current semantic version (without build metadata)
SEMANTIC_VERSION=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
BUILD_DATE=$(date +%Y%m%d%H%M)

PROMPT="Current version: $CURRENT_VERSION
Semantic version: $SEMANTIC_VERSION
Recent commits: $COMMITS_ESCAPED
Changed files: $FILES_ESCAPED

Analyze changes and determine deployment needs. Output ONLY valid JSON:

{
  \"bump_type\": \"none\",
  \"semantic_version\": \"$SEMANTIC_VERSION\",
  \"needs_cloud\": true,
  \"needs_desktop\": true,
  \"needs_mobile\": false,
  \"reasoning\": \"Conservative deployment for debugging changes\"
}

RULES:
- DEFAULT: bump_type=none, semantic_version=$SEMANTIC_VERSION (no version increment for debugging)
- PATCH: Only for user-visible bug fixes
- MINOR: Only for new user-facing features  
- MAJOR: Only for breaking user experience changes
- CORE CHANGES (main.dart, lib/services/, lib/models/) trigger ALL platforms
- PLATFORM-SPECIFIC (web/, windows/, android/) trigger only that platform
- Cloud: web/, services/, k8s/, auth changes
- Desktop: windows/, linux/, desktop code
- Mobile: android/, ios/, mobile code"

echo "DEBUG: Kilocode prompt includes version requirement: 'The new version MUST be higher than $CURRENT_VERSION'"

# Helper: Use provided Gemini API Key or env var
export GEMINI_API_KEY="${GEMINI_API_KEY:-AIzaSyBKEd9x72rgm_DyRQK4DkT-fWT-R3H1miE}"
MODEL="gemini-2.0-flash"

# Get response from Kilocode
echo "DEBUG: Sending request to Kilocode AI (model: $MODEL)..."
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
# Extract content between first { and last }
# Improved logic: Match from first { to last }, handling potential missing last } slightly better by NOT deleting everything if } is missing
JSON_RESPONSE=$(echo "$ONE_LINE" | sed 's/^[^\{]*//' | sed 's/}[^}]*$/}/')

# Basic repair for truncated JSON (missing closing brace)
if [[ "$JSON_RESPONSE" != *"}" ]]; then
    echo "DEBUG: JSON appears truncated, appending closing brace"
    JSON_RESPONSE="${JSON_RESPONSE}}"
fi        
echo "DEBUG: Extracted JSON:"
echo "$JSON_RESPONSE"
echo ""

        # Parse without fallback to empty, so we capture 'false' correctly
        SEMANTIC_VERSION_NEW=$(echo "$JSON_RESPONSE" | jq -r '.semantic_version')
        BUMP_TYPE=$(echo "$JSON_RESPONSE" | jq -r '.bump_type')
        NEEDS_CLOUD=$(echo "$JSON_RESPONSE" | jq -r '.needs_cloud')
        NEEDS_DESKTOP=$(echo "$JSON_RESPONSE" | jq -r '.needs_desktop')
        NEEDS_MOBILE=$(echo "$JSON_RESPONSE" | jq -r '.needs_mobile')
        REASONING=$(echo "$JSON_RESPONSE" | jq -r '.reasoning')

        # Build final version with build metadata
        NEW_VERSION="${SEMANTIC_VERSION_NEW}+${BUILD_DATE}"

        # Strict validation - Fail if mandatory fields are null or empty
        # Note: 'false' is a valid value for NEEDS_CLOUD, so we check for 'null' or empty
        if [ "$SEMANTIC_VERSION_NEW" == "null" ] || [ -z "$SEMANTIC_VERSION_NEW" ] || [ "$NEEDS_CLOUD" == "null" ] || [ -z "$NEEDS_CLOUD" ]; then
            echo "❌ ERROR: Failed to parse Kilocode response"
            echo "Extracted JSON: $JSON_RESPONSE"
            echo "Response (first 500 chars): ${RESPONSE:0:500}"
            echo "Version analysis REQUIRES valid Kilocode response"
            exit 1
        fi

        echo "✅ Kilocode Analysis:"
        echo "  Bump type: $BUMP_TYPE"
        echo "  New version: $NEW_VERSION"
        echo "  Cloud: $NEEDS_CLOUD"
        echo "  Desktop: $NEEDS_DESKTOP"
        echo "  Mobile: $NEEDS_MOBILE"
        echo "  Reasoning: $REASONING"

        # Override cloud deployment if web-related files changed
        if [ "$FORCE_CLOUD" = "true" ] && [ "$NEEDS_CLOUD" = "false" ]; then
            echo "🔧 OVERRIDING: AI incorrectly set needs_cloud=false for web changes"
            echo "   Web-related files detected, forcing needs_cloud=true"
            NEEDS_CLOUD="true"
            REASONING="$REASONING (OVERRIDE: Web-related files require cloud deployment)"
        fi

# Validate version format
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ ERROR: Invalid version format from Kilocode: $NEW_VERSION"
    echo "Expected format: x.y.z (e.g., 4.5.0)"
    exit 1
fi

# Validate version logic
echo "DEBUG: Validating version logic: $CURRENT_VERSION → $NEW_VERSION (bump: $BUMP_TYPE)"
echo "DEBUG: Semantic versions: $SEMANTIC_VERSION → $SEMANTIC_VERSION_NEW"

if [ "$BUMP_TYPE" = "none" ]; then
    if [ "$SEMANTIC_VERSION_NEW" != "$SEMANTIC_VERSION" ]; then
        echo "❌ ERROR: bump_type='none' but semantic version changed from $SEMANTIC_VERSION to $SEMANTIC_VERSION_NEW"
        exit 1
    fi
    echo "✅ No semantic version bump (debugging/fixes) - keeping $SEMANTIC_VERSION, updating build metadata"
else
    # Function to compare semantic versions (without build metadata)
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

    set +e
    version_compare "$SEMANTIC_VERSION_NEW" "$SEMANTIC_VERSION"
    COMPARE_RESULT=$?
    set -e

    if [ $COMPARE_RESULT -eq 2 ]; then
        echo "❌ ERROR: New semantic version ($SEMANTIC_VERSION_NEW) is NOT higher than current ($SEMANTIC_VERSION)"
        echo "For version bumps, new semantic version must be higher than current"
        exit 1
    elif [ $COMPARE_RESULT -eq 0 ]; then
        echo "❌ ERROR: New semantic version ($SEMANTIC_VERSION_NEW) is the SAME as current ($SEMANTIC_VERSION)"
        echo "Use bump_type='none' for no semantic version change, or increment for releases"
        exit 1
    else
        echo "✅ Semantic version validation passed: $SEMANTIC_VERSION → $SEMANTIC_VERSION_NEW"
    fi
fi

echo "✅ Final version: $NEW_VERSION (semantic: $SEMANTIC_VERSION_NEW, build: $BUILD_DATE)"

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