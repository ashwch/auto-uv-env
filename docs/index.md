---
layout: default
title: Home
---

# auto-uv-env 🐍

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![UV](https://img.shields.io/badge/UV-Required-blue.svg)](https://github.com/astral-sh/uv)

Automatic UV-based Python virtual environment management for your shell. No more manual `source .venv/bin/activate`!

## Why auto-uv-env?

- 🚀 **Automatic activation** - Activates Python virtual environments when you `cd` into a project
- 🐍 **UV-powered** - Uses [UV](https://github.com/astral-sh/uv) for lightning-fast environment creation
- 📦 **pyproject.toml aware** - Reads Python version from `requires-python`
- 🎯 **Zero configuration** - Works out of the box
- 🐚 **Multi-shell support** - Works with Zsh, Bash, and Fish
- ⚡ **Fast** - Adds <5ms to directory changes
- 🧹 **Clean** - Automatically deactivates when leaving Python projects

## Quick Start

### 1. Install with Homebrew

```bash
brew tap ashwch/tap
brew install auto-uv-env
```

### 2. Add to your shell

**Zsh** (~/.zshrc):
```zsh
source $(brew --prefix)/share/auto-uv-env/auto-uv-env.zsh
```

**Bash** (~/.bashrc):
```bash
source $(brew --prefix)/share/auto-uv-env/auto-uv-env.bash
```

**Fish** (~/.config/fish/config.fish):
```fish
source (brew --prefix)/share/auto-uv-env/auto-uv-env.fish
```

### 3. Start using it!

```bash
cd my-python-project/
# 🐍 Setting up Python 3.11 with UV...
# ✅ Virtual environment created
# 🚀 UV environment activated (Python 3.11.5)
```

## How It Works

1. When you `cd` into a directory, auto-uv-env checks for `pyproject.toml`
2. If found, it reads the `requires-python` field
3. Uses UV to create a virtual environment with the correct Python version
4. Activates the environment automatically
5. When you leave the directory, it deactivates the environment

## Requirements

- [UV](https://github.com/astral-sh/uv) - Install with: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- A shell (Zsh, Bash, or Fish)
- Python projects with `pyproject.toml`

