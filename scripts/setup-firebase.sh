#!/bin/bash

# CloudToLocalLLM - Firebase Setup Script
# This script sets up Firebase Authentication for the CloudToLocalLLM project

set -euo pipefail

# Configuration
PROJECT_ID="cloudtolocalllm-auth"
SERVICE_ACCOUNT="cloudtolocalllm-runner"
REGION="us-east4"

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

log_header() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

# Check if Firebase CLI is installed
check_firebase_cli() {
    if ! command -v firebase &> /dev/null; then
        log_error "Firebase CLI is not installed. Installing..."
        npm install -g firebase-tools
    fi
    log_success "Firebase CLI is available"
}

# Check if gcloud CLI is installed
check_gcloud_cli() {
    if ! command -v gcloud &> /dev/null; then
        log_error "Google Cloud CLI is not installed. Please install it first."
        exit 1
    fi
    log_success "Google Cloud CLI is available"
}

# Login to Firebase
firebase_login() {
    log_info "Checking Firebase authentication..."
    if ! firebase projects:list &> /dev/null; then
        log_info "Logging in to Firebase..."
        firebase login
    fi
    log_success "Firebase authentication verified"
}

# Login to Google Cloud
gcloud_login() {
    log_info "Checking Google Cloud authentication..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 &> /dev/null; then
        log_info "Logging in to Google Cloud..."
        gcloud auth login
    fi
    log_success "Google Cloud authentication verified"
}

# Create Firebase project
create_firebase_project() {
    log_header "Creating Firebase Project"
    
    # Check if project already exists
    if firebase projects:list | grep -q "$PROJECT_ID"; then
        log_warning "Firebase project $PROJECT_ID already exists"
        firebase use "$PROJECT_ID"
    else
        log_info "Creating Firebase project: $PROJECT_ID"
        firebase projects:create "$PROJECT_ID" --display-name "CloudToLocalLLM Auth"
        firebase use "$PROJECT_ID"
        log_success "Firebase project created"
    fi
}

# Enable required APIs
enable_apis() {
    log_header "Enabling Required APIs"
    
    log_info "Enabling Firebase Authentication API..."
    gcloud services enable firebase.googleapis.com --project="$PROJECT_ID"
    
    log_info "Enabling Identity and Access Management API..."
    gcloud services enable iam.googleapis.com --project="$PROJECT_ID"
    
    log_success "Required APIs enabled"
}

# Create service account
create_service_account() {
    log_header "Creating Service Account"
    
    # Check if service account exists
    if gcloud iam service-accounts describe "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" &> /dev/null; then
        log_warning "Service account $SERVICE_ACCOUNT already exists"
    else
        log_info "Creating service account: $SERVICE_ACCOUNT"
        gcloud iam service-accounts create "$SERVICE_ACCOUNT" \
            --display-name="CloudToLocalLLM Runner" \
            --description="Service account for CloudToLocalLLM Cloud Run services" \
            --project="$PROJECT_ID"
        log_success "Service account created"
    fi
    
    # Grant Firebase Admin role
    log_info "Granting Firebase Admin role..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
        --role="roles/firebase.admin" \
        --quiet
    
    log_success "Service account configured"
}

# Update Cloud Run services
update_cloud_run_services() {
    log_header "Updating Cloud Run Services"
    
    # Update API service
    log_info "Updating API service with Firebase configuration..."
    if gcloud run services describe cloudtolocalllm-api --region="$REGION" &> /dev/null; then
        gcloud run services update cloudtolocalllm-api \
            --platform=managed \
            --region="$REGION" \
            --set-env-vars="FIREBASE_PROJECT_ID=$PROJECT_ID" \
            --quiet
        log_success "API service updated"
    else
        log_warning "API service not found - will be configured during deployment"
    fi
}

# Display setup summary
display_summary() {
    log_header "Setup Summary"
    
    echo
    log_success "Firebase Authentication setup completed!"
    echo
    log_info "Configuration:"
    echo "  - Firebase Project ID: $PROJECT_ID"
    echo "  - Service Account: $SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"
    echo "  - Region: $REGION"
    echo
    log_info "Next steps:"
    echo "  1. Configure Firebase Authentication providers in Firebase Console:"
    echo "     https://console.firebase.google.com/project/$PROJECT_ID/authentication"
    echo "  2. Enable Google and Email/Password sign-in methods"
    echo "  3. Add authorized domains:"
    echo "     - app.cloudtolocalllm.online"
    echo "     - cloudtolocalllm.online"
    echo "  4. Deploy the updated API service"
    echo
    log_info "Firebase Console: https://console.firebase.google.com/project/$PROJECT_ID"
}

# Main function
main() {
    log_header "CloudToLocalLLM Firebase Setup"
    
    check_firebase_cli
    check_gcloud_cli
    firebase_login
    gcloud_login
    create_firebase_project
    enable_apis
    create_service_account
    update_cloud_run_services
    display_summary
}

# Run main function
main "$@"
