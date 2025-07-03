# Changelog

All notable changes to auto-uv-env will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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