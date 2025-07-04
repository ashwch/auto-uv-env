#!/usr/bin/env bash
# Build script for creating Red Hat/Fedora packages (.rpm files)
# This script creates a proper RPM package structure and builds the .rpm file

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
RELEASE="1"
ARCH="noarch"  # Architecture-independent package

# Build directory
BUILD_DIR="$PROJECT_ROOT/build/rpm"
RPMBUILD_DIR="$BUILD_DIR/rpmbuild"

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
    for cmd in rpmbuild; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("rpm-build")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing build dependencies: ${missing_deps[*]}"
        print_step "Install with:"
        print_step "  RHEL/CentOS/Rocky/Alma: sudo yum install -y rpm-build"
        print_step "  Fedora: sudo dnf install -y rpm-build"
        exit 1
    fi
}

setup_build_tree() {
    print_step "Setting up RPM build tree..."

    # Clean and create build directories
    rm -rf "$BUILD_DIR"
    mkdir -p "$RPMBUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

    # Create source tarball
    local tarball_name="${PACKAGE_NAME}-${VERSION}.tar.gz"
    cd "$PROJECT_ROOT"
    tar czf "$RPMBUILD_DIR/SOURCES/$tarball_name" \
        --transform "s,^,${PACKAGE_NAME}-${VERSION}/," \
        --exclude=".git" \
        --exclude="build" \
        --exclude="*.deb" \
        --exclude="*.rpm" \
        auto-uv-env \
        share/ \
        LICENSE \
        README.md \
        CHANGELOG.md \
        packaging/
}

create_spec_file() {
    print_step "Creating RPM spec file..."

    cat > "$RPMBUILD_DIR/SPECS/${PACKAGE_NAME}.spec" << EOF
Name:           ${PACKAGE_NAME}
Version:        ${VERSION}
Release:        ${RELEASE}%{?dist}
Summary:        Automatic UV-based Python virtual environment management

License:        MIT
URL:            https://github.com/ashwch/auto-uv-env
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  bash >= 4.0

# Runtime requirements
Requires:       bash >= 4.0
Requires(post): /bin/bash
Requires(preun): /bin/bash

# Recommended packages
Recommends:     python3
Recommends:     python3-virtualenv

# Weak dependencies (installed if available)
Suggests:       curl

%description
auto-uv-env automatically activates Python virtual environments when
you navigate to Python projects. It detects pyproject.toml files,
creates virtual environments using UV, and manages activation/deactivation
seamlessly.

Features:
- Automatic virtual environment activation based on pyproject.toml
- UV-powered for lightning-fast environment creation
- Multi-shell support (Bash, Zsh, Fish)
- Zero configuration required
- Respects .auto-uv-env-ignore files
- Performance optimized with fast-path for non-Python directories

UV is required but not packaged. Install with:
curl -LsSf https://astral.sh/uv/install.sh | sh

%prep
%setup -q

%build
# Nothing to build - this is a shell script

%install
# Create directories
install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_datadir}/%{name}
install -d %{buildroot}%{_docdir}/%{name}

# Install main script
install -p -m 755 auto-uv-env %{buildroot}%{_bindir}/

