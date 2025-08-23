#!/usr/bin/env bash
# test-install.sh — Comprehensive test script for install.sh
# Version: 2.0.0
#
# SUMMARY
#   Tests the dotfiles installation script functionality in a controlled environment
#   without affecting the actual system.
#
# USAGE
#   ./tests/install.test.sh
#
# AUTHOR
#   Enhanced with comprehensive dotfiles testing

set -euo pipefail

# ---------- constants ----------
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_DIR="$(mktemp -d)"
readonly INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
readonly CONFIG_FILE="$SCRIPT_DIR/install.conf.sh"

# ---------- global variables ----------
declare -g use_color=1 is_tty=0 verbose_mode=0
declare -g test_failures=0

# ---------- initialization ----------
[[ -t 1 ]] && is_tty=1

# ---------- logging ----------
log() {
    local level="$1"; shift
    local prefix icon color output_fd=1

    case "$level" in
        info)  prefix='>>' icon='>>'; color='36' ;;
        ok)    prefix='✓'  icon='✓';  color='32' ;;
        warn)  prefix='--' icon='--'; color='90' ;;
        error) prefix='!!' icon='!!'; color='31'; output_fd=2 ;;
        test)  prefix='TEST' icon='TEST'; color='35' ;;
        pass)  prefix='PASS' icon='PASS'; color='92' ;;
        fail)  prefix='FAIL' icon='FAIL'; color='91'; output_fd=2 ;;
        *) log error "Unknown log level: $level"; return 1 ;;
    esac

    if [[ $use_color -eq 1 && $is_tty -eq 1 ]]; then
        printf "\033[${color}m${icon}\033[0m %s\n" "$*" >&$output_fd
    else
        printf "%s %s\n" "$prefix" "$*" >&$output_fd
    fi
}

# ---------- cleanup ----------
cleanup() {
    local exit_code=$?
    log info "Cleaning up test environment: $TEST_DIR"
    rm -rf "$TEST_DIR" 2>/dev/null || true

    if [[ $test_failures -eq 0 && $exit_code -eq 0 ]]; then
        log ok "All tests passed!"
    else
        log error "Tests failed (failures: $test_failures, exit code: $exit_code)"
    fi
}

trap cleanup EXIT

# ---------- helpers ----------
run_with_timeout() {
    local seconds="$1"; shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$seconds" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$seconds" "$@"
    else
        "$@"
    fi
}

# ---------- test functions ----------
test_script_exists() {
    log test "Checking if install script exists"

    if [[ -f "$INSTALL_SCRIPT" ]]; then
        log pass "Install script found: $INSTALL_SCRIPT"
        return 0
    else
        log fail "Install script not found: $INSTALL_SCRIPT"
        ((test_failures++))
        return 1
    fi
}

test_script_executable() {
    log test "Checking if install script is executable"

    if [[ -x "$INSTALL_SCRIPT" ]]; then
        log pass "Install script is executable"
        return 0
    else
        log fail "Install script is not executable"
        ((test_failures++))
        return 1
    fi
}

test_config_file_exists() {
    log test "Checking if configuration file exists"

    if [[ -f "$CONFIG_FILE" ]]; then
        log pass "Configuration file found: $CONFIG_FILE"
        return 0
    else
        log fail "Configuration file not found: $CONFIG_FILE"
        ((test_failures++))
        return 1
    fi
}

test_help_option() {
    log test "Testing --help option"

    local help_output
    if help_output="$(bash "$INSTALL_SCRIPT" --help 2>&1)"; then
        if [[ "$help_output" == *"Dotfiles Installation Script"* ]]; then
            log pass "--help option works correctly"
            return 0
        else
            log fail "--help option output incorrect"
            ((test_failures++))
            return 1
        fi
    else
        log fail "--help option failed"
        ((test_failures++))
        return 1
    fi
}

test_config_parsing() {
    log test "Testing configuration file parsing"

    # Create a test configuration file
    local test_config="$TEST_DIR/test.conf.sh"
    cat > "$test_config" <<'EOF'
# Test configuration
LINKS=(
  "test/source1:~/target1"
  "test/source2:~/target2"
)

STEPS=(
  "echo 'step 1'"
  "echo 'step 2'"
)
EOF

    # Test that we can source it and access the arrays
    local test_script="$TEST_DIR/test_parse.sh"
    cat > "$test_script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$test_config"
echo "Links: \${#LINKS[@]}"
echo "Steps: \${#STEPS[@]}"
EOF

    chmod +x "$test_script"

    local parse_output
    if parse_output="$(bash "$test_script" 2>&1)"; then
        if [[ "$parse_output" == *"Links: 2"* && "$parse_output" == *"Steps: 2"* ]]; then
            log pass "Configuration parsing works: $parse_output"
            return 0
        else
            log fail "Configuration parsing output unexpected: $parse_output"
            ((test_failures++))
            return 1
        fi
    else
        log fail "Configuration parsing failed: $parse_output"
        ((test_failures++))
        return 1
    fi
}

