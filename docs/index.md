---
layout: default
title: Home
permalink: /
---

# auto-uv-env 🐍

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![UV](https://img.shields.io/badge/UV-Required-blue.svg)](https://github.com/astral-sh/uv)

Automatic UV-based Python virtual environment management for your shell.

`auto-uv-env` watches directory changes, discovers the nearest `pyproject.toml`, creates a project-local virtual environment with `uv`, and activates/deactivates it automatically.

## Why auto-uv-env?

- 🚀 Automatic activation when entering Python projects
- 🐍 UV-powered environment creation and Python installation
- 📦 `pyproject.toml` aware (`requires-python`)
- 🧠 Parent-directory project discovery (works from subdirectories)
- 🧹 Clean deactivation when leaving managed project trees
- 🛡️ Manual venv protection (does not override manually activated environments)
- ⚡ Optimized for low overhead in non-project directories

## Quick Start

### 1. Install auto-uv-env

**Quick install (any system):**
```bash
curl -LsSf https://auto-uv-env.ashwch.com/install.sh | sh
```

**macOS with Homebrew (recommended for Mac):**
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
cd my-python-project/src/app
# 🐍 Setting up Python 3.11 with UV...
# ✅ Virtual environment created
# 🚀 UV environment activated (Python 3.11.x)
```

## How It Works

1. Walk upward from `$PWD` to find the nearest `pyproject.toml`.
2. If `.auto-uv-env-ignore` appears first, activation is skipped for that subtree.
3. Read `requires-python` from the discovered project root.
4. Create `<project-root>/.venv` when missing.
5. Activate on entry and deactivate only environments managed by auto-uv-env.
6. If a manual venv is active, auto-uv-env does not override it.

## Features

### ⚡ Performance and Reliability

- v1.0.7 delivered roughly 93% startup overhead improvement.
- Typical startup overhead is low in Python projects and effectively near-zero in non-project directories.
- Directory-change overhead is typically sub-millisecond.
- Command path caching and lazy loading keep common shell paths fast.

### 🎯 Intelligent Activation

- Project-aware parent discovery from subdirectories
- `requires-python` version matching from `pyproject.toml`
- Ignore-file precedence with `.auto-uv-env-ignore`
- Manual venv protection to avoid breaking user-managed workflows

### 🛡️ Security First

- Path validation blocks traversal-style venv names
- Safe directive parsing in shell adapters
- Security checks in CI and local quality gates

## Documentation

- Installation: [`/installation/`]({{ "/installation/" | relative_url }})
- Usage and troubleshooting: [`/usage/`]({{ "/usage/" | relative_url }})
- Contributor guide: [`/contributing/`]({{ "/contributing/" | relative_url }})
- Deciding between tools: [`/alternatives/`]({{ "/alternatives/" | relative_url }})
- Repo contributor entrypoint: [CONTRIBUTE.md](https://github.com/ashwch/auto-uv-env/blob/main/CONTRIBUTE.md)
- Release runbook: [RELEASE.md](https://github.com/ashwch/auto-uv-env/blob/main/RELEASE.md)

## Requirements

- [UV](https://github.com/astral-sh/uv) - Install with: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- A shell (Zsh, Bash, or Fish)
- Python projects with `pyproject.toml`
