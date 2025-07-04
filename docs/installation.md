---
layout: page
title: Installation
permalink: /installation/
---

# Installation Guide

## Prerequisites

Before installing auto-uv-env, you need to have UV installed:

```bash
# Install UV (required)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Installation Methods

### Option 1: Quick Install (Recommended) 🚀

The simplest way to install auto-uv-env on any system:

```bash
curl -LsSf https://auto-uv-env.ashwch.com/install.sh | sh
```

This installer:
- Works on macOS, Linux, and BSD systems
- Detects your platform automatically
- Installs to `~/.local/bin` by default (respects XDG)
- Sets up shell integration for bash, zsh, and fish
- Suggests Homebrew on macOS (if available)

### Option 2: Homebrew (macOS preferred) 🍺

For macOS users with Homebrew:

```bash
# Add the tap
brew tap ashwch/tap

# Install auto-uv-env
brew install auto-uv-env
```

Benefits:
- Automatic updates with `brew upgrade`
- Clean uninstallation
- Managed dependencies

### Option 3: Install from GitHub

If you prefer to use GitHub directly:

```bash
curl -LsSf https://raw.githubusercontent.com/ashwch/auto-uv-env/main/docs/install.sh | sh
```

### Option 4: Manual Installation

For full control over the installation:

```bash
# Clone the repository
git clone https://github.com/ashwch/auto-uv-env.git
cd auto-uv-env

# Copy files manually
sudo cp auto-uv-env /usr/local/bin/
sudo chmod +x /usr/local/bin/auto-uv-env
sudo mkdir -p /usr/local/share/auto-uv-env
sudo cp share/auto-uv-env/* /usr/local/share/auto-uv-env/
```

## Installation Options

The installer supports several options:

```bash
# Show help
curl -LsSf https://auto-uv-env.ashwch.com/install.sh | sh -s -- --help

# Verbose output
curl -LsSf https://auto-uv-env.ashwch.com/install.sh | sh -s -- --verbose

# Custom installation directories
AUTO_UV_ENV_BIN_DIR=/opt/bin \
AUTO_UV_ENV_SHARE_DIR=/opt/share/auto-uv-env \
curl -LsSf https://auto-uv-env.ashwch.com/install.sh | sh
```

## Shell Integration Setup

After installation, add auto-uv-env to your shell configuration:

### Zsh Configuration

Add to your `~/.zshrc`:

```zsh
# For Homebrew installation
source $(brew --prefix)/share/auto-uv-env/auto-uv-env.zsh

# For manual installation
source /usr/local/share/auto-uv-env/auto-uv-env.zsh
```

### Bash Configuration

Add to your `~/.bashrc` or `~/.bash_profile`:

```bash
# For Homebrew installation
source $(brew --prefix)/share/auto-uv-env/auto-uv-env.bash

# For manual installation
source /usr/local/share/auto-uv-env/auto-uv-env.bash
```

### Fish Configuration

Add to your `~/.config/fish/config.fish`:

```fish
# For Homebrew installation
source (brew --prefix)/share/auto-uv-env/auto-uv-env.fish

# For manual installation
source /usr/local/share/auto-uv-env/auto-uv-env.fish
```

## Verify Installation

After setup, reload your shell and verify:

```bash
# Reload shell configuration
source ~/.zshrc  # or ~/.bashrc for Bash

# Check version
auto-uv-env --version

# Test in a Python project
cd /path/to/python/project
# Should automatically activate environment
```

## Updating

### With Homebrew

```bash
brew update
brew upgrade auto-uv-env
```

### Manual Update

```bash
cd /path/to/auto-uv-env
git pull origin main
sudo cp auto-uv-env /usr/local/bin/
sudo cp share/auto-uv-env/* /usr/local/share/auto-uv-env/
```

## Uninstallation

### Using the Uninstaller

```bash
# If installed with the install script
curl -LsSf https://auto-uv-env.ashwch.com/uninstall.sh | sh
```

### With Homebrew

```bash
brew uninstall auto-uv-env
brew untap ashwch/tap
```

### Manual Uninstallation

```bash
# Remove the executable
sudo rm /usr/local/bin/auto-uv-env
# Or if installed in ~/.local/bin
rm ~/.local/bin/auto-uv-env

# Remove shell integration files
sudo rm -rf /usr/local/share/auto-uv-env
# Or if installed in ~/.local/share
rm -rf ~/.local/share/auto-uv-env

# Remove from shell configuration
# Edit ~/.zshrc, ~/.bashrc, or ~/.config/fish/config.fish
# and remove the auto-uv-env source line
```

## Troubleshooting

### Command not found

If you get "command not found" after installation:
- Ensure `/usr/local/bin` is in your PATH
- For Homebrew, ensure `$(brew --prefix)/bin` is in your PATH
- For package installations, try `/usr/bin/auto-uv-env`

### UV not found

If you get "UV not found" error:
- Install UV: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Ensure UV is in your PATH
- Add `export PATH="$HOME/.cargo/bin:$PATH"` to your shell config

### Shell integration not working

- Make sure you've reloaded your shell configuration
- Check that the source path is correct for your installation method
- Try running the command manually to see any error messages
- For package installations, the integration files are in `/usr/share/auto-uv-env/`

### Performance issues

auto-uv-env is optimized for performance:
- Non-Python directories: ~4ms overhead (fast-path optimization)
- Python directories: ~50-100ms (includes environment checking)

If experiencing slow shell startup:
1. Ensure you have the latest version
2. Check for conflicting shell plugins
3. Report issues at https://github.com/ashwch/auto-uv-env/issues