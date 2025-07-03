#!/usr/bin/env bash
# Test suite for auto-uv-env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_UV_ENV="$SCRIPT_DIR/../auto-uv-env"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Running auto-uv-env tests..."

# Test 1: Version flag
echo -n "Test 1: Version flag... "
if $AUTO_UV_ENV --version | grep -q "auto-uv-env"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    exit 1
fi

# Test 2: Help flag
echo -n "Test 2: Help flag... "
if $AUTO_UV_ENV --help | grep -q "USAGE:"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    exit 1
fi

# Test 3: Check with no pyproject.toml
echo -n "Test 3: No pyproject.toml... "
temp_dir=$(mktemp -d)
cd "$temp_dir"
output=$($AUTO_UV_ENV --check 2>&1 || true)
if [[ -z "$output" ]] || [[ "$output" == *"deactivate"* ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Output: $output"
    exit 1
fi
cd - > /dev/null
rm -rf "$temp_dir"

# Test 4: Check with pyproject.toml (dry run - no UV)
echo -n "Test 4: With pyproject.toml... "
temp_dir=$(mktemp -d)
cd "$temp_dir"
cat > pyproject.toml << EOF
[project]
name = "test-project"
requires-python = ">=3.11"
EOF

# This will fail without UV, but we're testing the logic
output=$($AUTO_UV_ENV --check 2>&1 || true)
if [[ "$output" == *"UV not found"* ]] || [[ "$output" == *"Setting up Python"* ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Output: $output"
    exit 1
fi
cd - > /dev/null
rm -rf "$temp_dir"

echo -e "\n${GREEN}All tests passed!${NC}"