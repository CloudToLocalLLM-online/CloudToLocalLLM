#!/bin/bash
# CloudToLocalLLM Deployment Verification Script
# Comprehensive deployment verification with zero-tolerance quality gates
# Enforces strict quality standards for production deployments

set -euo pipefail

# Script metadata
SCRIPT_VERSION="4.0.0"
SCRIPT_NAME="CloudToLocalLLM Deployment Verification"

# Configuration
DOMAIN="cloudtolocalllm.online"
APP_URL="https://app.cloudtolocalllm.online"
DOCS_URL="https://docs.cloudtolocalllm.online"
MAIL_URL="https://mail.cloudtolocalllm.online"
PROJECT_DIR="/opt/cloudtolocalllm"
COMPOSE_FILE="docker-compose.yml"

# Test configuration
TIMEOUT_SECONDS=30
MAX_RETRIES=3
RETRY_DELAY=5

# Quality gate thresholds
MAX_RESPONSE_TIME=5000  # milliseconds
MIN_UPTIME_PERCENTAGE=99.0
MAX_ERROR_RATE=0.1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
declare -A TEST_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

# Test result functions
test_pass() {
    local test_name="$1"
    TEST_RESULTS["$test_name"]="PASS"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
    log_success "✅ $test_name"
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    TEST_RESULTS["$test_name"]="FAIL"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
    log_error "❌ $test_name: $reason"
}

test_warning() {
    local test_name="$1"
    local reason="$2"
    TEST_RESULTS["$test_name"]="WARNING"
    ((WARNING_TESTS++))
    ((TOTAL_TESTS++))
    log_warning "⚠️ $test_name: $reason"
}

# Show help
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --timeout SECONDS   Set timeout for HTTP requests (default: $TIMEOUT_SECONDS)
    --strict           Enable strict mode (warnings count as failures)
    --help             Show this help message

DESCRIPTION:
    Comprehensive deployment verification with zero-tolerance quality gates:
    1. Basic connectivity tests
    2. SSL certificate validation
    3. Container health checks
    4. Application functionality tests
    5. Performance benchmarks
    6. Security header validation

QUALITY GATES:
    - All containers must be healthy
    - SSL certificates must be valid
    - Response times must be under ${MAX_RESPONSE_TIME}ms
    - No HTTP errors allowed
    - All security headers must be present

EXIT CODES:
    0 - All tests passed
    1 - One or more tests failed
    2 - Configuration error
EOF
}

# Parse command line arguments
STRICT_MODE=false
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --timeout)
                TIMEOUT_SECONDS="$2"
                shift 2
                ;;
            --strict)
                STRICT_MODE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 2
                ;;
        esac
    done
}

# HTTP test with timeout and retry
http_test() {
    local url="$1"
    local test_name="$2"
    local expected_status="${3:-200}"

    echo "[DEBUG] Starting http_test for $test_name" >&2
    log_test "Testing $test_name: $url"
    echo "[DEBUG] After log_test" >&2
    
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        echo "[DEBUG] Attempt $attempt, calling curl..." >&2
        local start_time=$(date +%s%3N)
        local response=$(curl -k -s -o /dev/null -w "%{http_code}|%{time_total}" --max-time "$TIMEOUT_SECONDS" "$url" 2>/dev/null || echo "000|0")
        local end_time=$(date +%s%3N)
        echo "[DEBUG] Curl response: $response" >&2
        
        local status_code=$(echo "$response" | cut -d'|' -f1)
        local response_time_seconds=$(echo "$response" | cut -d'|' -f2)
        local response_time_ms=$(printf "%.0f" $(echo "$response_time_seconds * 1000" | bc 2>/dev/null || echo "0"))

        if [[ "$status_code" == "$expected_status" ]]; then
            if (( response_time_ms > MAX_RESPONSE_TIME )); then
                test_warning "$test_name" "Slow response: ${response_time_ms}ms (threshold: ${MAX_RESPONSE_TIME}ms)"
            else
                test_pass "$test_name (${response_time_ms}ms)"
            fi
            return 0
        fi
        
        if [[ $attempt -eq $MAX_RETRIES ]]; then
            test_fail "$test_name" "HTTP $status_code after $MAX_RETRIES attempts"
            return 1
        fi
        
        log_warning "Attempt $attempt failed (HTTP $status_code), retrying..."
        sleep $RETRY_DELAY
        ((attempt++))
    done
}

