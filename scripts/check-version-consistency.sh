#!/usr/bin/env bash
# Check version consistency across all project files

set -euo pipefail

# Extract version from main script (first occurrence only)
version=$(grep "VERSION=" auto-uv-env | head -1 | cut -d"=" -f2 | tr -d '"')
echo "Checking version consistency for: $version"

errors=0

# Check CHANGELOG.md
if ! grep -q "\[$version\]" CHANGELOG.md; then
    echo "❌ Version $version not found in CHANGELOG.md"
    errors=$((errors + 1))
else
    echo "✅ CHANGELOG.md contains version $version"
fi

# Check pyproject.toml
if ! grep -q "version = \"$version\"" pyproject.toml; then
    echo "❌ Version $version not found in pyproject.toml"
    errors=$((errors + 1))
else
    echo "✅ pyproject.toml contains version $version"
fi

# Check Homebrew formula (now in separate repository)
echo "ℹ️  Homebrew formula is maintained in ashwch/homebrew-tap repository"

if [[ $errors -eq 0 ]]; then
    echo "🎉 Version consistency check passed for $version"
    exit 0
else
    echo "💥 $errors version inconsistencies found"
    exit 1
fi
