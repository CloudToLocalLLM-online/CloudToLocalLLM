#!/bin/bash
set -e
# Load nvm if available
[ -s "/home/rightguy/.nvm/nvm.sh" ] && source "/home/rightguy/.nvm/nvm.sh"

# Analyze which platforms need updates using Gemini AI
# Outputs: new_version, needs_managed, needs_local, needs_desktop, needs_mobile

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Analyzing Platform Changes with Gemini AI"
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
if echo "$CHANGED_FILES" | grep -qE "(web/|lib/.*auth|lib/.*router|lib/config/|services/|k8s/|\.github/workflows/deploy-aks\.yml)"; then
    FORCE_CLOUD=true
    echo "🌐 DETECTED WEB-RELATED CHANGES - Cloud deployment will be forced"
fi

# Prepare prompt for Gemini - properly escape for JSON
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
  \"needs_managed\": true,
  \"needs_local\": true,
  \"needs_desktop\": true,
  \"needs_mobile\": false,
  \"reasoning\": \"Conservative deployment for debugging changes\"
}

CRITICAL RULES FOR VERSION BUMPING:
- DEFAULT: bump_type=none, semantic_version=$SEMANTIC_VERSION (NEVER increment for internal changes)
- DEBUGGING/FIXES/CI/SECURITY: Always bump_type=none (keep same semantic version)
- PATCH: ONLY for user-visible bug fixes that users will notice
- MINOR: ONLY for new user-facing features that users will see
- MAJOR: ONLY for breaking user experience changes
- Internal changes, CI fixes, security patches, debugging = NO VERSION BUMP

DEPLOYMENT RULES:
- CORE CHANGES (main.dart, lib/services/, lib/models/) trigger ALL platforms
- PLATFORM-SPECIFIC (web/, windows/, android/) trigger only that platform
- Managed (SaaS): web/, services/ (including package-lock.json/dependencies), k8s/, auth changes (production cloud)
- Local (On-Prem): web/, services/ (including package-lock.json/dependencies), k8s/, auth changes (docker desktop/local)
- Desktop: windows/, linux/, desktop code
- Mobile: android/, ios/, mobile code"

echo "DEBUG: Gemini prompt includes version requirement: 'The new version MUST be higher than $CURRENT_VERSION'"

# Helper: Use provided Gemini API Key or env var
export GEMINI_API_KEY="${GEMINI_API_KEY}"
MODEL="gemini-3-flash" 

# Get response from Gemini
echo "DEBUG: Sending request to Gemini AI (model: $MODEL)..."
set +e
# Try to find gemini-cli in PATH or use local script
if command -v gemini-cli >/dev/null 2>&1; then
    RESPONSE=$(gemini-cli "$PROMPT" 2>&1)
    EXIT_CODE=$?
else
    # Use local script path
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    RESPONSE=$("${SCRIPT_DIR}/gemini-cli.cjs" "$PROMPT" 2>&1)
    EXIT_CODE=$?
fi
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ ERROR: Gemini analysis failed"
    echo "$RESPONSE"
    exit 1
fi

echo "DEBUG: Gemini response length: ${#RESPONSE}"
echo "DEBUG: Gemini response (first 1000 chars):"
echo "${RESPONSE:0:1000}"

# Extract JSON from response (Gemini returns JSON directly)
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
        NEEDS_MANAGED=$(echo "$JSON_RESPONSE" | jq -r '.needs_managed')
        NEEDS_LOCAL=$(echo "$JSON_RESPONSE" | jq -r '.needs_local')
        NEEDS_DESKTOP=$(echo "$JSON_RESPONSE" | jq -r '.needs_desktop')
        NEEDS_MOBILE=$(echo "$JSON_RESPONSE" | jq -r '.needs_mobile')
        REASONING=$(echo "$JSON_RESPONSE" | jq -r '.reasoning')

        # Build final version with build metadata
        NEW_VERSION="${SEMANTIC_VERSION_NEW}+${BUILD_DATE}"

        # Strict validation - Fail if mandatory fields are null or empty
        # Note: 'false' is a valid value for NEEDS_MANAGED, so we check for 'null' or empty
        if [ "$SEMANTIC_VERSION_NEW" == "null" ] || [ -z "$SEMANTIC_VERSION_NEW" ] || [ "$NEEDS_MANAGED" == "null" ] || [ -z "$NEEDS_MANAGED" ]; then
            echo "❌ ERROR: Failed to parse Gemini response"
            echo "Extracted JSON: $JSON_RESPONSE"
            echo "Response (first 500 chars): ${RESPONSE:0:500}"
            echo "Version analysis REQUIRES valid Gemini response"
            exit 1
        fi

        echo "✅ Gemini Analysis:"
        echo "  Bump type: $BUMP_TYPE"
        echo "  New version: $NEW_VERSION"
        echo "  Managed: $NEEDS_MANAGED"
        echo "  Local: $NEEDS_LOCAL"
        echo "  Desktop: $NEEDS_DESKTOP"
        echo "  Mobile: $NEEDS_MOBILE"
        echo "  Reasoning: $REASONING"

        # Override cloud deployment if web-related files changed
        if [ "$FORCE_CLOUD" = "true" ]; then
            if [ "$NEEDS_MANAGED" = "false" ]; then
                echo "🔧 OVERRIDING: AI incorrectly set needs_managed=false for web changes"
                NEEDS_MANAGED="true"
            fi
            if [ "$NEEDS_LOCAL" = "false" ]; then
                echo "🔧 OVERRIDING: AI incorrectly set needs_local=false for web changes"
                NEEDS_LOCAL="true"
            fi
            REASONING="$REASONING (OVERRIDE: Web-related files require backend deployment)"
        fi

# Validate version format (allow build metadata)
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$'; then
    echo "❌ ERROR: Invalid version format: $NEW_VERSION"
    echo "Expected format: x.y.z or x.y.z+builddate (e.g., 4.5.0 or 4.5.0+202412151409)"
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
echo "  Managed: $NEEDS_MANAGED"
echo "  Local: $NEEDS_LOCAL"
echo "  Desktop: $NEEDS_DESKTOP"
echo "  Mobile: $NEEDS_MOBILE"

# Output for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "new_version=$NEW_VERSION" >> $GITHUB_OUTPUT
    echo "needs_managed=$NEEDS_MANAGED" >> $GITHUB_OUTPUT
    echo "needs_local=$NEEDS_LOCAL" >> $GITHUB_OUTPUT
    echo "needs_desktop=$NEEDS_DESKTOP" >> $GITHUB_OUTPUT
    echo "needs_mobile=$NEEDS_MOBILE" >> $GITHUB_OUTPUT
    echo "bump_type=$BUMP_TYPE" >> $GITHUB_OUTPUT
else
    echo "Running locally - GITHUB_OUTPUT not set"
    echo "new_version=$NEW_VERSION"
    echo "needs_managed=$NEEDS_MANAGED"
    echo "needs_local=$NEEDS_LOCAL"
    echo "needs_desktop=$NEEDS_DESKTOP"
    echo "needs_mobile=$NEEDS_MOBILE"
    echo "bump_type=$BUMP_TYPE"
fi