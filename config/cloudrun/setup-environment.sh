#!/bin/bash

# CloudToLocalLLM - Cloud Run Environment Setup Script
# This script sets up the complete environment for Cloud Run deployment
# including secrets, service accounts, and environment variables

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/config/cloudrun/.env.cloudrun"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Load environment configuration
load_env_config() {
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment configuration file not found: $ENV_FILE"
        log_error "Please copy and configure .env.cloudrun.template first"
        exit 1
    fi
    
    log_info "Loading environment configuration..."
    source "$ENV_FILE"
    
    # Validate required variables
    required_vars=(
        "GOOGLE_CLOUD_PROJECT"
        "GOOGLE_CLOUD_REGION"
        "AUTH0_DOMAIN"
        "AUTH0_CLIENT_ID"
        "AUTH0_CLIENT_SECRET"
        "JWT_SECRET"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    log_success "Environment configuration loaded"
}

# Create secrets in Google Secret Manager
create_secrets() {
    log_info "Creating secrets in Google Secret Manager..."
    
    # Auth0 secrets
    echo -n "$AUTH0_CLIENT_SECRET" | gcloud secrets create auth0-client-secret --data-file=- --replication-policy=automatic || log_warning "Secret auth0-client-secret already exists"
    echo -n "$JWT_SECRET" | gcloud secrets create jwt-secret --data-file=- --replication-policy=automatic || log_warning "Secret jwt-secret already exists"
    
    # Database secrets (if using Cloud SQL)
    if [ -n "${DB_PASSWORD:-}" ]; then
        echo -n "$DB_PASSWORD" | gcloud secrets create db-password --data-file=- --replication-policy=automatic || log_warning "Secret db-password already exists"
    fi
    
    # API keys (if configured)
    if [ -n "${LANGCHAIN_API_KEY:-}" ]; then
        echo -n "$LANGCHAIN_API_KEY" | gcloud secrets create langchain-api-key --data-file=- --replication-policy=automatic || log_warning "Secret langchain-api-key already exists"
    fi
    
    log_success "Secrets created successfully"
}

# Grant secret access to service accounts
grant_secret_access() {
    log_info "Granting secret access to service accounts..."
    
    local service_account="cloudtolocalllm-runner@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com"
    
    # Grant access to all secrets
    local secrets=("auth0-client-secret" "jwt-secret")
    
    if [ -n "${DB_PASSWORD:-}" ]; then
        secrets+=("db-password")
    fi
    
    if [ -n "${LANGCHAIN_API_KEY:-}" ]; then
        secrets+=("langchain-api-key")
    fi
    
    for secret in "${secrets[@]}"; do
        gcloud secrets add-iam-policy-binding "$secret" \
            --member="serviceAccount:$service_account" \
            --role="roles/secretmanager.secretAccessor" || log_warning "Failed to grant access to $secret"
    done
    
    log_success "Secret access granted"
}

# Create Cloud SQL instance (optional)
create_cloud_sql() {
    if [ "${DB_TYPE:-sqlite}" = "postgresql" ] || [ "${DB_TYPE:-sqlite}" = "mysql" ]; then
        log_info "Setting up Cloud SQL instance..."
        
        local db_instance="${DB_INSTANCE_NAME:-cloudtolocalllm-db}"
        local db_version="${DB_VERSION:-POSTGRES_13}"
        local db_tier="${DB_TIER:-db-f1-micro}"
        
        # Create Cloud SQL instance
        if ! gcloud sql instances describe "$db_instance" &>/dev/null; then
            log_info "Creating Cloud SQL instance: $db_instance"
            gcloud sql instances create "$db_instance" \
                --database-version="$db_version" \
                --tier="$db_tier" \
                --region="$GOOGLE_CLOUD_REGION" \
                --storage-type=SSD \
                --storage-size=10GB \
                --backup-start-time=03:00 \
                --enable-bin-log \
                --maintenance-window-day=SUN \
                --maintenance-window-hour=04 \
                --maintenance-release-channel=production
        else
            log_warning "Cloud SQL instance $db_instance already exists"
        fi
        
        # Create database
        local db_name="${DB_NAME:-cloudtolocalllm}"
        if ! gcloud sql databases describe "$db_name" --instance="$db_instance" &>/dev/null; then
            log_info "Creating database: $db_name"
            gcloud sql databases create "$db_name" --instance="$db_instance"
        else
            log_warning "Database $db_name already exists"
        fi
        
        # Create database user
        local db_user="${DB_USER:-appuser}"
        if ! gcloud sql users describe "$db_user" --instance="$db_instance" &>/dev/null; then
            log_info "Creating database user: $db_user"
            gcloud sql users create "$db_user" \
                --instance="$db_instance" \
                --password="$DB_PASSWORD"
        else
            log_warning "Database user $db_user already exists"
        fi
        
        log_success "Cloud SQL setup completed"
    else
        log_info "Using SQLite database - skipping Cloud SQL setup"
    fi
}

# Update Cloud Run services with environment variables
update_cloud_run_services() {
    log_info "Updating Cloud Run services with environment variables..."
    
    # Get service URLs for inter-service communication
    local web_url=$(gcloud run services describe cloudtolocalllm-web --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    local api_url=$(gcloud run services describe cloudtolocalllm-api --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    local streaming_url=$(gcloud run services describe cloudtolocalllm-streaming --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    
    # Update API service
    if [ -n "$api_url" ]; then
        log_info "Updating API service environment..."
        gcloud run services update cloudtolocalllm-api \
            --platform=managed \
            --region="$GOOGLE_CLOUD_REGION" \
            --set-env-vars="NODE_ENV=production,LOG_LEVEL=info,AUTH0_DOMAIN=$AUTH0_DOMAIN,AUTH0_CLIENT_ID=$AUTH0_CLIENT_ID,DB_TYPE=${DB_TYPE:-sqlite},CORS_ORIGINS=$web_url" \
            --set-secrets="AUTH0_CLIENT_SECRET=auth0-client-secret:latest,JWT_SECRET=jwt-secret:latest" \
            --quiet
    fi
    
    # Update streaming service
    if [ -n "$streaming_url" ]; then
        log_info "Updating streaming service environment..."
        gcloud run services update cloudtolocalllm-streaming \
            --platform=managed \
            --region="$GOOGLE_CLOUD_REGION" \
            --set-env-vars="NODE_ENV=production,LOG_LEVEL=info,OLLAMA_BASE_URL=$api_url" \
            --quiet
    fi
    
    log_success "Cloud Run services updated"
}

# Create service URLs configuration
create_service_urls_config() {
    log_info "Creating service URLs configuration..."
    
    local config_file="$PROJECT_ROOT/config/cloudrun/service-urls.json"
    
    # Get actual service URLs
    local web_url=$(gcloud run services describe cloudtolocalllm-web --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    local api_url=$(gcloud run services describe cloudtolocalllm-api --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    local streaming_url=$(gcloud run services describe cloudtolocalllm-streaming --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    
    cat > "$config_file" << EOF
{
  "services": {
    "web": {
      "name": "cloudtolocalllm-web",
      "url": "$web_url",
      "description": "Flutter web application"
    },
    "api": {
      "name": "cloudtolocalllm-api", 
      "url": "$api_url",
      "description": "Node.js API backend"
    },
    "streaming": {
      "name": "cloudtolocalllm-streaming",
      "url": "$streaming_url", 
      "description": "WebSocket streaming proxy"
    }
  },
  "endpoints": {
    "health": {
      "web": "$web_url/health",
      "api": "$api_url/health",
      "streaming": "$streaming_url/health"
    },
    "api": {
      "base": "$api_url/api",
      "auth": "$api_url/api/auth",
      "models": "$api_url/api/models"
    }
  },
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_success "Service URLs configuration created: $config_file"
}

# Main setup function
main() {
    log_info "Starting CloudToLocalLLM Cloud Run environment setup..."
    
    load_env_config
    
    # Set gcloud project
    gcloud config set project "$GOOGLE_CLOUD_PROJECT"
    
    create_secrets
    grant_secret_access
    create_cloud_sql
    update_cloud_run_services
    create_service_urls_config
    
    log_success "Cloud Run environment setup completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Verify services are running: gcloud run services list --platform=managed --region=$GOOGLE_CLOUD_REGION"
    echo "2. Test health endpoints using the URLs in: config/cloudrun/service-urls.json"
    echo "3. Configure custom domains if needed"
    echo "4. Set up monitoring and alerting"
}

# Run main function
main "$@"
