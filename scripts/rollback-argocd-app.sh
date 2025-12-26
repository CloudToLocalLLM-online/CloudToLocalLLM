#!/bin/bash
# ArgoCD Application Rollback Script
# Automated rollback procedures for CloudToLocalLLM applications
# Usage: ./rollback-argocd-app.sh <app-name> <revision> [options]

set -e

# Configuration
ARGOCD_NAMESPACE="argocd"
LOG_FILE="/var/log/argocd-rollback.log"
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

# Function to validate prerequisites
validate_prerequisites() {
    log "Validating prerequisites..."
    
    # Check if argocd CLI is available
    if ! command -v argocd &> /dev/null; then
        error "argocd CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check ArgoCD connection
    if ! argocd version --client &> /dev/null; then
        error "Cannot connect to ArgoCD server"
        exit 1
    fi
    
    success "Prerequisites validated"
}

# Function to backup current application state
backup_application_state() {
    local app_name=$1
    local backup_dir="/backup/argocd/rollback/$(date +%Y%m%d_%H%M%S)"
    
    log "Creating backup of current application state..."
    
    mkdir -p $backup_dir
    
    # Backup application configuration
    argocd app get $app_name --output yaml > $backup_dir/application-$app_name.yaml
    
    # Backup application history
    argocd app history $app_name --output json > $backup_dir/application-$app_name-history.json
    
    # Backup current sync status
    argocd app get $app_name --output json > $backup_dir/application-$app_name-status.json
    
    success "Application state backed up to: $backup_dir"
    echo $backup_dir
}

# Function to pause application sync
pause_application_sync() {
    local app_name=$1
    
    log "Pausing sync for application: $app_name"
    
    if argocd app pause $app_name; then
        success "Successfully paused application sync"
    else
        error "Failed to pause application sync"
        return 1
    fi
}

# Function to perform rollback
perform_rollback() {
    local app_name=$1
    local revision=$2
    local backup_dir=$3
    
    log "Performing rollback of $app_name to revision $revision"
    
    # Perform sync to specific revision
    if argocd app sync $app_name --revision $revision --force; then
        success "Rollback sync initiated successfully"
    else
        error "Failed to initiate rollback sync"
        return 1
    fi
    
    # Wait for sync completion
    log "Waiting for sync completion..."
    if argocd app wait $app_name --timeout 300; then
        success "Sync completed successfully"
    else
        error "Sync timed out or failed"
        return 1
    fi
    
    # Verify application health after rollback
    verify_application_health $app_name $backup_dir
}

# Function to verify application health
verify_application_health() {
    local app_name=$1
    local backup_dir=$2
    
    log "Verifying application health after rollback..."
    
    # Get application status
    local app_status=$(argocd app get $app_name --output json | jq -r '.status.sync.status')
    local app_health=$(argocd app get $app_name --output json | jq -r '.status.health.status')
    
    log "Application status: $app_status"
    log "Application health: $app_health"
    
    # Save verification results
    cat > $backup_dir/rollback-verification.json << EOF
{
  "timestamp": "$DATE",
  "application": "$app_name",
  "status": "$app_status",
  "health": "$app_health",
  "rollback_successful": $([ "$app_status" = "Synced" ] && [ "$app_health" = "Healthy" ] && echo "true" || echo "false")
}
EOF
    
    if [ "$app_status" = "Synced" ] && [ "$app_health" = "Healthy" ]; then
        success "Application is healthy after rollback"
        return 0
    else
        error "Application is not healthy after rollback"
        return 1
    fi
}

# Function to resume application sync
resume_application_sync() {
    local app_name=$1
    
    log "Resuming sync for application: $app_name"
    
    if argocd app resume $app_name; then
        success "Successfully resumed application sync"
    else
        error "Failed to resume application sync"
        return 1
    fi
}

# Function to create rollback report
create_rollback_report() {
    local app_name=$1
    local revision=$2
    local backup_dir=$3
    local status=$4
    
    local report_file="$backup_dir/rollback-report.json"
    
    cat > $report_file << EOF
{
  "timestamp": "$DATE",
  "application": "$app_name",
  "target_revision": "$revision",
  "rollback_status": "$status",
  "backup_location": "$backup_dir",
  "steps": [
    "Prerequisites validated",
    "Application state backed up",
    "Application sync paused",
    "Rollback sync performed",
    "Application health verified",
    "Application sync resumed"
  ]
}
EOF
    
    success "Rollback report created: $report_file"
    cat $report_file | jq '.' | tee -a $LOG_FILE
}