# Install shell integrations
install -p -m 644 share/auto-uv-env/* %{buildroot}%{_datadir}/%{name}/

# Install documentation
install -p -m 644 README.md %{buildroot}%{_docdir}/%{name}/
install -p -m 644 LICENSE %{buildroot}%{_docdir}/%{name}/
install -p -m 644 CHANGELOG.md %{buildroot}%{_docdir}/%{name}/

%post
# Post-installation message
cat << 'POSTINST'

auto-uv-env installed successfully!

To enable auto-uv-env, add the following to your shell configuration:

For Bash (~/.bashrc):
  source %{_datadir}/%{name}/auto-uv-env.bash

For Zsh (~/.zshrc):
  source %{_datadir}/%{name}/auto-uv-env.zsh

For Fish (~/.config/fish/config.fish):
  source %{_datadir}/%{name}/auto-uv-env.fish

POSTINST

# Check if UV is installed
if ! command -v uv >/dev/null 2>&1; then
    echo ""
    echo "Warning: UV is not installed."
    echo "auto-uv-env requires UV to function properly."
    echo ""
    echo "Install UV with:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

%preun
# Pre-uninstall script
# Deactivate any active virtual environments
if [ -n "\${VIRTUAL_ENV:-}" ] && [ -n "\${_AUTO_UV_ENV_ACTIVATION_DIR:-}" ]; then
    if command -v deactivate >/dev/null 2>&1; then
        deactivate 2>/dev/null || true
    fi
fi

%files
%license LICENSE
%doc README.md CHANGELOG.md
%{_bindir}/auto-uv-env
%{_datadir}/%{name}/

%changelog
* $(date +"%a %b %d %Y") Auto-generated <auto@generated> - ${VERSION}-${RELEASE}
- Performance optimization: Added fast-path for non-Python directories
- Fixed deactivation logic to only deactivate auto-activated environments
- Added state tracking with _AUTO_UV_ENV_ACTIVATION_DIR
- Fixed broken pipe error in version flag handling
- Updated documentation and added Linux distribution support

* Thu Jul 03 2025 Ashwini Chaudhary <ashwch@github.com> - 1.0.4-1
- Initial RPM package release
- Multi-shell support (Bash, Zsh, Fish)
- Automatic virtual environment management with UV
- Project detection via pyproject.toml
EOF
}

build_package() {
    print_step "Building RPM package..."

    # Build the RPM
    rpmbuild --define "_topdir $RPMBUILD_DIR" \
             -ba "$RPMBUILD_DIR/SPECS/${PACKAGE_NAME}.spec"

    # Copy built RPMs to project root
    find "$RPMBUILD_DIR/RPMS" -name "*.rpm" -exec cp {} "$PROJECT_ROOT/" \;
    find "$RPMBUILD_DIR/SRPMS" -name "*.src.rpm" -exec cp {} "$PROJECT_ROOT/" \;

    print_success "Packages built successfully!"
}

validate_package() {
    print_step "Validating package..."

    local rpm_file=$(find "$PROJECT_ROOT" -name "${PACKAGE_NAME}-${VERSION}-*.noarch.rpm" | head -1)

    if [[ -z "$rpm_file" ]]; then
        print_error "RPM file not found!"
        exit 1
    fi

    # Show package info
    echo ""
    echo "Package information:"
    rpm -qip "$rpm_file"

    # List files in package
    echo ""
    echo "Package contents:"
    rpm -qlp "$rpm_file"

    # Check dependencies
    echo ""
    echo "Package dependencies:"
    rpm -qRp "$rpm_file"

    # Run rpmlint if available
    if command -v rpmlint >/dev/null 2>&1; then
        echo ""
        print_step "Running rpmlint checks..."
        rpmlint "$rpm_file" || true
    fi
}

create_repo_files() {
    print_step "Creating YUM/DNF repository files..."

    cat > "$PROJECT_ROOT/auto-uv-env.repo" << EOF
[auto-uv-env]
name=auto-uv-env - Automatic UV-based Python virtual environment management
baseurl=https://github.com/ashwch/auto-uv-env/releases/download/v\$releasever/
enabled=1
gpgcheck=0
metadata_expire=300

[auto-uv-env-source]
name=auto-uv-env - Source
baseurl=https://github.com/ashwch/auto-uv-env/releases/download/v\$releasever/src/
enabled=0
gpgcheck=0
EOF

    print_success "Repository file created: auto-uv-env.repo"
}

main() {
    echo "Building RPM package for auto-uv-env v${VERSION}"
    echo "============================================="
    echo ""

    check_dependencies
    setup_build_tree
    create_spec_file
    build_package
    validate_package
    create_repo_files

    echo ""
    print_success "Build complete!"
    echo ""
    echo "To install the package:"
    echo "  sudo rpm -ivh ${PACKAGE_NAME}-${VERSION}-${RELEASE}.*.noarch.rpm"
    echo ""
    echo "Or with automatic dependency resolution:"
    echo "  sudo yum localinstall ${PACKAGE_NAME}-${VERSION}-${RELEASE}.*.noarch.rpm"
    echo "  sudo dnf install ${PACKAGE_NAME}-${VERSION}-${RELEASE}.*.noarch.rpm  # Fedora"
}

# Run main function
main "$@"
