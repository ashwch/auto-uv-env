# AGENTS.md - The auto-uv-env Story

*A guide for AI agents and humans working on this repository. It explains what the project is, how it works, where to change code safely, and how to validate changes.*

---

## What This Repo Is

**auto-uv-env** is a shell integration tool that automatically creates, activates, and deactivates Python virtual environments using `uv` when users move between directories.

It is a small system with a strict contract:

1. `auto-uv-env` (the main executable) decides *what should happen* and emits directives.
2. Shell adapters (`bash`, `zsh`, `fish`) decide *how to apply* those directives in the current shell process.

This split keeps shell state mutation out of the main executable and reduces command injection risk.

```
+--------------------------------------------------------------------------------+
|                                auto-uv-env repo                                |
+--------------------------------------------------------------------------------+
|                                                                                |
|  +----------------------+      directives       +---------------------------+  |
|  | auto-uv-env          |---------------------->| shell adapter             |  |
|  | (policy + detection) |                       | (bash/zsh/fish runtime)   |  |
|  +----------------------+                       +-------------+-------------+  |
|                                                           |                    |
|                                                           | source activate    |
|                                                           v                    |
|                                                   +---------------+            |
|                                                   | .venv         |            |
|                                                   | (uv-managed)  |            |
|                                                   +-------+-------+            |
|                                                           |                    |
|                                                           v                    |
|                                                   +---------------+            |
|                                                   | uv + python   |            |
|                                                   +---------------+            |
|                                                                                |
+--------------------------------------------------------------------------------+
```

---

## Architecture Diagrams

### Runtime Activation Flow

```
+-------------------+       +----------------------+       +----------------------+
| shell hook        |------>| auto-uv-env          |------>| directives           |
| (PWD changed)     |       | --check-safe <dir>   |       | CREATE_VENV=1        |
+---------+---------+       +----------+-----------+       | PYTHON_VERSION=3.11  |
          |                            |                   | ACTIVATE=/path/.venv |
          |                            |                   | DEACTIVATE=1         |
          |                            v                   +----------+-----------+
          |                  reads pyproject.toml                     |
          |                  validates venv name                      |
          |                  checks ignore file                       |
          |                                                           v
          |                                            +---------------------------+
          +------------------------------------------->| shell adapter applies     |
                                                       | uv python install         |
                                                       | uv venv                   |
                                                       | source activate           |
                                                       | deactivate                |
                                                       +---------------------------+
```

### Repository Lifecycle

```
+-------------------+    +-------------------+    +------------------------------+
| local change      |--->| test + lint       |--->| release automation           |
| auto-uv-env/*     |    | test/*.sh         |    | scripts/release.sh           |
| share/*           |    | pre-commit        |    | github tag workflow          |
+-------------------+    +-------------------+    +------------------------------+
         |                          |                               |
         |                          |                               |
         v                          v                               v
+-------------------+    +-------------------+    +------------------------------+
| docs source       |    | CI workflows      |    | distribution channels        |
| README.md         |    | .github/workflows |    | GitHub Releases              |
| docs/* (Jekyll)   |    | lint/test/security|    | Homebrew tap                 |
| AGENTS.md         |    | perf/docs pages   |    | install.sh / uninstall.sh    |
+-------------------+    +-------------------+    +------------------------------+
```

---

## Folder Structure

```text
auto-uv-env/
|
+-- auto-uv-env                         # Main executable (directive producer)
+-- share/auto-uv-env/
|   +-- auto-uv-env.bash               # Bash runtime adapter
|   +-- auto-uv-env.zsh                # Zsh runtime adapter
|   +-- auto-uv-env.fish               # Fish runtime adapter
|
+-- test/
|   +-- test.sh                        # Core CLI behavior tests
|   +-- test-shell-integrations.sh     # Adapter-level tests
|   +-- test-security.sh               # Security-focused tests
|   +-- test-deleted-venv.sh           # Deleted venv behavior regression test
|
+-- scripts/
|   +-- release.sh                     # Release orchestration
|   +-- bump-version.sh                # Semver bump helper
|   +-- check-version-consistency.sh   # Version consistency helper
|
+-- docs/                              # Jekyll docs site + installer scripts
|   +-- install.sh
|   +-- uninstall.sh
|   +-- installation.md
|   +-- usage.md
|
+-- .github/workflows/                 # CI/release/docs automation
+-- pyproject.toml                     # Package metadata + dev tooling config
+-- README.md                          # Human-facing project overview
+-- CLAUDE.md                          # Minimal source of truth pointer for Claude
+-- AGENTS.md                          # Canonical agent operating guide
```

---

## Technologies

| Category | Technology | Purpose |
|----------|------------|---------|
| Language | Bash / Zsh / Fish / POSIX shell | Core implementation and shell runtime integration |
| Python tooling | UV | Python installation and virtual environment creation |
| Packaging | `pyproject.toml` + Hatchling | Project metadata and package build backend |
| Docs site | Jekyll | Public documentation site generation |
| CI/CD | GitHub Actions | Linting, tests, docs deploy, releases |
| Security checks | Semgrep + detect-secrets | Static and secret scanning |

---

## Core Contracts

### Directive Contract (`auto-uv-env --check-safe`)

The main executable emits line-based `KEY=VALUE` directives:

- `CREATE_VENV=1`
- `PYTHON_VERSION=<x.y[.z]>`
- `MSG_SETUP=<text>`
- `ACTIVATE=<absolute path>`
- `DEACTIVATE=1`

Shell adapters must remain compatible with this exact format.

### State Tracking Contract

Adapters track `_AUTO_UV_ENV_ACTIVATION_DIR` to avoid deactivating unrelated/manual environments and to know when users leave a project tree.

### Project Discovery Contract

