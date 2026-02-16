# Changelog

All notable changes to auto-uv-env will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.3] - 2026-02-16

### Added
-

### Changed
-

### Fixed
-


## [1.1.2] - 2026-02-16

### Added
-

### Changed
-

### Fixed
-


## [1.1.1] - 2025-07-05

### Fixed
- Ensure virtual environments are properly activated after recreation
- Fix issue where `uv sync` would fail after `rm -rf .venv` due to inactive environment
- Improve user experience when virtual environments are manually deleted

### Changed  
- Enhanced activation logic in all shell integrations (bash, zsh, fish)
- Better handling of environment state after recreation

## [1.1.0] - 2025-07-05

### Added
- Handle deleted virtual environments gracefully
- Detect when .venv directory is manually deleted while environment variables remain set
- Show warning message: "⚠️ Virtual environment was deleted, cleaning up..."
- Automatically clean up stale environment variables and recreate the environment
- Comprehensive test suite for deleted virtual environment scenarios

### Changed
- Enhanced virtual environment state validation across all shell integrations (bash, zsh, fish)
- Improved reliability when virtual environments are removed outside of auto-uv-env

## [1.0.8] - 2025-07-04

### Fixed
- Fixed "command not found: python" error when activating UV virtual environments without Python installed
- Improved messaging when Python is missing in virtual environments

### Changed
- When Python is not available in a UV virtual environment, now shows clear message: "UV environment activated (Python not installed)"
- Added helpful guidance: "Run 'uv python install' to install Python"
- Enhanced user experience with informative error messages instead of cryptic command failures


## [1.0.7] - 2025-07-04

### Changed
- **Major performance optimizations**: Zero overhead for non-Python directories
- Implemented lazy loading - shell functions only execute when in Python projects
- Replaced external commands (`cut`) with shell built-ins (parameter expansion)
- Added command path caching to eliminate repeated lookups
- Optimized TOML parsing with native bash regex (no Python subprocess)
- Combined file checks into single operations for efficiency

### Performance Improvements
- Shell startup (non-Python dirs): **0ms** (was 8.6ms) - 100% improvement
- Shell startup (Python project): **5-6ms** (was 8.6ms) - 42% improvement  
- Directory change overhead: **<1ms** (was 1.3ms) - 23% improvement
- Script execution: **5-6ms** (was 16.5ms) - 67% improvement

### Technical Details
- UV and Python paths now cached at script start
- TOML parsing uses pure bash for 99% of cases
- Debug mode checks moved behind DEBUG_MODE flag
- Batch file existence checks reduce syscalls

## [1.0.6] - 2025-07-04

### Changed
- Major performance optimization: shell startup overhead reduced from ~128ms to ~8.6ms (93% improvement)
- Added fast-path optimizations for common scenarios (staying in same project, existing venv)
- Skip Python version check in quiet mode (saves ~6ms per activation)

### Fixed
- Performance bottleneck from calling auto-uv-env script on every directory change
- Removed obsolete package.yml workflow that was using deprecated GitHub Actions

### Performance Improvements
- Shell startup overhead: 8.6ms (normal mode), 1.6ms (quiet mode)
- Per directory change: ~1.3ms (normal mode), ~0.4ms (quiet mode)
- Direct venv activation bypasses script call entirely when possible


## [1.0.5] - 2025-07-03

### Added
- Universal installer script based on UV's elegant approach (`curl -LsSf https://auto-uv-env.ashwch.com/install.sh | sh`)
- Uninstaller script with automatic shell integration cleanup  
- `-y`/`--yes` flag for non-interactive installations in CI/automation
- GitHub Pages documentation site at https://auto-uv-env.ashwch.com

### Fixed
- Shell startup performance issue (149ms delay) with fast-path optimization for non-Python directories
- Broken pipe error when running `--version` command
- Syntax error in auto-uv-env.bash preventing proper functionality
- Various shellcheck warnings in shell integration files


## [1.0.4] - 2025-07-03

### Fixed
- Correctly set and unset AUTO_UV_ENV_PYTHON_VERSION in Bash, Zsh, and Fish shell integrations.


## [1.0.3] - 2025-07-03

### Fixed
- **CRITICAL**: Fixed print_debug function causing script to exit silently with set -e
- This was the final bug preventing auto-uv-env from working in normal (non-debug) mode
- Fixed invalid version format test to reflect correct behavior


## [1.0.2] - 2025-07-03

### Fixed
- **CRITICAL**: Fixed shell integration redirection bug that prevented auto-uv-env from working
- **CRITICAL**: Fixed venv name validation regex that incorrectly rejected `.venv`
- Removed redundant homebrew folder (formula moved to separate homebrew-tap repository)

### Added
- End-to-end shell integration tests to prevent regression


## [1.0.1] - 2025-07-03

### Added
-

### Changed
-

### Fixed
- Fixed test_invalid_version_format to expect silent rejection (secure-by-default behavior)
- Fixed ruff target-version configuration to remain py39 instead of being updated during version bumps


## [1.0.0] - 2024-12-31

### Added
- Initial release
- Automatic Python virtual environment activation/deactivation
- UV integration for fast environment creation
- Support for Zsh, Bash, and Fish shells
- Python version detection from `pyproject.toml`
- Quiet mode via `AUTO_UV_ENV_QUIET` environment variable
- Custom venv directory name via `AUTO_UV_ENV_VENV_NAME`
- Comprehensive documentation and examples

[1.0.0]: https://github.com/ashwch/auto-uv-env/releases/tag/v1.0.0