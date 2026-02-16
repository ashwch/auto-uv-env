#!/bin/bash
# Test for deleted virtual environment handling
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_COUNT=0
PASS_COUNT=0

sanitize_test_env() {
    unset VIRTUAL_ENV
    unset VIRTUAL_ENV_PROMPT
    unset _OLD_VIRTUAL_PATH
    unset _OLD_VIRTUAL_PS1
    unset _AUTO_UV_ENV_ACTIVATION_DIR
    unset AUTO_UV_ENV_PYTHON_VERSION
}

run_auto_uv_env_capture() {
    local capture_file
    capture_file=$(mktemp)
    auto_uv_env > "$capture_file" 2>&1
    OUTPUT=$(cat "$capture_file")
    rm -f "$capture_file"
}

test_case() {
    local name="$1"
    ((++TEST_COUNT))
    echo -e "${BLUE}Test $TEST_COUNT: $name${NC}"
}

assert_output_contains() {
    local output="$1"
    local expected="$2"

    if [[ "$output" == *"$expected"* ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((++PASS_COUNT))
    else
        echo -e "${RED}FAIL${NC}: Expected '$expected' in output"
        echo "Actual output: $output"
        return 1
    fi
}

assert_silent() {
    local output="$1"

    if [[ -z "$output" ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((++PASS_COUNT))
    else
        echo -e "${RED}FAIL${NC}: Expected silent output"
        echo "Actual output: $output"
        return 1
    fi
}

echo "🧪 Testing deleted virtual environment handling..."

sanitize_test_env

# Create isolated test environment
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# Create test project
cat > pyproject.toml << 'EOF'
[project]
name = "test-deleted-venv"
version = "1.0.0"
requires-python = ">=3.11"
dependencies = []
EOF

# Copy auto-uv-env for isolated testing
cp "$OLDPWD/auto-uv-env" ./
cp -r "$OLDPWD/share" ./
export PATH="$TEST_DIR:$PATH"
export AUTO_UV_ENV_QUIET=0

# Source shell integration
source ./share/auto-uv-env/auto-uv-env.bash

# Test 1: Normal environment creation
test_case "Normal environment creation"
unset VIRTUAL_ENV
unset _AUTO_UV_ENV_ACTIVATION_DIR
unset AUTO_UV_ENV_PYTHON_VERSION

run_auto_uv_env_capture
assert_output_contains "$OUTPUT" "UV environment activated"

# Test 2: Already active environment should be quiet
test_case "Already active environment (quiet)"
run_auto_uv_env_capture
assert_silent "$OUTPUT"

# Test 3: Delete .venv while variables are set
test_case "Delete .venv directory"
rm -rf .venv
if [[ ! -d ".venv" ]] && [[ -n "$VIRTUAL_ENV" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((++PASS_COUNT))
else
    echo -e "${RED}FAIL${NC}: .venv should be deleted but VIRTUAL_ENV should remain set"
fi

# Test 4: Detection and cleanup of deleted environment
test_case "Detect and handle deleted environment"
run_auto_uv_env_capture
assert_output_contains "$OUTPUT" "Virtual environment was deleted, cleaning up"

# Test 5: Environment recreated
test_case "Environment recreated"
if [[ -d ".venv" ]] && [[ -n "$VIRTUAL_ENV" ]] && [[ -d "$VIRTUAL_ENV" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((++PASS_COUNT))
else
    echo -e "${RED}FAIL${NC}: Environment not properly recreated"
fi

# Test 6: Subsequent calls are quiet
test_case "Subsequent calls are quiet"
run_auto_uv_env_capture
assert_silent "$OUTPUT"

echo ""
echo "Test Results:"
echo "Passed: $PASS_COUNT/$TEST_COUNT"

# Cleanup
cd "$OLDPWD"
rm -rf "$TEST_DIR"

if [[ $PASS_COUNT -eq $TEST_COUNT ]]; then
    echo -e "${GREEN}🎉 All deleted venv tests passed!${NC}"
    exit 0
else
    echo -e "${RED}💥 Some tests failed${NC}"
    exit 1
fi
