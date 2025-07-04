---
layout: page
title: Usage
permalink: /usage/
---

# Usage Guide

## Basic Usage

Once installed and configured, auto-uv-env works automatically:

```bash
# Navigate to a Python project
cd my-python-project/

# auto-uv-env automatically:
# 1. Detects pyproject.toml
# 2. Reads required Python version
# 3. Creates virtual environment if needed
# 4. Activates the environment

# You'll see:
# 🐍 Setting up Python 3.11 with UV...
# ✅ Virtual environment created
# 🚀 UV environment activated (Python 3.11.5)

# Your shell prompt may show the active Python version
(3.11.5) my-python-project $ 

# Leave the directory
cd ..
# ⬇️  Deactivated UV environment
```

## Configuration Options

### Environment Variables

Control auto-uv-env behavior with these environment variables:

```bash
# Suppress all status messages
export AUTO_UV_ENV_QUIET=1

# Use custom virtual environment name (default: .venv)
export AUTO_UV_ENV_VENV_NAME=.virtualenv

# Access current Python version in your prompt
# This is automatically set when an environment is active
echo $AUTO_UV_ENV_PYTHON_VERSION  # e.g., "3.11.5"
```

### Per-Project Configuration

#### pyproject.toml Example

```toml
[project]
name = "my-awesome-project"
version = "0.1.0"
requires-python = ">=3.11,<3.13"  # auto-uv-env uses this

[project.dependencies]
django = "^4.2"
requests = "^2.31"
```

#### Disabling for Specific Directories

Create a `.auto-uv-env-ignore` file to disable auto-uv-env:

```bash
# Disable in current directory
touch .auto-uv-env-ignore

# Useful when using other tools like direnv
echo "Using direnv for this project" > .auto-uv-env-ignore
```

### Working with Existing Virtual Environments

auto-uv-env respects existing virtual environments:

1. **Manual venvs are protected**: If you manually activate a venv, auto-uv-env won't deactivate it
2. **Existing .venv is reused**: If `.venv` already exists, auto-uv-env will use it
3. **State tracking**: Only deactivates environments it activated

## Command Line Interface

### Available Commands

```bash
# Show version
auto-uv-env --version
# Output: auto-uv-env 1.0.4

# Show help
auto-uv-env --help

# Check if environment should be activated (safe mode)
auto-uv-env --check-safe
# Output: {"activate": true, "venv": ".venv", "python": "3.11"}

# Show diagnostic information
auto-uv-env --diagnose
# Shows: UV version, Python detection, shell info

# Validate configuration
auto-uv-env --validate
# Checks all components are working correctly
```

## Advanced Usage

### Custom Shell Prompts

#### Zsh with Python Version

```zsh
# Add to ~/.zshrc
PROMPT='${AUTO_UV_ENV_PYTHON_VERSION:+(🐍 $AUTO_UV_ENV_PYTHON_VERSION) }%~ %# '
```

#### Bash with Python Version

```bash
# Add to ~/.bashrc
PS1='${AUTO_UV_ENV_PYTHON_VERSION:+(🐍 $AUTO_UV_ENV_PYTHON_VERSION) }\w $ '
```

#### Fish with Python Version

```fish
# Add to ~/.config/fish/config.fish
function fish_prompt
    if set -q AUTO_UV_ENV_PYTHON_VERSION
        echo -n "(🐍 $AUTO_UV_ENV_PYTHON_VERSION) "
    end
    echo -n (prompt_pwd) ' $ '
end
```

### Integration with Other Tools

#### VS Code

VS Code will automatically detect the `.venv` created by auto-uv-env. No additional configuration needed!

#### PyCharm

Point PyCharm to use `.venv/bin/python` as the project interpreter.

#### Jupyter

```bash
# Install ipykernel in your environment
pip install ipykernel

# Register the kernel
python -m ipykernel install --user --name=myproject
```

## Troubleshooting

### Environment Not Activating

1. **Check for pyproject.toml**:
   ```bash
   ls pyproject.toml
   ```

2. **Verify UV is installed**:
   ```bash
   which uv
   ```

3. **Run diagnostics**:
   ```bash
   auto-uv-env --diagnose
   ```

### Wrong Python Version

1. **Check pyproject.toml**:
   ```bash
   grep requires-python pyproject.toml
   ```

2. **Verify UV has the Python version**:
   ```bash
   uv python list
   ```

3. **Install missing Python version**:
   ```bash
   uv python install 3.11
   ```

### Performance Issues

auto-uv-env v1.0.7 includes major performance optimizations:
- **Shell startup overhead**: 2-3ms (Python projects), 0ms (non-Python directories)
- **Directory change overhead**: <1ms per `cd` command
- **First-time environment creation**: 1-5 seconds (UV creates the virtual environment)
- **Subsequent activations**: Near-instant (uses cached environment)

Key optimizations in v1.0.7:
- Lazy loading (no execution for non-Python directories)
- Command path caching
- Native bash TOML parsing (no Python subprocess)
- Shell built-ins instead of external commands

If experiencing slow directory changes:

1. **Verify you have the latest version**:
   ```bash
   auto-uv-env --version  # Should be 1.0.7 or later
   ```

2. **Check for shell conflicts**:
   ```bash
   # Temporarily disable other shell plugins
   # Check if performance improves
   ```

3. **Use quiet mode** for best performance:
   ```bash
   export AUTO_UV_ENV_QUIET=1
   ```

4. **Report persistent issues**:
   ```bash
   auto-uv-env --diagnose > diagnostic.txt
   # Share at: https://github.com/ashwch/auto-uv-env/issues
   ```

## Best Practices

1. **Always use pyproject.toml** - It's the modern Python standard
2. **Specify Python version** - Use `requires-python` for consistency
3. **Commit .gitignore** - Add `.venv/` to your `.gitignore`
4. **Use UV for packages** - `uv pip install` instead of `pip install`
5. **Don't mix activation methods** - Let auto-uv-env handle activation
6. **Use .auto-uv-env-ignore** - When using other virtual environment tools

## Examples

### Django Project

```toml
[project]
name = "my-django-app"
requires-python = ">=3.11"

[project.dependencies]
django = ">=4.2"
psycopg2-binary = ">=2.9"
python-decouple = ">=3.8"
```

### Data Science Project

```toml
[project]
name = "data-analysis"
requires-python = ">=3.10,<3.12"

[project.dependencies]
pandas = ">=2.0"
numpy = ">=1.24"
matplotlib = ">=3.7"
jupyter = ">=1.0"
```

### FastAPI Project

```toml
[project]
name = "api-service"
requires-python = ">=3.11"

[project.dependencies]
fastapi = ">=0.104"
uvicorn = {extras = ["standard"], version = ">=0.24"}
pydantic = ">=2.4"
```