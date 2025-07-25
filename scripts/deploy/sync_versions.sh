#!/bin/bash
# CloudToLocalLLM Version Synchronization Script
# Synchronizes version information across all version files
# Ensures consistency between pubspec.yaml, version.json, and Dart files

set -euo pipefail

# Script metadata
SCRIPT_VERSION="4.0.0"
SCRIPT_NAME="CloudToLocalLLM Version Synchronization"

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"
VERSION_JSON="$PROJECT_ROOT/assets/version.json"
DART_VERSION_FILE="$PROJECT_ROOT/lib/shared/lib/version.dart"
APP_CONFIG_FILE="$PROJECT_ROOT/lib/config/app_config.dart"
SHARED_PUBSPEC="$PROJECT_ROOT/lib/shared/pubspec.yaml"

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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Show help
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --check-only    Only check version consistency, don't sync
    --verbose       Enable verbose output
    --help          Show this help message

DESCRIPTION:
    Synchronizes version information across all version files:
    - pubspec.yaml (main version source)
    - assets/version.json
    - lib/shared/lib/version.dart
    - lib/config/app_config.dart
    - lib/shared/pubspec.yaml

EXAMPLES:
    $0                  # Synchronize all version files
    $0 --check-only     # Check consistency without changes
    $0 --verbose        # Detailed output

EXIT CODES:
    0 - Success (all versions synchronized)
    1 - Version inconsistency found
    2 - File not found or permission error
EOF
}

# Parse command line arguments
CHECK_ONLY=false
VERBOSE=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-only)
                CHECK_ONLY=true
                shift
                ;;
            --verbose)
                VERBOSE=true
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

# Verbose logging
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Extract version from pubspec.yaml
get_pubspec_version() {
    if [[ ! -f "$PUBSPEC_FILE" ]]; then
        log_error "pubspec.yaml not found: $PUBSPEC_FILE"
        exit 2
    fi
    
    local version_line=$(grep "^version:" "$PUBSPEC_FILE" | head -n1)
    if [[ -z "$version_line" ]]; then
        log_error "Version not found in pubspec.yaml"
        exit 2
    fi
    
    echo "$version_line" | sed 's/version: *//' | tr -d '"' | tr -d "'"
}

# Extract semantic version (without build number)
get_semantic_version() {
    local full_version="$1"
    echo "$full_version" | cut -d'+' -f1
}

# Extract build number
get_build_number() {
    local full_version="$1"
    if [[ "$full_version" == *"+"* ]]; then
        echo "$full_version" | cut -d'+' -f2
    else
        echo "1"
    fi
}

# Generate build timestamp
generate_build_timestamp() {
    date +"%Y%m%d%H%M"
}

# Check if file exists and is writable
check_file_access() {
    local file="$1"
    local file_name="$2"
    
    if [[ ! -f "$file" ]]; then
        log_warning "$file_name not found: $file"
        return 1
    fi
    
    if [[ ! -w "$file" ]]; then
        log_error "$file_name is not writable: $file"
        return 1
    fi
    
    return 0
}

