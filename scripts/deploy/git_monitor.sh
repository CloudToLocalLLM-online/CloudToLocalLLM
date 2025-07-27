#!/bin/bash
# CloudToLocalLLM VPS Git Monitoring System
# Autonomous VPS-based Git monitoring for automatic deployment
# Self-contained monitoring system that watches master branch for changes

set -euo pipefail

# Script metadata
SCRIPT_VERSION="4.0.0"
SCRIPT_NAME="CloudToLocalLLM Autonomous Git Monitor"

# Configuration
PROJECT_DIR="/opt/cloudtolocalllm"
SCRIPTS_DIR="$PROJECT_DIR/scripts/deploy"
MONITOR_BRANCH="master"
CHECK_INTERVAL=60  # seconds
LOCK_FILE="/tmp/cloudtolocalllm_git_monitor.lock"
LOG_FILE="/var/log/cloudtolocalllm/git_monitor.log"
STATE_FILE="/var/lib/cloudtolocalllm/git_monitor_state"

# VPS Configuration
VPS_USER="cloudllm"
DOMAIN="cloudtolocalllm.online"
APP_URL="https://app.cloudtolocalllm.online"

# Deployment settings
AUTO_DEPLOY=true
DEPLOYMENT_TIMEOUT=1800  # 30 minutes
MAX_DEPLOYMENT_RETRIES=2
DEPLOYMENT_COOLDOWN=300  # 5 minutes between deployments

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_monitor() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [MONITOR] $1"
    echo -e "${CYAN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

# Show help
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    start       Start the Git monitoring daemon
    stop        Stop the Git monitoring daemon
    status      Show monitoring status
    check       Perform a single check (no daemon)
    install     Install as systemd service
    uninstall   Remove systemd service

OPTIONS:
    --interval SECONDS    Set check interval (default: $CHECK_INTERVAL)
    --no-deploy          Disable automatic deployment
    --verbose            Enable verbose output
    --help               Show this help message

DESCRIPTION:
    Autonomous VPS-based Git monitoring system that watches the local
    Git repository for new commits on the master branch and automatically
    triggers deployment when changes are detected.

    Features:
    - Self-contained monitoring (no external dependencies)
    - Automatic deployment on new commits
    - Deployment cooldown to prevent rapid deployments
    - Lock file to prevent concurrent deployments
    - Comprehensive logging and state tracking
    - Systemd service integration for reliability

EXAMPLES:
    $0 start                    # Start monitoring daemon
    $0 check                    # Single check for changes
    $0 install                  # Install as systemd service
    $0 --interval 30 start      # Monitor every 30 seconds

SYSTEMD SERVICE:
    sudo systemctl enable cloudtolocalllm-git-monitor
    sudo systemctl start cloudtolocalllm-git-monitor
    sudo systemctl status cloudtolocalllm-git-monitor
EOF
}

# Parse command line arguments
COMMAND=""
VERBOSE=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            start|stop|status|check|install|uninstall)
                COMMAND="$1"
                shift
                ;;
            --interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            --no-deploy)
                AUTO_DEPLOY=false
                shift
                ;;
            --verbose)
                VERBOSE=true
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
    
    if [[ -z "$COMMAND" ]]; then
        COMMAND="start"
    fi
}

# Setup directories and files
setup_environment() {
    # Create log directory
    sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    sudo chown "$VPS_USER:$VPS_USER" "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Create state directory
    sudo mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
    sudo chown "$VPS_USER:$VPS_USER" "$(dirname "$STATE_FILE")" 2>/dev/null || true
    
    # Initialize state file if it doesn't exist
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "last_commit=" > "$STATE_FILE"
        echo "last_deployment=0" >> "$STATE_FILE"
        echo "deployment_count=0" >> "$STATE_FILE"
    fi
}

# Get current Git commit hash
get_current_commit() {
    cd "$PROJECT_DIR"
    git rev-parse HEAD 2>/dev/null || echo ""
}

# Get remote commit hash
get_remote_commit() {
    cd "$PROJECT_DIR"
    git fetch origin "$MONITOR_BRANCH" --quiet 2>/dev/null || true
    git rev-parse "origin/$MONITOR_BRANCH" 2>/dev/null || echo ""
}

# Read state from file
read_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
    else
        last_commit=""
        last_deployment=0
        deployment_count=0
    fi
}

