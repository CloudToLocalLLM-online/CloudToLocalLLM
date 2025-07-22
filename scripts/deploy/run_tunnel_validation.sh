#!/bin/bash

# Comprehensive Tunnel Deployment Validation Runner
# This script runs all available validation tests for the Simplified Tunnel System

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="/tmp/tunnel-validation-$TIMESTAMP"
API_BASE_URL="${API_BASE_URL:-https://api.cloudtolocalllm.online}"
TEST_JWT_TOKEN="${TEST_JWT_TOKEN:-}"
TEST_USER_ID="${TEST_USER_ID:-auth0|test-user-123}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

# Create results directory
mkdir -p "$RESULTS_DIR"

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Comprehensive validation runner for the Simplified Tunnel System deployment.

OPTIONS:
    -h, --help              Show this help message
    -u, --api-url URL       API base URL (default: https://api.cloudtolocalllm.online)
    -t, --token TOKEN       JWT token for authenticated tests
    -i, --user-id ID        Test user ID (default: auth0|test-user-123)
    -r, --results-dir DIR   Results directory (default: /tmp/tunnel-validation-TIMESTAMP)
    -s, --skip-bash         Skip bash validation script
    -n, --skip-node         Skip Node.js validation script
    -p, --skip-powershell   Skip PowerShell validation script
    -v, --verbose           Enable verbose output

ENVIRONMENT VARIABLES:
    API_BASE_URL           API base URL
    TEST_JWT_TOKEN         JWT token for authenticated tests
    TEST_USER_ID           Test user ID

EXAMPLES:
    # Run all validations
    $0

    # Run with custom settings
    $0 -u https://staging.cloudtolocalllm.online -t eyJ0eXAiOiJKV1Q...

    # Skip specific validation types
    $0 --skip-node --skip-powershell

EXIT CODES:
    0    All validations passed
    1    One or more validations failed
    2    Configuration error
    3    Missing dependencies
EOF
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for bash script
    if [ ! -f "$SCRIPT_DIR/validate_tunnel_deployment.sh" ]; then
        missing_deps+=("validate_tunnel_deployment.sh")
    fi
    
    # Check for Node.js script
    if [ ! -f "$SCRIPT_DIR/validate_tunnel_deployment.js" ]; then
        missing_deps+=("validate_tunnel_deployment.js")
    fi
    
    # Check for PowerShell script
    if [ ! -f "$SCRIPT_DIR/validate_tunnel_deployment.ps1" ]; then
        missing_deps+=("validate_tunnel_deployment.ps1")
    fi
    
    # Check for Node.js if we're going to run the Node.js script
    if ! command -v node >/dev/null 2>&1; then
        log_warning "Node.js not found - Node.js validation will be skipped"
    fi
    
    # Check for PowerShell if we're going to run the PowerShell script
    if ! command -v pwsh >/dev/null 2>&1 && ! command -v powershell >/dev/null 2>&1; then
        log_warning "PowerShell not found - PowerShell validation will be skipped"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing validation scripts: ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# Run bash validation
run_bash_validation() {
    log "Running Bash validation script..."
    
    local bash_log="$RESULTS_DIR/bash-validation.log"
    local bash_script="$SCRIPT_DIR/validate_tunnel_deployment.sh"
    
    if [ ! -f "$bash_script" ]; then
        log_error "Bash validation script not found: $bash_script"
        return 1
    fi
    
    # Make script executable
    chmod +x "$bash_script"
    
    # Run validation
    if "$bash_script" \
        -u "$API_BASE_URL" \
        -t "$TEST_JWT_TOKEN" \
        -i "$TEST_USER_ID" \
        -l "$bash_log" \
        > "$RESULTS_DIR/bash-output.txt" 2>&1; then
        log_success "Bash validation completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Bash validation failed with exit code $exit_code"
        return $exit_code
    fi
}

# Run Node.js validation
run_node_validation() {
    log "Running Node.js validation script..."
    
    local node_script="$SCRIPT_DIR/validate_tunnel_deployment.js"
    
    if [ ! -f "$node_script" ]; then
        log_error "Node.js validation script not found: $node_script"
        return 1
    fi
    
    if ! command -v node >/dev/null 2>&1; then
        log_warning "Node.js not available, skipping Node.js validation"
        return 0
    fi
    
    # Check if ws module is available
    if ! node -e "require('ws')" 2>/dev/null; then
        log_warning "WebSocket module not available, installing..."
        if command -v npm >/dev/null 2>&1; then
            npm install ws --no-save --silent 2>/dev/null || log_warning "Failed to install ws module"
        fi
    fi
    
    # Set environment variables for Node.js script
    export API_BASE_URL="$API_BASE_URL"
    export TEST_JWT_TOKEN="$TEST_JWT_TOKEN"
    export TEST_USER_ID="$TEST_USER_ID"
    
    # Run validation
    if node "$node_script" > "$RESULTS_DIR/node-output.txt" 2>&1; then
        log_success "Node.js validation completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Node.js validation failed with exit code $exit_code"
        return $exit_code
    fi
}

# Run PowerShell validation
run_powershell_validation() {
    log "Running PowerShell validation script..."
    
    local ps_script="$SCRIPT_DIR/validate_tunnel_deployment.ps1"
    
    if [ ! -f "$ps_script" ]; then
        log_error "PowerShell validation script not found: $ps_script"
        return 1
    fi
    
    local ps_cmd=""
    if command -v pwsh >/dev/null 2>&1; then
        ps_cmd="pwsh"
    elif command -v powershell >/dev/null 2>&1; then
        ps_cmd="powershell"
    else
        log_warning "PowerShell not available, skipping PowerShell validation"
        return 0
    fi
    
    # Run validation
    if "$ps_cmd" -File "$ps_script" \
        -ApiBaseUrl "$API_BASE_URL" \
        -TestJwtToken "$TEST_JWT_TOKEN" \
        -TestUserId "$TEST_USER_ID" \
        -LogFile "$RESULTS_DIR/powershell-validation.log" \
        > "$RESULTS_DIR/powershell-output.txt" 2>&1; then
        log_success "PowerShell validation completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "PowerShell validation failed with exit code $exit_code"
        return $exit_code
    fi
}

# Generate comprehensive report
generate_report() {
    local report_file="$RESULTS_DIR/validation-report.md"
    
    log "Generating comprehensive validation report..."
    
    cat > "$report_file" << EOF
# Simplified Tunnel System Validation Report

**Generated:** $(date)
**API Base URL:** $API_BASE_URL
**Test User ID:** $TEST_USER_ID
**Results Directory:** $RESULTS_DIR

## Summary

EOF
    
    # Count results
    local total_validations=0
    local passed_validations=0
    local failed_validations=0
    
    # Analyze bash results
    if [ -f "$RESULTS_DIR/bash-output.txt" ]; then
        echo "### Bash Validation Results" >> "$report_file"
        echo "" >> "$report_file"
        
        if grep -q "DEPLOYMENT VALIDATION PASSED" "$RESULTS_DIR/bash-output.txt"; then
            echo "✅ **Status:** PASSED" >> "$report_file"
            passed_validations=$((passed_validations + 1))
        else
            echo "❌ **Status:** FAILED" >> "$report_file"
            failed_validations=$((failed_validations + 1))
        fi
        
        total_validations=$((total_validations + 1))
        
        # Extract summary if available
        if [ -f "$RESULTS_DIR/bash-validation.log" ]; then
            echo "" >> "$report_file"
            echo "**Details:**" >> "$report_file"
            echo '```' >> "$report_file"
            tail -20 "$RESULTS_DIR/bash-validation.log" >> "$report_file"
            echo '```' >> "$report_file"
        fi
        
        echo "" >> "$report_file"
    fi
    
    # Analyze Node.js results
    if [ -f "$RESULTS_DIR/node-output.txt" ]; then
        echo "### Node.js Validation Results" >> "$report_file"
        echo "" >> "$report_file"
        
        if grep -q "DEPLOYMENT VALIDATION PASSED" "$RESULTS_DIR/node-output.txt"; then
            echo "✅ **Status:** PASSED" >> "$report_file"
            passed_validations=$((passed_validations + 1))
        else
            echo "❌ **Status:** FAILED" >> "$report_file"
            failed_validations=$((failed_validations + 1))
        fi
        
        total_validations=$((total_validations + 1))
        
        # Check for JSON results
        local json_file=$(find /tmp -name "tunnel-validation-*.json" -newer "$RESULTS_DIR" 2>/dev/null | head -1)
        if [ -f "$json_file" ]; then
            echo "" >> "$report_file"
            echo "**Summary:**" >> "$report_file"
            echo '```json' >> "$report_file"
            jq '.summary' "$json_file" 2>/dev/null >> "$report_file" || echo "JSON parsing failed" >> "$report_file"
            echo '```' >> "$report_file"
        fi
        
        echo "" >> "$report_file"
    fi
    
    # Analyze PowerShell results
    if [ -f "$RESULTS_DIR/powershell-output.txt" ]; then
        echo "### PowerShell Validation Results" >> "$report_file"
        echo "" >> "$report_file"
        
        if grep -q "DEPLOYMENT VALIDATION PASSED" "$RESULTS_DIR/powershell-output.txt"; then
            echo "✅ **Status:** PASSED" >> "$report_file"
            passed_validations=$((passed_validations + 1))
        else
            echo "❌ **Status:** FAILED" >> "$report_file"
            failed_validations=$((failed_validations + 1))
        fi
        
        total_validations=$((total_validations + 1))
        echo "" >> "$report_file"
    fi
    
    # Update summary
    sed -i "2i\\
**Total Validations:** $total_validations\\
**Passed:** $passed_validations\\
**Failed:** $failed_validations\\
**Success Rate:** $(( passed_validations * 100 / total_validations ))%\\
" "$report_file"
    
    # Add recommendations
    cat >> "$report_file" << EOF

## Recommendations

EOF
    
    if [ $failed_validations -eq 0 ]; then
        cat >> "$report_file" << EOF
✅ **All validations passed!** The Simplified Tunnel System deployment appears to be successful and ready for production use.

### Next Steps:
1. Monitor system performance and error rates
2. Verify user experience with real traffic
3. Update monitoring dashboards
4. Document any configuration changes
EOF
    else
        cat >> "$report_file" << EOF
❌ **Some validations failed.** Review the detailed results above and address issues before proceeding with production deployment.

### Immediate Actions:
1. Review failed test details in the output files
2. Check system logs for additional error information
3. Verify configuration settings
4. Consider rolling back if critical issues are found

### Investigation Steps:
1. Check API server logs: \`docker-compose logs api-backend\`
2. Verify database connectivity
3. Test WebSocket connections manually
4. Review authentication configuration
EOF
    fi
    
    cat >> "$report_file" << EOF

## Files Generated

- **Report:** $report_file
- **Bash Output:** $RESULTS_DIR/bash-output.txt
- **Node.js Output:** $RESULTS_DIR/node-output.txt
- **PowerShell Output:** $RESULTS_DIR/powershell-output.txt
- **Bash Log:** $RESULTS_DIR/bash-validation.log
- **PowerShell Log:** $RESULTS_DIR/powershell-validation.log

## Support

If issues persist, contact the development team with:
1. This validation report
2. All output files from the results directory
3. System logs from the time of validation
4. Description of any recent changes or deployments
EOF
    
    log_success "Validation report generated: $report_file"
    
    # Return overall status
    if [ $failed_validations -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Main execution
main() {
    local skip_bash=false
    local skip_node=false
    local skip_powershell=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -u|--api-url)
                API_BASE_URL="$2"
                shift 2
                ;;
            -t|--token)
                TEST_JWT_TOKEN="$2"
                shift 2
                ;;
            -i|--user-id)
                TEST_USER_ID="$2"
                shift 2
                ;;
            -r|--results-dir)
                RESULTS_DIR="$2"
                mkdir -p "$RESULTS_DIR"
                shift 2
                ;;
            -s|--skip-bash)
                skip_bash=true
                shift
                ;;
            -n|--skip-node)
                skip_node=true
                shift
                ;;
            -p|--skip-powershell)
                skip_powershell=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                set -x
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 2
                ;;
        esac
    done
    
    # Validate configuration
    if [ -z "$API_BASE_URL" ]; then
        log_error "API_BASE_URL is required"
        exit 2
    fi
    
    log "Starting comprehensive tunnel deployment validation"
    log "API Base URL: $API_BASE_URL"
    log "Test User ID: $TEST_USER_ID"
    log "Results Directory: $RESULTS_DIR"
    
    if [ -z "$TEST_JWT_TOKEN" ]; then
        log_warning "TEST_JWT_TOKEN not provided - some tests will be skipped"
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        exit 3
    fi
    
    local validation_results=()
    
    # Run validations
    if [ "$skip_bash" = false ]; then
        if run_bash_validation; then
            validation_results+=("bash:PASS")
        else
            validation_results+=("bash:FAIL")
        fi
    fi
    
    if [ "$skip_node" = false ]; then
        if run_node_validation; then
            validation_results+=("node:PASS")
        else
            validation_results+=("node:FAIL")
        fi
    fi
    
    if [ "$skip_powershell" = false ]; then
        if run_powershell_validation; then
            validation_results+=("powershell:PASS")
        else
            validation_results+=("powershell:FAIL")
        fi
    fi
    
    # Generate comprehensive report
    if generate_report; then
        log_success "All validations completed successfully"
        log "Validation report available at: $RESULTS_DIR/validation-report.md"
        
        # Display summary
        echo ""
        echo "=== VALIDATION SUMMARY ==="
        for result in "${validation_results[@]}"; do
            local validator="${result%:*}"
            local status="${result#*:}"
            if [ "$status" = "PASS" ]; then
                log_success "$validator validation: PASSED"
            else
                log_error "$validator validation: FAILED"
            fi
        done
        
        exit 0
    else
        log_error "One or more validations failed"
        log "Review the validation report at: $RESULTS_DIR/validation-report.md"
        exit 1
    fi
}

# Signal handlers
trap 'log_error "Validation interrupted"; exit 130' INT TERM

# Run main function
main "$@"