# Update version.json
update_version_json() {
    local semantic_version="$1"
    local build_number="$2"
    local build_timestamp="$3"
    
    log_verbose "Updating version.json..."
    
    if ! check_file_access "$VERSION_JSON" "version.json"; then
        return 1
    fi
    
    cat > "$VERSION_JSON" << EOF
{
  "version": "$semantic_version",
  "build_number": "$build_number",
  "build_timestamp": "$build_timestamp",
  "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    log_verbose "Updated: $VERSION_JSON"
    return 0
}

# Update Dart version file
update_dart_version() {
    local semantic_version="$1"
    local build_number="$2"
    local build_timestamp="$3"
    
    log_verbose "Updating Dart version file..."
    
    if ! check_file_access "$DART_VERSION_FILE" "version.dart"; then
        return 1
    fi
    
    # Create backup
    cp "$DART_VERSION_FILE" "$DART_VERSION_FILE.backup"
    
    # Update version constants
    sed -i "s/static const String mainAppVersion = '[^']*';/static const String mainAppVersion = '$semantic_version';/" "$DART_VERSION_FILE"
    sed -i "s/static const int mainAppBuildNumber = [0-9]*;/static const int mainAppBuildNumber = $build_number;/" "$DART_VERSION_FILE"
    sed -i "s/static const String buildTimestamp = '[^']*';/static const String buildTimestamp = '$(date -u +"%Y-%m-%dT%H:%M:%SZ")';/" "$DART_VERSION_FILE"
    
    log_verbose "Updated: $DART_VERSION_FILE"
    return 0
}

# Update app config
update_app_config() {
    local semantic_version="$1"
    
    log_verbose "Updating app config..."
    
    if ! check_file_access "$APP_CONFIG_FILE" "app_config.dart"; then
        return 1
    fi
    
    # Create backup
    cp "$APP_CONFIG_FILE" "$APP_CONFIG_FILE.backup"
    
    # Update version in app config
    sed -i "s/static const String version = '[^']*';/static const String version = '$semantic_version';/" "$APP_CONFIG_FILE"
    
    log_verbose "Updated: $APP_CONFIG_FILE"
    return 0
}

# Update shared pubspec
update_shared_pubspec() {
    local full_version="$1"
    
    log_verbose "Updating shared pubspec..."
    
    if ! check_file_access "$SHARED_PUBSPEC" "shared pubspec.yaml"; then
        return 1
    fi
    
    # Create backup
    cp "$SHARED_PUBSPEC" "$SHARED_PUBSPEC.backup"
    
    # Update version in shared pubspec
    sed -i "s/^version: .*/version: $full_version/" "$SHARED_PUBSPEC"
    
    log_verbose "Updated: $SHARED_PUBSPEC"
    return 0
}

# Check version consistency
check_consistency() {
    log_step "Checking version consistency..."
    
    local pubspec_version=$(get_pubspec_version)
    local semantic_version=$(get_semantic_version "$pubspec_version")
    local build_number=$(get_build_number "$pubspec_version")
    
    log_info "Master version (pubspec.yaml): $pubspec_version"
    log_info "Semantic version: $semantic_version"
    log_info "Build number: $build_number"
    
    local inconsistencies=0
    
    # Check version.json
    if [[ -f "$VERSION_JSON" ]]; then
        local json_version=$(grep '"version"' "$VERSION_JSON" | cut -d'"' -f4 2>/dev/null || echo "")
        if [[ "$json_version" != "$semantic_version" ]]; then
            log_warning "version.json version mismatch: $json_version != $semantic_version"
            ((inconsistencies++))
        fi
    else
        log_warning "version.json not found"
        ((inconsistencies++))
    fi
    
    # Check Dart version file
    if [[ -f "$DART_VERSION_FILE" ]]; then
        local dart_version=$(grep "mainAppVersion = " "$DART_VERSION_FILE" | cut -d"'" -f2 2>/dev/null || echo "")
        if [[ "$dart_version" != "$semantic_version" ]]; then
            log_warning "version.dart version mismatch: $dart_version != $semantic_version"
            ((inconsistencies++))
        fi
    else
        log_warning "version.dart not found"
        ((inconsistencies++))
    fi
    
    if [[ $inconsistencies -eq 0 ]]; then
        log_success "All versions are consistent: $semantic_version"
        return 0
    else
        log_error "Found $inconsistencies version inconsistencies"
        return 1
    fi
}

# Synchronize all versions
sync_versions() {
    log_step "Synchronizing version information..."
    
    local pubspec_version=$(get_pubspec_version)
    local semantic_version=$(get_semantic_version "$pubspec_version")
    local build_number=$(get_build_number "$pubspec_version")
    local build_timestamp=$(generate_build_timestamp)
    
    log_info "Synchronizing to version: $semantic_version (build: $build_number)"
    
    local sync_errors=0
    
    # Update all version files
    update_version_json "$semantic_version" "$build_number" "$build_timestamp" || ((sync_errors++))
    update_dart_version "$semantic_version" "$build_number" "$build_timestamp" || ((sync_errors++))
    update_app_config "$semantic_version" || ((sync_errors++))
    update_shared_pubspec "$pubspec_version" || ((sync_errors++))
    
    if [[ $sync_errors -eq 0 ]]; then
        log_success "✅ All versions synchronized to $semantic_version"
        return 0
    else
        log_error "❌ $sync_errors errors occurred during synchronization"
        return 1
    fi
}

# Main function
main() {
    echo "================================================================"
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "Time: $(date)"
    echo "Project: $PROJECT_ROOT"
    echo "================================================================"
    echo
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    if [[ "$CHECK_ONLY" == "true" ]]; then
        check_consistency
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_success "🎉 Version consistency check passed"
        else
            log_error "🚨 Version consistency check failed"
        fi
        
        exit $exit_code
    else
        # First check consistency
        if check_consistency; then
            log_info "Versions are already consistent"
        else
            log_info "Synchronizing inconsistent versions..."
            sync_versions
            local exit_code=$?
            
            if [[ $exit_code -eq 0 ]]; then
                log_success "🎉 Version synchronization completed"
            else
                log_error "🚨 Version synchronization failed"
            fi
            
            exit $exit_code
        fi
    fi
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    parse_args "$@"
    
    # Execute main function
    main
fi