# Write state to file
write_state() {
    cat > "$STATE_FILE" << EOF
last_commit=$1
last_deployment=$2
deployment_count=$3
EOF
}

# Check if deployment is allowed (cooldown period)
is_deployment_allowed() {
    read_state
    local current_time=$(date +%s)
    local time_since_last=$((current_time - last_deployment))
    
    if [[ $time_since_last -ge $DEPLOYMENT_COOLDOWN ]]; then
        return 0
    else
        local remaining=$((DEPLOYMENT_COOLDOWN - time_since_last))
        log_warning "Deployment cooldown active: ${remaining}s remaining"
        return 1
    fi
}

# Acquire deployment lock
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            log_warning "Deployment already in progress (PID: $lock_pid)"
            return 1
        else
            log_warning "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    return 0
}

# Release deployment lock
release_lock() {
    rm -f "$LOCK_FILE"
}

# Execute deployment
execute_deployment() {
    local commit_hash="$1"
    local commit_message="$2"
    
    log_info "🚀 Starting automatic deployment for commit: ${commit_hash:0:8}"
    log_info "📝 Commit message: $commit_message"
    
    if ! acquire_lock; then
        return 1
    fi
    
    # Update state
    read_state
    local current_time=$(date +%s)
    local new_count=$((deployment_count + 1))
    write_state "$commit_hash" "$current_time" "$new_count"
    
    # Execute deployment with timeout
    local deployment_script="$SCRIPTS_DIR/complete_deployment.sh"
    local deployment_cmd="timeout $DEPLOYMENT_TIMEOUT $deployment_script --force"
    
    if [[ "$VERBOSE" == "true" ]]; then
        deployment_cmd="$deployment_cmd --verbose"
    fi
    
    log_info "Executing: $deployment_cmd"
    
    if eval "$deployment_cmd"; then
        log_success "✅ Deployment #$new_count completed successfully"
        log_success "🌐 Application available at: $APP_URL"
        release_lock
        return 0
    else
        log_error "❌ Deployment #$new_count failed"
        release_lock
        return 1
    fi
}

# Check for Git changes
check_for_changes() {
    cd "$PROJECT_DIR"
    
    local current_commit=$(get_current_commit)
    local remote_commit=$(get_remote_commit)
    
    if [[ -z "$current_commit" ]] || [[ -z "$remote_commit" ]]; then
        log_error "Unable to get Git commit information"
        return 1
    fi
    
    read_state
    
    # Check if there are new commits
    if [[ "$remote_commit" != "$current_commit" ]]; then
        log_monitor "🔍 New commits detected on $MONITOR_BRANCH branch"
        log_monitor "Current: ${current_commit:0:8} -> Remote: ${remote_commit:0:8}"
        
        # Pull the latest changes
        log_info "📥 Pulling latest changes..."
        if git pull origin "$MONITOR_BRANCH" --quiet; then
            local new_commit=$(get_current_commit)
            local commit_message=$(git log -1 --pretty=format:"%s" "$new_commit" 2>/dev/null || echo "Unknown")
            
            if [[ "$AUTO_DEPLOY" == "true" ]]; then
                if is_deployment_allowed; then
                    execute_deployment "$new_commit" "$commit_message"
                else
                    log_warning "⏳ Deployment skipped due to cooldown period"
                fi
            else
                log_info "📋 Auto-deployment disabled, manual deployment required"
                write_state "$new_commit" "$last_deployment" "$deployment_count"
            fi
        else
            log_error "❌ Failed to pull latest changes"
            return 1
        fi
    else
        if [[ "$VERBOSE" == "true" ]]; then
            log_monitor "✅ No new commits detected (${current_commit:0:8})"
        fi
    fi
    
    return 0
}

# Monitor daemon
start_monitoring() {
    log_info "🎯 Starting Git monitoring daemon"
    log_info "📂 Project: $PROJECT_DIR"
    log_info "🌿 Branch: $MONITOR_BRANCH"
    log_info "⏱️ Interval: ${CHECK_INTERVAL}s"
    log_info "🚀 Auto-deploy: $AUTO_DEPLOY"
    log_info "📝 Log file: $LOG_FILE"
    
    # Initial check
    check_for_changes
    
    # Main monitoring loop
    while true; do
        sleep "$CHECK_INTERVAL"
        check_for_changes || log_warning "Check failed, continuing monitoring..."
    done
}

