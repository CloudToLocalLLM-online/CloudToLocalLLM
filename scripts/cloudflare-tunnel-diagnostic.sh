#!/bin/bash

# Cloudflare Tunnel Diagnostic and Restoration Script
# Version: 1.5.0 (SOP Aligned)
# Usage: CLOUDFLARE_API_KEY=xxx scripts/cloudflare-tunnel-diagnostic.sh

set -e

# Configuration (Defaults)
CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL:-"cmaltais@cloudtolocalllm.online"}
DOMAIN="cloudtolocalllm.online"
TUNNEL_ID="62da6c19-947b-4bf6-acad-100a73de4e0d"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Security Check
if [ -z "$CLOUDFLARE_API_KEY" ]; then
    log_error "CLOUDFLARE_API_KEY environment variable is not set."
    log_info "Usage: CLOUDFLARE_API_KEY=your_key $0"
    exit 1
fi

# Function to make Cloudflare API calls
cf_api_call() {
    local method=$1
    local endpoint=$2
    local data=$3

    curl -s -X "$method" "https://api.cloudflare.com/client/v4/$endpoint" \
        -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
        -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
        -H "Content-Type: application/json" \
        ${data:+-d "$data"}
}

# Main execution
main() {
    log_info "Starting Cloudflare Tunnel Diagnostic (Error 1033 Protocol)"
    
    # 1. Fetch Account ID
    log_info "Fetching Account ID..."
    ACCOUNT_ID=$(cf_api_call "GET" "accounts" | jq -r '.result[0].id')
    if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" == "null" ]; then
        log_error "Failed to retrieve Account ID. Check your API key."
        exit 1
    fi
    log_success "Account ID: $ACCOUNT_ID"

    # 2. Check Tunnel Status
    log_info "Checking Tunnel Status..."
    TUNNEL_STATUS=$(cf_api_call "GET" "accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID" | jq -r '.result.status')
    log_info "Tunnel Status: $TUNNEL_STATUS"

    if [ "$TUNNEL_STATUS" != "healthy" ]; then
        log_warning "Tunnel is not healthy. Current status: $TUNNEL_STATUS"
    else
        log_success "Tunnel is reported healthy at the edge."
    fi

    # 3. Check Active Connectors
    log_info "Checking Active Connectors..."
    CONNECTORS=$(cf_api_call "GET" "accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/connections" | jq -r '.result[] | .id')
    if [ -z "$CONNECTORS" ]; then
        log_error "No active connectors found. Error 1033 confirmed at origin side."
    else
        log_success "Found active connectors: $CONNECTORS"
    fi

    # 4. Verify CNAME Alignment for Stack
    log_info "Verifying DNS CNAME Alignment for all subdomains..."
    ZONE_ID=$(cf_api_call "GET" "zones?name=$DOMAIN" | jq -r '.result[0].id')
    
    ENDPOINTS=("" "app" "api" "argocd" "grafana")
    for SUB in "${ENDPOINTS[@]}"; do
        FULL_NAME="${SUB:+$SUB.}$DOMAIN"
        log_info "Verifying $FULL_NAME..."
        RECORD=$(cf_api_call "GET" "zones/$ZONE_ID/dns_records?name=$FULL_NAME&type=CNAME" | jq -r '.result[0].content')
        if [[ "$RECORD" == *".cfargotunnel.com"* ]]; then
            log_success "$FULL_NAME -> $RECORD (Correct)"
        else
            log_warning "$FULL_NAME record is missing or incorrect: $RECORD"
        fi
    done

    # 5. External Connectivity Check (Handshake)
    log_info "Performing HTTP/2 Handshake Verification..."
    URLS=(
        "https://cloudtolocalllm.online/"
        "https://app.cloudtolocalllm.online/health"
        "https://api.cloudtolocalllm.online/health"
    )

    for URL in "${URLS[@]}"; do
        log_info "Testing $URL..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --http2 --max-time 10 "$URL")
        if [ "$HTTP_CODE" == "200" ]; then
            log_success "$URL returned 200 OK"
        else
            log_error "$URL returned $HTTP_CODE"
        fi
    done

    log_success "Diagnostic Complete."
}

main "$@"
