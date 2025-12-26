#!/bin/bash
# ArgoCD Components Testing Script
# Comprehensive testing framework for ArgoCD stabilization components
# Tests unit functionality, integration scenarios, and error handling
# Usage: ./test-argocd-components.sh [options]

set -e

# Configuration
ARGOCD_NAMESPACE="argocd"
CLOUDTOLOCLLM_NAMESPACE="cloudtolocalllm"
LOG_FILE="/var/log/test-argocd-components.log"
REPORT_FILE="/tmp/argocd-test-report-$(date +%Y%m%d_%H%M%S).json"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$DATE]${NC} $1" | tee -a $LOG_FILE
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a $LOG_FILE
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a $LOG_FILE
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a $LOG_FILE
}

# Test result tracking
test_passed() {
    local test_name=$1
    log "✅ PASSED: $test_name"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

test_failed() {
    local test_name=$1
    local reason=$2
    error "❌ FAILED: $test_name - $reason"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

test_skipped() {
    local test_name=$1
    local reason=$2
    warning "⏭️  SKIPPED: $test_name - $reason"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Function to validate prerequisites
validate_prerequisites() {
    log "=== Validating Prerequisites ==="

    # Check if kubectl is available
    if command -v kubectl &> /dev/null; then
        test_passed "kubectl_available"
    else
        test_failed "kubectl_available" "kubectl not found in PATH"
        return 1
    fi

    # Check if argocd CLI is available
    if command -v argocd &> /dev/null; then
        test_passed "argocd_cli_available"
    else
        test_failed "argocd_cli_available" "argocd CLI not found in PATH"
        return 1
    fi

    # Check if jq is available
    if command -v jq &> /dev/null; then
        test_passed "jq_available"
    else
        test_failed "jq_available" "jq not found in PATH"
        return 1
    fi

    # Check cluster connectivity
    if kubectl cluster-info &> /dev/null; then
        test_passed "cluster_connectivity"
    else
        test_failed "cluster_connectivity" "Cannot connect to Kubernetes cluster"
        return 1
    fi

    # Check ArgoCD connectivity
    if argocd version --client &> /dev/null; then
        test_passed "argocd_connectivity"
    else
        test_failed "argocd_connectivity" "Cannot connect to ArgoCD server"
        return 1
    fi

    success "Prerequisites validation completed"
}

# Function to test ArgoCD server HA
test_argocd_server_ha() {
    log "=== Testing ArgoCD Server HA ==="

    # Check if deployment exists
    if ! kubectl get deployment argocd-server -n $ARGOCD_NAMESPACE &> /dev/null; then
        test_failed "server_deployment_exists" "ArgoCD server deployment not found"
        return 1
    fi
    test_passed "server_deployment_exists"

    # Check replica count
    local replicas=$(kubectl get deployment argocd-server -n $ARGOCD_NAMESPACE -o jsonpath='{.spec.replicas}')
    if [ "$replicas" -eq 3 ]; then
        test_passed "server_replicas_correct"
    else
        test_failed "server_replicas_correct" "Expected 3 replicas, got $replicas"
    fi

    # Check pod status
    local ready_pods=$(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running --no-headers | wc -l)
    if [ "$ready_pods" -eq 3 ]; then
        test_passed "server_pods_running"
    else
        test_failed "server_pods_running" "Expected 3 running pods, got $ready_pods"
    fi

    # Check service exists
    if kubectl get svc argocd-server -n $ARGOCD_NAMESPACE &> /dev/null; then
        test_passed "server_service_exists"
    else
        test_failed "server_service_exists" "ArgoCD server service not found"
    fi

    # Check load balancer type
    local service_type=$(kubectl get svc argocd-server -n $ARGOCD_NAMESPACE -o jsonpath='{.spec.type}')
    if [ "$service_type" = "LoadBalancer" ]; then
        test_passed "server_load_balancer"
    else
        test_failed "server_load_balancer" "Expected LoadBalancer service type, got $service_type"
    fi

    success "ArgoCD server HA testing completed"
}

# Function to test application controller
test_application_controller() {
    log "=== Testing Application Controller ==="

    # Check deployment exists
    if ! kubectl get deployment argocd-application-controller -n $ARGOCD_NAMESPACE &> /dev/null; then
        test_failed "controller_deployment_exists" "Application controller deployment not found"
        return 1
    fi
    test_passed "controller_deployment_exists"

    # Check replica count
    local replicas=$(kubectl get deployment argocd-application-controller -n $ARGOCD_NAMESPACE -o jsonpath='{.spec.replicas}')
    if [ "$replicas" -eq 2 ]; then
        test_passed "controller_replicas_correct"
    else
        test_failed "controller_replicas_correct" "Expected 2 replicas, got $replicas"
    fi

    # Check pod status
    local ready_pods=$(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-application-controller --field-selector=status.phase=Running --no-headers | wc -l)
    if [ "$ready_pods" -eq 2 ]; then
        test_passed "controller_pods_running"
    else
        test_failed "controller_pods_running" "Expected 2 running pods, got $ready_pods"
    fi

    # Check metrics service
    if kubectl get svc argocd-application-controller-metrics -n $ARGOCD_NAMESPACE &> /dev/null; then
        test_passed "controller_metrics_service"
    else
        test_failed "controller_metrics_service" "Controller metrics service not found"
    fi

    # Test metrics endpoint
    local metrics_url="http://argocd-application-controller-metrics.$ARGOCD_NAMESPACE.svc.cluster.local:8084/metrics"
    if curl -f --max-time 10 $metrics_url &> /dev/null; then
        test_passed "controller_metrics_endpoint"
    else
        test_failed "controller_metrics_endpoint" "Metrics endpoint not responding"
    fi

    success "Application controller testing completed"
}

# Function to test repository server
test_repo_server() {
    log "=== Testing Repository Server ==="

    # Check deployment exists
    if ! kubectl get deployment argocd-repo-server -n $ARGOCD_NAMESPACE &> /dev/null; then
        test_failed "repo_deployment_exists" "Repository server deployment not found"
        return 1
    fi
    test_passed "repo_deployment_exists"

    # Check replica count
    local replicas=$(kubectl get deployment argocd-repo-server -n $ARGOCD_NAMESPACE -o jsonpath='{.spec.replicas}')
    if [ "$replicas" -eq 2 ]; then
        test_passed "repo_replicas_correct"
    else
        test_failed "repo_replicas_correct" "Expected 2 replicas, got $replicas"
    fi

    # Check pod status
    local ready_pods=$(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-repo-server --field-selector=status.phase=Running --no-headers | wc -l)
    if [ "$ready_pods" -eq 2 ]; then
        test_passed "repo_pods_running"
    else
        test_failed "repo_pods_running" "Expected 2 running pods, got $ready_pods"
    fi

    # Check cache directory
    local cache_check=$(kubectl exec -n $ARGOCD_NAMESPACE deployment/argocd-repo-server -- ls -la /tmp/cache/ 2>/dev/null | wc -l)
    if [ "$cache_check" -gt 0 ]; then
        test_passed "repo_cache_directory"
    else
        test_failed "repo_cache_directory" "Cache directory not accessible"
    fi

    success "Repository server testing completed"
}

# Function to test monitoring setup
test_monitoring_setup() {
    log "=== Testing Monitoring Setup ==="

    # Check ServiceMonitor
    if kubectl get servicemonitor argocd-server-metrics -n $ARGOCD_NAMESPACE &> /dev/null; then
        test_passed "servicemonitor_exists"
    else
        test_failed "servicemonitor_exists" "ArgoCD ServiceMonitor not found"
    fi

    # Check PrometheusRule
    if kubectl get prometheusrule argocd-alerts -n $ARGOCD_NAMESPACE &> /dev/null; then
        test_passed "prometheusrule_exists"
    else
        test_failed "prometheusrule_exists" "ArgoCD PrometheusRule not found"
    fi

    # Check alert rules count
    local alert_count=$(kubectl get prometheusrule argocd-alerts -n $ARGOCD_NAMESPACE -o json | jq '.spec.groups[0].rules | length' 2>/dev/null || echo 0)
    if [ "$alert_count" -ge 25 ]; then
        test_passed "alert_rules_count"
    else
        test_failed "alert_rules_count" "Expected 25+ alert rules, got $alert_count"
    fi

    success "Monitoring setup testing completed"
}

# Function to test sync policies
test_sync_policies() {
    log "=== Testing Sync Policies ==="

    # Check if applications exist
    local app_count=$(kubectl get applications -n $ARGOCD_NAMESPACE --no-headers | wc -l)
    if [ "$app_count" -gt 0 ]; then
        test_passed "applications_exist"
    else
        test_failed "applications_exist" "No ArgoCD applications found"
        return 1
    fi

    # Check sync policy configuration
    local apps_with_retry=$(kubectl get applications -n $ARGOCD_NAMESPACE -o yaml | grep -c "retry:" || echo 0)
    if [ "$apps_with_retry" -gt 0 ]; then
        test_passed "sync_retry_configured"
    else
        test_failed "sync_retry_configured" "No applications have retry configuration"
    fi

    # Check sync wave configuration
    local apps_with_sync_wave=$(kubectl get applications -n $ARGOCD_NAMESPACE -o yaml | grep -c "sync-wave" || echo 0)
    if [ "$apps_with_sync_wave" -gt 0 ]; then
        test_passed "sync_waves_configured"
    else
        test_failed "sync_waves_configured" "No applications have sync wave configuration"
    fi

    # Check self-heal configuration
    local apps_with_self_heal=$(kubectl get applications -n $ARGOCD_NAMESPACE -o yaml | grep -c "selfHeal: true" || echo 0)
    if [ "$apps_with_self_heal" -gt 0 ]; then
        test_passed "self_heal_enabled"
    else
        test_failed "self_heal_enabled" "Self-heal not enabled on applications"
    fi

    success "Sync policies testing completed"
}

# Function to test health check script
test_health_check_script() {
    log "=== Testing Health Check Script ==="

    if [ ! -f "./scripts/argocd-health-check.sh" ]; then
        test_failed "health_check_script_exists" "Health check script not found"
        return 1
    fi
    test_passed "health_check_script_exists"

    # Test script execution
    if ./scripts/argocd-health-check.sh --help &> /dev/null; then
        test_passed "health_check_script_executable"
    else
        test_failed "health_check_script_executable" "Health check script not executable"
    fi

    # Test critical components check
    if ./scripts/argocd-health-check.sh --critical &> /dev/null; then
        test_passed "health_check_critical_mode"
    else
        test_failed "health_check_critical_mode" "Critical mode check failed"
    fi

    success "Health check script testing completed"
}

# Function to test rollback script
test_rollback_script() {
    log "=== Testing Rollback Script ==="

    if [ ! -f "./scripts/rollback-argocd-app.sh" ]; then
        test_failed "rollback_script_exists" "Rollback script not found"
        return 1
    fi
    test_passed "rollback_script_exists"

    # Test script execution
    if ./scripts/rollback-argocd-app.sh --help &> /dev/null; then
        test_passed "rollback_script_executable"
    else
        test_failed "rollback_script_executable" "Rollback script not executable"
    fi

    # Test list points functionality
    local app_count=$(kubectl get applications -n $ARGOCD_NAMESPACE --no-headers | wc -l)
    if [ "$app_count" -gt 0 ]; then
        local first_app=$(kubectl get applications -n $ARGOCD_NAMESPACE -o jsonpath='{.items[0].metadata.name}')
        if ./scripts/rollback-argocd-app.sh --list-points -a "$first_app" &> /dev/null; then
            test_passed "rollback_list_points"
        else
            test_failed "rollback_list_points" "List points functionality failed"
        fi
    else
        test_skipped "rollback_list_points" "No applications available for testing"
    fi

    success "Rollback script testing completed"
}

# Function to test backup restore script
test_backup_restore_script() {
    log "=== Testing Backup Restore Script ==="

    if [ ! -f "./scripts/argocd-backup-restore.sh" ]; then
        test_failed "backup_script_exists" "Backup restore script not found"
        return 1
    fi
    test_passed "backup_script_exists"

    # Test script execution
    if ./scripts/argocd-backup-restore.sh --help &> /dev/null; then
        test_passed "backup_script_executable"
    else
        test_failed "backup_script_executable" "Backup script not executable"
    fi

    # Test list functionality
    if ./scripts/argocd-backup-restore.sh --list &> /dev/null; then
        test_passed "backup_list_functionality"
    else
        test_failed "backup_list_functionality" "List functionality failed"
    fi

    success "Backup restore script testing completed"
}

# Function to test deployment SOP script
test_deployment_sop_script() {
    log "=== Testing Deployment SOP Script ==="

    if [ ! -f "./scripts/deployment-sop.sh" ]; then
        test_failed "sop_script_exists" "Deployment SOP script not found"
        return 1
    fi
    test_passed "sop_script_exists"

    # Test script execution
    if ./scripts/deployment-sop.sh --help &> /dev/null; then
        test_passed "sop_script_executable"
    else
        test_failed "sop_script_executable" "SOP script not executable"
    fi

    # Test dry run functionality
    if ./scripts/deployment-sop.sh -e test -a api-backend --dry-run &> /dev/null; then
        test_passed "sop_dry_run"
    else
        test_failed "sop_dry_run" "Dry run functionality failed"
    fi

    success "Deployment SOP script testing completed"
}

# Function to test error handling scenarios
test_error_handling() {
    log "=== Testing Error Handling Scenarios ==="

    # Test invalid application name
    if ./scripts/rollback-argocd-app.sh -a "nonexistent-app" -r HEAD~1 2>&1 | grep -q "not found"; then
        test_passed "error_invalid_app_handled"
    else
        test_failed "error_invalid_app_handled" "Invalid application error not handled properly"
    fi

    # Test invalid revision
    local app_count=$(kubectl get applications -n $ARGOCD_NAMESPACE --no-headers | wc -l)
    if [ "$app_count" -gt 0 ]; then
        local first_app=$(kubectl get applications -n $ARGOCD_NAMESPACE -o jsonpath='{.items[0].metadata.name}')
        if ./scripts/rollback-argocd-app.sh -a "$first_app" -r "invalid-revision" 2>&1 | grep -q "not available"; then
            test_passed "error_invalid_revision_handled"
        else
            test_failed "error_invalid_revision_handled" "Invalid revision error not handled properly"
        fi
    else
        test_skipped "error_invalid_revision_handled" "No applications available for testing"
    fi

    success "Error handling testing completed"
}

# Function to run unit tests
run_unit_tests() {
    log "=== Running Unit Tests ==="

    test_health_check_script
    test_rollback_script
    test_backup_restore_script
    test_deployment_sop_script
    test_error_handling

    success "Unit tests completed"
}

# Function to run integration tests
run_integration_tests() {
    log "=== Running Integration Tests ==="

    test_argocd_server_ha
    test_application_controller
    test_repo_server
    test_monitoring_setup
    test_sync_policies

    success "Integration tests completed"
}

# Function to generate test report
generate_test_report() {
    log "=== Generating Test Report ==="

    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    cat > $REPORT_FILE << EOF
{
  "test_summary": {
    "timestamp": "$DATE",
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "skipped_tests": $SKIPPED_TESTS,
    "success_rate": $success_rate
  },
  "test_results": {
    "prerequisites": $(validate_prerequisites 2>/dev/null && echo "true" || echo "false"),
    "unit_tests": $(run_unit_tests 2>/dev/null && echo "true" || echo "false"),
    "integration_tests": $(run_integration_tests 2>/dev/null && echo "true" || echo "false")
  },
  "recommendations": [
    $(if [ $FAILED_TESTS -gt 0 ]; then echo "\"Fix failed tests before proceeding\""; fi)
    $(if [ $success_rate -lt 100 ]; then echo "\"Achieve 100% test success rate\""; fi)
    $(if [ $TOTAL_TESTS -eq 0 ]; then echo "\"No tests were executed\""; fi)
  ]
}
EOF

    success "Test report generated: $REPORT_FILE"

    # Display summary
    log "=== Test Summary ==="
    log "Total Tests: $TOTAL_TESTS"
    log "Passed: $PASSED_TESTS"
    log "Failed: $FAILED_TESTS"
    log "Skipped: $SKIPPED_TESTS"
    log "Success Rate: ${success_rate}%"

    if [ $success_rate -eq 100 ]; then
        success "🎉 ALL TESTS PASSED! System is ready for production."
    else
        error "❌ TEST FAILURES DETECTED! Fix issues before proceeding."
        return 1
    fi
}

# Main execution function
main() {
    log "=== ArgoCD Components Testing Started ==="

    # Parse command line arguments
    local run_prerequisites=false
    local run_unit_tests=false
    local run_integration_tests=false
    local run_all_tests=false
    local generate_report=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-prerequisites)
                run_prerequisites=true
                shift
                ;;
            --unit-tests)
                run_unit_tests=true
                shift
                ;;
            --integration-tests)
                run_integration_tests=true
                shift
                ;;
            --all-tests)
                run_all_tests=true
                shift
                ;;
            --generate-report)
                generate_report=true
                shift
                ;;
            --test-server-ha)
                test_argocd_server_ha
                exit $?
                ;;
            --test-controller)
                test_application_controller
                exit $?
                ;;
            --test-repo-server)
                test_repo_server
                exit $?
                ;;
            --test-health-check)
                test_health_check_script
                exit $?
                ;;
            --test-rollback)
                test_rollback_script
                exit $?
                ;;
            --test-backup-restore)
                test_backup_restore_script
                exit $?
                ;;
            --test-deployment-sop)
                test_deployment_sop_script
                exit $?
                ;;
            --test-error-handling)
                test_error_handling
                exit $?
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --check-prerequisites    Check environment prerequisites"
                echo "  --unit-tests             Run unit tests for scripts"
                echo "  --integration-tests      Run integration tests for components"
                echo "  --all-tests              Run all tests"
                echo "  --generate-report        Generate detailed test report"
                echo "  --test-server-ha         Test ArgoCD server HA"
                echo "  --test-controller        Test application controller"
                echo "  --test-repo-server       Test repository server"
                echo "  --test-health-check      Test health check script"
                echo "  --test-rollback          Test rollback script"
                echo "  --test-backup-restore    Test backup restore script"
                echo "  --test-deployment-sop    Test deployment SOP script"
                echo "  --test-error-handling    Test error handling scenarios"
                echo "  --help                   Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Initialize log file
    echo "=== ArgoCD Components Testing Started at $DATE ===" > $LOG_FILE

    # Determine what to run
    if [ "$run_all_tests" = true ] || [ $# -eq 0 ]; then
        run_prerequisites=true
        run_unit_tests=true
        run_integration_tests=true
        generate_report=true
    fi

    # Execute tests
    local exit_code=0

    if [ "$run_prerequisites" = true ]; then
        if ! validate_prerequisites; then
            exit_code=1
        fi
    fi

    if [ "$run_unit_tests" = true ]; then
        if ! run_unit_tests; then
            exit_code=1
        fi
    fi

    if [ "$run_integration_tests" = true ]; then
        if ! run_integration_tests; then
            exit_code=1
        fi
    fi

    if [ "$generate_report" = true ]; then
        if ! generate_test_report; then
            exit_code=1
        fi
    fi

    # Final status
    if [ $exit_code -eq 0 ]; then
        success "All requested tests completed successfully"
    else
        error "Some tests failed. Check the log file: $LOG_FILE"
    fi

    exit $exit_code
}

# Run main function with all arguments
main "$@"