#!/bin/bash

# CloudToLocalLLM Deployment Verification Script
# Performs comprehensive post-deployment health checks and validations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_URL="https://localhost"
API_URL="https://localhost"
EXTERNAL_URL="https://app.cloudtolocalllm.online"
TIMEOUT=30
STRICT_MODE=false

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --strict)
            STRICT_MODE=true
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--strict] [--timeout SECONDS] [--help]"
            echo "  --strict    Treat warnings as failures"
            echo "  --timeout   HTTP request timeout in seconds (default: 30)"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Test results tracking
declare -A test_results
test_count=0
passed_count=0
warning_count=0

# Helper function to record test result
record_test() {
    local test_name="$1"
    local result="$2"  # "pass", "fail", "warning"
    
    test_results["$test_name"]="$result"
    ((test_count++))
    
    case "$result" in
        "pass")
            ((passed_count++))
            print_success "✅ $test_name"
            ;;
        "warning")
            ((warning_count++))
            print_warning "⚠️ $test_name"
            ;;
        "fail")
            print_error "❌ $test_name"
            ;;
    esac
}

# Test 1: Basic connectivity
test_basic_connectivity() {
    print_status "Testing basic connectivity to $APP_URL..."

    # Use curl with built-in timeouts and allow insecure connections for localhost
    if curl -s -f -k --connect-timeout 10 --max-time "$TIMEOUT" "$APP_URL" > /dev/null 2>&1; then
        record_test "Basic Connectivity" "pass"
    else
        record_test "Basic Connectivity" "fail"
    fi
}

# Test 2: Version endpoint
test_version_endpoint() {
    print_status "Testing version endpoint..."

    local version_url="$APP_URL/version.json"
    local response

    if response=$(curl -s -f -k --connect-timeout 10 --max-time "$TIMEOUT" "$version_url" 2>/dev/null); then
        if echo "$response" | jq -e '.version' > /dev/null 2>&1; then
            local version=$(echo "$response" | jq -r '.version')
            print_status "Deployed version: $version"
            record_test "Version Endpoint" "pass"
        else
            record_test "Version Endpoint" "warning"
        fi
    else
        record_test "Version Endpoint" "fail"
    fi
}

# Test 3: Container health
test_container_health() {
    print_status "Testing container health..."
    
    local unhealthy_containers=0
    local total_containers=0
    
    # Check if docker compose is available
    if ! command -v docker &> /dev/null; then
        record_test "Container Health" "warning"
        return
    fi
    
    # Get container status
    while IFS= read -r line; do
        if [[ "$line" =~ ^cloudtolocalllm- ]]; then
            ((total_containers++))
            if [[ ! "$line" =~ \(healthy\) ]] && [[ "$line" =~ Up ]]; then
                ((unhealthy_containers++))
            fi
        fi
    done < <(docker compose ps 2>/dev/null || echo "")
    
    if [[ $total_containers -eq 0 ]]; then
        record_test "Container Health" "warning"
    elif [[ $unhealthy_containers -eq 0 ]]; then
        record_test "Container Health" "pass"
    else
        record_test "Container Health" "fail"
    fi
}

# Test 4: SSL certificate (test external URL)
test_ssl_certificate() {
    print_status "Testing SSL certificate..."

    local domain="cloudtolocalllm.online"

    if openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | \
       openssl x509 -noout -dates 2>/dev/null | grep -q "notAfter"; then
        record_test "SSL Certificate" "pass"
    else
        record_test "SSL Certificate" "warning"
    fi
}

# Test 5: API backend health
test_api_backend() {
    print_status "Testing API backend health..."

    local api_health_url="$API_URL:8080/health"

    if curl -s -f -k --connect-timeout 10 --max-time "$TIMEOUT" "$api_health_url" > /dev/null 2>&1; then
        record_test "API Backend Health" "pass"
    else
        # Try alternative health check
        if curl -s -f -k --connect-timeout 10 --max-time "$TIMEOUT" "$API_URL/api/health" > /dev/null 2>&1; then
            record_test "API Backend Health" "pass"
        else
            record_test "API Backend Health" "warning"
        fi
    fi
}

# Test 6: Static assets
test_static_assets() {
    print_status "Testing static assets..."

    local assets=("main.dart.js" "flutter.js" "manifest.json")
    local failed_assets=0

    for asset in "${assets[@]}"; do
        if ! curl -s -f -k --connect-timeout 10 --max-time "$TIMEOUT" "$APP_URL/$asset" > /dev/null 2>&1; then
            ((failed_assets++))
        fi
    done

    if [[ $failed_assets -eq 0 ]]; then
        record_test "Static Assets" "pass"
    elif [[ $failed_assets -lt ${#assets[@]} ]]; then
        record_test "Static Assets" "warning"
    else
        record_test "Static Assets" "fail"
    fi
}

# Main verification function
main() {
    echo "================================================================"
    echo "CloudToLocalLLM Deployment Verification"
    echo "Time: $(date)"
    echo "URL: $APP_URL"
    echo "Strict Mode: $STRICT_MODE"
    echo "================================================================"
    echo
    
    # Run all tests
    test_basic_connectivity
    test_version_endpoint
    test_container_health
    test_ssl_certificate
    test_api_backend
    test_static_assets
    
    echo
    echo "================================================================"
    echo "Verification Summary"
    echo "================================================================"
    
    # Display results
    for test_name in "${!test_results[@]}"; do
        case "${test_results[$test_name]}" in
            "pass")
                echo -e "${GREEN}✅ $test_name${NC}"
                ;;
            "warning")
                echo -e "${YELLOW}⚠️ $test_name${NC}"
                ;;
            "fail")
                echo -e "${RED}❌ $test_name${NC}"
                ;;
        esac
    done
    
    echo
    echo "Results: $passed_count/$test_count tests passed, $warning_count warnings"
    
    # Determine exit code
    local failed_count=$((test_count - passed_count - warning_count))
    
    if [[ $failed_count -eq 0 ]] && [[ $warning_count -eq 0 ]]; then
        print_success "🎉 All tests passed! Deployment verification successful."
        exit 0
    elif [[ $failed_count -eq 0 ]] && [[ $STRICT_MODE == "false" ]]; then
        print_warning "⚠️ Deployment verification completed with warnings."
        exit 0
    else
        print_error "❌ Deployment verification failed."
        exit 1
    fi
}

# Execute main function
main "$@"
