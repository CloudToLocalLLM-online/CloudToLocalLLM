#!/bin/bash
# CloudToLocalLLM VPS Deployment Script
# Lightweight VPS-only deployment workflow for cloudtolocalllm.online
# Runs exclusively on the VPS Linux environment

set -euo pipefail

# Script metadata
SCRIPT_VERSION="4.0.0"
SCRIPT_NAME="CloudToLocalLLM VPS Deployment"

# Configuration
PROJECT_DIR="$(pwd)"
COMPOSE_FILE="docker-compose.yml"
BACKUP_DIR="$PROJECT_DIR/backups"
VPS_USER="$(whoami)"
DOMAIN="cloudtolocalllm.online"
APP_URL="https://app.cloudtolocalllm.online"
FLUTTER_BIN="/opt/flutter/bin/flutter"

# Default settings
FORCE=false
VERBOSE=false
SKIP_BACKUP=false
DRY_RUN=false
MAX_RETRIES=3
RETRY_DELAY=5

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

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Show help
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force         Skip safety prompts and proceed automatically
    --verbose       Enable verbose output
    --skip-backup   Skip backup creation (not recommended)
    --dry-run       Show what would be done without executing
    --help          Show this help message

DESCRIPTION:
    Lightweight VPS deployment script that:
    1. Pulls latest changes from Git
    2. Builds Flutter web application on VPS
    3. Manages Docker containers
    4. Verifies deployment health
    5. Validates SSL certificates

EXAMPLES:
    $0                          # Interactive deployment
    $0 --force --verbose        # Automatic deployment with verbose output
    $0 --dry-run               # Preview deployment actions

ENVIRONMENT:
    Must be run on the VPS as the cloudllm user
    Requires: Flutter SDK, Docker, Docker Compose, Git
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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

# Retry function with exponential backoff
retry_command() {
    local cmd="$1"
    local description="$2"
    local retries=0
    local delay=$RETRY_DELAY

    while [[ $retries -lt $MAX_RETRIES ]]; do
        log_verbose "Attempting: $description (attempt $((retries + 1))/$MAX_RETRIES)"

        if eval "$cmd"; then
            log_success "$description completed successfully"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $MAX_RETRIES ]]; then
                log_warning "$description failed, retrying in $delay seconds..."
                sleep $delay
                delay=$((delay * 2))  # Exponential backoff
            else
                log_error "$description failed after $MAX_RETRIES attempts"
                return 1
            fi
        fi
    done
}