# Check monitoring status
check_status() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            echo "Status: Deployment in progress (PID: $lock_pid)"
        else
            echo "Status: Stale lock file detected"
        fi
    else
        echo "Status: No active deployment"
    fi
    
    if [[ -f "$STATE_FILE" ]]; then
        echo "State information:"
        cat "$STATE_FILE"
    else
        echo "No state file found"
    fi
    
    local current_commit=$(get_current_commit)
    echo "Current commit: ${current_commit:0:8}"
}

# Install systemd service
install_service() {
    log_info "Installing systemd service..."

    local service_file="/etc/systemd/system/cloudtolocalllm-git-monitor.service"
    local script_path="$(realpath "$0")"

    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=CloudToLocalLLM Autonomous Git Monitor
After=network.target
Wants=network.target

[Service]
Type=simple
User=$VPS_USER
Group=$VPS_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$script_path start --verbose
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cloudtolocalllm-git-monitor

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$PROJECT_DIR /var/log/cloudtolocalllm /var/lib/cloudtolocalllm /tmp

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    log_success "Systemd service installed: $service_file"
    log_info "Enable with: sudo systemctl enable cloudtolocalllm-git-monitor"
    log_info "Start with: sudo systemctl start cloudtolocalllm-git-monitor"
}

# Uninstall systemd service
uninstall_service() {
    log_info "Uninstalling systemd service..."

    local service_file="/etc/systemd/system/cloudtolocalllm-git-monitor.service"

    # Stop and disable service
    sudo systemctl stop cloudtolocalllm-git-monitor 2>/dev/null || true
    sudo systemctl disable cloudtolocalllm-git-monitor 2>/dev/null || true

    # Remove service file
    if [[ -f "$service_file" ]]; then
        sudo rm "$service_file"
        sudo systemctl daemon-reload
        log_success "Systemd service uninstalled"
    else
        log_warning "Service file not found: $service_file"
    fi
}

# Stop monitoring
stop_monitoring() {
    log_info "Stopping Git monitoring..."

    # Kill any running monitor processes
    local pids=$(pgrep -f "git_monitor.sh.*start" 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
        echo "$pids" | xargs kill -TERM 2>/dev/null || true
        sleep 2
        echo "$pids" | xargs kill -KILL 2>/dev/null || true
        log_success "Stopped monitoring processes: $pids"
    else
        log_info "No monitoring processes found"
    fi

    # Remove lock file
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log_info "Removed lock file"
    fi
}

# Validate environment
validate_environment() {
    # Check if running as correct user
    if [[ "$(whoami)" != "$VPS_USER" ]]; then
        log_error "Must be run as $VPS_USER user"
        exit 1
    fi

    # Check if in correct directory
    if [[ ! -d "$PROJECT_DIR" ]]; then
        log_error "Project directory not found: $PROJECT_DIR"
        exit 1
    fi

    # Check if Git repository
    if [[ ! -d "$PROJECT_DIR/.git" ]]; then
        log_error "Not a Git repository: $PROJECT_DIR"
        exit 1
    fi

    # Check required scripts
    local required_scripts=(
        "$SCRIPTS_DIR/complete_deployment.sh"
        "$SCRIPTS_DIR/update_and_deploy.sh"
        "$SCRIPTS_DIR/verify_deployment.sh"
    )

    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_error "Required script not found: $script"
            exit 1
        fi

        if [[ ! -x "$script" ]]; then
            log_error "Script not executable: $script"
            exit 1
        fi
    done
}

# Main function
main() {
    echo "================================================================"
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "Time: $(date)"
    echo "Command: $COMMAND"
    echo "Project: $PROJECT_DIR"
    echo "Branch: $MONITOR_BRANCH"
    echo "User: $(whoami)"
    echo "================================================================"
    echo

    # Setup environment
    setup_environment

    case "$COMMAND" in
        start)
            validate_environment
            start_monitoring
            ;;
        stop)
            stop_monitoring
            ;;
        status)
            check_status
            ;;
        check)
            validate_environment
            check_for_changes
            ;;
        install)
            install_service
            ;;
        uninstall)
            uninstall_service
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# Cleanup on exit
cleanup() {
    if [[ "$COMMAND" == "start" ]]; then
        log_info "🛑 Git monitoring stopped"
        release_lock
    fi
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    parse_args "$@"

    # Execute main function
    main
fi