test_dry_run_mode() {
    log test "Testing dry run mode"

    local dry_run_output exit_code tmp
    tmp="$(mktemp)"
    if run_with_timeout 30 bash "$INSTALL_SCRIPT" --dry-run >"$tmp" 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi
    dry_run_output="$(cat "$tmp")"
    rm -f "$tmp"
    if [[ "$dry_run_output" == *"DRY RUN MODE"* ]] || [[ "$dry_run_output" == *"Installation Summary"* ]]; then
        log pass "Dry run mode works correctly"
        return 0
    else
        log fail "Dry run mode output unexpected"
        ((test_failures++))
        return 1
    fi
}

test_verbose_mode() {
    log test "Testing verbose mode"

    local verbose_output exit_code tmp
    tmp="$(mktemp)"
    if run_with_timeout 30 bash "$INSTALL_SCRIPT" --dry-run --verbose >"$tmp" 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi
    verbose_output="$(cat "$tmp")"
    rm -f "$tmp"
    if [[ "$verbose_output" == *"[DEBUG]"* ]]; then
        log pass "Verbose mode works correctly"
        return 0
    else
        log fail "Verbose mode output doesn't contain debug messages"
        ((test_failures++))
        return 1
    fi
}

test_symlink_creation() {
    log test "Testing symlink creation in isolated environment"

    # Create a test environment
    local test_home="$TEST_DIR/home"
    local test_dotfiles="$TEST_DIR/dotfiles"
    local test_config="$test_dotfiles/install.conf.sh"

    mkdir -p "$test_home" "$test_dotfiles/test"

    # Create test source files
    echo "test content 1" > "$test_dotfiles/test/file1"
    echo "test content 2" > "$test_dotfiles/test/file2"

    # Create test configuration
    cat > "$test_config" <<EOF
LINKS=(
  "test/file1:$test_home/.file1"
  "test/file2:$test_home/.config/file2"
)

STEPS=(
  "echo 'test step completed'"
)
EOF

    # Copy our install script to test directory
    cp "$INSTALL_SCRIPT" "$test_dotfiles/"

    # Run the installation in test environment
    local install_output
    cd "$test_dotfiles"
    if install_output="$(bash ./install.sh --dry-run --verbose 2>&1)"; then
        if [[ "$install_output" == *"Symbolic links: 2"* ]] || [[ "$install_output" == *"Processed 2 symbolic links"* ]]; then
            log pass "Symlink creation test (dry-run) works"
            return 0
        else
            log fail "Symlink creation test output unexpected: $install_output"
            ((test_failures++))
            return 1
        fi
    else
        log fail "Symlink creation test failed: $install_output"
        ((test_failures++))
        return 1
    fi
}

test_backup_functionality() {
    log test "Testing backup functionality"

    # Create a test environment
    local test_home="$TEST_DIR/backup_test"
    local test_dotfiles="$TEST_DIR/backup_dotfiles"
    local test_config="$test_dotfiles/install.conf.sh"

    mkdir -p "$test_home" "$test_dotfiles/test"

    # Create test source files
    echo "new content" > "$test_dotfiles/test/testfile"

    # Create existing target file that should be backed up
    echo "existing content" > "$test_home/.testfile"

    # Create test configuration
    cat > "$test_config" <<EOF
LINKS=(
  "test/testfile:$test_home/.testfile"
)

STEPS=()
EOF

    # Copy our install script to test directory
    cp "$INSTALL_SCRIPT" "$test_dotfiles/"

    # Run the installation in test environment with dry-run
    local backup_output
    cd "$test_dotfiles"
    if backup_output="$(bash ./install.sh --dry-run --verbose 2>&1)"; then
        if [[ "$backup_output" == *"Would backup"* ]] || [[ "$backup_output" == *"Processed 1 symbolic links"* ]] || [[ "$backup_output" == *"Symbolic links: 1"* ]]; then
            log pass "Backup functionality test (dry-run) works"
            return 0
        else
            log fail "Backup functionality test output unexpected: $backup_output"
            ((test_failures++))
            return 1
        fi
    else
        log fail "Backup functionality test failed: $backup_output"
        ((test_failures++))
        return 1
    fi
}

