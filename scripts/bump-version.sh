#!/usr/bin/env bash
# Simple version bumping helper for auto-uv-env

set -euo pipefail

# Get current version
CURRENT_VERSION=$(grep "VERSION=" auto-uv-env | cut -d"=" -f2 | tr -d '"')

# Parse version parts
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

usage() {
    cat << EOF
Usage: $0 <bump-type>

Bump types:
  patch     Increment patch version (e.g., 1.0.0 -> 1.0.1)
  minor     Increment minor version (e.g., 1.0.0 -> 1.1.0)
  major     Increment major version (e.g., 1.0.0 -> 2.0.0)

Current version: $CURRENT_VERSION

Examples:
  $0 patch     # Create v1.0.1 release
  $0 minor     # Create v1.1.0 release
  $0 major     # Create v2.0.0 release

This script calculates the new version and calls scripts/release.sh
EOF
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

BUMP_TYPE="$1"

case "$BUMP_TYPE" in
    patch)
        NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
        ;;
    minor)
        NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
        ;;
    major)
        NEW_VERSION="$((MAJOR + 1)).0.0"
        ;;
    *)
        echo "Error: Invalid bump type '$BUMP_TYPE'"
        usage
        exit 1
        ;;
esac

echo "🔄 Bumping version from $CURRENT_VERSION to $NEW_VERSION"
echo ""

# Call the main release script with remaining arguments
shift  # Remove the bump-type argument
exec "$(dirname "$0")/release.sh" "$NEW_VERSION" "$@"
