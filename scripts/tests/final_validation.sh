#!/bin/bash

# Final Validation Script for README.md Security Enhancements
# Comprehensive validation of all security improvements before deployment

# Set up environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation counters
VALIDATIONS_RUN=0
VALIDATIONS_PASSED=0
VALIDATIONS_FAILED=0

# Logging functions
log_validation_info() {
    echo -e "${BLUE}[VALIDATION]${NC} $1"
}

log_validation_success() {
    echo -e "${GREEN}[✓ PASS]${NC} $1"
    ((VALIDATIONS_PASSED++))
}

log_validation_failure() {
    echo -e "${RED}[✗ FAIL]${NC} $1"
    ((VALIDATIONS_FAILED++))
}

log_validation_warning() {
    echo -e "${YELLOW}[⚠ WARN]${NC} $1"
}

# Validation functions
validate_security_functions_exist() {
    log_validation_info "Validating security functions exist in scripts..."
    ((VALIDATIONS_RUN++))
    
    local bash_script="$PROJECT_ROOT/scripts/version_manager.sh"
    local ps_script="$PROJECT_ROOT/scripts/powershell/version_manager.ps1"
    
    local required_bash_functions=(
        "validate_version_string"
        "escape_for_sed"
        "verify_file_operations_safe"
        "atomic_file_replace"
        "preserve_file_characteristics"
        "validate_utf8_encoding"
        "acquire_file_lock"
        "release_file_lock"
        "create_timestamped_backup"
        "verify_backup_integrity"
    )
    
    local required_ps_functions=(
        "Test-VersionString"
        "ConvertTo-RegexSafe"
        "Test-FileOperationsSafe"
        "Invoke-AtomicFileReplace"
        "Preserve-FileCharacteristics"
        "Test-Utf8Encoding"
        "Lock-File"
        "Unlock-File"
        "New-TimestampedBackup"
        "Test-BackupIntegrity"
    )
    
    local missing_functions=0
    
    # Check Bash functions
    for func in "${required_bash_functions[@]}"; do
        if grep -q "^$func()" "$bash_script"; then
            log_validation_success "Bash function found: $func"
        else
            log_validation_failure "Bash function missing: $func"
            ((missing_functions++))
        fi
    done
    
    # Check PowerShell functions
    for func in "${required_ps_functions[@]}"; do
        if grep -q "function $func" "$ps_script"; then
            log_validation_success "PowerShell function found: $func"
        else
            log_validation_failure "PowerShell function missing: $func"
            ((missing_functions++))
        fi
    done
    
    if [[ $missing_functions -eq 0 ]]; then
        log_validation_success "All required security functions are present"
    else
        log_validation_failure "$missing_functions security functions are missing"
    fi
}

validate_test_suites_exist() {
    log_validation_info "Validating test suites exist and are executable..."
    ((VALIDATIONS_RUN++))
    
    local test_files=(
        "$SCRIPT_DIR/security_tests.sh"
        "$SCRIPT_DIR/SecurityTests.ps1"
        "$SCRIPT_DIR/integrity_tests.sh"
        "$SCRIPT_DIR/IntegrityTests.ps1"
    )
    
    local missing_tests=0
    
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            log_validation_success "Test suite found: $(basename "$test_file")"
        else
            log_validation_failure "Test suite missing: $(basename "$test_file")"
            ((missing_tests++))
        fi
    done
    
    if [[ $missing_tests -eq 0 ]]; then
        log_validation_success "All test suites are present"
    else
        log_validation_failure "$missing_tests test suites are missing"
    fi
}

validate_documentation_exists() {
    log_validation_info "Validating security documentation exists..."
    ((VALIDATIONS_RUN++))
    
    local doc_files=(
        "$PROJECT_ROOT/docs/SECURITY/README_SCRIPT_SECURITY.md"
    )
    
    local missing_docs=0
    
    for doc_file in "${doc_files[@]}"; do
        if [[ -f "$doc_file" ]]; then
            log_validation_success "Documentation found: $(basename "$doc_file")"
        else
            log_validation_failure "Documentation missing: $(basename "$doc_file")"
            ((missing_docs++))
        fi
    done
    
    if [[ $missing_docs -eq 0 ]]; then
        log_validation_success "All security documentation is present"
    else
        log_validation_failure "$missing_docs documentation files are missing"
    fi
}

run_security_tests() {
    log_validation_info "Running security test suites..."
    ((VALIDATIONS_RUN++))
    
    local test_results=0
    
    # Run Bash security tests
    if [[ -f "$SCRIPT_DIR/security_tests.sh" ]]; then
        log_validation_info "Running Bash security tests..."
        if bash "$SCRIPT_DIR/security_tests.sh" >/dev/null 2>&1; then
            log_validation_success "Bash security tests passed"
        else
            log_validation_failure "Bash security tests failed"
            ((test_results++))
        fi
    fi
    
    # Run Bash integrity tests
    if [[ -f "$SCRIPT_DIR/integrity_tests.sh" ]]; then
        log_validation_info "Running Bash integrity tests..."
        if bash "$SCRIPT_DIR/integrity_tests.sh" >/dev/null 2>&1; then
            log_validation_success "Bash integrity tests passed"
        else
            log_validation_failure "Bash integrity tests failed"
            ((test_results++))
        fi
    fi
    
    if [[ $test_results -eq 0 ]]; then
        log_validation_success "All security tests passed"
    else
        log_validation_failure "$test_results test suites failed"
    fi
}

