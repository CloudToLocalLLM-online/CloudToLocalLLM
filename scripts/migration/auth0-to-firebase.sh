#!/bin/bash

# CloudToLocalLLM - Auth0 to Firebase Authentication Migration Script
# This script automates the migration from Auth0 to Firebase Authentication

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
    echo -e "${CYAN}$1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_header "=== Checking Prerequisites ==="
    
    # Check if Firebase CLI is installed
    if ! command -v firebase &> /dev/null; then
        log_error "Firebase CLI is not installed. Please install it first:"
        echo "npm install -g firebase-tools"
        exit 1
    fi
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        log_error "Google Cloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if user is logged in to Firebase
    if ! firebase projects:list &> /dev/null; then
        log_error "Not logged in to Firebase. Please run: firebase login"
        exit 1
    fi
    
    # Check if user is logged in to Google Cloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 &> /dev/null; then
        log_error "Not logged in to Google Cloud. Please run: gcloud auth login"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Create Firebase project
create_firebase_project() {
    log_header "=== Creating Firebase Project ==="
    
    local project_id="cloudtolocalllm-auth"
    
    # Check if project already exists
    if firebase projects:list | grep -q "$project_id"; then
        log_warning "Firebase project $project_id already exists"
        return 0
    fi
    
    log_info "Creating Firebase project: $project_id"
    firebase projects:create "$project_id" --display-name "CloudToLocalLLM Auth"
    
    # Use the project
    firebase use "$project_id"
    
    log_success "Firebase project created and selected"
}