# SSL certificate test
ssl_test() {
    local domain="$1"
    local test_name="SSL Certificate - $domain"
    
    log_test "Testing $test_name"
    
    local ssl_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [[ -n "$ssl_info" ]]; then
        local not_after=$(echo "$ssl_info" | grep "notAfter" | cut -d'=' -f2)
        local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
        local current_date=$(date +%s)
        local days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
        
        if [[ $days_until_expiry -gt 30 ]]; then
            test_pass "$test_name ($days_until_expiry days until expiry)"
        elif [[ $days_until_expiry -gt 7 ]]; then
            test_warning "$test_name" "Certificate expires in $days_until_expiry days"
        else
            test_fail "$test_name" "Certificate expires in $days_until_expiry days"
        fi
    else
        test_fail "$test_name" "Unable to retrieve certificate information"
    fi
}

# Container health test
container_health_test() {
    log_test "Testing container health"
    
    if [[ ! -f "$PROJECT_DIR/$COMPOSE_FILE" ]]; then
        test_fail "Container Health" "Compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    local total_containers=$(docker-compose -f "$COMPOSE_FILE" config --services | wc -l)
    local running_containers=$(docker-compose -f "$COMPOSE_FILE" ps -q | wc -l)
    local healthy_containers=$(docker-compose -f "$COMPOSE_FILE" ps --filter "health=healthy" -q | wc -l)
    local unhealthy_containers=$(docker-compose -f "$COMPOSE_FILE" ps --filter "health=unhealthy" -q | wc -l)
    
    if [[ $running_containers -eq $total_containers ]]; then
        if [[ $unhealthy_containers -eq 0 ]]; then
            test_pass "Container Health ($running_containers/$total_containers running, $healthy_containers healthy)"
        else
            test_fail "Container Health" "$unhealthy_containers containers are unhealthy"
        fi
    else
        test_fail "Container Health" "Only $running_containers/$total_containers containers running"
    fi
}

