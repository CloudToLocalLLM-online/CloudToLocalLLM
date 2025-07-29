#!/bin/bash

# CloudToLocalLLM Enhanced Tunnel System Deployment Script
# Deploys the secure tunnel backend, web interface, and desktop client components
# with comprehensive validation and rollback capabilities

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="/var/log/cloudtolocalllm/tunnel_deployment.log"
BACKUP_DIR="/opt/cloudtolocalllm/backups/tunnel"
DEPLOYMENT_TIMEOUT=600  # 10 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Deployment failed at line $line_number with exit code $exit_code"
    log_error "Starting automatic rollback..."
    rollback_deployment
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Parse command line arguments
FORCE_DEPLOY=false
SKIP_TESTS=false
SKIP_BACKUP=false
ENVIRONMENT="production"

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_DEPLOY=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --force         Force deployment without confirmation"
            echo "  --skip-tests    Skip test execution"
            echo "  --skip-backup   Skip backup creation"
            echo "  --environment   Target environment (default: production)"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$BACKUP_DIR"

log_info "Starting CloudToLocalLLM Enhanced Tunnel System Deployment"
log_info "Environment: $ENVIRONMENT"
log_info "Force deploy: $FORCE_DEPLOY"
log_info "Skip tests: $SKIP_TESTS"
log_info "Skip backup: $SKIP_BACKUP"

# Pre-deployment checks
check_prerequisites() {
    log_step "Checking deployment prerequisites..."
    
    # Check if running as correct user
    if [[ "$USER" != "cloudllm" ]] && [[ "$EUID" -ne 0 ]]; then
        log_error "This script must be run as 'cloudllm' user or root"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # Check PostgreSQL connection
    if ! docker-compose exec -T postgres pg_isready &> /dev/null; then
        log_error "PostgreSQL database is not accessible"
        exit 1
    fi
    
    # Check disk space (require at least 2GB free)
    local available_space=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 2097152 ]]; then  # 2GB in KB
        log_error "Insufficient disk space. At least 2GB required."
        exit 1
    fi
    
    # Check environment variables
    local required_vars=("AUTH0_DOMAIN" "AUTH0_AUDIENCE" "DB_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Create backup
create_backup() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        log_info "Skipping backup creation"
        return 0
    fi
    
    log_step "Creating deployment backup..."
    
    local backup_timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/tunnel_backup_$backup_timestamp"
    
    mkdir -p "$backup_path"
    
    # Backup current tunnel system files
    if [[ -d "$PROJECT_ROOT/services/api-backend/tunnel" ]]; then
        cp -r "$PROJECT_ROOT/services/api-backend/tunnel" "$backup_path/"
    fi
    
    if [[ -d "$PROJECT_ROOT/services/api-backend/auth" ]]; then
        cp -r "$PROJECT_ROOT/services/api-backend/auth" "$backup_path/"
    fi
    
    if [[ -d "$PROJECT_ROOT/services/api-backend/database" ]]; then
        cp -r "$PROJECT_ROOT/services/api-backend/database" "$backup_path/"
    fi
    
    # Backup database schema
    docker-compose exec -T postgres pg_dump -U postgres cloudtolocalllm > "$backup_path/database_backup.sql"
    
    # Backup Docker Compose configuration
    cp "$PROJECT_ROOT/docker-compose.yml" "$backup_path/"
    
    # Create backup manifest
    cat > "$backup_path/manifest.json" << EOF
{
    "timestamp": "$backup_timestamp",
    "environment": "$ENVIRONMENT",
    "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "backup_type": "tunnel_system",
    "files": [
        "tunnel/",
        "auth/",
        "database/",
        "database_backup.sql",
        "docker-compose.yml"
    ]
}
EOF
    
    echo "$backup_path" > "$BACKUP_DIR/latest_backup.txt"
    
    log_success "Backup created at $backup_path"
}

# Run tests
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        log_info "Skipping test execution"
        return 0
    fi
    
    log_step "Running tunnel system tests..."
    
    cd "$PROJECT_ROOT/services/api-backend"
    
    # Install dependencies if needed
    if [[ ! -d "node_modules" ]] || [[ "package.json" -nt "node_modules" ]]; then
        log_info "Installing Node.js dependencies..."
        npm ci
    fi
    
    # Run unit tests
    log_info "Running unit tests..."
    npm run test:tunnel:unit
    
    # Run integration tests
    log_info "Running integration tests..."
    npm run test:tunnel:integration
    
    # Run security tests
    log_info "Running security tests..."
    npm run test:tunnel:security
    
    log_success "All tests passed"
}

# Deploy tunnel backend
deploy_tunnel_backend() {
    log_step "Deploying tunnel backend..."
    
    cd "$PROJECT_ROOT"
    
    # Build and deploy API backend with tunnel enhancements
    log_info "Building tunnel backend container..."
    docker-compose build api-backend
    
    # Run database migrations
    log_info "Running database migrations..."
    docker-compose exec -T api-backend npm run db:migrate
    
    # Validate database schema
    log_info "Validating database schema..."
    docker-compose exec -T api-backend npm run db:validate
    
    # Restart API backend with new tunnel system
    log_info "Restarting API backend service..."
    docker-compose up -d api-backend
    
    # Wait for service to be ready
    log_info "Waiting for tunnel backend to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s "http://localhost:8080/health" > /dev/null; then
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Tunnel backend failed to start within timeout"
            return 1
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting for tunnel backend..."
        sleep 10
        ((attempt++))
    done
    
    log_success "Tunnel backend deployed successfully"
}

