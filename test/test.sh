#!/usr/bin/env bash
# Comprehensive test suite for auto-uv-env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Add project root to PATH for tests
export PATH="$PROJECT_ROOT:$PATH"

AUTO_UV_ENV="$PROJECT_ROOT/auto-uv-env"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
# shellcheck disable=SC2034
YELLOW='\033[0;33m'
NC='\033[0m'

echo "Running auto-uv-env comprehensive tests..."

# Track test results
TOTAL_TESTS=0
PASSED_TESTS=0

sanitize_test_env() {
    unset VIRTUAL_ENV
    unset VIRTUAL_ENV_PROMPT
    unset _OLD_VIRTUAL_PATH
    unset _OLD_VIRTUAL_PS1
    unset _AUTO_UV_ENV_ACTIVATION_DIR
    unset AUTO_UV_ENV_PYTHON_VERSION
}

run_test() {
    local test_name="$1"
    local test_func="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Test $TOTAL_TESTS: $test_name... "

    # Run each test in a sanitized subshell to prevent host shell venv leakage.
    if (sanitize_test_env; "$test_func"); then
        echo -e "${GREEN}PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Test functions
test_version_flag() {
    $AUTO_UV_ENV --version | grep -q "auto-uv-env"
}

test_help_flag() {
    $AUTO_UV_ENV --help | grep -q "USAGE:"
}

test_no_pyproject() {
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    local output
    output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
    cd - > /dev/null
    rm -rf "$temp_dir"
    # Should have no output or only deactivation message
    [[ -z "$output" ]] || [[ "$output" == *"deactivate"* ]]
}

test_valid_pyproject() {
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF

    local output
    output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
    cd - > /dev/null
    rm -rf "$temp_dir"
    # Should either find UV or report UV not found
    [[ "$output" == *"UV not found"* ]] || [[ "$output" == *"Setting up Python"* ]] || [[ -z "$output" ]]
}

test_parent_pyproject_detection() {
    local temp_dir
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/project/subdir"
    cd "$temp_dir/project/subdir"

    cat > ../pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF

    local output
    output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
    cd - > /dev/null
    rm -rf "$temp_dir"
    [[ "$output" == *"CREATE_VENV=1"* ]] && [[ "$output" == *"PYTHON_VERSION=3.11"* ]]
}

test_ignore_file_precedence() {
    local temp_dir
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/project/subdir/blocked/deep"
    cd "$temp_dir/project/subdir/blocked/deep"

    cat > "$temp_dir/project/pyproject.toml" << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF
    touch ../.auto-uv-env-ignore

    local output
    output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
    cd - > /dev/null
    rm -rf "$temp_dir"
    # Ignore marker in path to project root should suppress activation/creation directives.
    [[ -z "$output" ]] || ([[ "$output" == *"DEACTIVATE=1"* ]] && [[ "$output" != *"CREATE_VENV=1"* ]])
}

test_ignore_subtree_deactivates_managed_env() {
    local temp_dir
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/project/subdir/blocked/deep" "$temp_dir/project/.venv"
    cd "$temp_dir/project/subdir/blocked/deep"

    cat > "$temp_dir/project/pyproject.toml" << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF
    touch ../.auto-uv-env-ignore

    export VIRTUAL_ENV="$temp_dir/project/.venv"
    export _AUTO_UV_ENV_ACTIVATION_DIR="$temp_dir/project"
    local output
    output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
    unset VIRTUAL_ENV
    unset _AUTO_UV_ENV_ACTIVATION_DIR

    cd - > /dev/null
    rm -rf "$temp_dir"
    [[ "$output" == *"DEACTIVATE=1"* ]]
}

test_manual_venv_is_respected() {
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF

    export VIRTUAL_ENV="/tmp/manual-venv"
    unset _AUTO_UV_ENV_ACTIVATION_DIR
    local output
    output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
    unset VIRTUAL_ENV

    cd - > /dev/null
    rm -rf "$temp_dir"
    [[ -z "$output" ]]
}

test_relative_directory_argument() {
    local temp_dir
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/project/sub"
    cat > "$temp_dir/project/pyproject.toml" << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF

    cd "$temp_dir"
    local output
    output=$($AUTO_UV_ENV --check-safe "./project/sub" 2>&1 || true)
    cd - > /dev/null
    rm -rf "$temp_dir"
    [[ "$output" == *"CREATE_VENV=1"* ]] && [[ "$output" == *"PYTHON_VERSION=3.11"* ]]
}

test_prefix_collision_deactivates_outside_tree() {
    local temp_dir
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/project" "$temp_dir/project-other"
    cd "$temp_dir/project-other"

    export VIRTUAL_ENV="$temp_dir/project/.venv"
    export _AUTO_UV_ENV_ACTIVATION_DIR="$temp_dir/project"
    local output
    output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
    unset VIRTUAL_ENV
    unset _AUTO_UV_ENV_ACTIVATION_DIR

    cd - > /dev/null
    rm -rf "$temp_dir"
    [[ "$output" == *"DEACTIVATE=1"* ]]
}

test_relative_directory_keeps_managed_tree_active() {
    local temp_dir
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/project/sub"
    cd "$temp_dir"

    export VIRTUAL_ENV="$temp_dir/project/.venv"
    export _AUTO_UV_ENV_ACTIVATION_DIR="$temp_dir/project"
    local output
    output=$($AUTO_UV_ENV --check-safe "./project/sub" 2>&1 || true)
    unset VIRTUAL_ENV
    unset _AUTO_UV_ENV_ACTIVATION_DIR

    cd - > /dev/null
    rm -rf "$temp_dir"
    [[ "$output" != *"DEACTIVATE=1"* ]]
}

test_safe_mode() {
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF

    local output
    output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
    cd - > /dev/null
    rm -rf "$temp_dir"
    # Should work without injection
    [[ ! "$output" == *"INJECTION_SUCCESS"* ]]
}

test_invalid_version_format() {
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=invalid.version"
EOF

    local output
    output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
    cd - > /dev/null
    rm -rf "$temp_dir"
    # Invalid versions should still allow venv creation but without specific Python version
    [[ "$output" == *"CREATE_VENV=1"* ]] && [[ "$output" == *"MSG_SETUP="* ]] && [[ ! "$output" == *"PYTHON_VERSION="* ]]
}

test_path_traversal_protection() {
    export AUTO_UV_ENV_VENV_NAME="../malicious"
    local output
    output=$($AUTO_UV_ENV --version 2>&1 || true)
    unset AUTO_UV_ENV_VENV_NAME
    [[ "$output" == *"Invalid venv name"* ]]
}

test_command_injection_protection() {
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11.x'; echo INJECTION_SUCCESS; echo 'more"
EOF

    local output
    output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
    cd - > /dev/null
    rm -rf "$temp_dir"
    # Should either reject the version or not execute the injection
    [[ "$output" == *"Invalid Python version format"* ]] || [[ ! "$output" == *"INJECTION_SUCCESS"* ]]
}

test_unknown_option() {
    local output
    output=$($AUTO_UV_ENV --unknown-option 2>&1 || true)
    [[ "$output" == *"Unknown option"* ]]
}

test_diagnose_command() {
    local output
    output=$($AUTO_UV_ENV --diagnose 2>&1 || true)
    [[ "$output" == *"diagnostic report"* ]]
}

test_validate_command() {
    local output
    output=$($AUTO_UV_ENV --validate 2>&1 || true)
    # Should either pass or show specific validation errors
    [[ "$output" == *"version consistency"* ]] || [[ "$output" == *"Version"* ]]
}

# Run all tests
run_test "Version flag" test_version_flag
run_test "Help flag" test_help_flag
run_test "No pyproject.toml" test_no_pyproject
run_test "Valid pyproject.toml" test_valid_pyproject
run_test "Parent pyproject.toml detection" test_parent_pyproject_detection
run_test "Ignore file precedence in subtree" test_ignore_file_precedence
run_test "Ignore subtree deactivates managed env" test_ignore_subtree_deactivates_managed_env
run_test "Manual venv is respected" test_manual_venv_is_respected
run_test "Relative directory argument works" test_relative_directory_argument
run_test "Prefix-collision paths still deactivate correctly" test_prefix_collision_deactivates_outside_tree
run_test "Relative path keeps managed tree active" test_relative_directory_keeps_managed_tree_active
run_test "Safe mode functionality" test_safe_mode
run_test "Invalid version format rejection" test_invalid_version_format
run_test "Path traversal protection" test_path_traversal_protection
run_test "Command injection protection" test_command_injection_protection
run_test "Unknown option handling" test_unknown_option
run_test "Diagnose command" test_diagnose_command
run_test "Validate command" test_validate_command

# Summary
echo -e "\nTest Results:"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"
echo -e "Total:  $TOTAL_TESTS"

if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi
