#!/usr/bin/env bash
# Universal installation script for auto-uv-env
# Supports: Ubuntu, Debian, RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux, Arch
# Also provides a universal installation method for other distributions

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    print_step "Installing for Debian/Ubuntu..."

    # Check if we can build a .deb package
    if command -v dpkg-deb >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/build-deb.sh" ]]; then
        print_step "Building Debian package..."
        "$SCRIPT_DIR/build-deb.sh"

        # Install the built package
        local deb_file="${SCRIPT_DIR}/../auto-uv-env_*.deb"
        if ls $deb_file 1> /dev/null 2>&1; then
            print_step "Installing package..."
            sudo dpkg -i $deb_file || sudo apt-get install -f -y
            return 0
        fi
    fi

    # Fall back to universal install
    print_warning "Cannot build .deb package, using universal installation"
    download_release
    install_files
}

install_rpm_package() {
    print_step "Installing for Red Hat/Fedora..."

    # Check if we can build an .rpm package
    if command -v rpmbuild >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/build-rpm.sh" ]]; then
        print_step "Building RPM package..."
        "$SCRIPT_DIR/build-rpm.sh"

        # Install the built package
        local rpm_file="${SCRIPT_DIR}/../auto-uv-env-*.noarch.rpm"
        if ls $rpm_file 1> /dev/null 2>&1; then
            print_step "Installing package..."
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y $rpm_file
            else
                sudo yum localinstall -y $rpm_file
            fi
            return 0
        fi
    fi

    # Fall back to universal install
    print_warning "Cannot build .rpm package, using universal installation"
    download_release
    install_files
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

show_usage() {
    cat << EOF
auto-uv-env installer

Usage: $0 [OPTIONS] [VERSION]

Options:
    -h, --help          Show this help message
    -u, --universal     Force universal installation (skip OS packages)
    -s, --skip-shell    Skip shell integration setup
    -d, --dir DIR       Installation directory (default: /usr/local)

Version:
    latest              Install the latest version (default)
    X.Y.Z               Install a specific version

Examples:
    $0                  # Install latest version
    $0 1.0.4            # Install version 1.0.4
    $0 --universal      # Force universal installation
    $0 --dir /opt      # Install to /opt instead of /usr/local

Supported operating systems:
    - Ubuntu / Debian (builds .deb package)
    - RHEL / CentOS / Fedora / Rocky / AlmaLinux (builds .rpm package)
    - Arch Linux (AUR compatible)
    - macOS (use Homebrew instead: brew install ashwch/tap/auto-uv-env)
    - Others (universal installation)

EOF
}

main() {
    # Parse arguments
    local skip_shell=0
    local force_universal=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -u|--universal)
                force_universal=1
                shift
                ;;
            -s|--skip-shell)
                skip_shell=1
                shift
                ;;
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                VERSION="$1"
                shift
                ;;
        esac
    done

    echo "auto-uv-env installer v${VERSION}"
    echo "=========================="
    echo ""

    # Detect OS
    detect_os
    print_step "Detected OS: $OS"

    # Show installation directory
    print_step "Installation directory: $INSTALL_DIR"

    # Check dependencies
    check_dependencies

    # Install based on OS
    if [[ "$force_universal" == "1" ]]; then
        print_step "Using universal installation method"
        download_release
        install_files
    else
        install_os_package
    fi

    # Setup shell integration
    if [[ "$skip_shell" == "0" ]]; then
        setup_shell
    else
        print_step "Skipping shell integration setup"
    fi

    # Verify installation
    if command -v auto-uv-env >/dev/null 2>&1; then
        local installed_version=$(auto-uv-env --version 2>/dev/null | cut -d' ' -f2)
        print_success "auto-uv-env $installed_version installed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Install UV if not already installed:"
        echo "   curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo ""
        if [[ "$skip_shell" == "0" ]]; then
            echo "2. Reload your shell configuration:"
            echo "   source ~/.bashrc  # or ~/.zshrc for Zsh, config.fish for Fish"
        else
            echo "2. Add auto-uv-env to your shell configuration manually."
            echo "   See: https://github.com/ashwch/auto-uv-env#setup"
        fi
        echo ""
        echo "3. Navigate to a Python project with pyproject.toml"
        echo ""
        echo "For more information: https://github.com/ashwch/auto-uv-env"
    else
        print_error "Installation failed. Please check the error messages above."
        exit 1
    fi
}

# Run main function
main "$@"
