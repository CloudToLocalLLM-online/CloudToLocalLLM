#!/bin/bash
# ArgoCD Backup and Restore Script
# Comprehensive backup and restore procedures for CloudToLocalLLM ArgoCD deployment
# Usage: ./argocd-backup-restore.sh [backup|restore] [options]

set -e

# Configuration
ARGOCD_NAMESPACE="argocd"
BACKUP_BASE_DIR="/backup/argocd"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/argocd-backup-restore.log"

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
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if argocd CLI is available
    if ! command -v argocd &> /dev/null; then
        error "argocd CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check ArgoCD connection
    if ! argocd version --client &> /dev/null; then
        error "Cannot connect to ArgoCD server"
        exit 1
    fi
    
    success "Prerequisites validated"
}

# Function to create backup directory
create_backup_directory() {
    local backup_type=$1
    local backup_dir="$BACKUP_BASE_DIR/$backup_type/$DATE"
    
    mkdir -p $backup_dir
    
    success "Created backup directory: $backup_dir"
    echo $backup_dir
}

# Function to backup ArgoCD applications
backup_applications() {
    local backup_dir=$1
    
    log "Backing up ArgoCD applications..."
    
    # Backup all applications
    kubectl get applications -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/applications.yaml
    
    # Backup application summaries with metadata
    argocd app list --output json > $backup_dir/applications_summary.json
    
    # Backup individual application details
    mkdir -p $backup_dir/applications_details
    argocd app list --output json | jq -r '.[].metadata.name' | while read app; do
        argocd app get $app --output yaml > $backup_dir/applications_details/${app}.yaml
    done
    
    success "Applications backed up successfully"
}

# Function to backup ApplicationSets
backup_applicationsets() {
    local backup_dir=$1
    
    log "Backing up ArgoCD ApplicationSets..."
    
    # Backup all application sets
    kubectl get applicationsets -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/applicationsets.yaml
    
    # Backup application set summaries
    kubectl get applicationsets -n $ARGOCD_NAMESPACE -o json > $backup_dir/applicationsets_summary.json
    
    # Backup individual application set details
    mkdir -p $backup_dir/applicationsets_details
    kubectl get applicationsets -n $ARGOCD_NAMESPACE -o json | jq -r '.items[].metadata.name' | while read appset; do
        kubectl get applicationset $appset -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/applicationsets_details/${appset}.yaml
    done
    
    success "ApplicationSets backed up successfully"
}

# Function to backup AppProjects
backup_appprojects() {
    local backup_dir=$1
    
    log "Backing up ArgoCD AppProjects..."
    
    # Backup all app projects
    kubectl get appprojects -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/appprojects.yaml
    
    # Backup app project summaries
    kubectl get appprojects -n $ARGOCD_NAMESPACE -o json > $backup_dir/appprojects_summary.json
    
    # Backup individual app project details
    mkdir -p $backup_dir/appprojects_details
    kubectl get appprojects -n $ARGOCD_NAMESPACE -o json | jq -r '.items[].metadata.name' | while read project; do
        kubectl get appproject $project -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/appprojects_details/${project}.yaml
    done
    
    success "AppProjects backed up successfully"
}

# Function to backup ConfigMaps
backup_configmaps() {
    local backup_dir=$1
    
    log "Backing up ConfigMaps..."
    
    # Backup all configmaps in argocd namespace
    kubectl get configmaps -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/configmaps.yaml
    
    # Backup specific ArgoCD configmaps
    local argocd_configmaps=("argocd-cm" "argocd-rbac-cm" "argocd-ssh-known-hosts-cm" "argocd-tls-certs-cm")
    
    mkdir -p $backup_dir/configmaps_details
    for cm in "${argocd_configmaps[@]}"; do
        if kubectl get configmap $cm -n $ARGOCD_NAMESPACE &> /dev/null; then
            kubectl get configmap $cm -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/configmaps_details/${cm}.yaml
        fi
    done
    
    success "ConfigMaps backed up successfully"
}

