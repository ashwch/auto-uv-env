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

### Option 1: Homebrew (macOS/Linux) 🍺

The easiest way to install auto-uv-env:

```bash
# Add the tap
brew tap ashwch/tap

# Install auto-uv-env
brew install auto-uv-env
```

### Option 2: Install Script (Universal)

Works on Ubuntu, Debian, RHEL, Fedora, CentOS, Rocky Linux, AlmaLinux, and more:

```bash
# Install latest version
curl -sSL https://raw.githubusercontent.com/ashwch/auto-uv-env/main/scripts/install.sh | bash

# Install specific version
curl -sSL https://raw.githubusercontent.com/ashwch/auto-uv-env/main/scripts/install.sh | bash -s -- 1.0.4

# Install with options
curl -sSL https://raw.githubusercontent.com/ashwch/auto-uv-env/main/scripts/install.sh | bash -s -- --help
```

The install script will:
- Detect your operating system
- Build native packages (.deb or .rpm) when possible
- Fall back to universal installation if needed
- Set up shell integration automatically
- Check for required dependencies

### Option 3: Manual Installation

For systems without Homebrew or if you prefer manual installation:

```bash
# Clone the repository
git clone https://github.com/ashwch/auto-uv-env.git
cd auto-uv-env

# Copy the executable to your PATH
sudo cp auto-uv-env /usr/local/bin/
sudo chmod +x /usr/local/bin/auto-uv-env

# Copy shell integration files
sudo mkdir -p /usr/local/share/auto-uv-env
sudo cp share/auto-uv-env/* /usr/local/share/auto-uv-env/
```

### Option 4: Linux Distribution Packages

#### Ubuntu/Debian (.deb)

```bash
# Method 1: Build and install locally
git clone https://github.com/ashwch/auto-uv-env.git
cd auto-uv-env
./scripts/build-deb.sh
sudo apt install ./auto-uv-env_*.deb

# Method 2: Download from releases (when available)
wget https://github.com/ashwch/auto-uv-env/releases/latest/download/auto-uv-env_1.0.4_all.deb
sudo apt install ./auto-uv-env_1.0.4_all.deb
```

#### RHEL/Fedora/CentOS/Rocky/AlmaLinux (.rpm)

```bash
# Method 1: Build and install locally
git clone https://github.com/ashwch/auto-uv-env.git
cd auto-uv-env
./scripts/build-rpm.sh
sudo dnf install ./auto-uv-env-*.noarch.rpm  # Fedora
sudo yum localinstall ./auto-uv-env-*.noarch.rpm  # RHEL/CentOS

# Method 2: Download from releases (when available)
wget https://github.com/ashwch/auto-uv-env/releases/latest/download/auto-uv-env-1.0.4-1.noarch.rpm
sudo dnf install ./auto-uv-env-1.0.4-1.noarch.rpm
```

#### Arch Linux (AUR)

```bash
# Using yay
yay -S auto-uv-env

# Using manual build
git clone https://aur.archlinux.org/auto-uv-env.git
cd auto-uv-env
makepkg -si
```

### Option 5: Direct Download

```bash
# Download the latest release
curl -LO https://github.com/ashwch/auto-uv-env/archive/v1.0.4.tar.gz
tar -xzf v1.0.4.tar.gz
cd auto-uv-env-1.0.4

# Install
sudo cp auto-uv-env /usr/local/bin/
sudo mkdir -p /usr/local/share/auto-uv-env
sudo cp share/auto-uv-env/* /usr/local/share/auto-uv-env/
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

### With Homebrew

```bash
brew uninstall auto-uv-env
brew untap ashwch/tap
```

### Manual Uninstallation

```bash
# Remove the executable
sudo rm /usr/local/bin/auto-uv-env

# Remove shell integration files
sudo rm -rf /usr/local/share/auto-uv-env

# Remove from shell configuration
# Edit ~/.zshrc, ~/.bashrc, or ~/.config/fish/config.fish
# and remove the source line
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