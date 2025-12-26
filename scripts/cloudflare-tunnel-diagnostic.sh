#!/bin/bash

# Cloudflare Tunnel Diagnostic and Remediation Script
# Uses Cloudflare API to diagnose and fix tunnel configuration issues

set -e

# Configuration
CLOUDFLARE_EMAIL="cmaltais@cloudtolocalllm.online"
CLOUDFLARE_API_KEY="abc12d491e2bc24a60e9e276be8d5b1af62bf"
CLOUDFLARE_ORIGIN_CA="v1.0-480cad9ef0df63ec95db4bef-cdaf75ed44dcc34cab97d21f9609c8616e1343c60fbec022bd0d5d4bd33b6c872b79db387f6833c667f1c1399ef50afbc6f01fccbdfcfd68e11298d8fa15965037a99d8be8791e7aba"
DOMAIN="cloudtolocalllm.online"
TUNNEL_ID="62da6c19-947b-4bf6-acad-100a73de4e0d"

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

# Function to make Cloudflare API calls
cf_api_call() {
    local method=$1
    local endpoint=$2
    local data=$3

    local auth_header="X-Auth-Email: $CLOUDFLARE_EMAIL"
    local key_header="X-Auth-Key: $CLOUDFLARE_API_KEY"

    if [ "$method" = "GET" ]; then
        curl -s -X GET "https://api.cloudflare.com/client/v4/$endpoint" \
            -H "$auth_header" \
            -H "$key_header"
    elif [ "$method" = "PUT" ]; then
        curl -s -X PUT "https://api.cloudflare.com/client/v4/$endpoint" \
            -H "$auth_header" \
            -H "$key_header" \
            -H "Content-Type: application/json" \
            -d "$data"
    elif [ "$method" = "POST" ]; then
        curl -s -X POST "https://api.cloudflare.com/client/v4/$endpoint" \
            -H "$auth_header" \
            -H "$key_header" \
            -H "Content-Type: application/json" \
            -d "$data"
    fi
}

# Function to get zone ID
get_zone_id() {
    log_info "Getting zone ID for $DOMAIN..."
    local response=$(cf_api_call "GET" "zones?name=$DOMAIN")
    local zone_id=$(echo $response | jq -r '.result[0].id')

    if [ "$zone_id" = "null" ] || [ -z "$zone_id" ]; then
        log_error "Failed to get zone ID for $DOMAIN"
        echo $response | jq .
        exit 1
    fi

    log_success "Zone ID: $zone_id"
    echo $zone_id
}

# Function to get tunnel configuration
get_tunnel_config() {
    local account_id=$1

    log_info "Getting tunnel configuration..."
    local response=$(cf_api_call "GET" "accounts/$account_id/cfd_tunnel/$TUNNEL_ID")

    if [ "$(echo $response | jq -r '.success')" = "false" ]; then
        log_error "Failed to get tunnel configuration"
        echo $response | jq .
        return 1
    fi

    echo $response | jq .
}

# Function to update tunnel configuration
update_tunnel_config() {
    local account_id=$1

    log_info "Updating tunnel configuration to fix ArgoCD HTTPS issue..."

    # Create the corrected configuration
    local config='{
        "config": {
            "ingress": [
                {
                    "hostname": "app.cloudtolocalllm.online",
                    "path": "/ws",
                    "service": "http://streaming-proxy.cloudtolocalllm.svc.cluster.local:3001"
                },
                {
                    "hostname": "app.cloudtolocalllm.online",
                    "path": "/api/tunnel",
                    "service": "http://streaming-proxy.cloudtolocalllm.svc.cluster.local:3001"
                },
                {
                    "hostname": "app.cloudtolocalllm.online",
                    "path": "/health",
                    "service": "http://api-backend.cloudtolocalllm.svc.cluster.local:8080"
                },
                {
                    "hostname": "app.cloudtolocalllm.online",
                    "path": "/api",
                    "service": "http://api-backend.cloudtolocalllm.svc.cluster.local:8080"
                },
                {
                    "hostname": "app.cloudtolocalllm.online",
                    "service": "http://web.cloudtolocalllm.svc.cluster.local:8080"
                },
                {
                    "hostname": "api.cloudtolocalllm.online",
                    "path": "/health",
                    "service": "http://api-backend.cloudtolocalllm.svc.cluster.local:8080"
                },
                {
                    "hostname": "api.cloudtolocalllm.online",
                    "service": "http://api-backend.cloudtolocalllm.svc.cluster.local:8080"
                },
                {
                    "hostname": "argocd.cloudtolocalllm.online",
                    "service": "http://argocd-server.argocd.svc.cluster.local:80"
                },
                {
                    "hostname": "grafana.cloudtolocalllm.online",
                    "service": "http://grafana.cloudtolocalllm.svc.cluster.local:3000"
                },
                {
                    "hostname": "cloudtolocalllm.online",
                    "service": "http://web.cloudtolocalllm.svc.cluster.local:8080"
                },
                {
                    "service": "http_status:404"
                }
            ]
        }
    }'

    local response=$(cf_api_call "PUT" "accounts/$account_id/cfd_tunnel/$TUNNEL_ID" "$config")

    if [ "$(echo $response | jq -r '.success')" = "true" ]; then
        log_success "Tunnel configuration updated successfully"
        echo $response | jq .
    else
        log_error "Failed to update tunnel configuration"
        echo $response | jq .
        return 1
    fi
}

