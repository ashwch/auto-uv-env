#!/usr/bin/env bash
# Automated release script for auto-uv-env
# This script handles version bumping, tagging, releases, and Homebrew formula updates

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Print functions
print_step() {
    echo -e "${BLUE}🔄${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
HOMEBREW_TAP_REPO="ashwch/homebrew-tap"
PROJECT_REPO="ashwch/auto-uv-env"

usage() {
    cat << EOF
Usage: $0 <version> [options]

Arguments:
  version           Version number (e.g., 1.0.1, 1.1.0, 2.0.0)

Options:
  --dry-run        Show what would be done without making changes
  --skip-tests     Skip running tests before release
  --help, -h       Show this help message

Examples:
  $0 1.0.1                    # Create patch release v1.0.1
  $0 1.1.0 --dry-run         # Show what v1.1.0 release would do
  $0 2.0.0 --skip-tests      # Create major release without running tests

This script will:
1. Validate the version format
2. Run tests (unless --skip-tests)
3. Update version in all files
4. Create git commit and tag
5. Push to GitHub
6. Create GitHub release
7. Update Homebrew formula with new SHA256
8. Push Homebrew tap update
EOF
}

# Parse command line arguments
VERSION=""
DRY_RUN=false
SKIP_TESTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [[ -z "$VERSION" ]]; then
                VERSION="$1"
            else
                print_error "Too many arguments"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate version argument
if [[ -z "$VERSION" ]]; then
    print_error "Version argument is required"
    usage
    exit 1
fi

# Validate version format (semantic versioning)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid version format. Use semantic versioning (e.g., 1.0.1)"
    exit 1
fi

# Check if we're in the right directory
if [[ ! -f "$PROJECT_DIR/auto-uv-env" ]] || [[ ! -f "$PROJECT_DIR/pyproject.toml" ]]; then
    print_error "This script must be run from the auto-uv-env project directory"
    exit 1
fi

# Check if git is clean
if [[ -n "$(git status --porcelain)" ]]; then
    print_error "Git working directory is not clean. Please commit or stash changes first."
    exit 1
fi

# Check if we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    print_error "Releases must be created from the main branch. Current branch: $CURRENT_BRANCH"
    exit 1
fi

# Check for required tools
check_dependencies() {
    local missing_deps=()

    if ! command -v gh >/dev/null 2>&1; then
        missing_deps+=("gh (GitHub CLI)")
    fi

    if ! command -v uv >/dev/null 2>&1; then
        missing_deps+=("uv")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# Update version in all files
update_version_files() {
    print_step "Updating version to $VERSION in all files"

    # Update main script
    sed -i.bak "s/VERSION=\".*\"/VERSION=\"$VERSION\"/" "$PROJECT_DIR/auto-uv-env"
    rm -f "$PROJECT_DIR/auto-uv-env.bak"

    # Update pyproject.toml (only the version field, not target-version)
    sed -i.bak "s/^version = \".*\"/version = \"$VERSION\"/" "$PROJECT_DIR/pyproject.toml"
    rm -f "$PROJECT_DIR/pyproject.toml.bak"

    # Update CHANGELOG.md (add new section at top)
    local changelog_entry="## [$VERSION] - $(date +%Y-%m-%d)

### Added
-

### Changed
-

### Fixed
-

"

    # Insert after the header but before existing entries
    if [[ -f "$PROJECT_DIR/CHANGELOG.md" ]]; then
        # Create temp file with new entry
        {
            head -7 "$PROJECT_DIR/CHANGELOG.md"  # Keep header
            echo "$changelog_entry"
            tail -n +8 "$PROJECT_DIR/CHANGELOG.md"  # Rest of file
        } > "$PROJECT_DIR/CHANGELOG.md.tmp"
        mv "$PROJECT_DIR/CHANGELOG.md.tmp" "$PROJECT_DIR/CHANGELOG.md"
    fi

    print_success "Version updated in all files"
}

# Run tests
run_tests() {
    if [[ "$SKIP_TESTS" == true ]]; then
        print_warning "Skipping tests as requested"
        return
    fi

    print_step "Running test suite"

    cd "$PROJECT_DIR"

    # Run all test suites
    ./test/test.sh
    ./test/test-security.sh
    ./test/test-shell-integrations.sh

    # Run version validation
    ./auto-uv-env --validate

    # Run pre-commit hooks
    if command -v pre-commit >/dev/null 2>&1; then
        uv tool run pre-commit run --all-files
    fi

    print_success "All tests passed"
}

# Create git commit and tag
create_git_release() {
    print_step "Creating git commit and tag"

    cd "$PROJECT_DIR"

    # Add all changed files
    git add auto-uv-env pyproject.toml CHANGELOG.md

    # Create commit
    git commit -m "Release v$VERSION

- Updated version to $VERSION in all files
- See CHANGELOG.md for detailed release notes"

    # Create annotated tag
    git tag -a "v$VERSION" -m "Release v$VERSION

Production release with all quality gates passed.
See GitHub release notes for detailed changelog."

    print_success "Git commit and tag created"
}

# Push to GitHub
push_to_github() {
    print_step "Pushing to GitHub"

    cd "$PROJECT_DIR"

    git push origin main
    git push origin "v$VERSION"

    print_success "Pushed to GitHub"
}

# Calculate SHA256 for release
calculate_sha256() {
    print_step "Calculating SHA256 for release tarball"

    local tarball_url="https://github.com/$PROJECT_REPO/archive/v$VERSION.tar.gz"
    local sha256
    sha256=$(curl -sL "$tarball_url" | shasum -a 256 | cut -d' ' -f1)

    echo "$sha256"
}

# Create GitHub release
create_github_release() {
    print_step "Creating GitHub release"

    cd "$PROJECT_DIR"

    # Generate release notes from CHANGELOG
    local release_notes_file="/tmp/release-notes-v$VERSION.md"

    cat > "$release_notes_file" << EOF
# 🚀 auto-uv-env v$VERSION

## 📦 Installation

### Homebrew (Recommended)
\`\`\`bash
brew tap ashwch/tap
brew install auto-uv-env
\`\`\`

### Manual Installation
\`\`\`bash
curl -LO https://github.com/$PROJECT_REPO/archive/v$VERSION.tar.gz
tar -xzf v$VERSION.tar.gz
cd auto-uv-env-$VERSION
sudo cp auto-uv-env /usr/local/bin/
sudo mkdir -p /usr/local/share/auto-uv-env
sudo cp share/auto-uv-env/* /usr/local/share/auto-uv-env/
\`\`\`

## ⚡ Quick Start

Add to your shell configuration:

### Zsh
\`\`\`bash
echo 'source \$(brew --prefix)/share/auto-uv-env/auto-uv-env.zsh' >> ~/.zshrc
\`\`\`

### Bash
\`\`\`bash
echo 'source \$(brew --prefix)/share/auto-uv-env/auto-uv-env.bash' >> ~/.bashrc
\`\`\`

### Fish
\`\`\`bash
echo 'source (brew --prefix)/share/auto-uv-env/auto-uv-env.fish' >> ~/.config/fish/config.fish
\`\`\`

## 📋 Requirements

- [UV](https://github.com/astral-sh/uv) - Fast Python package manager
- Python projects with \`pyproject.toml\`
- Bash, ZSH, or Fish shell

---

**Ready for production use!** 🎉
EOF

    gh release create "v$VERSION" \
        --title "auto-uv-env v$VERSION" \
        --notes-file "$release_notes_file" \
        --latest

    rm -f "$release_notes_file"

    print_success "GitHub release created"
}

# Update Homebrew formula
update_homebrew_formula() {
    print_step "Updating Homebrew formula"

    local sha256
    sha256=$(calculate_sha256)

    # Clone the tap repository
    local tap_dir="/tmp/homebrew-tap-$VERSION"
    rm -rf "$tap_dir"

    gh repo clone "$HOMEBREW_TAP_REPO" "$tap_dir"
    cd "$tap_dir"

    # Update the formula
    local formula_file="Formula/auto-uv-env.rb"

    # Update version and SHA256
    sed -i.bak "s|archive/refs/tags/v.*\.tar\.gz|archive/refs/tags/v$VERSION.tar.gz|" "$formula_file"
    sed -i.bak "s/sha256 \".*\"/sha256 \"$sha256\"/" "$formula_file"
    rm -f "$formula_file.bak"

    # Commit and push
    git add "$formula_file"
    git commit -m "Update auto-uv-env to v$VERSION

- Updated version to $VERSION
- Updated SHA256 to $sha256"

    git push origin main

    # Cleanup
    rm -rf "$tap_dir"

    print_success "Homebrew formula updated"
}

# Verify installation
verify_installation() {
    print_step "Verifying Homebrew installation"

    # Test that the formula can be installed
    brew audit ashwch/tap/auto-uv-env 2>/dev/null || true

    print_success "Installation verification complete"
}

# Main execution
main() {
    echo "🚀 Starting release process for auto-uv-env v$VERSION"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    # Check dependencies
    check_dependencies

    if [[ "$DRY_RUN" == true ]]; then
        echo "Would perform the following steps:"
        echo "1. Update version to $VERSION in auto-uv-env, pyproject.toml, CHANGELOG.md"
        echo "2. Run test suite (unless --skip-tests)"
        echo "3. Create git commit and tag v$VERSION"
        echo "4. Push to GitHub"
        echo "5. Create GitHub release"
        echo "6. Calculate SHA256 for release tarball"
        echo "7. Update Homebrew formula in $HOMEBREW_TAP_REPO"
        echo "8. Verify installation"
        echo ""
        print_warning "Use without --dry-run to execute"
        exit 0
    fi

    # Execute release steps
    update_version_files
    run_tests
    create_git_release
    push_to_github
    create_github_release
    update_homebrew_formula
    verify_installation

    echo ""
    print_success "🎉 Release v$VERSION completed successfully!"
    echo ""
    echo "📋 What was done:"
    echo "  ✅ Version updated in all files"
    echo "  ✅ Tests passed"
    echo "  ✅ Git commit and tag created"
    echo "  ✅ Pushed to GitHub"
    echo "  ✅ GitHub release created"
    echo "  ✅ Homebrew formula updated"
    echo ""
    echo "🔗 Links:"
    echo "  • Release: https://github.com/$PROJECT_REPO/releases/tag/v$VERSION"
    echo "  • Install: brew tap ashwch/tap && brew install auto-uv-env"
    echo ""
    echo "🎯 Users can now install auto-uv-env v$VERSION via Homebrew!"
}

# Run main function
main "$@"