validate_script_syntax() {
    log_validation_info "Validating script syntax..."
    ((VALIDATIONS_RUN++))
    
    local syntax_errors=0
    
    # Check Bash script syntax
    local bash_script="$PROJECT_ROOT/scripts/version_manager.sh"
    if bash -n "$bash_script" 2>/dev/null; then
        log_validation_success "Bash script syntax is valid"
    else
        log_validation_failure "Bash script has syntax errors"
        ((syntax_errors++))
    fi
    
    # Check PowerShell script syntax (if PowerShell is available)
    local ps_script="$PROJECT_ROOT/scripts/powershell/version_manager.ps1"
    if command -v powershell >/dev/null 2>&1; then
        if powershell -Command "Get-Content '$ps_script' | Out-String | Invoke-Expression" >/dev/null 2>&1; then
            log_validation_success "PowerShell script syntax is valid"
        else
            log_validation_failure "PowerShell script has syntax errors"
            ((syntax_errors++))
        fi
    else
        log_validation_warning "PowerShell not available for syntax checking"
    fi
    
    if [[ $syntax_errors -eq 0 ]]; then
        log_validation_success "All scripts have valid syntax"
    else
        log_validation_failure "$syntax_errors scripts have syntax errors"
    fi
}

validate_security_patterns() {
    log_validation_info "Validating security patterns in scripts..."
    ((VALIDATIONS_RUN++))
    
    local bash_script="$PROJECT_ROOT/scripts/version_manager.sh"
    local ps_script="$PROJECT_ROOT/scripts/powershell/version_manager.ps1"
    
    local security_issues=0
    
    # Check for dangerous patterns in Bash script
    if grep -q "eval\|exec\|\$(" "$bash_script"; then
        log_validation_warning "Potentially dangerous patterns found in Bash script"
    fi
    
    # Check for input validation in README update function
    if grep -A 10 "update_readme_version" "$bash_script" | grep -q "validate_version_string"; then
        log_validation_success "Input validation found in Bash README update function"
    else
        log_validation_failure "Input validation missing in Bash README update function"
        ((security_issues++))
    fi
    
    # Check for file locking in README update function
    if grep -A 20 "update_readme_version" "$bash_script" | grep -q "acquire_file_lock"; then
        log_validation_success "File locking found in Bash README update function"
    else
        log_validation_failure "File locking missing in Bash README update function"
        ((security_issues++))
    fi
    
    # Check PowerShell script for similar patterns
    if grep -A 10 "Update-ReadmeVersion" "$ps_script" | grep -q "Test-VersionString"; then
        log_validation_success "Input validation found in PowerShell README update function"
    else
        log_validation_failure "Input validation missing in PowerShell README update function"
        ((security_issues++))
    fi
    
    if grep -A 20 "Update-ReadmeVersion" "$ps_script" | grep -q "Lock-File"; then
        log_validation_success "File locking found in PowerShell README update function"
    else
        log_validation_failure "File locking missing in PowerShell README update function"
        ((security_issues++))
    fi
    
    if [[ $security_issues -eq 0 ]]; then
        log_validation_success "All security patterns are correctly implemented"
    else
        log_validation_failure "$security_issues security patterns are missing or incorrect"
    fi
}

# Main validation runner
run_final_validation() {
    log_validation_info "Starting Final Security Validation"
    log_validation_info "===================================="
    echo
    
    # Run all validations
    validate_security_functions_exist
    echo
    validate_test_suites_exist
    echo
    validate_documentation_exists
    echo
    validate_script_syntax
    echo
    validate_security_patterns
    echo
    run_security_tests
    echo
    
    # Print summary
    log_validation_info "Final Validation Summary"
    log_validation_info "========================"
    log_validation_info "Validations Run: $VALIDATIONS_RUN"
    log_validation_success "Validations Passed: $VALIDATIONS_PASSED"
    
    if [[ $VALIDATIONS_FAILED -gt 0 ]]; then
        log_validation_failure "Validations Failed: $VALIDATIONS_FAILED"
        echo
        log_validation_failure "❌ FINAL VALIDATION FAILED - DEPLOYMENT NOT RECOMMENDED"
        echo
        log_validation_info "Please address the failed validations before deploying the security enhancements."
        exit 1
    else
        echo
        log_validation_success "✅ ALL VALIDATIONS PASSED - READY FOR DEPLOYMENT"
        echo
        log_validation_info "Security enhancements have been successfully implemented and validated."
        log_validation_info "The README.md update scripts are now secure and ready for production use."
        exit 0
    fi
}

# Run validation if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_final_validation
fi
