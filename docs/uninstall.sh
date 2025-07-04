#!/bin/sh
# auto-uv-env uninstaller script
# Removes auto-uv-env from your system

set -e

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
    printf "%s\n" "$1"
}

err() {
    say "${RED}error${RESET}: $1" >&2
    exit 1
}

warn() {
    say "${YELLOW}warning${RESET}: $1" >&2
}

success() {
    say "${GREEN}✓${RESET} $1"
}

info() {
    say "${BLUE}→${RESET} $1"
}

# Find installation
find_installation() {
    # Check common locations
possible_locations="
        $HOME/.local/share/auto-uv-env
        /usr/local/share/auto-uv-env
        /usr/share/auto-uv-env
        /opt/homebrew/share/auto-uv-env
        /usr/local/opt/auto-uv-env/share/auto-uv-env
    "

    for loc in $possible_locations; do
        if [ -f "$loc/install-receipt.json" ] 2>/dev/null; then
            echo "$loc"
            return 0
        fi
    done

    # Check if installed via Homebrew
    if command -v brew >/dev/null 2>&1; then
        if brew list auto-uv-env >/dev/null 2>&1; then
            warn "auto-uv-env was installed via Homebrew"
            info "run: ${GREEN}brew uninstall auto-uv-env${RESET}"
            exit 0
        fi
    fi

    return 1
}

# Remove shell integration
remove_shell_integration() {
removed=0

    info "removing shell integration"

    # Remove from bash
    for file in "$HOME/.bashrc" "$HOME/.bash_profile"; do
        if [ -f "$file" ] && grep -q "auto-uv-env" "$file" 2>/dev/null; then
            say "  removing from $file"
            # Remove auto-uv-env lines
            sed -i.bak '/# auto-uv-env/,+1d' "$file" 2>/dev/null || \
            sed -i '' '/# auto-uv-env/,+1d' "$file" 2>/dev/null || \
            warn "failed to remove from $file"
            rm -f "$file.bak"
            removed=$((removed + 1))
        fi
    done

    # Remove from zsh
    if [ -f "$HOME/.zshrc" ] && grep -q "auto-uv-env" "$HOME/.zshrc" 2>/dev/null; then
        say "  removing from ~/.zshrc"
        sed -i.bak '/# auto-uv-env/,+1d' "$HOME/.zshrc" 2>/dev/null || \
        sed -i '' '/# auto-uv-env/,+1d' "$HOME/.zshrc" 2>/dev/null || \
        warn "failed to remove from ~/.zshrc"
        rm -f "$HOME/.zshrc.bak"
        removed=$((removed + 1))
    fi

    # Remove from fish
fish_config="$HOME/.config/fish/config.fish"
    if [ -f "$fish_config" ] && grep -q "auto-uv-env" "$fish_config" 2>/dev/null; then
        say "  removing from fish config"
        sed -i.bak '/# auto-uv-env/,+3d' "$fish_config" 2>/dev/null || \
        sed -i '' '/# auto-uv-env/,+3d' "$fish_config" 2>/dev/null || \
        warn "failed to remove from fish config"
        rm -f "$fish_config.bak"
        removed=$((removed + 1))
    fi

    if [ "$removed" -gt 0 ]; then
        success "removed shell integration from $removed file(s)"
    fi
}

# Main uninstall function
main() {
    say ""
    say "${BOLD}auto-uv-env uninstaller${RESET}"
    say ""

    # Find installation
    info "looking for auto-uv-env installation"

share_dir
    if ! share_dir="$(find_installation)"; then
        err "auto-uv-env installation not found"
    fi

    say "  found at: $share_dir"

    # Determine bin directory
bin_dir="$HOME/.local/bin"
    if [ -f "$share_dir/install-receipt.json" ]; then
        # Try to extract from receipt (basic parsing)
receipt_bin
        receipt_bin="$(grep '"bin_dir"' "$share_dir/install-receipt.json" | cut -d'"' -f4)"
        [ -n "$receipt_bin" ] && bin_dir="$receipt_bin"
    fi

    # Confirm uninstallation (skip if -y flag is set)
    if [ "${ASSUME_YES:-0}" != "1" ]; then
        printf "\nRemove auto-uv-env? [y/N] "
        read -r response
        case "$response" in
            [yY][eE][sS]|[yY]) ;;
            *)
                say "Uninstallation cancelled"
                exit 0
                ;;
        esac
    fi

    # Remove files
    info "removing auto-uv-env files"

    # Remove binary
    if [ -f "$bin_dir/auto-uv-env" ]; then
        rm -f "$bin_dir/auto-uv-env"
        success "removed $bin_dir/auto-uv-env"
    fi

    # Remove share directory
    if [ -d "$share_dir" ]; then
        rm -rf "$share_dir"
        success "removed $share_dir"
    fi

    # Remove shell integration
    remove_shell_integration

    # Deactivate if currently active
    if [ -n "${VIRTUAL_ENV:-}" ] && [ -n "${_AUTO_UV_ENV_ACTIVATION_DIR:-}" ]; then
        warn "auto-uv-env environment is currently active"
        info "restart your shell to complete deactivation"
    fi

    say ""
    success "auto-uv-env has been uninstalled"
    say ""
    info "restart your shell to complete the removal"
    say ""
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)
            ASSUME_YES=1
            ;;
        -h|--help)
            cat << EOF
auto-uv-env uninstaller

USAGE:
    uninstall.sh [OPTIONS]

OPTIONS:
    -y, --yes    Assume yes to all prompts (for CI/automation)
    -h, --help   Show this help message

EOF
            exit 0
            ;;
        *)
            err "unknown option: $1"
            ;;
    esac
    shift
done

# Run the uninstaller
main
