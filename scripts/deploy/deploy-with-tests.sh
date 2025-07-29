#!/bin/bash
# CloudToLocalLLM Deployment Script with Integrated Testing
# Enhanced deployment workflow with comprehensive test execution

set -euo pipefail

# Script metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="CloudToLocalLLM Test-Integrated Deployment"

# Configuration
PROJECT_DIR="$(pwd)"
SCRIPTS_DIR="$PROJECT_DIR/scripts/deploy"
TEST_DIR="$PROJECT_DIR/test"

# Default settings
FORCE=false
VERBOSE=false
SKIP_TESTS=false
RUN_FLUTTER_TESTS=true
RUN_NODEJS_TESTS=true
RUN_POWERSHELL_TESTS=true
RUN_E2E_TESTS=false  # Skip E2E by default for local deployment
DRY_RUN=false
FAIL_ON_TEST_FAILURE=true

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

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1"
    fi
}

# Show help
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force                  Skip safety prompts and proceed automatically
    --verbose                Enable verbose output
    --skip-tests             Skip all test execution
    --skip-flutter-tests     Skip Flutter tests only
    --skip-nodejs-tests      Skip Node.js tests only
    --skip-powershell-tests  Skip PowerShell tests only
    --include-e2e-tests      Include E2E tests (slower)
    --dry-run                Show what would be done without executing
    --continue-on-test-failure  Continue deployment even if tests fail
    --help                   Show this help message

EXAMPLES:
    $0                       # Run all tests then deploy
    $0 --skip-tests          # Deploy without running tests
    $0 --include-e2e-tests   # Run all tests including E2E
    $0 --dry-run             # Show deployment plan without executing

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --skip-flutter-tests)
                RUN_FLUTTER_TESTS=false
                shift
                ;;
            --skip-nodejs-tests)
                RUN_NODEJS_TESTS=false
                shift
                ;;
            --skip-powershell-tests)
                RUN_POWERSHELL_TESTS=false
                shift
                ;;
            --include-e2e-tests)
                RUN_E2E_TESTS=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --continue-on-test-failure)
                FAIL_ON_TEST_FAILURE=false
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 2
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking deployment prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "pubspec.yaml" ]]; then
        log_error "Not in CloudToLocalLLM project directory"
        exit 1
    fi
    
    # Check for required tools
    local missing_tools=()
    
    if [[ "$RUN_FLUTTER_TESTS" == "true" ]] && ! command -v flutter &> /dev/null; then
        missing_tools+=("flutter")
    fi
    
    if [[ "$RUN_NODEJS_TESTS" == "true" ]] && ! command -v npm &> /dev/null; then
        missing_tools+=("npm")
    fi
    
    if [[ "$RUN_POWERSHELL_TESTS" == "true" ]] && ! command -v pwsh &> /dev/null; then
        missing_tools+=("pwsh")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install missing tools or use --skip-tests to bypass"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Run Flutter tests
run_flutter_tests() {
    if [[ "$RUN_FLUTTER_TESTS" != "true" ]]; then
        log_info "Skipping Flutter tests"
        return 0
    fi
    
    log_info "Running Flutter tests..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: flutter test"
        return 0
    fi
    
    # Get dependencies
    log_verbose "Getting Flutter dependencies..."
    flutter pub get
    
    # Run static analysis
    log_verbose "Running Flutter analyze..."
    if ! flutter analyze --fatal-infos --fatal-warnings; then
        log_error "Flutter static analysis failed"
        return 1
    fi
    
    # Run tests
    log_verbose "Running Flutter unit tests..."
    if ! flutter test; then
        log_error "Flutter tests failed"
        return 1
    fi
    
    # Test build
    log_verbose "Testing Flutter build..."
    if ! flutter build web --release; then
        log_error "Flutter build failed"
        return 1
    fi
    
    log_success "Flutter tests passed"
    return 0
}

