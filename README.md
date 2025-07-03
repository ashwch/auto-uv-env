# auto-uv-env 🐍

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![UV](https://img.shields.io/badge/UV-Required-blue.svg)](https://github.com/astral-sh/uv)

Automatic UV-based Python virtual environment management for your shell. No more manual `source .venv/bin/activate`!

## Features

- 🚀 **Automatic activation** - Activates Python virtual environments when you `cd` into a project
- 🐍 **UV-powered** - Uses [UV](https://github.com/astral-sh/uv) for lightning-fast environment creation
- 📦 **pyproject.toml aware** - Reads Python version from `requires-python`
- 🎯 **Zero configuration** - Works out of the box
- 🐚 **Multi-shell support** - Works with Zsh, Bash, and Fish
- ⚡ **Fast** - Adds <5ms to directory changes
- 🧹 **Clean** - Automatically deactivates when leaving Python projects

## Installation

### Using Homebrew (recommended)

```bash
brew tap ashwch/tap
brew install auto-uv-env
```

### Manual Installation

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

## Setup

Add to your shell configuration:

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

## Usage

Just `cd` into any Python project with a `pyproject.toml`:

```bash
cd my-python-project/
# 🐍 Setting up Python 3.11 with UV...
# ✅ Virtual environment created
# 🚀 UV environment activated (Python 3.11.5)

cd ..
# ⬇️  Deactivated UV environment
```

That's it! The virtual environment is automatically:
- Created if it doesn't exist (using Python version from `requires-python`)
- Activated when you enter the directory
- Deactivated when you leave

## Configuration

### Environment Variables

- `AUTO_UV_ENV_QUIET=1` - Suppress all status messages
- `AUTO_UV_ENV_VENV_NAME=.venv` - Custom virtual environment directory name (default: `.venv`)

### Example pyproject.toml

```toml
[project]
name = "my-project"
requires-python = ">=3.11"
```

auto-uv-env will automatically use Python 3.11 for this project.

## Requirements

- [UV](https://github.com/astral-sh/uv) - Install with: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- A shell (Zsh, Bash, or Fish)
- Python projects with `pyproject.toml`

## How It Works

1. When you `cd` into a directory, auto-uv-env checks for `pyproject.toml`
2. If found, it reads the `requires-python` field
3. Uses UV to create a virtual environment with the correct Python version
4. Activates the environment automatically
5. When you leave the directory, it deactivates the environment

## Performance

auto-uv-env is designed to be fast:
- **Non-Python directories**: ~0ms (immediate return)
- **Python projects**: <5ms for activation check
- **First-time setup**: 1-5 seconds (UV creates the environment)

## Comparison

| Feature | auto-uv-env | direnv | pyenv-virtualenv |
|---------|------------|---------|------------------|
| Automatic activation | ✅ | ✅ | ✅ |
| UV integration | ✅ | ❌ | ❌ |
| Zero config | ✅ | ❌ | ❌ |
| Speed | ⚡ Fast | 🐢 Slower | 🐢 Slower |
| Python-specific | ✅ | ❌ | ✅ |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

Created by [Ashwini Chaudhary](https://github.com/ashwch)

## Acknowledgments

- [UV](https://github.com/astral-sh/uv) - The blazing-fast Python package manager
- Inspired by similar tools like direnv and pyenv-virtualenv