#!/usr/bin/env bash
# Script to build and serve Jekyll docs locally

set -euo pipefail

echo "📚 Building auto-uv-env documentation locally..."

# Check if Ruby is installed
if ! command -v ruby >/dev/null 2>&1; then
    echo "❌ Ruby is not installed. Please install Ruby first."
    echo "   On macOS: brew install ruby"
    echo "   On Ubuntu: sudo apt-get install ruby-full"
    exit 1
fi

# Check if bundler is installed
if ! command -v bundle >/dev/null 2>&1; then
    echo "📦 Installing bundler..."
    gem install bundler
fi

# Navigate to docs directory
cd "$(dirname "$0")"

# Install dependencies
echo "📦 Installing dependencies..."
bundle install

# Build and serve the site
echo "🚀 Starting Jekyll server..."
echo "📍 Site will be available at: http://localhost:4000"
echo "   Press Ctrl+C to stop the server"
echo ""

# Serve with live reload
bundle exec jekyll serve --livereload --open-url
