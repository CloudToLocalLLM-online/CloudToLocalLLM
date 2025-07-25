#!/bin/bash
# CloudToLocalLLM VPS Automation Installation Script
# Sets up the complete Augment agent-powered VPS deployment system
# Installs Git monitoring, deployment scripts, and systemd services

set -euo pipefail

# Script metadata
SCRIPT_VERSION="4.0.0"
SCRIPT_NAME="CloudToLocalLLM VPS Automation Installer"

# Configuration
PROJECT_DIR="/opt/cloudtolocalllm"
SCRIPTS_DIR="$PROJECT_DIR/scripts/deploy"
VPS_USER="cloudllm"
DOMAIN="cloudtolocalllm.online"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Show help
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --install-service    Install Git monitoring as systemd service
    --enable-service     Enable and start the systemd service
    --test-deployment    Run deployment test after installation
    --help              Show this help message

DESCRIPTION:
    Sets up the complete VPS automation system:
    1. Validates VPS environment and prerequisites
    2. Sets up deployment scripts and permissions
    3. Configures Git monitoring system
    4. Optionally installs systemd service
    5. Tests the deployment pipeline

COMPONENTS INSTALLED:
    - update_and_deploy.sh      (Core VPS deployment)
    - complete_deployment.sh    (Enhanced deployment with rollback)
    - verify_deployment.sh      (Deployment verification)
    - sync_versions.sh          (Version synchronization)
    - git_monitor.sh           (Augment agent Git monitoring)

SYSTEMD SERVICE:
    cloudtolocalllm-git-monitor.service
    - Monitors Git repository for changes
    - Automatically triggers deployments
    - Comprehensive logging and error handling

EXAMPLES:
    $0                          # Basic installation
    $0 --install-service        # Install with systemd service
    $0 --install-service --enable-service --test-deployment
EOF
}

# Parse command line arguments
INSTALL_SERVICE=false
ENABLE_SERVICE=false
TEST_DEPLOYMENT=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-service)
                INSTALL_SERVICE=true
                shift
                ;;
            --enable-service)
                ENABLE_SERVICE=true
                shift
                ;;
            --test-deployment)
                TEST_DEPLOYMENT=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate VPS environment
