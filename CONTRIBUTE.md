# Contribute

Quick contributor entrypoint for this repository.

## Start Here

- Full contributing guide: [`docs/contributing.md`](docs/contributing.md)
- Release process: [`RELEASE.md`](RELEASE.md)
- Agent-focused engineering guide: [`AGENTS.md`](AGENTS.md)

## Local Quality Gates

Run these before opening a PR:

```bash
./test/test.sh
./test/test-security.sh
./test/test-shell-integrations.sh
./test/test-deleted-venv.sh
uv tool run pre-commit run --all-files
```

If your shell has an active virtual environment, run tests in a sanitized env:

```bash
env -u VIRTUAL_ENV -u _AUTO_UV_ENV_ACTIVATION_DIR -u AUTO_UV_ENV_PYTHON_VERSION ./test/test.sh
```

## Release Note

Merging a PR does not publish a GitHub release. Releases are tag-driven (`v*`).
Use [`RELEASE.md`](RELEASE.md) for the canonical release workflow.

## Docs Publishing Note

Documentation at `https://auto-uv-env.ashwch.com/` is deployed by `docs.yml` on pushes to `main`.
Release tags do not deploy docs by themselves.
