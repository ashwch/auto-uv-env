#!/bin/sh
# auto-uv-env installer script
# Based on the elegant approach used by UV (https://github.com/astral-sh/uv)
#
# This script installs auto-uv-env on your system.
# It can be run with: curl -LsSf https://auto-uv-env.ashwch.com/install.sh | sh

set -e

# Configuration
REPO_URL="https://github.com/ashwch/auto-uv-env"
INSTALLER_VERSION="1.0.0"

# Default installation paths following XDG Base Directory Specification
BIN_DIR="${AUTO_UV_ENV_BIN_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"
SHARE_DIR="${AUTO_UV_ENV_SHARE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/auto-uv-env}"

# Terminal colors
if [ -t 1 ]; then
    RED="$(tput setaf 1 2>/dev/null || printf '')"
    GREEN="$(tput setaf 2 2>/dev/null || printf '')"
    YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
    BLUE="$(tput setaf 4 2>/dev/null || printf '')"
    BOLD="$(tput bold 2>/dev/null || printf '')"
    RESET="$(tput sgr0 2>/dev/null || printf '')"
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    RESET=""
fi

# Logging functions
say() {
    printf "%s\n" "$1" >&2
}

say_verbose() {
    if [ "${VERBOSE:-0}" = "1" ]; then
        printf "%s\n" "$1" >&2
    fi
}

err() {
    say "${RED}error${RESET}: $1" >&2
    exit 1
}

warn() {
    say "${YELLOW}warning${RESET}: $1" >&2
}

success() {
    say "${GREEN}✓${RESET} $1" >&2
}

info() {
    say "${BLUE}→${RESET} $1" >&2
}

# Helper functions
check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

need_cmd() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

ensure() {
    if ! "$@"; then
        err "command failed: $*"
    fi
}

# Get the user's home directory reliably
get_home() {
    if [ -n "${HOME:-}" ]; then
        printf '%s' "$HOME"
    else
        # Fall back to getent if HOME is not set
        local user
        user="${USER:-$(id -un)}"
        getent passwd "$user" 2>/dev/null | cut -d: -f6
    fi
}

# Detect the platform
detect_platform() {
    local os arch

    os="$(uname -s)"
    arch="$(uname -m)"

    # Normalize OS name
    case "$os" in
        Linux) os="linux" ;;
        Darwin) os="darwin" ;;
        FreeBSD) os="freebsd" ;;
        *) err "unsupported OS: $os" ;;
    esac

    # Normalize architecture
    case "$arch" in
        x86_64 | amd64) arch="x86_64" ;;
        aarch64 | arm64) arch="aarch64" ;;
        armv7l) arch="armv7" ;;
        i686) arch="i686" ;;
        *) err "unsupported architecture: $arch" ;;
    esac

    # Special handling for macOS Rosetta
    if [ "$os" = "darwin" ] && [ "$arch" = "x86_64" ]; then
        if sysctl hw.optional.arm64 2>/dev/null | grep -q ': 1'; then
            arch="aarch64"
            say_verbose "detected macOS Rosetta, using arm64 architecture"
        fi
    fi

    echo "${os}-${arch}"
}

# Download file with curl or wget
download() {
    local url="$1"
    local output="$2"

    if check_cmd curl; then
        # Check for broken snap curl
        if command -v curl | grep -q "/snap/bin/curl"; then
            warn "detected snap curl, which may have issues downloading"
            if check_cmd wget; then
                say_verbose "falling back to wget"
                wget -q --show-progress "$url" -O "$output"
                return
            fi
        fi
        curl -sSfL "$url" -o "$output" || err "download failed: $url"
    elif check_cmd wget; then
        wget -q --show-progress "$url" -O "$output"
    else
        err "need either 'curl' or 'wget' to download files"
    fi
}