# Security headers test
security_headers_test() {
    local url="$1"
    local test_name="Security Headers"
    
    log_test "Testing $test_name: $url"
    
    local headers=$(curl -k -s -I --max-time "$TIMEOUT_SECONDS" "$url" 2>/dev/null || echo "")
    
    local required_headers=("X-Frame-Options" "X-Content-Type-Options" "X-XSS-Protection")
    local missing_headers=()
    
    for header in "${required_headers[@]}"; do
        if ! echo "$headers" | grep -qi "$header"; then
            missing_headers+=("$header")
        fi
    done
    
    if [[ ${#missing_headers[@]} -eq 0 ]]; then
        test_pass "$test_name"
    else
        test_warning "$test_name" "Missing headers: ${missing_headers[*]}"
    fi
}

# Version endpoint test
version_test() {
    local url="$APP_URL/version.json"
    local test_name="Version Endpoint"

    log_test "Testing $test_name: $url"

    local response=$(curl -k -s --max-time "$TIMEOUT_SECONDS" "$url" 2>/dev/null || echo "")

    if [[ -n "$response" ]]; then
        local version=$(echo "$response" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
        local build_number=$(echo "$response" | grep -o '"build_number":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")

        if [[ -n "$version" ]]; then
            test_pass "$test_name (v$version, build: $build_number)"
        else
            test_fail "$test_name" "Invalid JSON response"
        fi
    else
        test_fail "$test_name" "No response received"
    fi
}

# Performance test
performance_test() {
    local url="$APP_URL"
    local test_name="Performance Test"

    log_test "Testing $test_name: $url"

    local total_time=0
    local successful_requests=0
    local test_requests=5

    for ((i=1; i<=test_requests; i++)); do
        local start_time=$(date +%s%3N)
        local status_code=$(curl -k -s -w "%{http_code}" --max-time "$TIMEOUT_SECONDS" -o /dev/null "$url" 2>/dev/null || echo "000")
        local end_time=$(date +%s%3N)
        local request_time=$((end_time - start_time))

        if [[ "$status_code" == "200" ]]; then
            total_time=$((total_time + request_time))
            ((successful_requests++))
        fi
    done

    if [[ $successful_requests -eq $test_requests ]]; then
        local avg_time=$((total_time / test_requests))
        if [[ $avg_time -le $MAX_RESPONSE_TIME ]]; then
            test_pass "$test_name (avg: ${avg_time}ms)"
        else
            test_warning "$test_name" "Average response time: ${avg_time}ms (threshold: ${MAX_RESPONSE_TIME}ms)"
        fi
    else
        test_fail "$test_name" "Only $successful_requests/$test_requests requests successful"
    fi
}

# Run all tests
run_all_tests() {
    echo "================================================================"
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "Time: $(date)"
    echo "Target: $APP_URL"
    echo "Timeout: ${TIMEOUT_SECONDS}s"
    echo "Strict Mode: $STRICT_MODE"
    echo "================================================================"
    echo

    # Basic connectivity tests
    log_info "Phase 1: Basic Connectivity Tests"
    http_test "$APP_URL" "Main Application"
    http_test "$APP_URL/version.json" "Version Endpoint"
    version_test
    echo

    # SSL certificate tests
    log_info "Phase 2: SSL Certificate Tests"
    ssl_test "app.cloudtolocalllm.online"
    ssl_test "cloudtolocalllm.online"
    echo

    # Container health tests
    log_info "Phase 3: Container Health Tests"
    container_health_test
    echo

    # Security tests
    log_info "Phase 4: Security Tests"
    security_headers_test "$APP_URL"
    echo

    # Performance tests
    log_info "Phase 5: Performance Tests"
    performance_test
    echo
}

# Generate test report
generate_report() {
    echo "================================================================"
    echo "DEPLOYMENT VERIFICATION REPORT"
    echo "================================================================"
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "Warnings: $WARNING_TESTS"
    echo

    # Show detailed results
    echo "Detailed Results:"
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$test_name]}"
        case $result in
            "PASS")
                echo -e "  ${GREEN}✅ $test_name${NC}"
                ;;
            "FAIL")
                echo -e "  ${RED}❌ $test_name${NC}"
                ;;
            "WARNING")
                echo -e "  ${YELLOW}⚠️ $test_name${NC}"
                ;;
        esac
    done
    echo

    # Determine overall result
    local exit_code=0

    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${RED}🚨 DEPLOYMENT VERIFICATION FAILED${NC}"
        echo "Reason: $FAILED_TESTS test(s) failed"
        exit_code=1
    elif [[ $WARNING_TESTS -gt 0 && "$STRICT_MODE" == "true" ]]; then
        echo -e "${YELLOW}⚠️ DEPLOYMENT VERIFICATION FAILED (STRICT MODE)${NC}"
        echo "Reason: $WARNING_TESTS warning(s) in strict mode"
        exit_code=1
    elif [[ $WARNING_TESTS -gt 0 ]]; then
        echo -e "${YELLOW}⚠️ DEPLOYMENT VERIFICATION PASSED WITH WARNINGS${NC}"
        echo "Warnings: $WARNING_TESTS (use --strict to treat as failures)"
    else
        echo -e "${GREEN}🎉 DEPLOYMENT VERIFICATION PASSED${NC}"
        echo "All $TOTAL_TESTS tests passed successfully!"
    fi

    echo "================================================================"
    return $exit_code
}

# Main function
main() {
    # Check if running on VPS
    if [[ ! -d "$PROJECT_DIR" ]]; then
        log_error "Project directory not found: $PROJECT_DIR"
        log_error "This script must be run on the VPS"
        exit 2
    fi

    # Run all tests
    run_all_tests

    # Generate and display report
    generate_report
    local exit_code=$?

    # Additional information
    echo
    log_info "Next steps:"
    if [[ $exit_code -eq 0 ]]; then
        log_info "  ✅ Deployment is ready for production use"
        log_info "  📊 Monitor application performance"
        log_info "  🔍 Check logs: docker-compose -f $COMPOSE_FILE logs -f"
    else
        log_info "  🔧 Fix identified issues before production use"
        log_info "  📋 Review failed tests above"
        log_info "  🔄 Re-run verification after fixes"
    fi

    exit $exit_code
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    parse_args "$@"

    # Execute main function
    main
fi