validate_environment() {
    log_step "Validating VPS environment..."
    
    # Check if running as correct user
    if [[ "$(whoami)" != "$VPS_USER" ]]; then
        log_error "Must be run as $VPS_USER user"
        exit 1
    fi
    
    # Check if in correct directory
    if [[ "$(pwd)" != "$PROJECT_DIR" ]]; then
        log_error "Must be run from $PROJECT_DIR directory"
        exit 1
    fi
    
    # Check if Git repository
    if [[ ! -d "$PROJECT_DIR/.git" ]]; then
        log_error "Not a Git repository: $PROJECT_DIR"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("git" "docker" "curl" "systemctl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done

    # Check Flutter installation
    if ! /opt/flutter/bin/flutter --version &> /dev/null; then
        log_error "Flutter not properly installed at /opt/flutter/bin/flutter"
        exit 1
    fi

    # Check Docker Compose (v2 syntax)
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose not available (tried 'docker compose')"
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon not running or not accessible"
        exit 1
    fi
    
    # Check Flutter installation
    if ! /opt/flutter/bin/flutter --version &> /dev/null; then
        log_error "Flutter not properly installed at /opt/flutter/bin/flutter"
        exit 1
    fi
    
    log_success "VPS environment validation passed"
}

# Setup directories and permissions
setup_directories() {
    log_step "Setting up directories and permissions..."
    
    # Create log directory
    sudo mkdir -p /var/log/cloudtolocalllm
    sudo chown "$VPS_USER:$VPS_USER" /var/log/cloudtolocalllm
    sudo chmod 755 /var/log/cloudtolocalllm
    
    # Create state directory
    sudo mkdir -p /var/lib/cloudtolocalllm
    sudo chown "$VPS_USER:$VPS_USER" /var/lib/cloudtolocalllm
    sudo chmod 755 /var/lib/cloudtolocalllm
    
    # Ensure scripts directory exists and has correct permissions
    mkdir -p "$SCRIPTS_DIR"
    chmod 755 "$SCRIPTS_DIR"
    
    log_success "Directories and permissions configured"
}

# Validate deployment scripts
validate_scripts() {
    log_step "Validating deployment scripts..."
    
    local required_scripts=(
        "$SCRIPTS_DIR/update_and_deploy.sh"
        "$SCRIPTS_DIR/complete_deployment.sh"
        "$SCRIPTS_DIR/verify_deployment.sh"
        "$SCRIPTS_DIR/sync_versions.sh"
        "$SCRIPTS_DIR/git_monitor.sh"
    )
    
    local missing_scripts=()
    local non_executable_scripts=()
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            missing_scripts+=("$(basename "$script")")
        elif [[ ! -x "$script" ]]; then
            non_executable_scripts+=("$(basename "$script")")
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_error "Missing scripts: ${missing_scripts[*]}"
        exit 1
    fi
    
    if [[ ${#non_executable_scripts[@]} -gt 0 ]]; then
        log_warning "Making scripts executable: ${non_executable_scripts[*]}"
        for script in "${required_scripts[@]}"; do
            chmod +x "$script" 2>/dev/null || true
        done
    fi
    
    log_success "All deployment scripts validated"
}

# Test deployment pipeline
test_deployment() {
    log_step "Testing deployment pipeline..."
    
    # Test version synchronization
    log_info "Testing version synchronization..."
    if "$SCRIPTS_DIR/sync_versions.sh" --check-only; then
        log_success "Version synchronization test passed"
    else
        log_warning "Version synchronization test failed (non-blocking)"
    fi
    
    # Test deployment verification
    log_info "Testing deployment verification..."
    if "$SCRIPTS_DIR/verify_deployment.sh"; then
        log_success "Deployment verification test passed"
    else
        log_warning "Deployment verification test failed (non-blocking)"
    fi
    
    # Test Git monitoring (single check)
    log_info "Testing Git monitoring..."
    if "$SCRIPTS_DIR/git_monitor.sh" check; then
        log_success "Git monitoring test passed"
    else
        log_warning "Git monitoring test failed (non-blocking)"
    fi
    
    log_success "Deployment pipeline testing completed"
}

# Install systemd service
install_systemd_service() {
    log_step "Installing systemd service..."
    
    if "$SCRIPTS_DIR/git_monitor.sh" install; then
        log_success "Systemd service installed successfully"
        
        if [[ "$ENABLE_SERVICE" == "true" ]]; then
            log_info "Enabling and starting service..."
            sudo systemctl enable cloudtolocalllm-git-monitor
            sudo systemctl start cloudtolocalllm-git-monitor
            
            # Wait a moment and check status
            sleep 2
            if sudo systemctl is-active --quiet cloudtolocalllm-git-monitor; then
                log_success "Service is running successfully"
            else
                log_error "Service failed to start"
                sudo systemctl status cloudtolocalllm-git-monitor
                exit 1
            fi
        fi
    else
        log_error "Failed to install systemd service"
        exit 1
    fi
}

# Display installation summary
show_summary() {
    echo
    echo "================================================================"
    log_success "🎉 VPS AUTOMATION INSTALLATION COMPLETED"
    echo "================================================================"
    echo
    echo "📋 Installed Components:"
    echo "  ✅ Core deployment scripts"
    echo "  ✅ Git monitoring system"
    echo "  ✅ Directory structure and permissions"
    
    if [[ "$INSTALL_SERVICE" == "true" ]]; then
        echo "  ✅ Systemd service"
    fi
    
    echo
    echo "🚀 Available Commands:"
    echo "  Manual deployment:     $SCRIPTS_DIR/complete_deployment.sh --force"
    echo "  Quick deployment:      $SCRIPTS_DIR/update_and_deploy.sh --force"
    echo "  Verify deployment:     $SCRIPTS_DIR/verify_deployment.sh"
    echo "  Sync versions:         $SCRIPTS_DIR/sync_versions.sh"
    echo "  Git monitoring:        $SCRIPTS_DIR/git_monitor.sh start"
    
    if [[ "$INSTALL_SERVICE" == "true" ]]; then
        echo
        echo "🔧 Systemd Service Management:"
        echo "  Status:    sudo systemctl status cloudtolocalllm-git-monitor"
        echo "  Start:     sudo systemctl start cloudtolocalllm-git-monitor"
        echo "  Stop:      sudo systemctl stop cloudtolocalllm-git-monitor"
        echo "  Logs:      sudo journalctl -u cloudtolocalllm-git-monitor -f"
    fi
    
    echo
    echo "📝 Log Files:"
    echo "  Git Monitor:   /var/log/cloudtolocalllm/git_monitor.log"
    echo "  State File:    /var/lib/cloudtolocalllm/git_monitor_state"
    
    echo
    echo "🌐 Application URL: https://app.cloudtolocalllm.online"
    echo "================================================================"
}

# Main function
main() {
    echo "================================================================"
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "Time: $(date)"
    echo "VPS: $DOMAIN"
    echo "User: $(whoami)"
    echo "Directory: $(pwd)"
    echo "================================================================"
    echo "Configuration:"
    echo "  Install Service: $INSTALL_SERVICE"
    echo "  Enable Service: $ENABLE_SERVICE"
    echo "  Test Deployment: $TEST_DEPLOYMENT"
    echo "================================================================"
    echo
    
    # Execute installation phases
    validate_environment
    setup_directories
    validate_scripts
    
    if [[ "$TEST_DEPLOYMENT" == "true" ]]; then
        test_deployment
    fi
    
    if [[ "$INSTALL_SERVICE" == "true" ]]; then
        install_systemd_service
    fi
    
    show_summary
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    parse_args "$@"
    
    # Execute main function
    main
fi