# Run Node.js tests
run_nodejs_tests() {
    if [[ "$RUN_NODEJS_TESTS" != "true" ]]; then
        log_info "Skipping Node.js tests"
        return 0
    fi
    
    log_info "Running Node.js tests..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run Node.js tests in services/api-backend"
        return 0
    fi
    
    # Check if API backend exists
    if [[ ! -d "services/api-backend" ]]; then
        log_warning "API backend directory not found, skipping Node.js tests"
        return 0
    fi
    
    cd services/api-backend
    
    # Install dependencies
    log_verbose "Installing Node.js dependencies..."
    npm ci
    
    # Run linting
    log_verbose "Running ESLint..."
    if ! npm run lint; then
        log_error "ESLint failed"
        cd "$PROJECT_DIR"
        return 1
    fi
    
    # Run tests
    log_verbose "Running Node.js tests..."
    if ! npm test; then
        log_error "Node.js tests failed"
        cd "$PROJECT_DIR"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    log_success "Node.js tests passed"
    return 0
}

# Run PowerShell tests
run_powershell_tests() {
    if [[ "$RUN_POWERSHELL_TESTS" != "true" ]]; then
        log_info "Skipping PowerShell tests"
        return 0
    fi
    
    log_info "Running PowerShell tests..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run PowerShell tests"
        return 0
    fi
    
    # Check if PowerShell tests exist
    if [[ ! -f "test/powershell/CI-TestRunner.ps1" ]]; then
        log_warning "PowerShell test runner not found, skipping PowerShell tests"
        return 0
    fi
    
    # Run PowerShell tests
    log_verbose "Running PowerShell deployment tests..."
    if ! pwsh -File test/powershell/CI-TestRunner.ps1 -OutputFormat Minimal -FailFast; then
        log_error "PowerShell tests failed"
        return 1
    fi
    
    log_success "PowerShell tests passed"
    return 0
}

# Run E2E tests
run_e2e_tests() {
    if [[ "$RUN_E2E_TESTS" != "true" ]]; then
        log_info "Skipping E2E tests"
        return 0
    fi
    
    log_info "Running E2E tests..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run Playwright E2E tests"
        return 0
    fi
    
    # Check if Playwright is configured
    if [[ ! -f "playwright.config.js" ]]; then
        log_warning "Playwright config not found, skipping E2E tests"
        return 0
    fi
    
    # Install dependencies and browsers
    log_verbose "Installing Playwright dependencies..."
    npm ci
    npx playwright install --with-deps
    
    # Run E2E tests
    log_verbose "Running Playwright E2E tests..."
    if ! npx playwright test test/e2e/ci-health-check.spec.js; then
        log_error "E2E tests failed"
        return 1
    fi
    
    log_success "E2E tests passed"
    return 0
}

# Main execution
main() {
    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    
    # Parse arguments
    parse_args "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Run tests if not skipped
    if [[ "$SKIP_TESTS" != "true" ]]; then
        log_info "Running test suite..."
        
        local test_failures=0
        
        # Run each test suite
        if ! run_flutter_tests; then
            ((test_failures++))
        fi
        
        if ! run_nodejs_tests; then
            ((test_failures++))
        fi
        
        if ! run_powershell_tests; then
            ((test_failures++))
        fi
        
        if ! run_e2e_tests; then
            ((test_failures++))
        fi
        
        # Handle test failures
        if [[ $test_failures -gt 0 ]]; then
            log_error "$test_failures test suite(s) failed"
            if [[ "$FAIL_ON_TEST_FAILURE" == "true" ]]; then
                log_error "Deployment aborted due to test failures"
                exit 1
            else
                log_warning "Continuing deployment despite test failures"
            fi
        else
            log_success "All tests passed!"
        fi
    else
        log_warning "Skipping all tests as requested"
    fi
    
    # Run deployment
    log_info "Starting deployment..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $SCRIPTS_DIR/complete_deployment.sh"
        log_success "Dry run completed successfully"
        exit 0
    fi
    
    # Execute the actual deployment
    local deploy_args=""
    if [[ "$FORCE" == "true" ]]; then
        deploy_args="$deploy_args --force"
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        deploy_args="$deploy_args --verbose"
    fi
    
    if ! "$SCRIPTS_DIR/complete_deployment.sh" $deploy_args; then
        log_error "Deployment failed"
        exit 1
    fi
    
    log_success "Deployment completed successfully!"
}

# Execute main function with all arguments
main "$@"
