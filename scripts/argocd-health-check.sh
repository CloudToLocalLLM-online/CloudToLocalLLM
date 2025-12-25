#!/bin/bash
# ArgoCD Health Check Script
# Comprehensive health monitoring for CloudToLocalLLM ArgoCD deployment
# Usage: ./argocd-health-check.sh [options]

set -e

# Configuration
ARGOCD_NAMESPACE="argocd"
CLOUDTOLOCLLM_NAMESPACE="cloudtolocalllm"
LOG_FILE="/var/log/argocd-health-check.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

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

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi
}

# Function to check if argocd CLI is available
check_argocd_cli() {
    if ! command -v argocd &> /dev/null; then
        error "argocd CLI is not installed or not in PATH"
        exit 1
    fi
}

# Function to check ArgoCD components
check_argocd_components() {
    log "=== Checking ArgoCD Components ==="
    
    local components=("server" "application-controller" "repo-server" "applicationset-controller")
    local failed_components=0
    
    for component in "${components[@]}"; do
        local pod_count=$(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-$component --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        
        if [ $pod_count -eq 0 ]; then
            error "ArgoCD $component is not running"
            failed_components=$((failed_components + 1))
        else
            success "ArgoCD $component is running ($pod_count pods)"
        fi
    done
    
    if [ $failed_components -gt 0 ]; then
        error "Found $failed_components failed ArgoCD components"
        return 1
    fi
    
    return 0
}

# Function to check application health
check_application_health() {
    log "=== Checking CloudToLocalLLM Applications ==="
    
    local critical_apps=("api-backend" "web-frontend" "postgres" "redis")
    local failed_apps=0
    
    for app in "${critical_apps[@]}"; do
        local full_app_name="cloudtolocalllm-$app"
        
        # Check if application exists
        if ! argocd app get $full_app_name &> /dev/null; then
            warning "Application $full_app_name not found"
            continue
        fi
        
        # Get application status
        local app_status=$(argocd app get $full_app_name --output json 2>/dev/null | jq -r '.status.sync.status' || echo "Unknown")
        local app_health=$(argocd app get $full_app_name --output json 2>/dev/null | jq -r '.status.health.status' || echo "Unknown")
        
        if [ "$app_status" != "Synced" ] || [ "$app_health" != "Healthy" ]; then
            error "Application $app is not healthy (Status: $app_status, Health: $app_health)"
            failed_apps=$((failed_apps + 1))
        else
            success "Application $app is healthy (Status: $app_status, Health: $app_health)"
        fi
    done
    
    if [ $failed_apps -gt 0 ]; then
        error "Found $failed_apps unhealthy applications"
        return 1
    fi
    
    return 0
}

# Function to check resource utilization
check_resource_utilization() {
    log "=== Checking Resource Utilization ==="
    
    # Check if metrics-server is available
    if kubectl top nodes &> /dev/null; then
        log "Resource utilization (ArgoCD namespace):"
        kubectl top pods -n $ARGOCD_NAMESPACE --sort-by=memory | head -10 | tee -a $LOG_FILE
        
        log "Resource utilization (CloudToLocalLLM namespace):"
        kubectl top pods -n $CLOUDTOLOCLLM_NAMESPACE --sort-by=memory | head -10 | tee -a $LOG_FILE
    else
        warning "Metrics server not available, skipping resource utilization check"
    fi
}

# Function to check repository connectivity
check_repository_connectivity() {
    log "=== Checking Repository Connectivity ==="
    
    # List repositories
    local repo_count=$(argocd repo list --output json 2>/dev/null | jq length || echo 0)
    
    if [ $repo_count -eq 0 ]; then
        error "No repositories configured in ArgoCD"
        return 1
    fi
    
    success "Found $repo_count configured repositories"
    
    # Check main repository
    if argocd repo get https://github.com/imrightguy/CloudToLocalLLM &> /dev/null; then
        success "Main repository is accessible"
    else
        error "Main repository is not accessible"
        return 1
    fi
}

# Function to check sync status across all applications
check_sync_status() {
    log "=== Checking Sync Status ==="
    
    local out_of_sync_count=$(argocd app list --output json 2>/dev/null | jq '[.[] | select(.status.sync.status != "Synced")] | length' || echo 0)
    
    if [ $out_of_sync_count -gt 0 ]; then
        warning "Found $out_of_sync_count applications out of sync"
        argocd app list --output json 2>/dev/null | jq '.[] | select(.status.sync.status != "Synced") | {name: .metadata.name, status: .status.sync.status, health: .status.health.status}' | tee -a $LOG_FILE
    else
        success "All applications are in sync"
    fi
}

# Function to check ArgoCD version and compatibility
check_version_compatibility() {
    log "=== Checking Version Compatibility ==="
    
    # Check ArgoCD server version
    local server_version=$(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null | cut -d':' -f2 || echo "Unknown")
    
    # Check CLI version
    local cli_version=$(argocd version --client --output json 2>/dev/null | jq -r '.Version' || echo "Unknown")
    
    success "ArgoCD Server Version: $server_version"
    success "ArgoCD CLI Version: $cli_version"
    
    # Check for version mismatch
    if [ "$server_version" != "$cli_version" ] && [ "$server_version" != "Unknown" ] && [ "$cli_version" != "Unknown" ]; then
        warning "Version mismatch between server and CLI detected"
    fi
}

# Function to generate health report
generate_health_report() {
    log "=== Generating Health Report ==="
    
    local report_file="/tmp/argocd-health-report-$(date +%Y%m%d_%H%M%S).json"
    
    # Create comprehensive health report
    cat > $report_file << EOF
{
  "timestamp": "$DATE",
  "argocd_namespace": "$ARGOCD_NAMESPACE",
  "cloudtolocalllm_namespace": "$CLOUDTOLOCLLM_NAMESPACE",
  "components": {
    "server": $(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l),
    "application_controller": $(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-application-controller --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l),
    "repo_server": $(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-repo-server --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l),
    "applicationset_controller": $(kubectl get pods -n $ARGOCD_NAMESPACE -l app.kubernetes.io/name=argocd-applicationset-controller --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  },
  "applications": $(argocd app list --output json 2>/dev/null || echo '[]'),
  "repositories": $(argocd repo list --output json 2>/dev/null || echo '[]')
}
EOF
    
    success "Health report generated: $report_file"
    echo "Report contents:"
    cat $report_file | jq '.' | tee -a $LOG_FILE
}

# Function to send alerts (placeholder for integration with alerting systems)
send_alert() {
    local severity=$1
    local message=$2
    
    log "ALERT [$severity]: $message"
    
    # Here you would integrate with your alerting system
    # Examples: PagerDuty, Slack, email, etc.
    case $severity in
        "CRITICAL")
            # Send critical alert
            ;;
        "WARNING")
            # Send warning alert
            ;;
        "INFO")
            # Send info notification
            ;;
    esac
}