# Pre-deployment checks
check_prerequisites() {
    log_step "Checking prerequisites..."

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

    # Check required commands
    local required_commands=("git" "docker" "curl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done

    # Check Docker Compose v2
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose v2 not available (tried 'docker compose')"
        exit 1
    fi

    # Check Flutter separately with full path
    if [[ ! -x "$FLUTTER_BIN" ]]; then
        log_error "Flutter not found or not executable: $FLUTTER_BIN"
        exit 1
    fi

    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon not running or not accessible"
        exit 1
    fi

    # Check compose file
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker compose file not found: $COMPOSE_FILE"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Create backup
create_backup() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        log_warning "Skipping backup creation"
        return 0
    fi

    log_step "Creating deployment backup..."

    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="deployment_backup_$timestamp"
    local backup_path="$BACKUP_DIR/$backup_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create backup at: $backup_path"
        return 0
    fi

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Create backup of current state
    if [[ -d "build/web" ]]; then
        log_verbose "Backing up current web build..."
        cp -r build/web "$backup_path"
        log_success "Backup created: $backup_path"
    else
        log_warning "No existing web build to backup"
    fi
}

# Pull latest changes from Git
pull_latest_changes() {
    log_step "Pulling latest changes from Git..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute git operations"
        return 0
    fi

    # Clean any uncommitted changes (VPS is ephemeral consumer-only)
    log_verbose "Cleaning uncommitted changes..."
    git reset --hard HEAD
    git clean -fd -e certbot/

    # Stash any remaining local changes
    log_verbose "Stashing any local changes..."
    git stash push -m "Auto-stash before deployment $(date)" 2>/dev/null || true

    # Pull latest changes with retry logic
    retry_command "git pull origin master" "Git pull from origin/master"

    log_success "Git pull completed"
}

# Build Flutter web application
build_flutter_web() {
    log_step "Building Flutter web application..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would build Flutter web application"
        return 0
    fi

    # Clean previous build
    log_verbose "Cleaning previous Flutter build..."
    /opt/flutter/bin/flutter clean

    # Get dependencies
    log_verbose "Getting Flutter dependencies..."
    retry_command "/opt/flutter/bin/flutter pub get" "Flutter pub get"

    # Build web application
    log_verbose "Building Flutter web application..."
    local build_cmd="/opt/flutter/bin/flutter build web --release --no-tree-shake-icons"

    if [[ "$VERBOSE" == "true" ]]; then
        build_cmd="$build_cmd --verbose"
    fi

    if ! eval "$build_cmd"; then
        log_error "Flutter web build failed"
        return 1
    fi

    # Verify build output
    if [[ ! -d "build/web" ]] || [[ ! -f "build/web/index.html" ]]; then
        log_error "Flutter build output missing or incomplete"
        return 1
    fi

    log_success "Flutter web build completed"
}

# Container management
manage_containers() {
    log_step "Managing Docker containers..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would manage Docker containers"
        return 0
    fi

    # Stop existing containers
    log_verbose "Stopping existing containers..."
    docker compose -f "$COMPOSE_FILE" down --timeout 30 --remove-orphans 2>/dev/null || true

    # Remove orphaned containers
    log_verbose "Removing orphaned containers..."
    docker container prune -f 2>/dev/null || true

    # Build and start containers
    log_verbose "Building and starting containers..."
    if ! docker compose -f "$COMPOSE_FILE" up -d --build; then
        log_error "Failed to start Docker containers"
        return 1
    fi

    # Wait for containers to stabilize
    log_verbose "Waiting for containers to stabilize..."
    sleep 10

    # Check container status
    local running_containers=$(docker compose -f "$COMPOSE_FILE" ps -q | wc -l)
    local total_containers=$(docker compose -f "$COMPOSE_FILE" config --services | wc -l)

    log_verbose "Container status: $running_containers/$total_containers running"

    if [[ $running_containers -eq $total_containers ]] && [[ $total_containers -gt 0 ]]; then
        log_success "All containers started successfully ($running_containers/$total_containers)"
    else
        log_error "Some containers failed to start ($running_containers/$total_containers)"
        log_info "Container details:"
        docker compose -f "$COMPOSE_FILE" ps
        return 1
    fi
}

# Health checks
perform_health_checks() {
    log_step "Performing health checks..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would perform health checks"
        return 0
    fi

    # Wait for application to be ready
    log_verbose "Waiting for application to be ready..."
    sleep 15

    # Check application accessibility
    log_verbose "Checking application accessibility..."
    local max_attempts=10
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_verbose "Health check attempt $attempt/$max_attempts"

        if curl -k -f -s "$APP_URL" > /dev/null; then
            log_success "Application is accessible at $APP_URL"
            break
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Application not accessible after $max_attempts attempts"
            return 1
        fi

        sleep 5
        ((attempt++))
    done

    # Check SSL certificate
    log_verbose "Checking SSL certificate..."
    if curl -s --connect-timeout 10 "$APP_URL" > /dev/null; then
        log_success "SSL certificate is valid"
    else
        log_warning "SSL certificate check failed (non-blocking)"
    fi

    # Check container health
    log_verbose "Checking container health..."
    local unhealthy_containers=$(docker compose -f "$COMPOSE_FILE" ps --filter "health=unhealthy" -q | wc -l)

    if [[ $unhealthy_containers -eq 0 ]]; then
        log_success "All containers are healthy"
    else
        log_warning "$unhealthy_containers containers are unhealthy"
    fi

    log_success "Health checks completed"
}

# Deployment verification
verify_deployment() {
    log_step "Verifying deployment..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would verify deployment"
        return 0
    fi

    # Check version endpoint
    log_verbose "Checking version endpoint..."
    if curl -k -f -s "$APP_URL/version.json" > /dev/null; then
        local version=$(curl -k -s "$APP_URL/version.json" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
        log_success "Version endpoint accessible: $version"
    else
        log_warning "Version endpoint not accessible (non-blocking)"
    fi

    # Final connectivity test
    log_verbose "Final connectivity test..."
    if curl -k -f -s --max-time 10 "$APP_URL" > /dev/null; then
        log_success "Deployment verification passed"
        return 0
    else
        log_error "Deployment verification failed"
        return 1
    fi
}

# Rollback function
rollback_deployment() {
    log_error "Deployment failed - initiating rollback..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would perform rollback"
        return 0
    fi

    # Stop current containers
    log_verbose "Stopping failed containers..."
    docker compose -f "$COMPOSE_FILE" down --timeout 30 2>/dev/null || true

    # Restore from backup if available
    local latest_backup=$(ls -t "$BACKUP_DIR"/ 2>/dev/null | head -n1)
    if [[ -n "$latest_backup" && -d "$BACKUP_DIR/$latest_backup" ]]; then
        log_verbose "Restoring from backup: $latest_backup"
        rm -rf build/web 2>/dev/null || true
        cp -r "$BACKUP_DIR/$latest_backup" build/web

        # Restart containers with backup
        docker compose -f "$COMPOSE_FILE" up -d 2>/dev/null || true
        log_warning "Rollback completed using backup: $latest_backup"
    else
        log_warning "No backup available for rollback"
    fi
}

# Main deployment function
main() {
    echo "================================================================"
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "Time: $(date)"
    echo "VPS: $DOMAIN"
    echo "User: $(whoami)"
    echo "Directory: $(pwd)"
    echo "================================================================"
    echo

    # Safety prompt (unless --force is used)
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        log_warning "Production deployment starting"
        log_info "Use --force flag for automated/CI environments"
        log_info "Proceeding with deployment in 3 seconds..."
        sleep 3
    fi

    # Execute deployment phases
    local deployment_failed=false

    check_prerequisites || deployment_failed=true

    if [[ "$deployment_failed" != "true" ]]; then
        create_backup || deployment_failed=true
    fi

    if [[ "$deployment_failed" != "true" ]]; then
        pull_latest_changes || deployment_failed=true
    fi

    if [[ "$deployment_failed" != "true" ]]; then
        build_flutter_web || deployment_failed=true
    fi

    if [[ "$deployment_failed" != "true" ]]; then
        manage_containers || deployment_failed=true
    fi

    if [[ "$deployment_failed" != "true" ]]; then
        perform_health_checks || deployment_failed=true
    fi

    if [[ "$deployment_failed" != "true" ]]; then
        verify_deployment || deployment_failed=true
    fi

    # Handle deployment result
    if [[ "$deployment_failed" == "true" ]]; then
        rollback_deployment
        log_error "Deployment failed and rollback attempted"
        exit 1
    else
        echo
        echo "================================================================"
        log_success "🎉 Deployment completed successfully!"
        echo "================================================================"
        log_info "Application URL: $APP_URL"
        log_info "Next steps:"
        log_info "  1. Verify application functionality"
        log_info "  2. Monitor container logs if needed:"
        log_info "     docker compose -f $COMPOSE_FILE logs -f"
        echo
    fi
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    parse_args "$@"

    # Execute main function
    main
fi