# Deploy web interface
deploy_web_interface() {
    log_step "Deploying web interface..."
    
    cd "$PROJECT_ROOT"
    
    # Build Flutter web application
    log_info "Building Flutter web application..."
    flutter build web --release
    
    # Update web container
    log_info "Updating web container..."
    docker-compose build webapp
    docker-compose up -d webapp
    
    # Wait for web interface to be ready
    log_info "Waiting for web interface to be ready..."
    local max_attempts=20
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s "https://app.cloudtolocalllm.online" > /dev/null; then
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Web interface failed to start within timeout"
            return 1
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting for web interface..."
        sleep 5
        ((attempt++))
    done
    
    log_success "Web interface deployed successfully"
}

# Validate deployment
validate_deployment() {
    log_step "Validating tunnel system deployment..."
    
    # Check tunnel backend health
    log_info "Checking tunnel backend health..."
    local backend_health=$(curl -s "http://localhost:8080/health" | jq -r '.status' 2>/dev/null || echo "error")
    if [[ "$backend_health" != "healthy" ]]; then
        log_error "Tunnel backend health check failed"
        return 1
    fi
    
    # Check WebSocket endpoint
    log_info "Checking WebSocket tunnel endpoint..."
    if ! curl -f -s -H "Connection: Upgrade" -H "Upgrade: websocket" "http://localhost:8080/ws/tunnel" > /dev/null; then
        log_error "WebSocket tunnel endpoint is not accessible"
        return 1
    fi
    
    # Check database connectivity
    log_info "Checking database connectivity..."
    local db_stats=$(docker-compose exec -T api-backend npm run db:stats 2>/dev/null || echo "error")
    if [[ "$db_stats" == "error" ]]; then
        log_error "Database connectivity check failed"
        return 1
    fi
    
    # Check web interface
    log_info "Checking web interface..."
    local web_status=$(curl -s -o /dev/null -w "%{http_code}" "https://app.cloudtolocalllm.online")
    if [[ "$web_status" != "200" ]]; then
        log_error "Web interface is not accessible (HTTP $web_status)"
        return 1
    fi
    
    # Check SSL certificates
    log_info "Checking SSL certificates..."
    local cert_expiry=$(echo | openssl s_client -servername app.cloudtolocalllm.online -connect app.cloudtolocalllm.online:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
    local cert_expiry_epoch=$(date -d "$cert_expiry" +%s 2>/dev/null || echo "0")
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (cert_expiry_epoch - current_epoch) / 86400 ))
    
    if [[ $days_until_expiry -lt 30 ]]; then
        log_warning "SSL certificate expires in $days_until_expiry days"
    fi
    
    log_success "Deployment validation completed successfully"
}

# Rollback deployment
rollback_deployment() {
    log_step "Rolling back tunnel system deployment..."
    
    if [[ ! -f "$BACKUP_DIR/latest_backup.txt" ]]; then
        log_error "No backup found for rollback"
        return 1
    fi
    
    local backup_path=$(cat "$BACKUP_DIR/latest_backup.txt")
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory not found: $backup_path"
        return 1
    fi
    
    log_info "Restoring from backup: $backup_path"
    
    # Stop services
    docker-compose down
    
    # Restore files
    if [[ -d "$backup_path/tunnel" ]]; then
        rm -rf "$PROJECT_ROOT/services/api-backend/tunnel"
        cp -r "$backup_path/tunnel" "$PROJECT_ROOT/services/api-backend/"
    fi
    
    if [[ -d "$backup_path/auth" ]]; then
        rm -rf "$PROJECT_ROOT/services/api-backend/auth"
        cp -r "$backup_path/auth" "$PROJECT_ROOT/services/api-backend/"
    fi
    
    if [[ -d "$backup_path/database" ]]; then
        rm -rf "$PROJECT_ROOT/services/api-backend/database"
        cp -r "$backup_path/database" "$PROJECT_ROOT/services/api-backend/"
    fi
    
    # Restore database
    if [[ -f "$backup_path/database_backup.sql" ]]; then
        docker-compose up -d postgres
        sleep 10
        docker-compose exec -T postgres psql -U postgres -d cloudtolocalllm < "$backup_path/database_backup.sql"
    fi
    
    # Restore Docker Compose
    if [[ -f "$backup_path/docker-compose.yml" ]]; then
        cp "$backup_path/docker-compose.yml" "$PROJECT_ROOT/"
    fi
    
    # Restart services
    docker-compose up -d
    
    log_success "Rollback completed successfully"
}

# Main deployment function
main() {
    local start_time=$(date +%s)
    
    log_info "=== CloudToLocalLLM Enhanced Tunnel System Deployment Started ==="
    
    # Confirmation prompt
    if [[ "$FORCE_DEPLOY" != "true" ]]; then
        echo -e "${YELLOW}This will deploy the enhanced tunnel system to $ENVIRONMENT environment.${NC}"
        echo -e "${YELLOW}This includes WebSocket tunnel backend, authentication service, and database schema.${NC}"
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Execute deployment steps
    check_prerequisites
    create_backup
    run_tests
    deploy_tunnel_backend
    deploy_web_interface
    validate_deployment
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "=== Enhanced Tunnel System Deployment Completed Successfully ==="
    log_success "Total deployment time: ${duration} seconds"
    log_info "Tunnel backend: http://localhost:8080"
    log_info "WebSocket endpoint: ws://localhost:8080/ws/tunnel"
    log_info "Web interface: https://app.cloudtolocalllm.online"
    log_info "Database stats: docker-compose exec api-backend npm run db:stats"
}

# Execute main function
main "$@"
