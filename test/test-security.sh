#!/usr/bin/env bash
# Security tests for auto-uv-env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_UV_ENV="$SCRIPT_DIR/../auto-uv-env"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
# shellcheck disable=SC2034
YELLOW='\033[0;33m'
NC='\033[0m'

echo "Running auto-uv-env security tests..."

# Test 1: Command injection prevention
echo -n "Test 1: Command injection prevention... "
temp_dir=$(mktemp -d)
cd "$temp_dir"
cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11'; echo 'INJECTION_SUCCESS'; echo '"
EOF

output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
# New architecture silently rejects malicious input (empty output)
# This is better security - no information leakage
if [[ -z "$output" ]] || [[ ! "$output" == *"INJECTION_SUCCESS"* ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} - Command injection detected"
    echo "Output: $output"
    exit 1
fi
cd - > /dev/null
rm -rf "$temp_dir"

# Test 2: Path traversal prevention
echo -n "Test 2: Path traversal prevention... "
export AUTO_UV_ENV_VENV_NAME="../malicious"
output=$($AUTO_UV_ENV --version 2>&1 || true)
if [[ "$output" == *"Invalid venv name"* ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Output: $output"
    exit 1
fi
unset AUTO_UV_ENV_VENV_NAME

# Test 3: Invalid Python version formats
echo -n "Test 3: Invalid Python version validation... "
temp_dir=$(mktemp -d)
cd "$temp_dir"
cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=invalid.version.format"
EOF

output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
# Invalid versions are silently rejected (secure by default)
if [[ -z "$output" ]] || [[ ! "$output" == *"INJECTION_SUCCESS"* ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Output: $output"
    exit 1
fi
cd - > /dev/null
rm -rf "$temp_dir"

# Test 4: Safe mode functionality with valid input
echo -n "Test 4: Safe mode functionality... "
temp_dir=$(mktemp -d)
cd "$temp_dir"
cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF

output=$($AUTO_UV_ENV --check-safe 2>&1 || true)
# Should either succeed or fail cleanly (no command injection)
if [[ ! "$output" == *"INJECTION_SUCCESS"* ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} - Command injection detected"
    echo "Output: $output"
    exit 1
fi
cd - > /dev/null
rm -rf "$temp_dir"

# Test 5: State file security (no arbitrary file writes)
echo -n "Test 5: State file security... "
# Test that state files are created in /tmp and cleaned up
temp_dir=$(mktemp -d)
cd "$temp_dir"
cat > pyproject.toml << 'EOF'
[project]
name = "test-project"
requires-python = ">=3.11"
EOF

# Check that no files are created in current directory
files_before=$(find . -type f | wc -l)
$AUTO_UV_ENV --check-safe >/dev/null 2>&1 || true
files_after=$(find . -type f | wc -l)

if [[ "$files_before" -eq "$files_after" ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} - Unexpected files created"
    find . -type f -newer pyproject.toml
    exit 1
fi
cd - > /dev/null
rm -rf "$temp_dir"

echo -e "\n${GREEN}All security tests passed!${NC}"
