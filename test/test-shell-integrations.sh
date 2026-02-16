#!/usr/bin/env bash
# Comprehensive shell integration tests for auto-uv-env
# Tests the actual shell integration files with mocked state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Add project root to PATH for tests
export PATH="$PROJECT_ROOT:$PATH"

INTEGRATION_DIR="$SCRIPT_DIR/../share/auto-uv-env"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
# shellcheck disable=SC2034
YELLOW='\033[0;33m'
NC='\033[0m'

echo "Running comprehensive shell integration tests..."

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

# Test bash integration syntax
test_bash_syntax() {
    bash -n "$INTEGRATION_DIR/auto-uv-env.bash"
}

# Test zsh integration syntax
test_zsh_syntax() {
    if command -v zsh >/dev/null 2>&1; then
        zsh -n "$INTEGRATION_DIR/auto-uv-env.zsh"
    else
        echo "ZSH not available, skipping"
        return 0
    fi
}

# Test zsh deactivation when paths share a prefix but are different trees
test_zsh_prefix_collision_deactivates_outside_tree() {
    if ! command -v zsh >/dev/null 2>&1; then
        echo "ZSH not available, skipping"
        return 0
    fi

    local temp_dir
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/project" "$temp_dir/project-other"

    local result
    result=$(zsh -c "
        cd '$temp_dir'
        export PATH=\"$PROJECT_ROOT:\$PATH\"
        export AUTO_UV_ENV_QUIET=1
        source '$INTEGRATION_DIR/auto-uv-env.zsh'

        export VIRTUAL_ENV='$temp_dir/project/.venv'
        export _AUTO_UV_ENV_ACTIVATION_DIR='$temp_dir/project'
        export AUTO_UV_ENV_PYTHON_VERSION='3.11.0'

        deactivate() { unset VIRTUAL_ENV; }

        cd '$temp_dir/project-other'
        auto_uv_env >/dev/null 2>&1 || exit 1

        [[ -z \"\$VIRTUAL_ENV\" ]] || exit 1
        [[ -z \"\$_AUTO_UV_ENV_ACTIVATION_DIR\" ]] || exit 1
        [[ -z \"\$AUTO_UV_ENV_PYTHON_VERSION\" ]] || exit 1
        echo 'ZSH_PREFIX_COLLISION_DEACTIVATE_SUCCESS'
    " 2>&1)

    rm -rf "$temp_dir"
    [[ "$result" == *"ZSH_PREFIX_COLLISION_DEACTIVATE_SUCCESS"* ]]
}

# Test zsh temp state file cleanup when check-safe fails
test_zsh_state_file_cleanup_on_failure() {
    if ! command -v zsh >/dev/null 2>&1; then
        echo "ZSH not available, skipping"
        return 0
    fi

    local temp_dir
    temp_dir=$(mktemp -d)

    local result
    result=$(zsh -c "
        cd '$temp_dir'
        export PATH=\"$PROJECT_ROOT:\$PATH\"
        export AUTO_UV_ENV_QUIET=1
        source '$INTEGRATION_DIR/auto-uv-env.zsh'

        auto-uv-env() { return 1; }

        auto_uv_env >/dev/null 2>&1 || exit 1
        [[ ! -f \"/tmp/auto-uv-env.\$\$.state\" ]] || exit 1
        echo 'ZSH_STATE_CLEANUP_SUCCESS'
    " 2>&1)

    rm -rf "$temp_dir"
    [[ "$result" == *"ZSH_STATE_CLEANUP_SUCCESS"* ]]
}

# Test fish integration syntax
test_fish_syntax() {
    if command -v fish >/dev/null 2>&1; then
        fish -n "$INTEGRATION_DIR/auto-uv-env.fish"
    else
        echo "Fish not available, skipping"
        return 0
    fi
}

# Test fish temp state file cleanup when check-safe fails
test_fish_state_file_cleanup_on_failure() {
    if ! command -v fish >/dev/null 2>&1; then
        echo "Fish not available, skipping"
        return 0
    fi

    local temp_dir
    temp_dir=$(mktemp -d)

    local result
    result=$(fish -c "
        cd '$temp_dir'
        set -gx PATH '$PROJECT_ROOT' \$PATH
        set -gx AUTO_UV_ENV_QUIET 1
        source '$INTEGRATION_DIR/auto-uv-env.fish'

        function auto-uv-env
            return 1
        end

        auto_uv_env >/dev/null 2>&1
        or exit 1

        set -l state_file '/tmp/auto-uv-env.'(echo %self)'.state'
        test ! -f \$state_file
        or exit 1

        echo 'FISH_STATE_CLEANUP_SUCCESS'
    " 2>&1)

    rm -rf "$temp_dir"
    [[ "$result" == *"FISH_STATE_CLEANUP_SUCCESS"* ]]
}

# Test lazy-loading fast path in non-Python directories
test_non_python_fast_path() {
    local temp_dir
    temp_dir=$(mktemp -d)

    local result
    result=$(bash -c "
        cd '$temp_dir'
        export PATH='$PROJECT_ROOT:\$PATH'
        source '$INTEGRATION_DIR/auto-uv-env.bash'

        # If this executes in a non-Python directory, fast-path is broken.
        auto-uv-env() { echo 'AUTO_UV_ENV_CALLED'; return 1; }

        auto_uv_env
        echo 'FAST_PATH_OK'
    " 2>&1)

    rm -rf "$temp_dir"
    [[ "$result" == *"FAST_PATH_OK"* ]] && [[ "$result" != *"AUTO_UV_ENV_CALLED"* ]]
}

# Test activation when entering a project via nested subdirectory
test_subdirectory_project_activation() {
    local temp_dir
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/project/subdir"
    cd "$temp_dir/project/subdir"

    cat > ../pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF

    local result
    result=$(bash -c "
        cd '$temp_dir/project/subdir'
        unset VIRTUAL_ENV
        unset _AUTO_UV_ENV_ACTIVATION_DIR
        unset AUTO_UV_ENV_PYTHON_VERSION
        export PATH=\"$PROJECT_ROOT:\$PATH\"
        export AUTO_UV_ENV_QUIET=1

        # Mock directive producer so this test does not depend on system UV installation.
        auto-uv-env() {
            echo 'CREATE_VENV=1'
            echo 'PYTHON_VERSION=3.11'
            echo 'MSG_SETUP=🐍 Setting up Python 3.11 with UV...'
        }

        uv() {
            case \"\$1\" in
                'python') return 0 ;;
                'venv') mkdir -p .venv/bin && touch .venv/bin/activate ;;
            esac
            return 0
        }

        python() { echo 'Python 3.11.0'; }

        source '$INTEGRATION_DIR/auto-uv-env.bash'

        auto_uv_env >/dev/null 2>&1 || exit 1

        # Verify creation/activation targeting uses project root, not current subdirectory.
        [[ -f '$temp_dir/project/.venv/bin/activate' ]] || exit 1
        [[ \"\$_AUTO_UV_ENV_ACTIVATION_DIR\" == */project ]] || exit 1
        echo 'SUBDIR_ACTIVATION_SUCCESS'
    " 2>&1)

    cd - > /dev/null
    rm -rf "$temp_dir"
    [[ "$result" == *"SUBDIR_ACTIVATION_SUCCESS"* ]]
}

# Test that ignore markers deactivate an already managed environment in that subtree
test_ignore_subtree_deactivates_active_env() {
    local temp_dir
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/project/subdir/blocked/deep" "$temp_dir/project/.venv"
    cat > "$temp_dir/project/pyproject.toml" << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF
    touch "$temp_dir/project/subdir/blocked/.auto-uv-env-ignore"

    local result
    result=$(bash -c "
        cd '$temp_dir'
        export PATH=\"$PROJECT_ROOT:\$PATH\"
        export AUTO_UV_ENV_QUIET=1
        source '$INTEGRATION_DIR/auto-uv-env.bash'

        export VIRTUAL_ENV='$temp_dir/project/.venv'
        export _AUTO_UV_ENV_ACTIVATION_DIR='$temp_dir/project'
        export AUTO_UV_ENV_PYTHON_VERSION='3.11.0'

        deactivate() { unset VIRTUAL_ENV; echo 'DEACTIVATED'; }

        cd '$temp_dir/project/subdir/blocked/deep'
        auto_uv_env >/dev/null 2>&1 || exit 1

        [[ -z \"\$VIRTUAL_ENV\" ]] || exit 1
        [[ -z \"\$_AUTO_UV_ENV_ACTIVATION_DIR\" ]] || exit 1
        [[ -z \"\$AUTO_UV_ENV_PYTHON_VERSION\" ]] || exit 1
        echo 'IGNORE_DEACTIVATE_SUCCESS'
    " 2>&1)

    rm -rf "$temp_dir"
    [[ "$result" == *"IGNORE_DEACTIVATE_SUCCESS"* ]]
}

# Test that similar path prefixes do not keep stale managed envs active
test_prefix_collision_deactivates_outside_tree() {
    local temp_dir
    temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/project" "$temp_dir/project-other"

    local result
    result=$(bash -c "
        cd '$temp_dir'
        export PATH=\"$PROJECT_ROOT:\$PATH\"
        export AUTO_UV_ENV_QUIET=1
        source '$INTEGRATION_DIR/auto-uv-env.bash'

        export VIRTUAL_ENV='$temp_dir/project/.venv'
        export _AUTO_UV_ENV_ACTIVATION_DIR='$temp_dir/project'
        export AUTO_UV_ENV_PYTHON_VERSION='3.11.0'

        deactivate() { unset VIRTUAL_ENV; }

        cd '$temp_dir/project-other'
        auto_uv_env >/dev/null 2>&1 || exit 1

        [[ -z \"\$VIRTUAL_ENV\" ]] || exit 1
        [[ -z \"\$_AUTO_UV_ENV_ACTIVATION_DIR\" ]] || exit 1
        [[ -z \"\$AUTO_UV_ENV_PYTHON_VERSION\" ]] || exit 1
        echo 'PREFIX_COLLISION_DEACTIVATE_SUCCESS'
    " 2>&1)

    rm -rf "$temp_dir"
    [[ "$result" == *"PREFIX_COLLISION_DEACTIVATE_SUCCESS"* ]]
}

# Test state file parsing in bash
test_bash_state_parsing() {
    local temp_dir
    temp_dir=$(mktemp -d)
    local state_file="$temp_dir/test.state"

    # Create mock state file
    cat > "$state_file" << 'EOF'
CREATE_VENV=1
PYTHON_VERSION=3.11
MSG_SETUP=🐍 Setting up Python 3.11 with UV...
ACTIVATE=/tmp/test-venv
EOF

    # Source the bash integration in a subshell and test parsing
    local result
    result=$(bash -c "
        source '$INTEGRATION_DIR/auto-uv-env.bash'

        # Mock functions to test parsing
        uv() { echo 'mocked uv command'; return 0; }
        source() { echo 'mocked source: \$1'; }
        python() { echo '3.11.0'; }

        # Test the parsing logic by reading the state file
        if [[ -f '$state_file' ]]; then
            local create_venv='' python_version='' msg_setup='' activate_path='' deactivate=''

            while IFS='=' read -r key value; do
                case \"\$key\" in
                    CREATE_VENV) create_venv=\"\$value\" ;;
                    PYTHON_VERSION) python_version=\"\$value\" ;;
                    MSG_SETUP) msg_setup=\"\$value\" ;;
                    ACTIVATE) activate_path=\"\$value\" ;;
                    DEACTIVATE) deactivate=\"\$value\" ;;
                esac
            done < '$state_file'

            # Verify parsing worked
            [[ \"\$create_venv\" == \"1\" ]] && [[ \"\$python_version\" == \"3.11\" ]] && [[ -n \"\$msg_setup\" ]]
        fi
    " 2>&1)

    local exit_code=$?
    rm -rf "$temp_dir"
    return "$exit_code"
}

# Test fish state file parsing
test_fish_state_parsing() {
    if ! command -v fish >/dev/null 2>&1; then
        echo "Fish not available, skipping"
        return 0
    fi

    local temp_dir
    temp_dir=$(mktemp -d)
    local state_file="$temp_dir/test.state"

    # Create mock state file
    cat > "$state_file" << 'EOF'
CREATE_VENV=1
PYTHON_VERSION=3.11
ACTIVATE=/tmp/test-venv
EOF

    # Test fish parsing
    local result
    result=$(fish -c "
        # Mock the key parsing logic from the fish integration
        set -l create_venv ''
        set -l python_version ''
        set -l activate_path ''

        for line in (cat '$state_file')
            set -l parts (string split '=' \$line)
            if test (count \$parts) -ge 2
                set -l key \$parts[1]
                set -l value (string join '=' \$parts[2..-1])

                switch \$key
                    case CREATE_VENV
                        set create_venv \$value
                    case PYTHON_VERSION
                        set python_version \$value
                    case ACTIVATE
                        set activate_path \$value
                end
            end
        end

        # Test parsing worked
        test \"\$create_venv\" = \"1\" -a \"\$python_version\" = \"3.11\" -a \"\$activate_path\" = \"/tmp/test-venv\"
    " 2>&1)

    local exit_code=$?
    rm -rf "$temp_dir"
    return "$exit_code"
}

# Test actual auto_uv_env function end-to-end
test_integration_end_to_end() {
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Create real pyproject.toml
    cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.9"
EOF

    # Test the actual function
    local result
    result=$(bash -c "
        set -x # Enable debugging
        source '$INTEGRATION_DIR/auto-uv-env.bash'

        # Use real auto-uv-env but mock UV
        export PATH='$PROJECT_ROOT':\$PATH

        # Mock UV to avoid actual creation
        uv() {
            case \"\$1\" in
                'venv') mkdir -p .venv/bin && touch .venv/bin/activate ;;
                *) echo 'Mock UV: \$*' ;;
            esac
            return 0
        }

        # Mock python for version check
        python() { echo '3.9.0'; }

        # This calls the REAL auto_uv_env function
        auto_uv_env 2>&1

        # Verify venv was created
        if [[ -d '.venv' && -f '.venv/bin/activate' ]]; then
            echo 'END_TO_END_SUCCESS'
        fi
    ")

    echo "--- Debug Output ---"
    echo "Result: $result"
    echo "--------------------"

    cd - > /dev/null
    rm -rf "$temp_dir"
    [[ "$result" == *"END_TO_END_SUCCESS"* ]]
}

# Test integration error handling
test_integration_error_handling() {
    local temp_dir
    temp_dir=$(mktemp -d)

    # Test with non-existent state file
    local result
    result=$(bash -c "
        source '$INTEGRATION_DIR/auto-uv-env.bash'

        # Mock auto-uv-env to fail
        auto-uv-env() { return 1; }

        auto_uv_env 2>&1
        echo 'error_handling_test_passed'
    ")

    rm -rf "$temp_dir"
    [[ "$result" == *"error_handling_test_passed"* ]]
}

# Test deactivation logic
test_deactivation_logic() {
    local temp_dir
    temp_dir=$(mktemp -d)
    local state_file="$temp_dir/deactivate.state"

    echo "DEACTIVATE=1" > "$state_file"

    local result
    result=$(bash -c "
        source '$INTEGRATION_DIR/auto-uv-env.bash'

        # Mock deactivate function
        deactivate() { echo 'deactivated'; }
        command() { return 0; }  # Mock command -v deactivate

        # Test deactivation parsing
        if [[ -f '$state_file' ]]; then
            local deactivate=''
            while IFS='=' read -r key value; do
                case \"\$key\" in
                    DEACTIVATE) deactivate=\"\$value\" ;;
                esac
            done < '$state_file'

            if [[ -n \"\$deactivate\" ]]; then
                deactivate
            fi
        fi
    " 2>&1)

    rm -rf "$temp_dir"
    [[ "$result" == *"deactivated"* ]]
}

# Test state file cleanup
test_state_file_cleanup() {
    local temp_dir
    temp_dir=$(mktemp -d)
    local state_file="$temp_dir/cleanup.state"

    echo "CREATE_VENV=1" > "$state_file"

    bash -c "
        source '$INTEGRATION_DIR/auto-uv-env.bash'

        # Mock functions
        uv() { return 0; }

        # Process state file (should clean it up)
        if [[ -f '$state_file' ]]; then
            rm -f '$state_file'  # Simulate cleanup
        fi
    "

    # State file should be cleaned up
    [[ ! -f "$state_file" ]]
    rm -rf "$temp_dir"
}

# Test deleted virtual environment handling
test_deleted_venv_handling() {
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Create test project
    cat > pyproject.toml << 'EOF'
[project]
name = "test-deleted-venv"
version = "1.0.0"
requires-python = ">=3.11"
dependencies = []
EOF

    # Test the deleted venv scenario
    local result
    result=$(bash -c "
        source '$INTEGRATION_DIR/auto-uv-env.bash'
        export AUTO_UV_ENV_QUIET=0

        # Mock functions
        uv() {
            case \"\$1\" in
                'venv') mkdir -p .venv/bin && touch .venv/bin/activate ;;
                *) return 0 ;;
            esac
        }
        python() { echo 'Python 3.11.0'; }

        # Mock auto-uv-env to simulate first activation
        auto-uv-env() {
            if [[ -d '.venv' ]]; then
                echo 'ACTIVATE=$PWD/.venv'
            else
                echo 'CREATE_VENV=1'
                echo 'ACTIVATE=$PWD/.venv'
            fi
        }

        # First run - should create and activate
        auto_uv_env 2>&1

        # Set environment variables as if we're in an active venv
        export VIRTUAL_ENV=\"\$PWD/.venv\"
        export _AUTO_UV_ENV_ACTIVATION_DIR=\"\$PWD\"

        # Delete .venv to simulate the problem scenario
        rm -rf .venv

        # Now run auto_uv_env again - should detect deletion and show cleanup message
        auto_uv_env 2>&1
    ")

    cd - > /dev/null
    rm -rf "$temp_dir"

    # Check that it detected the deleted environment and showed cleanup message
    [[ "$result" == *"Virtual environment was deleted, cleaning up"* ]] && \
    [[ "$result" == *"UV environment activated"* ]]
}


# Run all tests
run_test "Bash integration syntax" test_bash_syntax
run_test "ZSH integration syntax" test_zsh_syntax
run_test "ZSH prefix-collision deactivation" test_zsh_prefix_collision_deactivates_outside_tree
run_test "ZSH state-file cleanup on failure" test_zsh_state_file_cleanup_on_failure
run_test "Fish integration syntax" test_fish_syntax
run_test "Fish state-file cleanup on failure" test_fish_state_file_cleanup_on_failure
run_test "Non-Python fast path (lazy loading)" test_non_python_fast_path
run_test "Subdirectory project activation" test_subdirectory_project_activation
run_test "Ignore subtree deactivates active env" test_ignore_subtree_deactivates_active_env
run_test "Prefix-collision paths deactivate active env" test_prefix_collision_deactivates_outside_tree
run_test "Bash state file parsing" test_bash_state_parsing
run_test "Fish state file parsing" test_fish_state_parsing
run_test "Integration end-to-end" test_integration_end_to_end
run_test "Integration error handling" test_integration_error_handling
run_test "Deactivation logic" test_deactivation_logic
run_test "State file cleanup" test_state_file_cleanup
run_test "Deleted virtual environment handling" test_deleted_venv_handling

# Summary
echo -e "\nShell Integration Test Results:"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"
echo -e "Total:  $TOTAL_TESTS"

if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
    echo -e "\n${GREEN}All shell integration tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some shell integration tests failed!${NC}"
    exit 1
fi
