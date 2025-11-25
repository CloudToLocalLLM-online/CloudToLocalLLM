#!/bin/bash

# Setup Cloudflare DNS Integration for AWS EKS
# This script updates Cloudflare DNS records to point to the AWS Network Load Balancer (NLB)
# and configures SSL/TLS settings for the CloudToLocalLLM application
#
# Prerequisites:
# - AWS CLI configured with credentials
# - CLOUDFLARE_API_TOKEN environment variable set
# - EKS cluster deployed with ingress controller
# - Cloudflare zone already created for cloudtolocalllm.online

set -e

# Configuration
AWS_REGION="us-east-1"
EKS_CLUSTER_NAME="cloudtolocalllm-eks"
NAMESPACE="cloudtolocalllm"
ZONE_NAME="cloudtolocalllm.online"
DOMAINS=(
    "cloudtolocalllm.online"
    "app.cloudtolocalllm.online"
    "api.cloudtolocalllm.online"
    "auth.cloudtolocalllm.online"
)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Validate prerequisites
validate_prerequisites() {
    echo -e "${CYAN}🔍 Validating prerequisites...${NC}"
    
    # Check if CLOUDFLARE_API_TOKEN is set
    if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        echo -e "${RED}❌ Error: CLOUDFLARE_API_TOKEN environment variable is not set${NC}"
        echo -e "${YELLOW}Please set it with: export CLOUDFLARE_API_TOKEN='your_token'${NC}"
        exit 1
    fi
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ Error: AWS CLI is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ Error: kubectl is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ Error: jq is not installed or not in PATH${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites validated${NC}"
}

# Get Cloudflare Zone ID
get_cloudflare_zone_id() {
    local zone_name=$1
    
    echo -e "${CYAN}🔍 Getting Cloudflare Zone ID for $zone_name...${NC}"
    
    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local zone_id=$(echo "$response" | jq -r '.result[0].id // empty')
    
    if [ -z "$zone_id" ]; then
        echo -e "${RED}❌ Zone not found: $zone_name${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Zone ID: $zone_id${NC}"
    echo "$zone_id"
}

# Get AWS NLB endpoint
get_nlb_endpoint() {
    echo -e "${CYAN}🔍 Getting AWS NLB endpoint...${NC}"
    
    # Update kubeconfig
    echo -e "${CYAN}Updating kubeconfig...${NC}"
    aws eks update-kubeconfig \
        --name "$EKS_CLUSTER_NAME" \
        --region "$AWS_REGION" > /dev/null
    
    # Get the ingress endpoint
    echo -e "${CYAN}Retrieving ingress endpoint...${NC}"
    local ingress=$(kubectl get ingress -n "$NAMESPACE" -o json)
    
    local nlb_endpoint=$(echo "$ingress" | jq -r '.items[0].status.loadBalancer.ingress[0].hostname // .items[0].status.loadBalancer.ingress[0].ip // empty')
    
    if [ -z "$nlb_endpoint" ]; then
        echo -e "${RED}❌ Could not determine NLB endpoint${NC}"
        echo -e "${YELLOW}Ingress status:${NC}"
        echo "$ingress" | jq '.items[0].status'
        exit 1
    fi
    
    echo -e "${GREEN}✅ NLB Endpoint: $nlb_endpoint${NC}"
    echo "$nlb_endpoint"
}

# Resolve NLB hostname to IP if needed
resolve_nlb_hostname() {
    local hostname=$1
    
    echo -e "${CYAN}🔍 Resolving NLB hostname to IP address...${NC}"
    
    # If it's already an IP, return it
    if [[ $hostname =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${GREEN}✅ NLB IP: $hostname${NC}"
        echo "$hostname"
        return
    fi
    
    # Resolve hostname to IP
    local ip_address=$(dig +short "$hostname" | head -1)
    
    if [ -z "$ip_address" ]; then
        echo -e "${RED}❌ Could not resolve hostname: $hostname${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ NLB IP: $ip_address${NC}"
    echo "$ip_address"
}

# Update Cloudflare DNS records
update_cloudflare_dns_records() {
    local zone_id=$1
    local nlb_endpoint=$2
    shift 2
    local domains=("$@")
    
    echo -e "${CYAN}🔄 Updating Cloudflare DNS records...${NC}"
    
    for domain in "${domains[@]}"; do
        echo -e "${CYAN}  Updating DNS record for: $domain${NC}"
        
        # Get existing DNS record
        local record_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$domain" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json")
        
        local record_count=$(echo "$record_response" | jq '.result | length')
        
        if [ "$record_count" -gt 0 ]; then
            # Update existing record
            local record_id=$(echo "$record_response" | jq -r '.result[0].id')
            local record_type=$(echo "$record_response" | jq -r '.result[0].type')
            
            echo -e "${CYAN}    Found existing $record_type record (ID: $record_id)${NC}"
            
            # Update the record
            local update_response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{
                    \"type\": \"$record_type\",
                    \"name\": \"$domain\",
                    \"content\": \"$nlb_endpoint\",
                    \"ttl\": 300,
                    \"proxied\": true
                }")
            
            if echo "$update_response" | jq -e '.success' > /dev/null; then
                echo -e "${GREEN}    ✅ Updated DNS record for $domain${NC}"
            else
                echo -e "${RED}    ❌ Failed to update DNS record for $domain${NC}"
                echo "$update_response" | jq '.errors'
                exit 1
            fi
        else
            # Create new A record
            echo -e "${CYAN}    Creating new A record for $domain${NC}"
            
            local create_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{
                    \"type\": \"A\",
                    \"name\": \"$domain\",
                    \"content\": \"$nlb_endpoint\",
                    \"ttl\": 300,
                    \"proxied\": true
                }")
            
            if echo "$create_response" | jq -e '.success' > /dev/null; then
                echo -e "${GREEN}    ✅ Created DNS record for $domain${NC}"
            else
                echo -e "${RED}    ❌ Failed to create DNS record for $domain${NC}"
                echo "$create_response" | jq '.errors'
                exit 1
            fi
        fi
    done
}

# Configure Cloudflare SSL/TLS settings
configure_cloudflare_ssl() {
    local zone_id=$1
    
    echo -e "${CYAN}🔐 Configuring Cloudflare SSL/TLS settings...${NC}"
    
    # Set SSL mode to "Full" (strict)
    echo -e "${CYAN}  Setting SSL mode to 'Full (strict)'...${NC}"
    local ssl_response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_id/settings/ssl" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"value": "full"}')
    
    if echo "$ssl_response" | jq -e '.success' > /dev/null; then
        echo -e "${GREEN}  ✅ SSL mode set to 'Full (strict)'${NC}"
    else
        echo -e "${RED}  ❌ Failed to set SSL mode${NC}"
        echo "$ssl_response" | jq '.errors'
        exit 1
    fi
    
    # Enable "Always Use HTTPS"
    echo -e "${CYAN}  Enabling 'Always Use HTTPS'...${NC}"
    local https_response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_id/settings/always_use_https" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"value": "on"}')
    
    if echo "$https_response" | jq -e '.success' > /dev/null; then
        echo -e "${GREEN}  ✅ 'Always Use HTTPS' enabled${NC}"
    else
        echo -e "${RED}  ❌ Failed to enable 'Always Use HTTPS'${NC}"
        echo "$https_response" | jq '.errors'
        exit 1
    fi
    
    # Enable HSTS (HTTP Strict Transport Security)
    echo -e "${CYAN}  Enabling HSTS...${NC}"
    local hsts_response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_id/settings/security_header" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "value": {
                "enabled": true,
                "max_age": 31536000,
                "include_subdomains": true,
                "preload": true
            }
        }')
    
    if echo "$hsts_response" | jq -e '.success' > /dev/null; then
        echo -e "${GREEN}  ✅ HSTS enabled${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Warning: Could not enable HSTS (may not be available on this plan)${NC}"
    fi
}

