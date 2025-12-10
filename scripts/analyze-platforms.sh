#!/bin/bash
set -e

# Analyze which platforms need updates using Copilot AI
# Outputs: new_version, needs_cloud, needs_desktop, needs_mobile

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Analyzing Platform Changes with Copilot AI"
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

# Prepare prompt for Copilot
COMMITS_ESCAPED=$(echo "$COMMITS" | sed 's/"/\"/g' | tr '\n' ' ')
FILES_ESCAPED=$(echo "$CHANGED_FILES" | sed 's/"/\"/g' | tr '\n' ' ')

PROMPT="You are a semantic versioning and platform deployment expert. Analyze these changes and determine: 1) appropriate version bump, and 2) which platforms need deployment. Current version: $CURRENT_VERSION. Commits: $COMMITS_ESCAPED. Changed files: $FILES_ESCAPED. Version bump rules: BREAKING CHANGE means MAJOR (x.0.0). feat: means MINOR (0.x.0) ONLY if it adds significant NEW user-facing functionality to the Desktop or Mobile app. ALL other changes (backend improvements, infrastructure changes, provider swaps, enabling work, fixes, even if labeled feat) should be PATCH (0.0.x). Platform rules: Cloud platform needs update if changed files include: services/, k8s/, lib/, web/, .github/workflows/deploy-aks.yml. Desktop platform needs update if changed files include: lib/, pubspec.yaml (excluding web/). Mobile platform needs update if changed files include: lib/, pubspec.yaml (excluding web/). Respond with ONLY this exact JSON format: {\"bump_type\": \"major or minor or patch\", \"new_version\": \"x.y.z\", \"needs_cloud\": true or false, \"needs_desktop\": true or false, \"needs_mobile\": true or false, \"reasoning\": \"brief explanation\"}. No other text or formatting."

# Call Copilot
echo "Calling Copilot AI..."

# Using local Ollama, no API key needed
    set +e
    # Try to find copilot-cli in PATH or use local script
    if command -v copilot-cli >/dev/null 2>&1; then
        RESPONSE=$(copilot-cli "$PROMPT" 2>&1)
    else
        # Use local script path
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        RESPONSE=$("${SCRIPT_DIR}/copilot-cli.cjs" "$PROMPT" 2>&1)
    fi
    EXIT_CODE=$?
    set -e
    
    echo "DEBUG: Copilot exit code: $EXIT_CODE"
    echo "DEBUG: Copilot response length: ${#RESPONSE}"
    echo "DEBUG: Copilot response (first 1000 chars):"
    echo "${RESPONSE:0:1000}"
    echo ""
    
    if [ $EXIT_CODE -ne 0 ] || [ -z "$RESPONSE" ]; then
        echo "❌ ERROR: Copilot API call failed (exit code: $EXIT_CODE)"
        echo "Response: $RESPONSE"
        echo "Version bump REQUIRES successful Copilot analysis"
        exit 1
    fi
        # Extract JSON from response (Copilot returns JSON directly)
        JSON_RESPONSE="$RESPONSE"
        
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
            echo "❌ ERROR: Failed to parse Copilot response"
            echo "Extracted JSON: $JSON_RESPONSE"
            echo "Version bump REQUIRES valid Copilot analysis"
            exit 1
        fi
        
        echo "✅ Copilot Analysis:"
        echo "  New version: $NEW_VERSION"
        echo "  Cloud: $NEEDS_CLOUD"
        echo "  Desktop: $NEEDS_DESKTOP"
        echo "  Mobile: $NEEDS_MOBILE"
        echo "  Reasoning: $REASONING"

# Validate version format
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ ERROR: Invalid version format from Copilot: $NEW_VERSION"
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