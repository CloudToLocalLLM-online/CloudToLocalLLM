#!/bin/bash

# Production-ready Bash script to synchronize credentials from Auth0 to local .env and GitHub Secrets.
# Designed for WSL/Linux environments.
# Author: Senior DevOps Engineer (Kilo Code)

set -euo pipefail

# --- Configuration & Initialization ---

ENV_FILE=".env"

# Colors for non-sensitive logging
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# --- Validation Logic ---

log_info "Validating requirements..."

# Check if required tools are installed
for tool in auth0 gh jq sed; do
    if ! command -v "$tool" &> /dev/null; then
        log_error "Required tool '$tool' is not installed. Please install it and try again."
        exit 1
    fi
done

# Check Auth0 CLI session
if ! auth0 tenants list &> /dev/null; then
    log_error "No active Auth0 CLI session found. Please run 'auth0 login'."
    exit 1
fi

# Check GitHub CLI session
if ! gh auth status &> /dev/null; then
    log_error "No active GitHub CLI session found. Please run 'gh auth login'."
    exit 1
fi

# Check if we are in a Git repository (required for gh secret set)
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    log_error "Not inside a Git repository. GitHub secrets require a repository context."
    exit 1
fi

log_success "Validation complete."

# --- Credential Retrieval Logic ---

log_info "Fetching credentials from Auth0..."

# Fetch active tenant domain
# We filter for the active tenant or take the first one if multiple exist but 'active' isn't explicitly marked in list output (depends on version)
# Based on research, we parse the domain.
AUTH0_DOMAIN=$(auth0 tenants list --json | jq -r '.[0].domain // empty')

if [[ -z "$AUTH0_DOMAIN" ]]; then
    log_error "Failed to retrieve Auth0 tenant domain."
    exit 1
fi

# Fetch application details (Client ID and Client Secret)
# Using 'auth0 apps show' without ID usually targets the default app configured via 'auth0 apps use'
APP_JSON=$(auth0 apps show --reveal-secrets --json)

AUTH0_CLIENT_ID=$(echo "$APP_JSON" | jq -r '.client_id // empty')
AUTH0_CLIENT_SECRET=$(echo "$APP_JSON" | jq -r '.client_secret // empty')

if [[ -z "$AUTH0_CLIENT_ID" || -z "$AUTH0_CLIENT_SECRET" ]]; then
    log_error "Failed to retrieve application credentials. Ensure you have a default app set or valid permissions."
    exit 1
fi

log_success "Credentials retrieved securely."

# --- Idempotent .env Update Logic ---

update_env_var() {
    local key="$1"
    local value="$2"
    
    if grep -q "^${key}=" "$ENV_FILE"; then
        # Replace existing value
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$ENV_FILE"
    else
        # Append new value
        echo "${key}=\"${value}\"" >> "$ENV_FILE"
    fi
}

log_info "Updating local $ENV_FILE..."

# Ensure .env exists and has restrictive permissions
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

update_env_var "AUTH0_DOMAIN" "$AUTH0_DOMAIN"
update_env_var "AUTH0_CLIENT_ID" "$AUTH0_CLIENT_ID"
update_env_var "AUTH0_CLIENT_SECRET" "$AUTH0_CLIENT_SECRET"

log_success "Local $ENV_FILE updated (idempotent)."

# --- GitHub Secrets Synchronization Logic ---

log_info "Synchronizing GitHub Repository Secrets..."

# Securely set secrets using --body flag to avoid leaking to logs or shell history
gh secret set AUTH0_DOMAIN --body "$AUTH0_DOMAIN"
gh secret set AUTH0_CLIENT_ID --body "$AUTH0_CLIENT_ID"
gh secret set AUTH0_CLIENT_SECRET --body "$AUTH0_CLIENT_SECRET"

log_success "GitHub Repository Secrets synchronized."

# --- Finalization ---

log_success "Synchronization completed successfully for tenant: $AUTH0_DOMAIN"
