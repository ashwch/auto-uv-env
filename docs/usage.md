---
layout: page
title: Usage
permalink: /usage/
---

# Usage

## Basic Usage

Just `cd` into any Python project with a `pyproject.toml`:

```bash
cd my-python-project/
# 🐍 Setting up Python 3.11 with UV...
# ✅ Virtual environment created
# 🚀 UV environment activated (Python 3.11.5)

cd ..
# ⬇️  Deactivated UV environment
```

## Configuration

### Environment Variables

- `AUTO_UV_ENV_QUIET=1` - Suppress all status messages
- `AUTO_UV_ENV_VENV_NAME=.venv` - Custom virtual environment directory name
- `AUTO_UV_ENV_PYTHON_VERSION` - Contains Python version of active environment

### Example pyproject.toml

```toml
[project]
name = "my-project"
requires-python = ">=3.11"
```

## Command Line Options

- `--version` - Show version information
- `--help` - Show help message
- `--check-safe` - Check if environment should be activated (safe mode)
- `--diagnose` - Show diagnostic information
- `--validate` - Validate configuration

## Performance

- **Non-Python directories**: ~0ms
- **Python projects**: <5ms for activation check
- **First-time setup**: 1-5 seconds (UV creates environment)