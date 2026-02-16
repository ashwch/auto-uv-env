# Release Guide

Canonical release playbook for `auto-uv-env`.

## Release Contract

- A merged PR does **not** create a GitHub release.
- Releases are triggered by pushing a tag that matches `v*` (see `.github/workflows/release.yml`).
- Docs publishing is separate: `.github/workflows/docs.yml` deploys on pushes to `main`.
- Release operations must be run from a clean `main` branch.
- The GitHub release tag and project version must match (for example `v1.1.2` <-> `version = "1.1.2"`).

## Standard Release Format

- Tag: `vX.Y.Z`
- Title: `Release vX.Y.Z`
- Notes header: `## What's New in vX.Y.Z`
- Notes sections:
  - `### 🐛 Fixed`
  - `### 🔧 Changed`
  - `### ✅ Added`
  - `### 📚 Documentation` (if applicable)
  - `### 🧪 Testing`

Use this format consistently so release history stays readable.

## Preferred Release Flow

From repo root:

```bash
# 1) Ensure clean working tree and up-to-date main
git checkout main
git pull --ff-only origin main
git status --short

# 2) Dry run first
./scripts/release.sh 1.1.3 --dry-run

# 3) Execute release
./scripts/release.sh 1.1.3
```

The script performs:

1. version update (`auto-uv-env`, `pyproject.toml`, `CHANGELOG.md`)
2. tests + quality gates
3. release commit + annotated tag
4. push `main` and tag
5. create GitHub release
6. update Homebrew tap formula

## Post-Release Verification

```bash
gh release view v1.1.3
gh release list --limit 5
git tag --sort=-creatordate | head -10
gh run list --workflow release.yml --limit 5
gh run list --workflow docs.yml --branch main --limit 5
```

Verify Homebrew tap formula:

```bash
gh api 'repos/ashwch/homebrew-tap/contents/Formula/auto-uv-env.rb?ref=main' \
  --jq '.content' | python3 -c 'import sys,base64;print(base64.b64decode(sys.stdin.read()).decode())'
```

## Release Notes Normalization

If an automated release body/title does not match the standard format:

```bash
gh release edit v1.1.3 \
  --title "Release v1.1.3" \
  --notes-file /path/to/notes.md
```

## Docs Publishing Verification

After the release script pushes `main`, confirm docs deployment status:

```bash
gh run list --workflow docs.yml --branch main --limit 5
```

If needed, inspect the latest docs workflow run and logs:

```bash
gh run view <run-id> --log
```

## Known Caveats

1. `scripts/release.sh` requires a completely clean tree.
Untracked files (for example local `uv.lock`) will fail the release precheck.

2. Tag workflow status is not the only source of truth.
A `v*` tag push triggers `.github/workflows/release.yml`.
If that workflow fails, check whether `gh release view vX.Y.Z` already exists.

3. If Homebrew update fails in the script, complete it manually.
Calculate SHA256 from the release tarball.
Update `Formula/auto-uv-env.rb` in `ashwch/homebrew-tap`.
Commit and push the formula update.

4. GitHub Pages deploy is asynchronous and main-branch-driven.
Even when a release exists, docs may lag until the latest `docs.yml` run on `main` finishes.

## Manual Fallback (Last Resort)

```bash
# version + changelog updates
# run tests
./test/test.sh
./test/test-security.sh
./test/test-shell-integrations.sh
uv tool run pre-commit run --all-files

# release commit + tag + push
git add auto-uv-env pyproject.toml CHANGELOG.md
git commit -m "Release v1.1.3"
git tag -a v1.1.3 -m "Release v1.1.3"
git push origin main
git push origin v1.1.3

# create/edit release
gh release create v1.1.3 --title "Release v1.1.3" --notes-file /path/to/notes.md --latest
```