# Download and extract the latest release
download_and_extract() {
    local platform="$1"
    local temp_dir
    temp_dir="$(mktemp -d)"

    # Clean up on exit
    trap 'rm -rf "$temp_dir"' EXIT

    info "downloading auto-uv-env (latest)"

    local archive_url="${REPO_URL}/archive/main.tar.gz"
    local archive_file="$temp_dir/auto-uv-env.tar.gz"

    download "$archive_url" "$archive_file"

    info "extracting archive"
    tar -xzf "$archive_file" -C "$temp_dir"

    # The archive extracts to auto-uv-env-main/
    printf '%s' "$temp_dir/auto-uv-env-main"
}

# Install auto-uv-env files
install_auto_uv_env() {
    local source_dir="$1"

    # Create directories
    say_verbose "creating directories"
    mkdir -p "$BIN_DIR"
    mkdir -p "$SHARE_DIR"

    # Install main script
    info "installing auto-uv-env to $BIN_DIR"
    ensure cp "$source_dir/auto-uv-env" "$BIN_DIR/auto-uv-env"
    ensure chmod +x "$BIN_DIR/auto-uv-env"

    # Install shell integration files
    info "installing shell integration files"
    for shell_file in "$source_dir"/share/auto-uv-env/*; do
        ensure cp "$shell_file" "$SHARE_DIR/"
    done

    # Create installation receipt
    cat > "$SHARE_DIR/install-receipt.json" << EOF
{
    "version": "$(grep '^VERSION=' "$source_dir/auto-uv-env" | cut -d'"' -f2)",
    "installer_version": "$INSTALLER_VERSION",
    "install_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "bin_dir": "$BIN_DIR",
    "share_dir": "$SHARE_DIR",
    "platform": "$(detect_platform)"
}
EOF

    success "installed auto-uv-env"
}

# Check if directory is in PATH
is_in_path() {
    case ":${PATH}:" in
        *:"$1":*) return 0 ;;
        *) return 1 ;;
    esac
}

# Setup shell integration
setup_shell_integration() {
    info "setting up shell integration"

    # Create env script that can be sourced
    cat > "$SHARE_DIR/env" << EOF
# auto-uv-env environment setup
# This file is sourced by shell init scripts

# Add auto-uv-env to PATH if not already present
case ":\${PATH}:" in
    *:"$BIN_DIR":*) ;;
    *) export PATH="$BIN_DIR:\$PATH" ;;
esac

# Source the appropriate shell integration
if [ -n "\${BASH_VERSION:-}" ]; then
    [ -f "$SHARE_DIR/auto-uv-env.bash" ] && . "$SHARE_DIR/auto-uv-env.bash"
elif [ -n "\${ZSH_VERSION:-}" ]; then
    [ -f "$SHARE_DIR/auto-uv-env.zsh" ] && . "$SHARE_DIR/auto-uv-env.zsh"
fi
EOF

    # Detect current shell and available shells
    local shells_updated=""
    local current_shell="$(basename "${SHELL:-/bin/sh}")"

    # Update shell configurations
    update_shell_profile "bash" ".bashrc" ".bash_profile" && shells_updated="${shells_updated}bash "
    update_shell_profile "zsh" ".zshrc" && shells_updated="${shells_updated}zsh "
    update_fish_config && shells_updated="${shells_updated}fish "

    if [ -n "$shells_updated" ]; then
        success "updated shell configuration for: $shells_updated"
    else
        warn "no shell configuration files were updated"
        info "manually add this to your shell config: source $SHARE_DIR/env"
    fi
}

# Update bash/zsh profile
update_shell_profile() {
    local shell_name="$1"
    shift

    local updated=0
    local home_dir
    home_dir="$(get_home)"

    for profile in "$@"; do
        local profile_path="$home_dir/$profile"

        # Skip if file doesn't exist and we haven't updated any file yet
        if [ ! -f "$profile_path" ] && [ "$updated" -eq 0 ]; then
            continue
        fi

        # Check if already configured
        if [ -f "$profile_path" ] && grep -q "auto-uv-env" "$profile_path" 2>/dev/null; then
            say_verbose "$profile already contains auto-uv-env configuration"
            return 0
        fi

        # Add configuration
        say_verbose "updating $profile"
        {
            echo ""
            echo "# auto-uv-env"
            echo "[ -f \"$SHARE_DIR/env\" ] && . \"$SHARE_DIR/env\""
        } >> "$profile_path"

        updated=1
        break
    done

    [ "$updated" -eq 1 ]
}

# Update fish configuration
update_fish_config() {
    local home_dir
    home_dir="$(get_home)"
    local fish_config="$home_dir/.config/fish/config.fish"

    # Check if fish config exists
    if [ ! -d "$home_dir/.config/fish" ]; then
        return 1
    fi

    # Check if already configured
    if [ -f "$fish_config" ] && grep -q "auto-uv-env" "$fish_config" 2>/dev/null; then
        say_verbose "fish config already contains auto-uv-env configuration"
        return 0
    fi

    # Create config file if it doesn't exist
    mkdir -p "$home_dir/.config/fish"

    # Add configuration
    say_verbose "updating fish config"
    {
        echo ""
        echo "# auto-uv-env"
        echo "if test -f $SHARE_DIR/auto-uv-env.fish"
        echo "    source $SHARE_DIR/auto-uv-env.fish"
        echo "end"
    } >> "$fish_config"

    return 0
}

# Check for UV installation
check_uv() {
    if check_cmd uv; then
        success "UV is already installed"
    else
        warn "UV is not installed"
        info "install UV with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi
}

# Main installation function
main() {
    local platform
    platform="$(detect_platform)"

    say ""
    say "${BOLD}auto-uv-env installer${RESET}"
    say ""

    # Check if running on macOS
    if [ "${platform%%-*}" = "darwin" ]; then
        if check_cmd brew; then
            say "${YELLOW}Homebrew detected!${RESET}"
            say ""
            say "For macOS, we recommend installing via Homebrew:"
            say "  ${GREEN}brew tap ashwch/tap${RESET}"
            say "  ${GREEN}brew install auto-uv-env${RESET}"
            say ""
            printf "Continue with direct installation instead? [y/N] "
            read -r response
            case "$response" in
                [yY][eE][sS]|[yY]) ;;
                *)
                    say "Installation cancelled. Use Homebrew instead!"
                    exit 0
                    ;;
            esac
        fi
    fi

    info "detected platform: $platform"

    # Check for required commands
    need_cmd uname
    need_cmd mktemp
    need_cmd rm
    need_cmd tar
    need_cmd chmod
    need_cmd mkdir
    need_cmd cp

    # Download and extract
    local source_dir
    source_dir="$(download_and_extract "$platform")"

    # Install files
    install_auto_uv_env "$source_dir"

    # Setup shell integration
    setup_shell_integration

    # Check if bin directory is in PATH
    if ! is_in_path "$BIN_DIR"; then
        warn "$BIN_DIR is not in your PATH"
        info "you may need to restart your shell or run: source ~/.bashrc"
    fi

    # Check for UV
    check_uv

    say ""
    success "auto-uv-env installed successfully!"
    say ""
    say "Next steps:"
    say "  1. Restart your shell or run: ${GREEN}source ~/.bashrc${RESET}"
    say "  2. Navigate to a Python project with pyproject.toml"
    say "  3. Watch auto-uv-env work its magic! ✨"
    say ""
    say "For more information: https://github.com/ashwch/auto-uv-env"
    say ""
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            ;;
        -q|--quiet)
            QUIET=1
            ;;
        --ci)
            CI_MODE=1
            ;;
        -h|--help)
            cat << EOF
auto-uv-env installer

USAGE:
    install.sh [OPTIONS]

OPTIONS:
    -v, --verbose    Show verbose output
    -q, --quiet      Suppress output
    -h, --help       Show this help message

ENVIRONMENT VARIABLES:
    AUTO_UV_ENV_BIN_DIR     Custom binary directory (default: ~/.local/bin)
    AUTO_UV_ENV_SHARE_DIR   Custom share directory (default: ~/.local/share/auto-uv-env)

EOF
            exit 0
            ;;
        *)
            err "unknown option: $1"
            ;;
    esac
    shift
done

# Run the installer
main