# Function to backup Secrets
backup_secrets() {
    local backup_dir=$1
    
    log "Backing up Secrets..."
    
    # Backup all secrets in argocd namespace
    kubectl get secrets -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/secrets.yaml
    
    # Backup specific ArgoCD secrets
    local argocd_secrets=("argocd-initial-admin-secret" "argocd-secret")
    
    mkdir -p $backup_dir/secrets_details
    for secret in "${argocd_secrets[@]}"; do
        if kubectl get secret $secret -n $ARGOCD_NAMESPACE &> /dev/null; then
            kubectl get secret $secret -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/secrets_details/${secret}.yaml
        fi
    done
    
    success "Secrets backed up successfully"
}

# Function to backup RBAC configuration
backup_rbac() {
    local backup_dir=$1
    
    log "Backing up RBAC configuration..."
    
    # Backup RBAC roles and role bindings
    kubectl get roles -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/roles.yaml
    kubectl get rolebindings -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/rolebindings.yaml
    kubectl get clusterroles -o yaml | grep -A 1000 -B 10 "argocd" > $backup_dir/clusterroles.yaml
    kubectl get clusterrolebindings -o yaml | grep -A 1000 -B 10 "argocd" > $backup_dir/clusterrolebindings.yaml
    
    success "RBAC configuration backed up successfully"
}

# Function to backup persistent volumes
backup_persistent_volumes() {
    local backup_dir=$1
    
    log "Backing up Persistent Volumes..."
    
    # Backup PV and PVC information
    kubectl get pv -o yaml > $backup_dir/persistentvolumes.yaml
    kubectl get pvc -n $ARGOCD_NAMESPACE -o yaml > $backup_dir/persistentvolumeclaims.yaml
    
    success "Persistent Volumes backed up successfully"
}

# Function to create backup manifest
create_backup_manifest() {
    local backup_dir=$1
    local backup_type=$2
    
    local manifest_file="$backup_dir/backup-manifest.json"
    
    cat > $manifest_file << EOF
{
  "backup_type": "$backup_type",
  "timestamp": "$DATE",
  "argocd_namespace": "$ARGOCD_NAMESPACE",
  "backup_components": [
    "applications",
    "applicationsets", 
    "appprojects",
    "configmaps",
    "secrets",
    "rbac",
    "persistent_volumes"
  ],
  "backup_files": {
    "applications": "applications.yaml",
    "applications_summary": "applications_summary.json",
    "applicationsets": "applicationsets.yaml",
    "appprojects": "appprojects.yaml",
    "configmaps": "configmaps.yaml",
    "secrets": "secrets.yaml",
    "roles": "roles.yaml",
    "rolebindings": "rolebindings.yaml",
    "clusterroles": "clusterroles.yaml",
    "clusterrolebindings": "clusterrolebindings.yaml",
    "persistentvolumes": "persistentvolumes.yaml",
    "persistentvolumeclaims": "persistentvolumeclaims.yaml"
  },
  "restore_instructions": "Use ./argocd-backup-restore.sh restore $backup_dir"
}
EOF
    
    success "Backup manifest created: $manifest_file"
}

# Function to perform full backup
perform_full_backup() {
    log "=== Starting Full ArgoCD Backup ==="
    
    local backup_dir=$(create_backup_directory "full")
    
    # Perform all backup operations
    backup_applications $backup_dir
    backup_applicationsets $backup_dir
    backup_appprojects $backup_dir
    backup_configmaps $backup_dir
    backup_secrets $backup_dir
    backup_rbac $backup_dir
    backup_persistent_volumes $backup_dir
    
    # Create backup manifest
    create_backup_manifest $backup_dir "full"
    
    # Create backup summary
    local summary_file="$backup_dir/backup-summary.txt"
    cat > $summary_file << EOF
ArgoCD Full Backup Summary
==========================
Backup Date: $DATE
Backup Directory: $backup_dir
Components Backed Up:
- Applications
- ApplicationSets
- AppProjects
- ConfigMaps
- Secrets
- RBAC Configuration
- Persistent Volumes

Total Files: $(find $backup_dir -type f | wc -l)
Backup Size: $(du -sh $backup_dir | cut -f1)
EOF
    
    success "Full backup completed successfully"
    log "Backup location: $backup_dir"
    log "Backup summary: $summary_file"
    
    # Display backup summary
    cat $summary_file | tee -a $LOG_FILE
}

