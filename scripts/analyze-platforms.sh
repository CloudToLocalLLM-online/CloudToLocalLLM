#!/bin/bash
set -e

# Analyze which platforms need updates using Kilo Code AI
# Outputs: new_version, needs_cloud, needs_desktop, needs_mobile

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Analyzing Platform Changes with Kilo Code AI"
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

# Prepare prompt for Kilo Code
COMMITS_ESCAPED=$(echo "$COMMITS" | sed 's/"/\\"/g' | tr '\n' ' ')
FILES_ESCAPED=$(echo "$CHANGED_FILES" | sed 's/"/\\"/g' | tr '\n' ' ')

PROMPT="You are a semantic versioning and platform deployment expert. Analyze these changes and determine: 1) appropriate version bump, and 2) which platforms need deployment. Current version: $CURRENT_VERSION. Commits: $COMMITS_ESCAPED. Changed files: $FILES_ESCAPED. Version bump rules: BREAKING CHANGE means MAJOR (x.0.0). feat: means MINOR (0.x.0) ONLY if it adds significant NEW user-facing functionality to the Desktop or Mobile app. Backend improvements, infrastructure changes, provider swaps (e.g., changing auth provider), enabling work, or fixes (even if labeled feat) should be PATCH (0.0.x) if they do not change the user experience. fix: means PATCH (0.0.x). Platform rules: Cloud platform needs update if changed files include: services/, k8s/, lib/, web/, .github/workflows/deploy-aks.yml. Desktop platform needs update if changed files include: lib/, pubspec.yaml (excluding web/). Mobile platform needs update if changed files include: lib/, pubspec.yaml (excluding web/). Respond with ONLY this exact JSON format: {\"bump_type\": \"major or minor or patch\", \"new_version\": \"x.y.z\", \"needs_cloud\": true or false, \"needs_desktop\": true or false, \"needs_mobile\": true or false, \"reasoning\": \"brief explanation\"}. No other text or formatting."

# Call Kilo Code
echo "Calling Kilo Code AI..."

# Check for KILOCODE_API_KEY, fallback to GEMINI_API_KEY for migration
API_KEY="${KILOCODE_API_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbnYiOiJwcm9kdWN0aW9uIiwia2lsb1VzZXJJZCI6Im9hdXRoL2dvb2dsZToxMDI1MDk0MzM1MzEzNDE1NDI1NTAiLCJhcGlUb2tlblBlcHBlciI6bnVsbCwidmVyc2lvbiI6MywiaWF0IjoxNzY1MzMwMDc0LCJleHAiOjE5MjMxMTgwNzR9.-aKR0OtweBGAP0Qe25qgM2csVqrF4zSBbUxbs8dxshg}"

if [ -z "$API_KEY" ]; then
    echo "❌ ERROR: KILOCODE_API_KEY not set"
    echo "Version bump REQUIRES Kilo Code AI analysis"
    echo "Add the secret: gh secret set KILOCODE_API_KEY"
    exit 1
fi
    set +e
    # Try to find kilocode-cli in PATH or use local script
    if command -v kilocode-cli >/dev/null 2>&1; then
        RESPONSE=$(kilocode-cli "$PROMPT" 2>&1)
    else
        # Use local script path
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        RESPONSE=$("${SCRIPT_DIR}/kilocode-cli.cjs" "$PROMPT" 2>&1)
    fi
    EXIT_CODE=$?
    set -e
    
    echo "DEBUG: Kilo Code exit code: $EXIT_CODE"
    echo "DEBUG: Kilo Code response length: ${#RESPONSE}"
    echo "DEBUG: Kilo Code response (first 1000 chars):"
    echo "${RESPONSE:0:1000}"
    echo ""
    
    if [ $EXIT_CODE -ne 0 ] || [ -z "$RESPONSE" ]; then
        echo "❌ ERROR: Kilo Code API call failed (exit code: $EXIT_CODE)"
        echo "Response: $RESPONSE"
        echo "Version bump REQUIRES successful Kilo Code analysis"
        exit 1
    fi
        # Extract JSON from response (Kilo Code wraps in ```json ``` blocks)
        # Remove markdown code blocks and extract multi-line JSON
        JSON_RESPONSE=$(echo "$RESPONSE" | sed '/```json/,/```/!d' | sed '/```/d' | tr -d '\n' | sed 's/  */ /g')
        
        # If that didn't work, try simpler extraction
        if [ -z "$JSON_RESPONSE" ] || ! echo "$JSON_RESPONSE" | jq . >/dev/null 2>&1; then
            # Try to extract anything between first { and last }
            JSON_RESPONSE=$(echo "$RESPONSE" | tr '\n' ' ' | sed 's/.*{\(.*\)}.*/{\1}/')
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
        
        # If parsing failed, EXIT - no fallback
        if [ -z "$NEW_VERSION" ] || [ -z "$NEEDS_CLOUD" ]; then
            echo "❌ ERROR: Failed to parse Kilo Code response"
            echo "Extracted JSON: $JSON_RESPONSE"
            echo "Version bump REQUIRES valid Kilo Code analysis"
            exit 1
        fi
        
        echo "✅ Kilo Code Analysis:"
        echo "  New version: $NEW_VERSION"
        echo "  Cloud: $NEEDS_CLOUD"
        echo "  Desktop: $NEEDS_DESKTOP"
        echo "  Mobile: $NEEDS_MOBILE"
        echo "  Reasoning: $REASONING"

# Validate version format
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ ERROR: Invalid version format from Kilo Code: $NEW_VERSION"
    echo "Expected format: x.y.z (e.g., 4.5.0)"
    exit 1
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