# Main execution function
main() {
    log "Starting ArgoCD health check..."
    
    # Parse command line arguments
    local check_only_critical=false
    local generate_report=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --critical)
                check_only_critical=true
                shift
                ;;
            --report)
                generate_report=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --critical    Only check critical components"
                echo "  --report      Generate detailed health report"
                echo "  --help        Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Pre-flight checks
    check_kubectl
    check_argocd_cli
    
    # Initialize log file
    echo "=== ArgoCD Health Check Started at $DATE ===" > $LOG_FILE
    
    local health_score=100
    local failed_checks=0
    
    # Run health checks
    log "Running comprehensive health checks..."
    
    if ! check_argocd_components; then
        failed_checks=$((failed_checks + 1))
        health_score=$((health_score - 25))
        send_alert "CRITICAL" "ArgoCD components health check failed"
    fi
    
    if ! check_application_health; then
        failed_checks=$((failed_checks + 1))
        health_score=$((health_score - 25))
        send_alert "CRITICAL" "Application health check failed"
    fi
    
    if ! check_repository_connectivity; then
        failed_checks=$((failed_checks + 1))
        health_score=$((health_score - 25))
        send_alert "WARNING" "Repository connectivity check failed"
    fi
    
    check_sync_status
    check_resource_utilization
    check_version_compatibility
    
    # Generate report if requested
    if [ "$generate_report" = true ]; then
        generate_health_report
    fi
    
    # Final summary
    log "=== Health Check Summary ==="
    log "Health Score: $health_score/100"
    log "Failed Checks: $failed_checks"
    
    if [ $failed_checks -eq 0 ]; then
        success "All health checks passed! ArgoCD deployment is healthy."
        exit 0
    else
        error "Health check completed with $failed_checks failures."
        exit 1
    fi
}

# Run main function with all arguments
main "$@"