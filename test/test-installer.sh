#!/usr/bin/env bash
# Installer regression tests for auto-uv-env
#
# These tests exist because the installer has one subtle shell-lifecycle trap:
#
#   parent shell
#     -> source_dir="$(download_and_extract ...)"
#           ^ command substitution runs in a subshell
#
#   subshell
#     -> create temp dir
#     -> extract release archive there
#     -> print extracted path
#     -> EXIT trap fires
#     -> temp dir is deleted too early
#
#   parent shell
#     -> tries to copy files from a path that no longer exists
#
# The regression test below keeps that mental model visible for future readers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
INSTALLER="$PROJECT_ROOT/docs/install.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TOTAL_TESTS=0
PASSED_TESTS=0

run_test() {
    local test_name="$1"
    local test_func="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    printf 'Test %d: %s... ' "$TOTAL_TESTS" "$test_name"
    if "$test_func"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Regression: downloaded/extracted source directory must still exist when
# install_auto_uv_env starts copying files from it.
#
# First principles:
# - We want to test the *real* installer flow, not AUTO_UV_ENV_TEST_MODE.
# - But we also want a deterministic, offline test.
# - So we mock curl, return fake release JSON, and generate a tiny tarball that
#   looks like a real auto-uv-env release archive.
#
# Expected behavior after the fix:
# - install.sh exits successfully
# - the binary is installed
# - the share files are installed
#
# The key contract this protects is simple:
#
#   download_and_extract -> returns extracted source_dir
#   install_auto_uv_env  -> must still be able to copy from that source_dir
#
# If that contract breaks, this test should fail loudly.
test_installer_keeps_extracted_dir_alive_until_install() {
    local temp_dir mockbin home_dir fixture_dir log_file
    temp_dir=$(mktemp -d)
    mockbin="$temp_dir/mockbin"
    home_dir="$temp_dir/home"
    fixture_dir="$temp_dir/fixture"
    log_file="$temp_dir/install.log"

    mkdir -p "$mockbin" "$home_dir" "$fixture_dir/share/auto-uv-env"
    touch "$home_dir/.bashrc"

    cat > "$fixture_dir/auto-uv-env" <<'EOF'
#!/usr/bin/env bash
VERSION="9.9.9"
echo auto-uv-env
EOF
    chmod +x "$fixture_dir/auto-uv-env"

    cat > "$fixture_dir/share/auto-uv-env/auto-uv-env.bash" <<'EOF'
# mock bash integration
EOF
    cat > "$fixture_dir/share/auto-uv-env/auto-uv-env.zsh" <<'EOF'
# mock zsh integration
EOF
    cat > "$fixture_dir/share/auto-uv-env/auto-uv-env.fish" <<'EOF'
# mock fish integration
EOF

    cat > "$mockbin/curl" <<'EOF'
#!/bin/sh
set -eu

output=""
url=""
prev=""
for arg in "$@"; do
    if [ "$prev" = "-o" ]; then
        output="$arg"
        prev=""
        continue
    fi
    case "$arg" in
        -o)
            prev="-o"
            ;;
        -*)
            ;;
        *)
            url="$arg"
            ;;
    esac
done

case "$url" in
    */releases/latest)
        printf '%s\n' '{"browser_download_url":"https://example.invalid/auto-uv-env-v9.9.9.tar.gz"}'
        ;;
    *.tar.gz)
        [ -n "$output" ] || exit 1
        release_root="$MOCK_RELEASE_ROOT/auto-uv-env-v9.9.9"
        mkdir -p "$release_root"
        cp -R "$MOCK_FIXTURE_DIR/." "$release_root/"
        tar -czf "$output" -C "$MOCK_RELEASE_ROOT" auto-uv-env-v9.9.9
        ;;
    *)
        echo "unexpected curl url: $url" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$mockbin/curl"

    if HOME="$home_dir" \
       PATH="$mockbin:$PATH" \
       MOCK_FIXTURE_DIR="$fixture_dir" \
       MOCK_RELEASE_ROOT="$temp_dir/release-root" \
       AUTO_UV_ENV_BIN_DIR="$home_dir/.local/bin" \
       AUTO_UV_ENV_SHARE_DIR="$home_dir/.local/share/auto-uv-env" \
       bash "$INSTALLER" -y --verbose >"$log_file" 2>&1; then
        local ok=0
        [[ -f "$home_dir/.local/bin/auto-uv-env" ]] || ok=1
        [[ -f "$home_dir/.local/share/auto-uv-env/auto-uv-env.bash" ]] || ok=1
        rm -rf "$temp_dir"
        return "$ok"
    else
        echo "--- installer output ---"
        cat "$log_file"
        echo "------------------------"
        rm -rf "$temp_dir"
        return 1
    fi
}

echo "Running installer regression tests..."
run_test "Installer keeps extracted directory alive until install" test_installer_keeps_extracted_dir_alive_until_install

echo -e "\nInstaller Test Results:"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"
echo -e "Total:  $TOTAL_TESTS"

if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
    echo -e "\n${GREEN}All installer tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some installer tests failed!${NC}"
    exit 1
fi