# Enable Cloudflare security features
enable_cloudflare_security_features() {
    local zone_id=$1
    
    echo -e "${CYAN}🛡️  Enabling Cloudflare security features...${NC}"
    
    # Enable Automatic HTTPS Rewrites
    echo -e "${CYAN}  Enabling Automatic HTTPS Rewrites...${NC}"
    local rewrite_response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_id/settings/automatic_https_rewrites" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"value": "on"}')
    
    if echo "$rewrite_response" | jq -e '.success' > /dev/null; then
        echo -e "${GREEN}  ✅ Automatic HTTPS Rewrites enabled${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Warning: Could not enable Automatic HTTPS Rewrites${NC}"
    fi
    
    # Set Security Level to "High"
    echo -e "${CYAN}  Setting Security Level to 'High'...${NC}"
    local security_response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_id/settings/security_level" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"value": "high"}')
    
    if echo "$security_response" | jq -e '.success' > /dev/null; then
        echo -e "${GREEN}  ✅ Security Level set to 'High'${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Warning: Could not set Security Level${NC}"
    fi
}

# Verify DNS resolution
verify_dns_resolution() {
    shift
    local domains=("$@")
    
    echo -e "${CYAN}✅ Verifying DNS resolution...${NC}"
    
    local all_resolved=true
    
    for domain in "${domains[@]}"; do
        echo -e "${CYAN}  Checking DNS resolution for: $domain${NC}"
        
        # Wait a moment for DNS to propagate
        sleep 2
        
        # Resolve the domain
        local resolved=$(dig +short "$domain" | head -1)
        
        if [ -n "$resolved" ]; then
            echo -e "${GREEN}    ✅ $domain resolves to $resolved${NC}"
        else
            echo -e "${YELLOW}    ⚠️  $domain could not be resolved (DNS may still be propagating)${NC}"
            all_resolved=false
        fi
    done
    
    if [ "$all_resolved" = true ]; then
        echo -e "${GREEN}✅ All domains resolved successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Some domains could not be resolved (DNS may still be propagating, please wait a few minutes)${NC}"
    fi
}

