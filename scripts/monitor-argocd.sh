#!/bin/bash
# CloudToLocalLLM - ArgoCD Monitoring Script
# This script checks the health and sync status of ArgoCD and its applications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if argocd CLI is available
if ! command -v argocd &> /dev/null; then
    print_error "argocd CLI not found. Please install it first."
    print_info "Download from: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
    exit 1
fi
print_success "argocd CLI is available"

# Check if kubectl can access cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please configure kubectl."
    exit 1
fi
print_success "Connected to Kubernetes cluster"

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    print_error "ArgoCD namespace not found. Is ArgoCD installed?"
    exit 1
fi
print_success "ArgoCD namespace exists"

# Check ArgoCD server status
print_header "Checking ArgoCD Server Status"
ARGOCD_SERVER_PODS=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[*].status.phase}')
if [[ -z "$ARGOCD_SERVER_PODS" ]]; then
    print_error "No ArgoCD server pods found"
    exit 1
fi

RUNNING_COUNT=0
for status in $ARGOCD_SERVER_PODS; do
    if [[ "$status" == "Running" ]]; then
        ((RUNNING_COUNT++))
    else
        print_warning "ArgoCD server pod status: $status"
    fi
done

if [[ $RUNNING_COUNT -gt 0 ]]; then
    print_success "ArgoCD server is running ($RUNNING_COUNT pods)"
else
    print_error "ArgoCD server is not running"
    exit 1
fi

# Get ArgoCD server URL
ARGOCD_SERVER_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [[ -n "$ARGOCD_SERVER_URL" ]]; then
    print_info "ArgoCD server URL: https://$ARGOCD_SERVER_URL"
else
    print_warning "Could not determine ArgoCD server URL"
fi

# Check ArgoCD applications
print_header "Checking ArgoCD Applications"

# Get all applications
APPS=$(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
if [[ -z "$APPS" ]]; then
    print_warning "No ArgoCD applications found"
else
    APP_COUNT=$(echo "$APPS" | wc -w)
    print_info "Found $APP_COUNT applications: $APPS"

    # Check each application status
    for app in $APPS; do
        echo ""
        print_info "Checking application: $app"

        # Get application status
        SYNC_STATUS=$(kubectl get application $app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
        HEALTH_STATUS=$(kubectl get application $app -o jsonpath='{.status.health.status}' 2>/dev/null)

        case $SYNC_STATUS in
            "Synced")
                print_success "Sync status: $SYNC_STATUS"
                ;;
            "OutOfSync")
                print_warning "Sync status: $SYNC_STATUS"
                ;;
            *)
                print_error "Sync status: $SYNC_STATUS"
                ;;
        esac

        case $HEALTH_STATUS in
            "Healthy")
                print_success "Health status: $HEALTH_STATUS"
                ;;
            "Progressing")
                print_info "Health status: $HEALTH_STATUS"
                ;;
            "Degraded"|"Missing")
                print_error "Health status: $HEALTH_STATUS"
                ;;
            *)
                print_warning "Health status: $HEALTH_STATUS"
                ;;
        esac
    done
fi

# Check for sync operations in progress
print_header "Checking Sync Operations"
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.operationState.phase}{"\n"}{end}' | while IFS=$'\t' read -r app phase; do
    if [[ "$phase" == "Running" ]]; then
        print_info "Sync operation in progress for: $app"
    fi
done

print_header "ArgoCD Monitoring Complete"
print_info "For more detailed information, access the ArgoCD UI or use 'argocd app get <app-name>'"
print_info "To login to ArgoCD CLI: argocd login <server-url>"