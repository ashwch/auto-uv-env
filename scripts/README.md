# Release Scripts

This directory contains automated scripts for releasing auto-uv-env.

## Release Trigger Model

- GitHub releases are tag-driven (`v*`) via `.github/workflows/release.yml`.
- Merging a PR alone does not publish a release.
- A complete release requires a new tag push (for example `v1.1.3`).
- Docs publishing is separate and runs from `.github/workflows/docs.yml` on pushes to `main`.

## 🚀 Quick Release

For most releases, use the bump version script:

```bash
# Patch release (1.0.0 -> 1.0.1)
./scripts/bump-version.sh patch

# Minor release (1.0.0 -> 1.1.0)  
./scripts/bump-version.sh minor

# Major release (1.0.0 -> 2.0.0)
./scripts/bump-version.sh major
```

## 📋 What the Scripts Do

### `bump-version.sh`
- Calculates the next version based on current version
- Calls `release.sh` with the calculated version

### `release.sh`
Performs a complete release process:

1. **Version Update**: Updates version in `auto-uv-env`, `pyproject.toml`, and `CHANGELOG.md`
2. **Quality Gates**: Runs all tests and pre-commit hooks
3. **Git Operations**: Creates commit and annotated tag
4. **GitHub Push**: Pushes code and tags to GitHub
5. **GitHub Release**: Creates release with automated notes
6. **Homebrew Update**: Updates formula with new SHA256
7. **Verification**: Tests the Homebrew installation

## 🏷️ Release Naming and Notes Convention

Preferred format:

- Tag: `vX.Y.Z`
- Title: `Release vX.Y.Z`
- Notes header: `## What's New in vX.Y.Z`
- Notes sections:
  - `### 🐛 Fixed`
  - `### 🔧 Changed`
  - `### ✅ Added`
  - `### 📚 Documentation` (if needed)
  - `### 🧪 Testing`

If an automated release body/title does not match this convention, normalize it:

```bash
gh release edit v1.1.3 --title "Release v1.1.3" --notes-file /path/to/notes.md
```

## 🛠️ Manual Release

For custom versions or advanced options:

```bash
# Specific version
./scripts/release.sh 1.2.3

# Dry run to see what would happen
./scripts/release.sh 1.2.3 --dry-run

# Skip tests (not recommended)
./scripts/release.sh 1.2.3 --skip-tests
```

## 📚 Examples

```bash
# Test what a patch release would do
./scripts/bump-version.sh patch --dry-run

# Create a minor release
./scripts/bump-version.sh minor

# Create a specific version
./scripts/release.sh 1.5.0

# Emergency patch without tests (NOT recommended)
./scripts/release.sh 1.0.1 --skip-tests
```

## ✅ Prerequisites

Before running these scripts, ensure:

1. **Clean Git State**: No uncommitted changes
2. **Main Branch**: Must be on `main` branch
3. **Dependencies**: `gh` (GitHub CLI) and `uv` must be installed
4. **Authentication**: GitHub CLI must be authenticated
5. **Permissions**: Write access to both `auto-uv-env` and `homebrew-tap` repositories

## 🔧 Configuration

The scripts automatically handle:
- Repository names (`ashwch/auto-uv-env`, `ashwch/homebrew-tap`)
- SHA256 calculation for Homebrew formula
- Release note generation
- Version consistency across all files

## 🚨 Error Handling

The scripts include comprehensive error checking:
- Version format validation
- Git state verification
- Dependency checks
- Test suite validation
- Homebrew formula syntax

If any step fails, the process stops and reports the error.

## Known Caveats

1. `release.sh` requires a clean working tree, including no untracked files.

2. The tag-triggered release workflow status is not the only source of truth.
- If the workflow fails, verify whether the release still exists:
  - `gh release view vX.Y.Z`

3. If Homebrew tap update fails in the script, complete it manually:
- compute SHA256 from the release tarball
- update `Formula/auto-uv-env.rb` in `ashwch/homebrew-tap`
- commit and push to tap `main`

4. Docs updates appear on `https://auto-uv-env.ashwch.com/` only after `docs.yml` on `main` completes.

## 📝 Manual Steps (if needed)

If the automated scripts fail, you can manually:

1. Update version in files
2. Run tests: `./test/test.sh && ./test/test-security.sh`
3. Commit and tag: `git commit -m "Release vX.Y.Z" && git tag vX.Y.Z`
4. Push: `git push origin main && git push origin vX.Y.Z`
5. Create release: `gh release create vX.Y.Z`
6. Update Homebrew formula with new SHA256

## 🎯 Best Practices

- Always run `--dry-run` first for major releases
- Update `CHANGELOG.md` with meaningful notes after version bump
- Test the Homebrew installation after release
- Monitor GitHub Actions CI after pushing

---

These scripts ensure consistent, reliable releases with minimal manual intervention.