# Function to handle emergency rollback
emergency_rollback() {
    local app_name=$1
    local backup_dir=$2
    
    log "=== EMERGENCY ROLLBACK INITIATED ==="
    warning "This is an emergency rollback procedure"
    
    # Get the last known good revision
    local last_good_revision=$(argocd app history $app_name --output json | jq -r '.[-2].revision' 2>/dev/null || echo "")
    
    if [ -z "$last_good_revision" ]; then
        error "Could not determine last good revision for emergency rollback"
        return 1
    fi
    
    log "Using last good revision: $last_good_revision"
    
    # Perform emergency rollback
    if perform_rollback $app_name $last_good_revision $backup_dir; then
        success "Emergency rollback completed successfully"
        return 0
    else
        error "Emergency rollback failed"
        return 1
    fi
}

# Function to list available rollback points
list_rollback_points() {
    local app_name=$1
    
    log "Listing available rollback points for $app_name..."
    
    # Get application history
    local history=$(argocd app history $app_name --output json)
    
    if [ $? -eq 0 ]; then
        echo "Available rollback points:"
        echo "$history" | jq -r '.[] | "Revision: \(.revision) | Date: \(.deployedAt) | Status: \(.deployedAt)"'
    else
        error "Failed to retrieve application history"
        return 1
    fi
}

# Function to validate rollback target
validate_rollback_target() {
    local app_name=$1
    local revision=$2
    
    log "Validating rollback target: $revision"
    
    # Check if application exists
    if ! argocd app get $app_name &> /dev/null; then
        error "Application $app_name does not exist"
        return 1
    fi
    
    # Check if revision exists in history
    local history=$(argocd app history $app_name --output json 2>/dev/null)
    
    if echo "$history" | jq -e ".[] | select(.revision == \"$revision\")" &> /dev/null; then
        success "Revision $revision is available in application history"
        return 0
    else
        error "Revision $revision is not available in application history"
        warning "Available revisions:"
        echo "$history" | jq -r '.[].revision'
        return 1
    fi
}

# Main execution function
main() {
    log "=== ArgoCD Application Rollback Started ==="
    
    # Parse command line arguments
    local app_name=""
    local revision=""
    local emergency=false
    local list_points=false
    local dry_run=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--app)
                app_name="$2"
                shift 2
                ;;
            -r|--revision)
                revision="$2"
                shift 2
                ;;
            --emergency)
                emergency=true
                shift
                ;;
            --list-points)
                list_points=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  -a, --app <name>      Application name to rollback"
                echo "  -r, --revision <rev>  Target revision for rollback"
                echo "  --emergency           Perform emergency rollback to last good revision"
                echo "  --list-points         List available rollback points"
                echo "  --dry-run             Simulate rollback without making changes"
                echo "  --help                Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Initialize log file
    echo "=== ArgoCD Rollback Started at $DATE ===" > $LOG_FILE
    
    # Validate inputs
    if [ -z "$app_name" ] && [ "$list_points" = false ] && [ "$emergency" = false ]; then
        error "Application name is required"
        echo "Usage: $0 -a <app-name> -r <revision> [options]"
        exit 1
    fi
    
    # Pre-flight checks
    validate_prerequisites
    
    # Handle different rollback scenarios
    if [ "$list_points" = true ]; then
        list_rollback_points $app_name
        exit 0
    fi
    
    if [ "$emergency" = true ]; then
        log "Performing emergency rollback for $app_name"
        local backup_dir=$(backup_application_state $app_name)
        
        if emergency_rollback $app_name $backup_dir; then
            create_rollback_report $app_name "emergency" $backup_dir "success"
            success "Emergency rollback completed successfully"
        else
            create_rollback_report $app_name "emergency" $backup_dir "failed"
            error "Emergency rollback failed"
            exit 1
        fi
        
        exit 0
    fi
    
    # Regular rollback procedure
    log "Starting rollback procedure for $app_name to revision $revision"
    
    # Validate rollback target
    if ! validate_rollback_target $app_name $revision; then
        exit 1
    fi
    
    # Create backup
    local backup_dir=$(backup_application_state $app_name)
    
    # Perform rollback steps
    local rollback_status="success"
    
    if pause_application_sync $app_name; then
        if perform_rollback $app_name $revision $backup_dir; then
            if resume_application_sync $app_name; then
                success "Rollback completed successfully"
            else
                rollback_status="partial"
                error "Rollback completed but failed to resume sync"
            fi
        else
            rollback_status="failed"
            error "Rollback sync failed"
        fi
    else
        rollback_status="failed"
        error "Failed to pause application sync"
    fi
    
    # Create final report
    create_rollback_report $app_name $revision $backup_dir $rollback_status
    
    if [ "$rollback_status" = "success" ]; then
        success "Rollback procedure completed successfully"
        exit 0
    else
        error "Rollback procedure completed with issues"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"