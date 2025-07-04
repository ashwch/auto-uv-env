#!/usr/bin/env bash
# Build script for creating Debian/Ubuntu packages (.deb files)
# This script creates a proper Debian package structure and builds the .deb file

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Configuration
PACKAGE_NAME="auto-uv-env"
VERSION=$(grep '^VERSION=' "$PROJECT_ROOT/auto-uv-env" | cut -d'"' -f2)
ARCH="all"  # Architecture-independent package
MAINTAINER="Ashwini Chaudhary <ashwch@github.com>"
DESCRIPTION="Automatic UV-based Python virtual environment management"

# Build directory
BUILD_DIR="$PROJECT_ROOT/build/deb"
DEB_ROOT="$BUILD_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}"

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

check_dependencies() {
    local missing_deps=()

    # Check for required build tools
    for cmd in dpkg-deb fakeroot; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing build dependencies: ${missing_deps[*]}"
        print_step "Install with: sudo apt-get update && sudo apt-get install -y dpkg-dev fakeroot"
        exit 1
    fi
}

clean_build_dir() {
    print_step "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$DEB_ROOT"
}

create_debian_structure() {
    print_step "Creating Debian package structure..."

    # Create necessary directories
    mkdir -p "$DEB_ROOT/DEBIAN"
    mkdir -p "$DEB_ROOT/usr/bin"
    mkdir -p "$DEB_ROOT/usr/share/$PACKAGE_NAME"
    mkdir -p "$DEB_ROOT/usr/share/doc/$PACKAGE_NAME"

    # Copy the main script
    cp "$PROJECT_ROOT/auto-uv-env" "$DEB_ROOT/usr/bin/"
    chmod 755 "$DEB_ROOT/usr/bin/auto-uv-env"

    # Copy shell integrations
    cp -r "$PROJECT_ROOT/share/auto-uv-env/"* "$DEB_ROOT/usr/share/$PACKAGE_NAME/"

    # Copy documentation
    cp "$PROJECT_ROOT/README.md" "$DEB_ROOT/usr/share/doc/$PACKAGE_NAME/"
    cp "$PROJECT_ROOT/LICENSE" "$DEB_ROOT/usr/share/doc/$PACKAGE_NAME/copyright"
    if [[ -f "$PROJECT_ROOT/CHANGELOG.md" ]]; then
        cp "$PROJECT_ROOT/CHANGELOG.md" "$DEB_ROOT/usr/share/doc/$PACKAGE_NAME/"
    fi
}

create_control_file() {
    print_step "Creating control file..."

    cat > "$DEB_ROOT/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Depends: bash (>= 4.0)
Recommends: python3, python3-venv
Suggests: curl | wget
Homepage: https://github.com/ashwch/auto-uv-env
Description: $DESCRIPTION
 auto-uv-env automatically activates Python virtual environments when
 you navigate to Python projects. It detects pyproject.toml files,
 creates virtual environments using UV, and manages activation/deactivation
 seamlessly.
 .
 Features:
  - Automatic virtual environment activation based on pyproject.toml
  - UV-powered for lightning-fast environment creation
  - Multi-shell support (Bash, Zsh, Fish)
  - Zero configuration required
  - Respects .auto-uv-env-ignore files
  - Performance optimized with fast-path for non-Python directories
 .
 UV Installation:
  UV is required but not packaged. Install with:
  curl -LsSf https://astral.sh/uv/install.sh | sh
EOF
}

create_postinst_script() {
    print_step "Creating post-installation script..."

    cat > "$DEB_ROOT/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo ""
echo -e "${GREEN}auto-uv-env installed successfully!${NC}"
echo ""

# Check if UV is installed
if ! command -v uv >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: UV is not installed.${NC}"
    echo "auto-uv-env requires UV to function properly."
    echo ""
    echo "Install UV with:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo ""
fi

echo "To enable auto-uv-env, add the following to your shell configuration:"
echo ""
echo "For Bash (~/.bashrc):"
echo "  source /usr/share/auto-uv-env/auto-uv-env.bash"
echo ""
echo "For Zsh (~/.zshrc):"
echo "  source /usr/share/auto-uv-env/auto-uv-env.zsh"
echo ""
echo "For Fish (~/.config/fish/config.fish):"
echo "  source /usr/share/auto-uv-env/auto-uv-env.fish"
echo ""

exit 0
EOF
    chmod 755 "$DEB_ROOT/DEBIAN/postinst"
}

create_prerm_script() {
    print_step "Creating pre-removal script..."

    cat > "$DEB_ROOT/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e

# Deactivate any active virtual environments
if [[ -n "${VIRTUAL_ENV:-}" ]] && [[ -n "${_AUTO_UV_ENV_ACTIVATION_DIR:-}" ]]; then
    if command -v deactivate >/dev/null 2>&1; then
        deactivate 2>/dev/null || true
    fi
fi

exit 0
EOF
    chmod 755 "$DEB_ROOT/DEBIAN/prerm"
}

calculate_size() {
    # Calculate installed size in KB
    local size=$(du -sk "$DEB_ROOT" | cut -f1)
    echo "Installed-Size: $size" >> "$DEB_ROOT/DEBIAN/control"
}

build_package() {
    print_step "Building Debian package..."

    # Set proper permissions
    find "$DEB_ROOT" -type d -exec chmod 755 {} \;
    find "$DEB_ROOT" -type f -exec chmod 644 {} \;
    chmod 755 "$DEB_ROOT/usr/bin/auto-uv-env"
    chmod 755 "$DEB_ROOT/DEBIAN/postinst"
    chmod 755 "$DEB_ROOT/DEBIAN/prerm"

    # Build the package
    cd "$BUILD_DIR"
    fakeroot dpkg-deb --build "${PACKAGE_NAME}_${VERSION}_${ARCH}"

    # Move to project root
    mv "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb" "$PROJECT_ROOT/"

    print_success "Package built: ${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
}

validate_package() {
    print_step "Validating package..."

    local deb_file="$PROJECT_ROOT/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

    # Check package info
    dpkg-deb --info "$deb_file"

    # List contents
    echo ""
    echo "Package contents:"
    dpkg-deb --contents "$deb_file"

    # Run lintian if available
    if command -v lintian >/dev/null 2>&1; then
        echo ""
        print_step "Running lintian checks..."
        lintian "$deb_file" || true
    fi
}

main() {
    echo "Building Debian package for auto-uv-env v${VERSION}"
    echo "=============================================="
    echo ""

    check_dependencies
    clean_build_dir
    create_debian_structure
    create_control_file
    create_postinst_script
    create_prerm_script
    calculate_size
    build_package
    validate_package

    echo ""
    print_success "Build complete!"
    echo ""
    echo "To install the package:"
    echo "  sudo dpkg -i ${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
    echo ""
    echo "To install with automatic dependency resolution:"
    echo "  sudo apt install ./${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
}

# Run main function
main "$@"