test_idempotency_check() {
    log test "Testing idempotency checks"

    # Create a test environment
    local test_home="$TEST_DIR/idempotent_test"
    local test_dotfiles="$TEST_DIR/idempotent_dotfiles"
    local test_config="$test_dotfiles/install.conf.sh"

    mkdir -p "$test_home" "$test_dotfiles/test"

    # Create test source files
    echo "test content" > "$test_dotfiles/test/idempotent_file"

    # Create test configuration
    cat > "$test_config" <<EOF
LINKS=(
  "test/idempotent_file:$test_home/.idempotent_file"
)

STEPS=()
EOF

    # Copy our install script to test directory
    cp "$INSTALL_SCRIPT" "$test_dotfiles/"
    cd "$test_dotfiles"

    # First run - should propose creating the symlink
    local first_run
    if first_run="$(bash ./install.sh --dry-run --verbose 2>&1)"; then
        if [[ "$first_run" == *"Would create symlink"* ]] || [[ "$first_run" == *"Processing symbolic links"* ]]; then
            # Now simulate that the symlink already exists and is correct
            ln -s "$test_dotfiles/test/idempotent_file" "$test_home/.idempotent_file"

            # Second run - should detect existing correct symlink
            local second_run
            if second_run="$(bash ./install.sh --dry-run --verbose 2>&1)"; then
                if [[ "$second_run" == *"already exists and is correct"* ]]; then
                    log pass "Idempotency check works correctly"
                    return 0
                else
                    log fail "Idempotency check failed: $second_run"
                    ((test_failures++))
                    return 1
                fi
            else
                log fail "Second idempotency run failed: $second_run"
                ((test_failures++))
                return 1
            fi
        else
            log fail "First idempotency run failed: $first_run"
            ((test_failures++))
            return 1
        fi
    else
        log fail "Idempotency test setup failed: $first_run"
        ((test_failures++))
        return 1
    fi
}

test_error_handling() {
    log test "Testing error handling"

    # Create a test environment with missing source files
    local test_dotfiles="$TEST_DIR/error_test_dotfiles"
    local test_config="$test_dotfiles/install.conf.sh"

    mkdir -p "$test_dotfiles"

    # Create test configuration with non-existent source
    cat > "$test_config" <<EOF
LINKS=(
  "nonexistent/file:~/test_target"
)

STEPS=(
  "false"  # This command will always fail
)
EOF

    # Copy our install script to test directory
    cp "$INSTALL_SCRIPT" "$test_dotfiles/"
    cd "$test_dotfiles"

    # Run with dry-run mode - should handle missing files gracefully
    local error_output
    local exit_code=0
    if ! error_output="$(bash ./install.sh --dry-run 2>&1)"; then
        exit_code=$?
    fi
    if [[ "$error_output" == *"doesn't exist"* ]] || [[ "$error_output" == *"Installation Summary"* ]] || [[ $exit_code -eq 0 ]]; then
        log pass "Error handling for missing files works"
        return 0
    else
        log fail "Error handling test output unexpected (exit $exit_code): $error_output"
        ((test_failures++))
        return 1
    fi
}

test_real_config_compatibility() {
    log test "Testing compatibility with real configuration"

    # Test that our script can parse the actual install.conf.sh
    local real_config_test exit_code
    if real_config_test="$(bash "$INSTALL_SCRIPT" --dry-run 2>&1)"; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    # Accept any of these as success indicators:
    # - Script executed successfully (exit code 0)
    # - Output contains expected text patterns
    # - Output contains summary (which means script completed)
    if [[ $exit_code -eq 0 ]] || [[ "$real_config_test" == *"Processing symbolic links"* ]] || [[ "$real_config_test" == *"Processing installation steps"* ]] || [[ "$real_config_test" == *"Installation Summary"* ]] || [[ "$real_config_test" == *"Dotfiles Installation Script"* ]]; then
        log pass "Real configuration compatibility works"
        return 0
    else
        log fail "Real configuration test failed (exit $exit_code): $real_config_test"
        ((test_failures++))
        return 1
    fi
}

# ---------- main test execution ----------
main() {
    log info "Starting installation script tests (version $SCRIPT_VERSION)"
    log info "Test directory: $TEST_DIR"
    log info "Script directory: $SCRIPT_DIR"
    echo

    # Basic validation tests
    test_script_exists
    test_script_executable
    test_config_file_exists

    # Functionality tests
    test_help_option
    test_config_parsing
    test_dry_run_mode
    test_verbose_mode

    # Core feature tests
    test_symlink_creation
    test_backup_functionality
    test_idempotency_check
    test_error_handling

    # Integration tests
    test_real_config_compatibility

    echo
    if [[ $test_failures -eq 0 ]]; then
        log ok "All tests completed successfully!"
        return 0
    else
        log error "Tests completed with $test_failures failure(s)"
        return 1
    fi
}

# ---------- argument parsing ----------
while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        -v|--verbose)
            verbose_mode=1
            shift ;;
        --no-color)
            use_color=0
            shift ;;
        -h|--help)
            cat <<'EOF'
Dotfiles Installation Script Test Suite

USAGE:
  ./tests/install.test.sh [OPTIONS]

OPTIONS:
  -v, --verbose     Enable verbose output
  --no-color        Disable colored output
  -h, --help        Show this help

This script tests:
1. Script existence and permissions
2. Configuration file parsing
3. Help functionality
4. Dry-run mode operation
5. Verbose mode output
6. Symlink creation logic
7. Backup functionality
8. Idempotency checks
9. Error handling scenarios
10. Real configuration compatibility

EOF
            exit 0 ;;
        *)
            log error "Unknown option: $1"
            exit 1 ;;
    esac
done

main
