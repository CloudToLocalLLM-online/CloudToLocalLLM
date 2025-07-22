#!/bin/bash

# Container Tunnel Integration Test Runner
# Tests that containers can communicate through the simplified tunnel proxy

set -e

echo "🧪 CloudToLocalLLM Container Tunnel Integration Tests"
echo "===================================================="

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is required to run integration tests"
    exit 1
fi

# Set default environment variables if not provided
export TEST_USER_ID="${TEST_USER_ID:-test-user-123}"
export API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"
export CONTAINER_HEALTH_URL="${CONTAINER_HEALTH_URL:-http://localhost:8081}"

echo "Configuration:"
echo "  Test User ID: $TEST_USER_ID"
echo "  API Base URL: $API_BASE_URL"
echo "  Container Health URL: $CONTAINER_HEALTH_URL"
echo ""

# Run the integration tests
echo "Starting integration tests..."
node "$(dirname "$0")/test-container-tunnel-integration.js"

echo ""
echo "✅ Container tunnel integration tests completed successfully!"