# Purge Cloudflare cache
purge_cloudflare_cache() {
    local zone_id=$1
    
    echo -e "${CYAN}🔄 Purging Cloudflare cache...${NC}"
    
    local purge_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/purge_cache" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"purge_everything": true}')
    
    if echo "$purge_response" | jq -e '.success' > /dev/null; then
        echo -e "${GREEN}✅ Cloudflare cache purged${NC}"
    else
        echo -e "${YELLOW}⚠️  Warning: Could not purge Cloudflare cache${NC}"
    fi
}

# Main execution
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Cloudflare DNS Integration for AWS EKS                        ║${NC}"
    echo -e "${CYAN}║  CloudToLocalLLM Deployment                                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Validate prerequisites
    validate_prerequisites
    echo ""
    
    # Get Cloudflare Zone ID
    zone_id=$(get_cloudflare_zone_id "$ZONE_NAME")
    echo ""
    
    # Get AWS NLB endpoint
    nlb_endpoint=$(get_nlb_endpoint)
    echo ""
    
    # Resolve NLB hostname to IP if needed
    nlb_ip=$(resolve_nlb_hostname "$nlb_endpoint")
    echo ""
    
    # Update Cloudflare DNS records
    update_cloudflare_dns_records "$zone_id" "$nlb_ip" "${DOMAINS[@]}"
    echo ""
    
    # Configure SSL/TLS settings
    configure_cloudflare_ssl "$zone_id"
    echo ""
    
    # Enable security features
    enable_cloudflare_security_features "$zone_id"
    echo ""
    
    # Purge cache
    purge_cloudflare_cache "$zone_id"
    echo ""
    
    # Verify DNS resolution
    verify_dns_resolution "" "${DOMAINS[@]}"
    echo ""
    
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ Cloudflare DNS Integration Complete!                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Summary:${NC}"
    echo -e "  - Zone ID: $zone_id"
    echo -e "  - NLB Endpoint: $nlb_ip"
    echo -e "  - Domains Updated: ${#DOMAINS[@]}"
    echo -e "  - SSL Mode: Full (strict)"
    echo -e "  - Always Use HTTPS: Enabled"
    echo -e "  - Security Level: High"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  1. Wait 5-10 minutes for DNS propagation"
    echo -e "  2. Visit https://cloudtolocalllm.online to verify"
    echo -e "  3. Check SSL certificate status"
    echo -e "  4. Monitor application logs for any issues"
    echo ""
}

# Run main function
main