# Function to perform selective backup
perform_selective_backup() {
    local backup_dir=$1
    local components=$2
    
    log "=== Starting Selective ArgoCD Backup ==="
    log "Components to backup: $components"
    
    # Parse components list
    IFS=',' read -ra COMPONENT_ARRAY <<< "$components"
    
    for component in "${COMPONENT_ARRAY[@]}"; do
        case $component in
            "applications")
                backup_applications $backup_dir
                ;;
            "applicationsets")
                backup_applicationsets $backup_dir
                ;;
            "appprojects")
                backup_appprojects $backup_dir
                ;;
            "configmaps")
                backup_configmaps $backup_dir
                ;;
            "secrets")
                backup_secrets $backup_dir
                ;;
            "rbac")
                backup_rbac $backup_dir
                ;;
            "persistent_volumes")
                backup_persistent_volumes $backup_dir
                ;;
            *)
                warning "Unknown component: $component"
                ;;
        esac
    done
    
    # Create backup manifest
    create_backup_manifest $backup_dir "selective"
    
    success "Selective backup completed successfully"
    log "Backup location: $backup_dir"
}

# Function to restore applications
restore_applications() {
    local backup_dir=$1
    
    log "Restoring ArgoCD applications..."
    
    if [ -f "$backup_dir/applications.yaml" ]; then
        kubectl apply -f $backup_dir/applications.yaml
        success "Applications restored successfully"
    else
        warning "Applications backup file not found"
    fi
}

# Function to restore ApplicationSets
restore_applicationsets() {
    local backup_dir=$1
    
    log "Restoring ArgoCD ApplicationSets..."
    
    if [ -f "$backup_dir/applicationsets.yaml" ]; then
        kubectl apply -f $backup_dir/applicationsets.yaml
        success "ApplicationSets restored successfully"
    else
        warning "ApplicationSets backup file not found"
    fi
}

# Function to restore AppProjects
restore_appprojects() {
    local backup_dir=$1
    
    log "Restoring ArgoCD AppProjects..."
    
    if [ -f "$backup_dir/appprojects.yaml" ]; then
        kubectl apply -f $backup_dir/appprojects.yaml
        success "AppProjects restored successfully"
    else
        warning "AppProjects backup file not found"
    fi
}

# Function to restore ConfigMaps
restore_configmaps() {
    local backup_dir=$1
    
    log "Restoring ConfigMaps..."
    
    if [ -f "$backup_dir/configmaps.yaml" ]; then
        kubectl apply -f $backup_dir/configmaps.yaml
        success "ConfigMaps restored successfully"
    else
        warning "ConfigMaps backup file not found"
    fi
}

# Function to restore Secrets
restore_secrets() {
    local backup_dir=$1
    
    log "Restoring Secrets..."
    
    if [ -f "$backup_dir/secrets.yaml" ]; then
        kubectl apply -f $backup_dir/secrets.yaml
        success "Secrets restored successfully"
    else
        warning "Secrets backup file not found"
    fi
}

# Function to restore RBAC
restore_rbac() {
    local backup_dir=$1
    
    log "Restoring RBAC configuration..."
    
    if [ -f "$backup_dir/roles.yaml" ]; then
        kubectl apply -f $backup_dir/roles.yaml
    fi
    
    if [ -f "$backup_dir/rolebindings.yaml" ]; then
        kubectl apply -f $backup_dir/rolebindings.yaml
    fi
    
    if [ -f "$backup_dir/clusterroles.yaml" ]; then
        kubectl apply -f $backup_dir/clusterroles.yaml
    fi
    
    if [ -f "$backup_dir/clusterrolebindings.yaml" ]; then
        kubectl apply -f $backup_dir/clusterrolebindings.yaml
    fi
    
    success "RBAC configuration restored successfully"
}

# Function to perform full restore
perform_full_restore() {
    local backup_dir=$1
    
    log "=== Starting Full ArgoCD Restore ==="
    log "Restore source: $backup_dir"
    
    # Validate backup directory
    if [ ! -d "$backup_dir" ]; then
        error "Backup directory does not exist: $backup_dir"
        exit 1
    fi
    
    # Check for backup manifest
    if [ -f "$backup_dir/backup-manifest.json" ]; then
        log "Validating backup manifest..."
        local backup_type=$(cat $backup_dir/backup-manifest.json | jq -r '.backup_type')
        log "Backup type: $backup_type"
    fi
    
    # Perform restore operations in order
    restore_appprojects $backup_dir
    restore_configmaps $backup_dir
    restore_secrets $backup_dir
    restore_rbac $backup_dir
    restore_applicationsets $backup_dir
    restore_applications $backup_dir
    
    success "Full restore completed successfully"
    
    # Verify restore
    log "Verifying restore..."
    argocd app list | tee -a $LOG_FILE
}

