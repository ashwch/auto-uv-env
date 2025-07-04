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
- ⚡ **Performance optimized** - Minimal overhead: 8.6ms on shell startup, 1.3ms per directory change
- 🧹 **Smart deactivation** - Only deactivates environments it activated
- 🛡️ **Security focused** - Path validation and injection protection
- 📍 **Project-aware** - Stays active in project subdirectories
- 🔒 **Respects manual venvs** - Won't interfere with manually activated environments

## Installation

### Quick Install (Recommended)

```bash
# Install auto-uv-env
curl -LsSf https://auto-uv-env.ashwch.com/install.sh | sh
```

### Using Homebrew (macOS preferred)

```bash
brew tap ashwch/tap
brew install auto-uv-env
```

### Alternative Installation Methods

#### Install from GitHub

```bash
# Using the installer from GitHub
curl -LsSf https://raw.githubusercontent.com/ashwch/auto-uv-env/main/docs/install.sh | sh
```

#### Manual Installation

```bash
# Clone and install manually
git clone https://github.com/ashwch/auto-uv-env.git
cd auto-uv-env
sudo cp auto-uv-env /usr/local/bin/
sudo mkdir -p /usr/local/share/auto-uv-env
sudo cp share/auto-uv-env/* /usr/local/share/auto-uv-env/
```

### Uninstallation

```bash
# If installed with the installer script
curl -LsSf https://auto-uv-env.ashwch.com/uninstall.sh | sh

# If installed with Homebrew
brew uninstall auto-uv-env
```

## Setup

Add to your shell configuration:

### Zsh (~/.zshrc)
```zsh
# For Homebrew
source $(brew --prefix)/share/auto-uv-env/auto-uv-env.zsh

# For Linux/manual installation
source /usr/local/share/auto-uv-env/auto-uv-env.zsh
# Or if installed via package
source /usr/share/auto-uv-env/auto-uv-env.zsh
```

### Bash (~/.bashrc)
```bash
# For Homebrew
source $(brew --prefix)/share/auto-uv-env/auto-uv-env.bash

# For Linux/manual installation
source /usr/local/share/auto-uv-env/auto-uv-env.bash
# Or if installed via package
source /usr/share/auto-uv-env/auto-uv-env.bash
```

### Fish (~/.config/fish/config.fish)
```fish
# For Homebrew
source (brew --prefix)/share/auto-uv-env/auto-uv-env.fish

# For Linux/manual installation
source /usr/local/share/auto-uv-env/auto-uv-env.fish
# Or if installed via package
source /usr/share/auto-uv-env/auto-uv-env.fish
```

## Usage

Just `cd` into any Python project with a `pyproject.toml`:

```bash
cd my-python-project/
# 🐍 Setting up Python 3.11 with UV...
# ✅ Virtual environment created
# 🚀 UV environment activated (Python 3.11.5)

# Your prompt might look like this (if configured to show Python version):
# (3.11.5) my-python-project $ 

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
- `AUTO_UV_ENV_PYTHON_VERSION` - Contains the Python version of the currently activated virtual environment. Useful for prompt customization.

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

auto-uv-env is designed with performance in mind. Based on real-world measurements:

### Shell Startup Overhead
- **Normal mode**: 8.6ms added to shell startup
- **Quiet mode**: 1.6ms added to shell startup (81% faster)

### Directory Change Overhead (`cd` command)
- **Normal mode**: 1.3ms per directory change
- **Quiet mode**: 0.4ms per directory change

### First-time Environment Creation
- **Initial setup**: 1-5 seconds (UV creates the virtual environment)
- **Subsequent activations**: Near-instant (uses cached environment)

### Performance Tips
For best performance, enable quiet mode:
```bash
export AUTO_UV_ENV_QUIET=1
```
This skips the Python version display, reducing overhead by ~80%.

## Integration with Other Tools

### Disabling in Specific Directories

If you need to disable auto-uv-env in specific directories (e.g., when using direnv), create a `.auto-uv-env-ignore` file:

```bash
# Disable auto-uv-env in this directory
touch .auto-uv-env-ignore
```

## Comparison

| Feature | auto-uv-env | direnv | pyenv-virtualenv |
|---------|------------|---------|------------------|
| Automatic activation | ✅ | ✅ | ✅ |
| UV integration | ✅ | ❌ | ❌ |
| Zero config | ✅ | ❌ | ❌ |
| Speed | ⚡ Fast | 🐢 Slower | 🐢 Slower |
| Python-specific | ✅ | ❌ | ✅ |

## Contributing

Contributions are welcome! Please follow these steps to contribute:

### Prerequisites

- [UV](https://github.com/astral-sh/uv) - Install with: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Git
- A shell (Zsh, Bash, or Fish)

### Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/ashwch/auto-uv-env.git
   cd auto-uv-env
   ```

2. **Install development dependencies**
   ```bash
   uv tool install pre-commit
   ```

3. **Set up pre-commit hooks**
   ```bash
   uv tool run pre-commit install
   ```

### Development Workflow

1. **Make your changes** to the relevant files:
   - `auto-uv-env` - Main bash script
   - `share/auto-uv-env/` - Shell integration files
   - `test/` - Test files

2. **Run tests**
   ```bash
   ./test/test.sh
   ```

3. **Check code quality** (runs automatically via pre-commit)
   ```bash
   uv tool run pre-commit run --all-files
   ```

4. **Test manually**
   ```bash
   # Make script executable
   chmod +x auto-uv-env
   
   # Test commands
   ./auto-uv-env --help
   ./auto-uv-env --version
   ./auto-uv-env --check
   
   # Test in a Python project
   cd /path/to/python/project
   ./auto-uv-env --check
   ```

### Pre-commit Hooks

The project uses comprehensive pre-commit hooks that automatically run:

- **Code Quality**: shellcheck for shell script linting
- **Security**: detect-secrets for credential scanning
- **Formatting**: beautysh for shell script formatting
- **Testing**: Run the test suite before push
- **Validation**: Syntax checks for all shell integrations
- **Project Checks**: Version consistency, TODO detection

### Testing

Run the test suite to ensure everything works:

```bash
./test/test.sh
```

For security testing:
```bash
./test/test-security.sh
```

### Homebrew Formula Testing

If modifying the Homebrew formula:

```bash
# Test locally
brew tap-new local/test
cp homebrew/auto-uv-env.rb $(brew --repository)/Library/Taps/local/homebrew-test/Formula/
brew install --build-from-source local/test/auto-uv-env
brew test local/test/auto-uv-env
```

### Code Style

- Use 4-space indentation for shell scripts
- Follow existing patterns and conventions
- Add comments for complex logic
- Ensure all scripts have proper shebangs
- Use shellcheck-compliant code

### Pull Request Guidelines

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the development workflow
4. Ensure all tests pass and pre-commit hooks succeed
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Issue Reporting

When reporting issues, please include:
- Operating system and shell type
- UV version (`uv --version`)
- auto-uv-env version (`auto-uv-env --version`)
- Steps to reproduce
- Expected vs actual behavior
- Relevant log output

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

Created by [Ashwini Chaudhary](https://github.com/ashwch)

## Acknowledgments

- [UV](https://github.com/astral-sh/uv) - The blazing-fast Python package manager
- Inspired by similar tools like direnv and pyenv-virtualenv