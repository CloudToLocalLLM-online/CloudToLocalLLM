#!/bin/bash
set -e

# Cloudflare Cache Purge Script
# This script purges Cloudflare cache for all domains after deployment
# Usage:
#   export CLOUDFLARE_API_TOKEN="your_api_token"
#   export CLOUDFLARE_ZONE_ID="your_zone_id" (optional, will be fetched if not provided)
#   ./scripts/cloudflare-cache-purge.sh

# Configuration
DOMAIN="cloudtolocalllm.online"
SUBDOMAINS=("app" "api" "docs" "mail")
MAX_RETRIES=3
RETRY_DELAY=5

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

# Validate environment
validate_env() {
    if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        log_error "CLOUDFLARE_API_TOKEN not set"
        echo "Please set the CLOUDFLARE_API_TOKEN environment variable"
        echo "You can get this from: https://dash.cloudflare.com/profile/api-tokens"
        exit 1
    fi

    log_info "Environment validation passed"
}

# Get Zone ID
get_zone_id() {
    local zone_name="$1"

    if [ -n "$CLOUDFLARE_ZONE_ID" ]; then
        log_info "Using provided Zone ID: $CLOUDFLARE_ZONE_ID"
        echo "$CLOUDFLARE_ZONE_ID"
        return 0
    fi

    log_info "Fetching Zone ID for domain: $zone_name"

    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json")

    if echo "$response" | grep -q '"success":true'; then
        local zone_id
        zone_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$zone_id" ]; then
            log_success "Zone ID retrieved: $zone_id"
            echo "$zone_id"
            return 0
        fi
    fi

    log_error "Failed to retrieve Zone ID"
    echo "Response: $response" >&2
    return 1
}

# Purge cache with retry logic
purge_cache() {
    local zone_id="$1"
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "Cache purge attempt $attempt/$MAX_RETRIES for zone: $zone_id"

        local response
        response=$(curl -s -X POST \
            "https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data '{"purge_everything": true}')

        if echo "$response" | grep -q '"success":true'; then
            log_success "Cache purge successful for zone $zone_id"
            return 0
        else
            log_warning "Cache purge attempt $attempt failed"
            echo "Response: $response"

            if [ $attempt -lt $MAX_RETRIES ]; then
                log_info "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
        fi

        ((attempt++))
    done

    log_error "Cache purge failed after $MAX_RETRIES attempts"
    return 1
}

# Verify cache purge by checking response headers
verify_cache_purge() {
    local domain="$1"
    local url="https://$domain"

    log_info "Verifying cache purge for: $url"

    # Make a request and check for cache headers
    local response
    response=$(curl -s -I "$url" 2>/dev/null || echo "")

    if [ -z "$response" ]; then
        log_warning "Could not reach $url for verification"
        return 0
    fi

    # Check if CF-Cache-Status indicates cache was purged
    if echo "$response" | grep -q "CF-Cache-Status: MISS\|CF-Cache-Status: EXPIRED"; then
        log_success "Cache verification successful for $domain (cache miss/expired)"
        return 0
    elif echo "$response" | grep -q "CF-Cache-Status: HIT"; then
        log_warning "Cache still serving cached content for $domain"
        return 1
    else
        log_info "Cache status unknown for $domain (may not be cached)"
        return 0
    fi
}

# Main execution
main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Cloudflare Cache Purge for CloudToLocalLLM"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Validate environment
    validate_env

    # Get Zone ID
    local zone_id
    if ! zone_id=$(get_zone_id "$DOMAIN"); then
        exit 1
    fi

    # Purge cache
    if ! purge_cache "$zone_id"; then
        log_error "Cache purge failed - deployment may continue but users might see cached content"
        exit 1
    fi

    echo ""
    log_info "Cache purge completed. Affected domains:"
    echo "  - $DOMAIN"
    for subdomain in "${SUBDOMAINS[@]}"; do
        echo "  - $subdomain.$DOMAIN"
    done

    echo ""
    log_info "Verifying cache purge effectiveness..."

    # Verify main domain
    verify_cache_purge "$DOMAIN"

    # Verify subdomains
    for subdomain in "${SUBDOMAINS[@]}"; do
        verify_cache_purge "$subdomain.$DOMAIN"
    done

    echo ""
    log_success "Cloudflare cache purge process completed"
    log_info "Users should now receive the latest deployed version"
    log_info "Note: DNS propagation and cache invalidation may take a few minutes globally"
}

# Run main function
main "$@"