# Function to create scoped API token for DNS management
create_dns_token() {
    local zone_id=$1
    local account_id=$2

    log_info "Creating scoped API token for DNS management..."

    local token_config='{
        "name": "CloudToLocalLLM-DNS-Automation",
        "policies": [
            {
                "effect": "allow",
                "resources": {
                    "com.cloudflare.api.account.zone.'$zone_id'": "*"
                },
                "permission_groups": [
                    {
                        "id": "c1fde68c7bcc44588cbb6ddbc16d6480",
                        "name": "DNS Write"
                    }
                ]
            }
        ],
        "ttl": 365
    }'

    local response=$(cf_api_call "POST" "user/tokens" "$token_config")

    if [ "$(echo $response | jq -r '.success')" = "true" ]; then
        local token=$(echo $response | jq -r '.result.value')
        log_success "DNS API token created successfully"
        echo "Token: $token"

        # Save token to Kubernetes secret
        log_info "Saving token to Kubernetes secret..."
        kubectl create secret generic cloudflare-dns-token \
            --from-literal=token=$token \
            --namespace=cloudtolocalllm \
            --dry-run=client -o yaml | kubectl apply -f -

        log_success "Token saved to cloudflare-dns-token secret"
    else
        log_error "Failed to create DNS API token"
        echo $response | jq .
    fi
}

# Function to test tunnel connectivity
test_connectivity() {
    log_info "Testing tunnel connectivity..."

    # Test ArgoCD
    log_info "Testing ArgoCD connectivity..."
    if curl -s --max-time 10 https://argocd.cloudtolocalllm.online/ > /dev/null 2>&1; then
        log_success "ArgoCD is accessible"
    else
        log_warning "ArgoCD is not accessible (may be authentication required)"
    fi

    # Test Grafana
    log_info "Testing Grafana connectivity..."
    if curl -s --max-time 10 https://grafana.cloudtolocalllm.online/ > /dev/null 2>&1; then
        log_success "Grafana is accessible"
    else
        log_error "Grafana is not accessible"
    fi

    # Test main domain
    log_info "Testing main domain connectivity..."
    if curl -s --max-time 10 https://cloudtolocalllm.online/ > /dev/null 2>&1; then
        log_success "Main domain is accessible"
    else
        log_error "Main domain is not accessible"
    fi
}

# Main execution
main() {
    log_info "Starting Cloudflare Tunnel Diagnostic and Remediation"
    log_info "Domain: $DOMAIN"
    log_info "Tunnel ID: $TUNNEL_ID"

    # Get zone ID
    ZONE_ID=$(get_zone_id)

    # Get account ID (needed for tunnel operations)
    log_info "Getting account ID..."
    local accounts_response=$(cf_api_call "GET" "accounts")
    ACCOUNT_ID=$(echo $accounts_response | jq -r '.result[0].id')

    if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" = "null" ]; then
        log_error "Failed to get account ID"
        exit 1
    fi

    log_success "Account ID: $ACCOUNT_ID"

    # Get current tunnel configuration
    log_info "=== Current Tunnel Configuration ==="
    get_tunnel_config $ACCOUNT_ID

    # Check if tunnel uses remote config
    log_info "=== Analyzing Tunnel Configuration ==="
    local tunnel_info=$(cf_api_call "GET" "accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID")
    local remote_config=$(echo $tunnel_info | jq -r '.result.remote_config')

    if [ "$remote_config" = "true" ]; then
        log_warning "Tunnel uses remote configuration (managed via Cloudflare dashboard)"
        log_warning "Cannot update configuration via API - must be done in Cloudflare dashboard"
        log_info ""
        log_info "MANUAL ACTION REQUIRED:"
        log_info "1. Go to https://dash.cloudflare.com/"
        log_info "2. Navigate to Zero Trust > Networks > Tunnels"
        log_info "3. Find tunnel: cloudtolocalllm-aks ($TUNNEL_ID)"
        log_info "4. Edit the configuration to change ArgoCD service from:"
        log_info "   https://argocd-server.argocd.svc.cluster.local:443"
        log_info "   TO:"
        log_info "   http://argocd-server.argocd.svc.cluster.local:80"
        log_info "5. Save and apply the configuration"
        log_info ""
    else
        log_info "Tunnel uses local configuration - attempting API update..."
        update_tunnel_config $ACCOUNT_ID
    fi

    # Create DNS automation token
    log_info "=== Creating DNS Automation Token ==="
    create_dns_token $ZONE_ID $ACCOUNT_ID

    # Test connectivity
    log_info "=== Testing Connectivity ==="
    test_connectivity

    log_success "Cloudflare Tunnel diagnostic and remediation completed"
    log_info "Note: DNS changes may take a few minutes to propagate"
}

# Run main function
main "$@"