#!/bin/bash

# CloudToLocalLLM - Cloud Run Services Configuration Script
# This script configures the deployed Cloud Run services with proper
# environment variables, secrets, and inter-service communication

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
        exit 1
    fi
    
    log_info "Loading environment configuration..."
    source "$ENV_FILE"
    
    # Set gcloud project
    gcloud config set project "$GOOGLE_CLOUD_PROJECT"
    
    log_success "Environment configuration loaded"
}

# Get service URLs
get_service_urls() {
    log_info "Retrieving service URLs..."
    
    WEB_URL=$(gcloud run services describe cloudtolocalllm-web --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    API_URL=$(gcloud run services describe cloudtolocalllm-api --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    STREAMING_URL=$(gcloud run services describe cloudtolocalllm-streaming --platform=managed --region="$GOOGLE_CLOUD_REGION" --format="value(status.url)" 2>/dev/null || echo "")
    
    if [ -z "$WEB_URL" ] || [ -z "$API_URL" ] || [ -z "$STREAMING_URL" ]; then
        log_error "One or more services are not deployed. Please deploy services first."
        exit 1
    fi
    
    log_success "Service URLs retrieved"
    log_info "  Web: $WEB_URL"
    log_info "  API: $API_URL"
    log_info "  Streaming: $STREAMING_URL"
}

# Configure API service
configure_api_service() {
    log_info "Configuring API service..."
    
    # Prepare environment variables
    local env_vars="NODE_ENV=production,LOG_LEVEL=info,DB_TYPE=sqlite,CORS_ORIGINS=$WEB_URL"
    
    # Prepare secrets
    local secrets=""
    if gcloud secrets describe jwt-secret &>/dev/null; then
        secrets="JWT_SECRET=jwt-secret:latest"
    fi
    
    # Update the service
    local update_cmd=(
        gcloud run services update cloudtolocalllm-api
        --platform=managed
        --region="$GOOGLE_CLOUD_REGION"
        --set-env-vars="$env_vars"
        --quiet
    )
    
    if [ -n "$secrets" ]; then
        update_cmd+=(--set-secrets="$secrets")
    fi
    
    "${update_cmd[@]}"
    
    log_success "API service configured"
}

# Configure streaming service
configure_streaming_service() {
    log_info "Configuring streaming service..."
    
    # Prepare environment variables
    local env_vars="NODE_ENV=production,LOG_LEVEL=info,OLLAMA_BASE_URL=$API_URL"
    
    # Update the service
    gcloud run services update cloudtolocalllm-streaming \
        --platform=managed \
        --region="$GOOGLE_CLOUD_REGION" \
        --set-env-vars="$env_vars" \
        --quiet
    
    log_success "Streaming service configured"
}

# Configure web service (if needed)
configure_web_service() {
    log_info "Configuring web service..."
    
    # The web service is mostly static, but we can set some environment variables
    local env_vars="NODE_ENV=production,API_URL=$API_URL,STREAMING_URL=$STREAMING_URL"
    
    # Update the service
    gcloud run services update cloudtolocalllm-web \
        --platform=managed \
        --region="$GOOGLE_CLOUD_REGION" \
        --set-env-vars="$env_vars" \
        --quiet
    
    log_success "Web service configured"
}

# Create service configuration file
create_service_config() {
    log_info "Creating service configuration file..."
    
    local config_file="$PROJECT_ROOT/config/cloudrun/service-urls.json"
    
    cat > "$config_file" << EOF
{
  "services": {
    "web": {
      "name": "cloudtolocalllm-web",
      "url": "$WEB_URL",
      "description": "Flutter web application",
      "health": "$WEB_URL/health"
    },
    "api": {
      "name": "cloudtolocalllm-api", 
      "url": "$API_URL",
      "description": "Node.js API backend",
      "health": "$API_URL/health"
    },
    "streaming": {
      "name": "cloudtolocalllm-streaming",
      "url": "$STREAMING_URL", 
      "description": "WebSocket streaming proxy",
      "health": "$STREAMING_URL/health"
    }
  },
  "endpoints": {
    "health": {
      "web": "$WEB_URL/health",
      "api": "$API_URL/health",
      "streaming": "$STREAMING_URL/health"
    },
    "api": {
      "base": "$API_URL/api",
      "auth": "$API_URL/api/auth",
      "models": "$API_URL/api/models",
      "chat": "$API_URL/api/chat"
    },
    "streaming": {
      "proxy": "$STREAMING_URL/proxy",
      "websocket": "$STREAMING_URL/ws"
    }
  },
  "configuration": {
    "cors_origins": "$WEB_URL",
    "environment": "production",
    "region": "$GOOGLE_CLOUD_REGION"
  },
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_success "Service configuration created: $config_file"
}

# Create JavaScript configuration for web app
create_web_config() {
    log_info "Creating web application configuration..."
    
    local web_config_file="$PROJECT_ROOT/web/cloudrun-config-generated.js"
    
    cat > "$web_config_file" << EOF
// CloudToLocalLLM - Generated Cloud Run Configuration
// This file is automatically generated during deployment
// DO NOT EDIT MANUALLY - Changes will be overwritten

window.cloudRunConfig = window.cloudRunConfig || {};

// Override service URLs with actual deployed URLs
Object.assign(window.cloudRunConfig, {
  services: {
    api: {
      baseUrl: '$API_URL',
      endpoints: {
        health: '/health',
        auth: '/api/auth',
        models: '/api/models',
        chat: '/api/chat',
        streaming: '/api/streaming'
      }
    },
    streaming: {
      baseUrl: '$STREAMING_URL',
      endpoints: {
        health: '/health',
        proxy: '/proxy',
        websocket: '/ws'
      }
    }
  },
  
  // Deployment information
  deployment: {
    timestamp: '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    region: '$GOOGLE_CLOUD_REGION',
    environment: 'production'
  }
});

console.log('CloudToLocalLLM: Loaded generated Cloud Run configuration');
console.log('  API Service:', '$API_URL');
console.log('  Streaming Service:', '$STREAMING_URL');
EOF
    
    log_success "Web configuration created: $web_config_file"
}

# Test service connectivity
test_connectivity() {
    log_info "Testing service connectivity..."
    
    local services=("$WEB_URL" "$API_URL" "$STREAMING_URL")
    local service_names=("Web" "API" "Streaming")
    local healthy_count=0
    
    for i in "${!services[@]}"; do
        local service_url="${services[$i]}"
        local service_name="${service_names[$i]}"
        local health_url="$service_url/health"
        
        log_info "Testing $service_name service: $health_url"
        
        if curl -s -f "$health_url" > /dev/null; then
            log_success "$service_name service is healthy"
            ((healthy_count++))
        else
            log_warning "$service_name service health check failed"
        fi
    done
    
    log_info "Health check results: $healthy_count/${#services[@]} services healthy"
    
    if [ "$healthy_count" -eq "${#services[@]}" ]; then
        log_success "All services are healthy!"
    else
        log_warning "Some services may need attention"
    fi
}

# Main configuration function
main() {
    log_info "Starting CloudToLocalLLM Cloud Run services configuration..."
    
    load_env_config
    get_service_urls
    
    configure_api_service
    configure_streaming_service
    configure_web_service
    
    create_service_config
    create_web_config
    
    test_connectivity
    
    log_success "Cloud Run services configuration completed successfully!"
    echo
    log_info "Configuration files created:"
    echo "  Service URLs: config/cloudrun/service-urls.json"
    echo "  Web Config: web/cloudrun-config-generated.js"
    echo
    log_info "Service URLs:"
    echo "  Web Application: $WEB_URL"
    echo "  API Backend: $API_URL"
    echo "  Streaming Proxy: $STREAMING_URL"
    echo
    log_info "Next steps:"
    echo "1. Test the web application: $WEB_URL"
    echo "2. Verify API functionality: $API_URL/health"
    echo "3. Configure custom domains (optional)"
    echo "4. Set up monitoring and alerting"
}

# Run main function
main "$@"