# Initialize Firebase in the project
initialize_firebase() {
    log_header "=== Initializing Firebase ==="
    
    cd "$PROJECT_ROOT"
    
    # Initialize Firebase (non-interactive)
    log_info "Initializing Firebase Authentication..."
    
    # Create firebase.json if it doesn't exist
    if [ ! -f "firebase.json" ]; then
        log_info "Creating firebase.json configuration..."
        cat > firebase.json << 'EOF'
{
  "hosting": {
    "public": "web/build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
EOF
    fi
    
    log_success "Firebase initialized"
}

# Enable Firebase Authentication
enable_firebase_auth() {
    log_header "=== Enabling Firebase Authentication ==="
    
    local project_id="cloudtolocalllm-auth"
    
    log_info "Enabling Firebase Authentication for project: $project_id"
    
    # Enable Authentication (this requires manual setup in Firebase Console)
    log_warning "Please complete the following steps in Firebase Console:"
    echo "1. Go to https://console.firebase.google.com/project/$project_id/authentication"
    echo "2. Click 'Get started' to enable Authentication"
    echo "3. Go to 'Sign-in method' tab"
    echo "4. Enable 'Google' provider"
    echo "5. Enable 'Email/Password' provider"
    echo "6. Add authorized domains:"
    echo "   - app.cloudtolocalllm.online"
    echo "   - cloudtolocalllm.online"
    echo ""
    read -p "Press Enter when you have completed these steps..."
    
    log_success "Firebase Authentication enabled"
}

# Create service account for Cloud Run
create_service_account() {
    log_header "=== Creating Service Account ==="
    
    local project_id="cloudtolocalllm-auth"
    local service_account="cloudtolocalllm-runner"
    
    # Create service account
    if ! gcloud iam service-accounts describe "$service_account@$project_id.iam.gserviceaccount.com" &> /dev/null; then
        log_info "Creating service account: $service_account"
        gcloud iam service-accounts create "$service_account" \
            --display-name="CloudToLocalLLM Runner" \
            --description="Service account for CloudToLocalLLM Cloud Run services"
    else
        log_warning "Service account $service_account already exists"
    fi
    
    # Grant necessary roles
    log_info "Granting Firebase Admin role..."
    gcloud projects add-iam-policy-binding "$project_id" \
        --member="serviceAccount:$service_account@$project_id.iam.gserviceaccount.com" \
        --role="roles/firebase.admin"
    
    # Create and download service account key
    local key_file="$PROJECT_ROOT/config/cloudrun/firebase-service-account.json"
    log_info "Creating service account key..."
    gcloud iam service-accounts keys create "$key_file" \
        --iam-account="$service_account@$project_id.iam.gserviceaccount.com"
    
    log_success "Service account created and key downloaded"
    log_warning "Keep the service account key secure: $key_file"
}

# Update Cloud Run services
update_cloud_run_services() {
    log_header "=== Updating Cloud Run Services ==="
    
    local project_id="cloudtolocalllm-auth"
    
    # Update API service with Firebase configuration
    log_info "Updating API service with Firebase configuration..."
    gcloud run services update cloudtolocalllm-api \
        --platform=managed \
        --region=us-east4 \
        --set-env-vars="FIREBASE_PROJECT_ID=$project_id" \
        --quiet
    
    log_success "Cloud Run services updated"
}

# Install dependencies
install_dependencies() {
    log_header "=== Installing Dependencies ==="
    
    # Install Firebase Admin SDK for Node.js
    log_info "Installing Firebase Admin SDK..."
    cd "$PROJECT_ROOT/services/api-backend"
    npm install firebase-admin@^12.0.0
    
    log_success "Dependencies installed"
}

# Create migration summary
create_migration_summary() {
    log_header "=== Migration Summary ==="
    
    local summary_file="$PROJECT_ROOT/FIREBASE_MIGRATION_SUMMARY.md"
    
    cat > "$summary_file" << EOF
# Firebase Authentication Migration Summary

## Migration Completed: $(date)

### What was migrated:
- ✅ Firebase project created: cloudtolocalllm-auth
- ✅ Firebase Authentication enabled
- ✅ Service account created for Cloud Run
- ✅ Dependencies updated (firebase-admin)
- ✅ Cloud Run services configured

### Next Steps:

1. **Update your application code:**
   - Replace Auth0 middleware with Firebase middleware
   - Update frontend authentication service
   - Test authentication flows

2. **Deploy updated services:**
   \`\`\`bash
   gcloud builds triggers run cloudtolocalllm-trigger --branch=main
   \`\`\`

3. **Test the migration:**
   - Verify Google Sign-In works
   - Verify Email/Password authentication works
   - Test API authentication

4. **Clean up Auth0 (after successful migration):**
   - Remove Auth0 environment variables
   - Cancel Auth0 subscription
   - Remove Auth0 dependencies

### Configuration Files Updated:
- services/api-backend/package.json (added firebase-admin)
- config/cloudrun/.env.cloudrun.template (Firebase config)
- firebase.json (Firebase project config)

### New Files Created:
- services/api-backend/middleware/firebase-auth.js
- lib/services/firebase_auth_service.dart
- docs/MIGRATION/AUTH0_TO_FIREBASE_MIGRATION.md

### Cost Savings:
- Before: \$23-240/month (Auth0)
- After: \$0/month for up to 50,000 users (Firebase)
- Annual savings: \$276-2,880

### Support:
- Firebase Console: https://console.firebase.google.com/project/cloudtolocalllm-auth
- Documentation: docs/MIGRATION/AUTH0_TO_FIREBASE_MIGRATION.md
EOF
    
    log_success "Migration summary created: $summary_file"
}

# Main migration function
main() {
    log_header "=== CloudToLocalLLM: Auth0 to Firebase Migration ==="
    log_info "Starting migration from Auth0 to Firebase Authentication..."
    
    check_prerequisites
    create_firebase_project
    initialize_firebase
    enable_firebase_auth
    create_service_account
    install_dependencies
    update_cloud_run_services
    create_migration_summary
    
    echo
    log_success "Migration completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Review the migration summary: FIREBASE_MIGRATION_SUMMARY.md"
    echo "2. Update your application code to use Firebase Auth"
    echo "3. Deploy and test the updated services"
    echo "4. Clean up Auth0 configuration after successful testing"
    echo
    log_info "Estimated cost savings: \$276-2,880 per year"
}

# Run main function
main "$@"
