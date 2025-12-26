#!/bin/bash

# Setup script for Copilot CLI
# Configures the API key and verifies the installation

set -e

echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo "Copilot CLI Setup"
echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"

# Check if API key is provided as argument
if [ -n "$1" ]; then
    API_KEY="$1"
else
    # Prompt for API key
    echo "Using local Ollama, no API key needed"
    read -s API_KEY
fi

if [ -z "$API_KEY" ]; then
    echo "âŒ Error: API Key cannot be empty."
    exit 1
fi

# Export the key for the current session
export OLLAMA_HOST="http://localhost:11434"
echo ""
echo "âœ… API Key configured for this session."

# Verify the key
echo "Verifying API key with a test request..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESPONSE=$("${SCRIPT_DIR}/copilot-cli.cjs" "Hello, are you working?" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ] && [ -n "$TEST_RESPONSE" ]; then
    echo "âœ… Verification successful!"
    echo "Response from Ollama: ${TEST_RESPONSE:0:100}..."
    
    echo ""
    echo "To persist this key, add the following to your shell profile (e.g., ~/.bashrc or ~/.zshrc):"
    echo "export OLLAMA_HOST='http://localhost:11434'"
    
    echo ""
    echo "No secret needed for local Ollama"
else
    echo "âŒ Verification failed."
    echo "Exit code: $EXIT_CODE"
    echo "Response: $TEST_RESPONSE"
    exit 1
fi