# Function to perform selective restore
perform_selective_restore() {
    local backup_dir=$1
    local components=$2
    
    log "=== Starting Selective ArgoCD Restore ==="
    log "Components to restore: $components"
    log "Restore source: $backup_dir"
    
    # Parse components list
    IFS=',' read -ra COMPONENT_ARRAY <<< "$components"
    
    for component in "${COMPONENT_ARRAY[@]}"; do
        case $component in
            "applications")
                restore_applications $backup_dir
                ;;
            "applicationsets")
                restore_applicationsets $backup_dir
                ;;
            "appprojects")
                restore_appprojects $backup_dir
                ;;
            "configmaps")
                restore_configmaps $backup_dir
                ;;
            "secrets")
                restore_secrets $backup_dir
                ;;
            "rbac")
                restore_rbac $backup_dir
                ;;
            *)
                warning "Unknown component: $component"
                ;;
        esac
    done
    
    success "Selective restore completed successfully"
}

# Function to list available backups
list_backups() {
    log "Listing available backups..."
    
    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        warning "No backup directory found: $BACKUP_BASE_DIR"
        return 0
    fi
    
    echo "Available backups:"
    find $BACKUP_BASE_DIR -name "backup-manifest.json" | while read manifest; do
        local backup_dir=$(dirname $manifest)
        local backup_info=$(cat $manifest | jq -r '"\(.backup_type) backup from \(.timestamp)"')
        echo "  $backup_dir: $backup_info"
    done
}

# Function to clean old backups
clean_old_backups() {
    local retention_days=$1
    
    log "Cleaning backups older than $retention_days days..."
    
    if [ -z "$retention_days" ]; then
        error "Retention days not specified"
        exit 1
    fi
    
    find $BACKUP_BASE_DIR -type d -mtime +$retention_days -exec rm -rf {} \;
    
    success "Old backups cleaned successfully"
}

# Main execution function
main() {
    log "=== ArgoCD Backup and Restore Started ==="
    
    # Parse command line arguments
    local operation=""
    local backup_dir=""
    local components=""
    local retention_days=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            backup)
                operation="backup"
                shift
                ;;
            restore)
                operation="restore"
                shift
                ;;
            --type)
                components="$2"
                shift 2
                ;;
            --dir)
                backup_dir="$2"
                shift 2
                ;;
            --list)
                list_backups
                exit 0
                ;;
            --clean)
                retention_days="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [backup|restore] [options]"
                echo "Operations:"
                echo "  backup                    Perform full backup"
                echo "  restore <backup_dir>      Restore from backup"
                echo "  --list                    List available backups"
                echo "  --clean <days>            Clean backups older than specified days"
                echo ""
                echo "Options:"
                echo "  --type <components>       Comma-separated list of components to backup/restore"
                echo "                            (applications,applicationsets,appprojects,configmaps,secrets,rbac,persistent_volumes)"
                echo "  --dir <backup_dir>        Specify backup directory for restore operation"
                echo "  --help                    Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Initialize log file
    echo "=== ArgoCD Backup and Restore Started at $DATE ===" > $LOG_FILE
    
    # Pre-flight checks
    validate_prerequisites
    
    # Execute operations
    case $operation in
        "backup")
            if [ -n "$components" ]; then
                local backup_dir=$(create_backup_directory "selective")
                perform_selective_backup $backup_dir "$components"
            else
                perform_full_backup
            fi
            ;;
        "restore")
            if [ -z "$backup_dir" ]; then
                error "Backup directory required for restore operation"
                exit 1
            fi
            
            if [ -n "$components" ]; then
                perform_selective_restore $backup_dir "$components"
            else
                perform_full_restore $backup_dir
            fi
            ;;
        "")
            error "No operation specified. Use 'backup' or 'restore'"
            exit 1
            ;;
        *)
            error "Unknown operation: $operation"
            exit 1
            ;;
    esac
    
    success "Operation completed successfully"
}

# Run main function with all arguments
main "$@"