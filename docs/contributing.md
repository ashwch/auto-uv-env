---
layout: page
title: Contributing
permalink: /contributing/
---

# Contributing

## Contributor Docs

- Quick contributor entrypoint: [CONTRIBUTE.md](https://github.com/ashwch/auto-uv-env/blob/main/CONTRIBUTE.md)
- Release runbook: [RELEASE.md](https://github.com/ashwch/auto-uv-env/blob/main/RELEASE.md)
- Agent/automation contract: [AGENTS.md](https://github.com/ashwch/auto-uv-env/blob/main/AGENTS.md)

## Development Setup

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

## Testing

Run the full quality gate before opening a PR:

```bash
./test/test.sh
./test/test-security.sh
./test/test-shell-integrations.sh
./test/test-deleted-venv.sh
uv tool run pre-commit run --all-files
```

If your shell has an active virtual environment, sanitize test env variables:

```bash
env -u VIRTUAL_ENV -u _AUTO_UV_ENV_ACTIVATION_DIR -u AUTO_UV_ENV_PYTHON_VERSION ./test/test.sh
```

## Code Style

- Use 4-space indentation for shell scripts
- Follow existing patterns and conventions
- Add comments for complex logic
- Ensure all scripts have proper shebangs
- Use shellcheck-compliant code

## Pull Request Guidelines

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the development workflow
4. Ensure all tests pass and pre-commit hooks succeed
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Releases

- Merging a PR into `main` does **not** publish a GitHub release.
- Releases are triggered by pushing a `v*` tag.
- Standard format is `Release vX.Y.Z` with structured notes sections.
- Use [RELEASE.md](https://github.com/ashwch/auto-uv-env/blob/main/RELEASE.md) for the canonical release process, naming conventions, and verification steps.

## Documentation Publishing

- The docs site is deployed by `.github/workflows/docs.yml`.
- Any push to `main` triggers a docs build; only `main` pushes deploy to GitHub Pages.
- Release tags (`v*`) do not publish docs on their own.
- Verify recent docs runs with:

```bash
gh run list --workflow docs.yml --branch main --limit 5
```
