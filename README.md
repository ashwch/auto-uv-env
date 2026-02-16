# auto-uv-env 🐍

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![UV](https://img.shields.io/badge/UV-Required-blue.svg)](https://github.com/astral-sh/uv)

Automatic UV-based Python virtual environment management for your shell.

`auto-uv-env` watches directory changes, discovers the nearest `pyproject.toml`, creates a project-local virtual environment with `uv`, and activates/deactivates it automatically.

## Architecture Overview

```text
+-------------------------+      --check-safe       +--------------------------+
| shell hook              |------------------------>| auto-uv-env             |
| bash/zsh/fish adapter   |<------------------------| directive producer       |
+------------+------------+      KEY=VALUE lines    +------------+-------------+
             |                                                   |
             | applies directives                               | reads pyproject.toml
             v                                                   | validates venv name
      +------+--------------------------+                        |
      | source/deactivate virtualenv    |                        |
      | uv python install / uv venv     |<-----------------------+
      +---------------------------------+
```

## Quick Start

### 1) Install UV

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2) Install auto-uv-env

Installer script:

```bash
curl -LsSf https://auto-uv-env.ashwch.com/install.sh | sh
```

Homebrew:

```bash
brew tap ashwch/tap
brew install auto-uv-env
```

### 3) Add shell integration

Zsh (`~/.zshrc`):

```zsh
source $(brew --prefix)/share/auto-uv-env/auto-uv-env.zsh
# or: source /usr/local/share/auto-uv-env/auto-uv-env.zsh
```

Bash (`~/.bashrc`):

```bash
source $(brew --prefix)/share/auto-uv-env/auto-uv-env.bash
# or: source /usr/local/share/auto-uv-env/auto-uv-env.bash
```

Fish (`~/.config/fish/config.fish`):

```fish
source (brew --prefix)/share/auto-uv-env/auto-uv-env.fish
# or: source /usr/local/share/auto-uv-env/auto-uv-env.fish
```

### 4) Use it

```bash
cd my-project/src/app
# 🐍 Setting up Python 3.11 with UV...
# ✅ Virtual environment created
# 🚀 UV environment activated (Python 3.11.x)

cd ..
# ⬇️  Deactivated UV environment
```

## Core Behavior

1. Walk upward from `$PWD` to find the nearest `pyproject.toml`.
2. If `.auto-uv-env-ignore` appears first, skip activation for that subtree.
3. Read `requires-python` from the discovered project root.
4. Create `<project-root>/.venv` when missing.
5. Activate on entry and deactivate only environments managed by auto-uv-env.
6. If a manual venv is active, auto-uv-env does not override it.

## Configuration

Environment variables:

- `AUTO_UV_ENV_QUIET=1`: suppress status messages.
- `AUTO_UV_ENV_VENV_NAME=.venv`: change the venv directory name.
- `AUTO_UV_ENV_PYTHON_VERSION`: exported Python version of the active managed env.

`pyproject.toml` example:

```toml
[project]
name = "my-project"
requires-python = ">=3.11"
```

Disable in a subtree:

```bash
touch .auto-uv-env-ignore
```

Ignore precedence:

- Upward discovery stops activation when ignore is found before `pyproject.toml`.
- Entering an ignored subtree deactivates the currently managed environment.

## CLI Reference

```bash
auto-uv-env --help
auto-uv-env --version
auto-uv-env --check-safe [DIR]
auto-uv-env --diagnose [DIR]
auto-uv-env --validate
```

`--check-safe` emits directive lines (for shell adapters), for example:

```text
CREATE_VENV=1
PYTHON_VERSION=3.11
MSG_SETUP=🐍 Setting up Python 3.11 with UV...
ACTIVATE=/path/to/project/.venv
```

## Performance

- v1.0.7 delivered roughly 93% startup overhead improvement versus earlier behavior.
- Typical startup overhead is low in Python projects and effectively near-zero in non-project directories.
- Directory-change overhead is typically sub-millisecond.

## Choosing This Tool

`auto-uv-env` is a strong fit when you want:

- UV-first Python environment automation (no extra orchestration layer)
- `pyproject.toml`-driven project discovery
- Automatic activate/deactivate across Bash, Zsh, and Fish
- Project-local `.venv` behavior with minimal setup

If you are deciding between this and `direnv`, `mise`, `pyenv-virtualenv`, or shell-specific plugins, see the decision guide:
[`docs/alternatives.md`](docs/alternatives.md).

## Documentation Map

- Installation details: [`docs/installation.md`](docs/installation.md)
- Usage and troubleshooting: [`docs/usage.md`](docs/usage.md)
- Contributing guide: [`docs/contributing.md`](docs/contributing.md)
- Alternatives decision guide: [`docs/alternatives.md`](docs/alternatives.md)
- Contributor quick entrypoint: [`CONTRIBUTE.md`](CONTRIBUTE.md)
- Release runbook: [`RELEASE.md`](RELEASE.md)

## For Contributors

Essential checks:

```bash
./test/test.sh
./test/test-security.sh
./test/test-shell-integrations.sh
./test/test-deleted-venv.sh
uv tool run pre-commit run --all-files
```

If your shell currently has an active venv, use a sanitized test invocation:

```bash
env -u VIRTUAL_ENV -u _AUTO_UV_ENV_ACTIVATION_DIR -u AUTO_UV_ENV_PYTHON_VERSION ./test/test.sh
```

Release reminder: merging a PR does not create a GitHub release. Releases are published on `v*` tag pushes; follow [`RELEASE.md`](RELEASE.md).
Docs publishing reminder: `https://auto-uv-env.ashwch.com/` is deployed by `docs.yml` on pushes to `main`.

## LLM Agent Docs

- [`AGENTS.md`](AGENTS.md): canonical architecture, workflows, quality gates, and safety rules.
- [`CLAUDE.md`](CLAUDE.md): minimal Claude entrypoint that sources `AGENTS.md`.

## License

MIT License. See [`LICENSE`](LICENSE).

## Author

Created by [Ashwini Chaudhary](https://github.com/ashwch).
