#!/usr/bin/env bash
# Universal installation script for auto-uv-env

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/ashwch/auto-uv-env"
INSTALL_DIR="/usr/local"
VERSION="${1:-latest}"

# Functions
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    elif [[ -f /etc/redhat-release ]]; then
        OS="rhel"
        VER=$(rpm -q --qf "%{VERSION}" redhat-release)
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
}

check_dependencies() {
    local missing_deps=()

    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        missing_deps+=("curl or wget")
    fi

    if ! command -v uv >/dev/null 2>&1; then
        print_warning "UV is not installed. auto-uv-env requires UV to function."
        print_step "Install UV with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        case "$OS" in
            ubuntu|debian)
                print_step "Install with: sudo apt-get update && sudo apt-get install -y ${missing_deps[*]}"
                ;;
            rhel|centos|fedora|rocky|almalinux)
                print_step "Install with: sudo yum install -y ${missing_deps[*]}"
                ;;
            arch)
                print_step "Install with: sudo pacman -S ${missing_deps[*]}"
                ;;
        esac
        exit 1
    fi
}

download_release() {
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    if [[ "$VERSION" == "latest" ]]; then
        local download_url="${REPO_URL}/archive/main.tar.gz"
        print_step "Downloading latest version from main branch..."
    else
        local download_url="${REPO_URL}/archive/v${VERSION}.tar.gz"
        print_step "Downloading version ${VERSION}..."
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -sL "$download_url" -o auto-uv-env.tar.gz
    else
        wget -q "$download_url" -O auto-uv-env.tar.gz
    fi

    tar -xzf auto-uv-env.tar.gz
    cd auto-uv-env-*/
}

install_files() {
    print_step "Installing auto-uv-env..."

    # Install the main script
    sudo install -m 755 auto-uv-env "${INSTALL_DIR}/bin/auto-uv-env"

    # Install shell integrations
    sudo mkdir -p "${INSTALL_DIR}/share/auto-uv-env"
    sudo install -m 644 share/auto-uv-env/* "${INSTALL_DIR}/share/auto-uv-env/"

    print_success "auto-uv-env installed successfully!"
}

install_os_package() {
    case "$OS" in
        ubuntu|debian)
            install_debian_package
            ;;
        rhel|centos|fedora|rocky|almalinux)
            install_rpm_package
            ;;
        *)
            print_warning "No native package available for $OS"
            print_step "Using universal installation method..."
            download_release
            install_files
            ;;
    esac
}

install_debian_package() {
    print_step "Building Debian package..."

    # This would normally build a .deb package
    # For now, fall back to universal install
    download_release
    install_files

    # TODO: Add actual .deb building logic
}

install_rpm_package() {
    print_step "Building RPM package..."

    # This would normally build an .rpm package
    # For now, fall back to universal install
    download_release
    install_files

    # TODO: Add actual .rpm building logic
}

setup_shell() {
    local shell_name=$(basename "$SHELL")
    local shell_rc=""

    case "$shell_name" in
        bash)
            shell_rc="$HOME/.bashrc"
            ;;
        zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        fish)
            shell_rc="$HOME/.config/fish/config.fish"
            ;;
        *)
            print_warning "Unknown shell: $shell_name"
            return
            ;;
    esac

    if [[ -f "$shell_rc" ]]; then
        if ! grep -q "auto-uv-env" "$shell_rc"; then
            print_step "Adding auto-uv-env to $shell_rc..."
            echo "" >> "$shell_rc"
            echo "# auto-uv-env" >> "$shell_rc"
            echo "source ${INSTALL_DIR}/share/auto-uv-env/auto-uv-env.${shell_name}" >> "$shell_rc"
            print_success "Shell integration added!"
            print_step "Reload your shell or run: source $shell_rc"
        else
            print_success "Shell integration already configured"
        fi
    fi
}

main() {
    echo "auto-uv-env installer"
    echo "===================="
    echo ""

    # Detect OS
    detect_os
    print_step "Detected OS: $OS"

    # Check dependencies
    check_dependencies

    # Install based on OS
    if [[ "${USE_UNIVERSAL:-0}" == "1" ]]; then
        download_release
        install_files
    else
        install_os_package
    fi

    # Setup shell integration
    setup_shell

    # Verify installation
    if command -v auto-uv-env >/dev/null 2>&1; then
        local installed_version=$(auto-uv-env --version 2>/dev/null | cut -d' ' -f2)
        print_success "auto-uv-env $installed_version installed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Install UV if not already installed:"
        echo "   curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo ""
        echo "2. Reload your shell configuration:"
        echo "   source ~/.bashrc  # or ~/.zshrc"
        echo ""
        echo "3. Navigate to a Python project with pyproject.toml"
    else
        print_error "Installation failed. Please check the error messages above."
        exit 1
    fi
}

# Run main function
main "$@"