- Project detection walks upward from `$PWD` to find the nearest `pyproject.toml`.
- If `.auto-uv-env-ignore` is encountered before any `pyproject.toml`, activation is skipped for that subtree.
- Entering an ignored subtree deactivates any currently auto-uv-env-managed environment.
- Venv creation and activation target the discovered project root, not necessarily the current directory.

### Safety Contract

- Venv directory name is validated and path traversal is blocked.
- Shell state mutation stays in shell adapters, not in the main script.
- `--check` is deprecated; use `--check-safe`.

---

## Quality Gates

### Pre-commit

Configured in `.pre-commit-config.yaml`:

- `pre-commit-hooks`: whitespace, YAML/TOML/JSON checks, merge conflict checks, executable/shebang checks.
- `shellcheck`: strict shell linting (external sources enabled, SC1091 ignored for sourced files).
- `detect-secrets`: scans against `.secrets.baseline`.
- Local hooks:
  - run tests (`./test/test.sh`) on pre-push
  - reject `TODO|FIXME|HACK` in main script
  - validate shell integration syntax
  - grep for dangerous `eval` patterns
  - check version consistency

### CI Workflows

- `ci.yml`: lint, security scan, tests, Homebrew audit, release checks, perf checks.
- `docs.yml`: builds/deploys Jekyll docs to Pages.
- `release.yml`: creates release artifacts from version tags.
- `test-installer.yml`: validates install/uninstall behavior across platforms.

---

## Do

- Keep behavior consistent across all three shell adapters when changing activation logic.
- Preserve the directive protocol between `auto-uv-env` and shell adapters.
- Run tests in a clean environment when validating behavior.
- Update docs when command interfaces or output formats change.
- Keep version fields synchronized across `auto-uv-env`, `pyproject.toml`, and `CHANGELOG.md`.

## Don't

- Don't reintroduce `eval`-driven execution of untrusted content.
- Don't change directive keys without updating all adapters and tests.
- Don't use deprecated `--check` in docs/examples/scripts.
- Don't assume tests are environment-isolated unless they explicitly sanitize `VIRTUAL_ENV`.
- Don't edit release automation without checking Homebrew/tap assumptions.

---

## Common Commands

```bash
# Core checks
./auto-uv-env --help
./auto-uv-env --version
./auto-uv-env --diagnose
./auto-uv-env --validate

# Test suites
./test/test.sh
./test/test-security.sh
./test/test-shell-integrations.sh
./test/test-deleted-venv.sh

# Safer test execution when current shell has active venv state
env -u VIRTUAL_ENV -u _AUTO_UV_ENV_ACTIVATION_DIR -u AUTO_UV_ENV_PYTHON_VERSION ./test/test.sh
env -u VIRTUAL_ENV -u _AUTO_UV_ENV_ACTIVATION_DIR -u AUTO_UV_ENV_PYTHON_VERSION ./test/test-shell-integrations.sh

# Lint/quality
uv tool run pre-commit run --all-files

# Docs
./docs/serve-local.sh

# Release helpers
./scripts/check-version-consistency.sh
./scripts/bump-version.sh patch --dry-run
```

---

## Known Quirks and Guardrails

1. `set -e` with `((COUNT++))` can exit on first increment.
This previously affected `test/test-deleted-venv.sh` and was fixed by using pre-increment (`((++COUNT))`).

2. Tests can leak behavior when run from a shell with an active virtual environment.
Core test suites now sanitize environment variables internally; for ad-hoc runs, this wrapper remains safe:
`env -u VIRTUAL_ENV -u _AUTO_UV_ENV_ACTIVATION_DIR -u AUTO_UV_ENV_PYTHON_VERSION <test-command>`.

3. Performance baseline to preserve: v1.0.7 achieved ~93% startup overhead improvement.
Non-project directories should remain effectively near-zero overhead via lazy loading and cached command paths.

---

## The Hard Lessons

### Lesson 1: Adapter and core must evolve together

**What happened:** behavior changes were added in adapters without complete contract-level test updates.

**Cause:** adapter logic duplicated across three shells; drift is easy.

**Fix:** treat directive keys and adapter parsing as an API, and update all adapters/tests in one change.

### Lesson 2: Shell environment leakage causes false failures

**What happened:** tests failed when run from shells with active `VIRTUAL_ENV`.

**Cause:** tests assumed clean process environment.

**Fix:** run critical suites with `env -u VIRTUAL_ENV ...` when debugging or in local validation scripts.

### Lesson 3: Shell arithmetic with `set -e` can abort tests unexpectedly

**What happened:** `test/test-deleted-venv.sh` can exit early.

**Cause:** `((TEST_COUNT++))` returns status `1` on first increment under `set -e`.

**Fix:** use `((++TEST_COUNT))` or `TEST_COUNT=$((TEST_COUNT + 1))`.

### Lesson 4: Docs drift from CLI output format breaks contributors

**What happened:** docs described JSON output for `--check-safe`, but implementation emits `KEY=VALUE`.

**Cause:** docs were not updated with contract changes.

**Fix:** update README/docs whenever CLI output contracts are changed.

---

## Quick Reference

**Main entrypoints**

- `auto-uv-env` -> directive producer
- `share/auto-uv-env/auto-uv-env.bash` -> Bash runtime
- `share/auto-uv-env/auto-uv-env.zsh` -> Zsh runtime
- `share/auto-uv-env/auto-uv-env.fish` -> Fish runtime

**Key flags**

- `--check-safe <dir>`: emits directives (internal integration mode)
- `--diagnose [dir]`: environment diagnostics
- `--validate`: version consistency checks
- `--version`: semantic version string

**When in doubt:** keep the main script declarative, keep shell adapters imperative, and verify all three adapters plus tests before shipping.
