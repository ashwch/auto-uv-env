---
layout: page
title: Installation
permalink: /installation/
---

# Installation

## Using Homebrew (Recommended)

```bash
brew tap ashwch/tap
brew install auto-uv-env
```

## Manual Installation

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

## Shell Setup

### Zsh (~/.zshrc)
```zsh
source $(brew --prefix)/share/auto-uv-env/auto-uv-env.zsh
```

### Bash (~/.bashrc)
```bash
source $(brew --prefix)/share/auto-uv-env/auto-uv-env.bash
```

### Fish (~/.config/fish/config.fish)
```fish
source (brew --prefix)/share/auto-uv-env/auto-uv-env.fish
```

## Requirements

- [UV](https://github.com/astral-sh/uv) - Install with: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- A shell (Zsh, Bash, or Fish)
- Python projects with `pyproject.toml`