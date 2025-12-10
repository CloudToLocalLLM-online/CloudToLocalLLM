#!/bin/bash

# Setup script for Gemini CLI
# Configures the API key and verifies the installation

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Gemini CLI Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if API key is provided as argument
if [ -n "$1" ]; then
    API_KEY="$1"
else
    # Prompt for API key
    echo "Please enter your Google Cloud API Key for Gemini:"
    read -s API_KEY
fi

if [ -z "$API_KEY" ]; then
    echo "❌ Error: API Key cannot be empty."
    exit 1
fi

# Export the key for the current session
export GEMINI_API_KEY="$API_KEY"
echo ""
echo "✅ API Key configured for this session."

# Verify the key
echo "Verifying API key with a test request..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESPONSE=$("${SCRIPT_DIR}/gemini-cli.cjs" "Hello, are you working?" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ] && [ -n "$TEST_RESPONSE" ]; then
    echo "✅ Verification successful!"
    echo "Response from Gemini: ${TEST_RESPONSE:0:100}..."
    
    echo ""
    echo "To persist this key, add the following to your shell profile (e.g., ~/.bashrc or ~/.zshrc):"
    echo "export GEMINI_API_KEY='$API_KEY'"
    
    echo ""
    echo "For GitHub Actions, add a secret named GEMINI_API_KEY:"
    echo "gh secret set GEMINI_API_KEY --body '$API_KEY'"
else
    echo "❌ Verification failed."
    echo "Exit code: $EXIT_CODE"
    echo "Response: $TEST_RESPONSE"
    exit 1
fi
