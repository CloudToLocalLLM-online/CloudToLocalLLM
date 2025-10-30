#!/bin/bash
# ============================================================================
# CloudToLocalLLM - Simple Docker Compose Deployment Script
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
ENV_TEMPLATE="${SCRIPT_DIR}/env.template"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.production.yml"

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "\n${BLUE}============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================================================
# Prerequisite Checks
# ============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    print_success "Docker is installed"
    
    # Check if Docker Compose is installed
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    print_success "Docker Compose is installed"
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    print_success "Docker daemon is running"
}

# ============================================================================
# Environment Configuration
# ============================================================================

setup_environment() {
    print_header "Environment Configuration"
    
    if [ -f "$ENV_FILE" ]; then
        print_warning ".env file already exists"
        read -p "Do you want to reconfigure? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing .env file"
            return
        fi
    fi
    
    print_info "Creating .env file from template..."
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    
    # Prompt for required values
    read -p "Enter your domain (e.g., example.com): " DOMAIN
    read -p "Enter email for SSL certificates: " SSL_EMAIL
    read -p "Enter Auth0 domain: " AUTH0_DOMAIN
    read -p "Enter Auth0 audience: " AUTH0_AUDIENCE
    
    # Generate secure passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    JWT_SECRET=$(openssl rand -base64 32)
    
    # Update .env file
    sed -i "s|DOMAIN=yourdomain.com|DOMAIN=$DOMAIN|g" "$ENV_FILE"
    sed -i "s|SSL_EMAIL=admin@yourdomain.com|SSL_EMAIL=$SSL_EMAIL|g" "$ENV_FILE"
    sed -i "s|AUTH0_DOMAIN=your-tenant.us.auth0.com|AUTH0_DOMAIN=$AUTH0_DOMAIN|g" "$ENV_FILE"
    sed -i "s|AUTH0_AUDIENCE=https://app.yourdomain.com|AUTH0_AUDIENCE=$AUTH0_AUDIENCE|g" "$ENV_FILE"
    sed -i "s|POSTGRES_PASSWORD=changeme_generate_strong_password|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|g" "$ENV_FILE"
    sed -i "s|JWT_SECRET=changeme_generate_strong_jwt_secret|JWT_SECRET=$JWT_SECRET|g" "$ENV_FILE"
    
    print_success ".env file created successfully"
    print_info "Generated secure passwords for database and JWT"
}

# ============================================================================
# SSL Certificate Setup
# ============================================================================

setup_ssl() {
    print_header "SSL Certificate Setup"
    
    # Load environment variables
    source "$ENV_FILE"
    
    # Create certbot directories
    mkdir -p certbot/conf certbot/www certbot/logs
    
    print_info "Requesting SSL certificate from Let's Encrypt..."
    print_warning "Make sure your domain DNS is pointing to this server!"
    
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    
    # Request certificate
    docker compose -f "$COMPOSE_FILE" run --rm certbot certonly \
        --webroot -w /var/www/certbot \
        --email "$SSL_EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" \
        -d "app.$DOMAIN" \
        -d "api.$DOMAIN"
    
    if [ $? -eq 0 ]; then
        print_success "SSL certificate obtained successfully"
    else
        print_error "Failed to obtain SSL certificate"
        print_info "You can try again later by running this script again"
        exit 1
    fi
}

# ============================================================================
# Deployment
# ============================================================================

deploy() {
    print_header "Deploying CloudToLocalLLM"
    
    # Pull latest images
    print_info "Pulling latest images..."
    docker compose -f "$COMPOSE_FILE" pull
    
    # Build custom images
    print_info "Building custom images..."
    docker compose -f "$COMPOSE_FILE" build
    
    # Start services
    print_info "Starting services..."
    docker compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to be healthy
    print_info "Waiting for services to be healthy..."
    sleep 10
    
    # Check service health
    print_info "Checking service health..."
    docker compose -f "$COMPOSE_FILE" ps
    
    print_success "Deployment complete!"
}

# ============================================================================
# Post-Deployment Information
# ============================================================================

show_info() {
    print_header "Deployment Information"
    
    source "$ENV_FILE"
    
    echo -e "${GREEN}CloudToLocalLLM is now running!${NC}\n"
    echo -e "Web Application: ${BLUE}https://$DOMAIN${NC}"
    echo -e "App Interface:   ${BLUE}https://app.$DOMAIN${NC}"
    echo -e "API Endpoint:    ${BLUE}https://api.$DOMAIN${NC}"
    echo -e "\n${YELLOW}Important Commands:${NC}"
    echo -e "  View logs:    ${BLUE}docker compose -f $COMPOSE_FILE logs -f${NC}"
    echo -e "  Stop:         ${BLUE}docker compose -f $COMPOSE_FILE down${NC}"
    echo -e "  Restart:      ${BLUE}docker compose -f $COMPOSE_FILE restart${NC}"
    echo -e "  Status:       ${BLUE}docker compose -f $COMPOSE_FILE ps${NC}"
    echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header "CloudToLocalLLM Deployment Script"
    
    check_prerequisites
    setup_environment
    
    # Ask if user wants to setup SSL now or later
    read -p "Do you want to setup SSL certificates now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_ssl
    else
        print_warning "SSL setup skipped. You can run './deploy.sh ssl' later."
    fi
    
    deploy
    show_info
}

# Handle subcommands
case "${1:-}" in
    ssl)
        setup_ssl
        ;;
    *)
        main
        ;;
esac

