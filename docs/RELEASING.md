# Release Process

This document describes how to cut a release of `gravatar-avatar-sync`.

## Versioning Policy

This project follows [Semantic Versioning 2.0.0](https://semver.org/):

```
MAJOR.MINOR.PATCH
```

| Component | When to bump |
|-----------|-------------|
| **MAJOR** | Incompatible changes to the public interface (e.g., removal of a config key, renamed binary, breaking change to install paths). |
| **MINOR** | New backwards-compatible functionality (e.g., new identity source, new env var, new platform support). |
| **PATCH** | Backwards-compatible bug fixes, documentation updates, and minor internal improvements. |

Pre-release labels (`-alpha.1`, `-beta.1`, `-rc.1`) may be appended for
release candidates when significant changes warrant wider testing before a
stable release.

> **Note:** While the project is at `0.x.y`, the MINOR version may also
> include breaking changes per SemVer spec (§4).  Once `v1.0.0` is tagged the
> full stability guarantees apply.

---

## Checklist: Cutting a Release

Follow these steps in order.  All commands assume you are on the `main` branch
with a clean working tree.

### 1. Prepare the release commit

1. Decide the next version number (see [Versioning Policy](#versioning-policy)
   above).  For this example we use `X.Y.Z`.

2. Update `CHANGELOG.md`:
   - Rename the `[Unreleased]` section header to `[X.Y.Z] - YYYY-MM-DD`.
   - Add a new empty `[Unreleased]` section at the top.
   - Update the comparison links at the bottom of the file:
     ```
     [Unreleased]: https://github.com/KevinTCoughlin/gravatar-avatar-sync/compare/vX.Y.Z...HEAD
     [X.Y.Z]: https://github.com/KevinTCoughlin/gravatar-avatar-sync/compare/vPREV...vX.Y.Z
     ```

3. Commit the changelog update:
   ```bash
   git add CHANGELOG.md
   git commit -m "chore: release v${X.Y.Z}"
   ```

### 2. Tag the release

```bash
git tag -a "vX.Y.Z" -m "Release vX.Y.Z"
git push origin main "vX.Y.Z"
```

Pushing the tag triggers the [release workflow](#automated-github-release) and
creates the GitHub Release automatically.

### 3. Verify the GitHub Release

1. Open the [Releases page](https://github.com/KevinTCoughlin/gravatar-avatar-sync/releases).
2. Confirm the new release is listed with the correct tag and changelog body.
3. Download the source tarball and verify it is complete.

### 4. Post-release

- Close any milestones associated with this release on
  [GitHub Milestones](https://github.com/KevinTCoughlin/gravatar-avatar-sync/milestones).
- Announce in relevant channels if applicable.

---

## Automated GitHub Release

The file [`.github/workflows/release.yml`](../.github/workflows/release.yml)
automates GitHub Release creation whenever a `v*` tag is pushed.

The workflow:
1. Checks out the tagged commit.
2. Builds a `.tar.gz` source archive named
   `gravatar-avatar-sync-X.Y.Z.tar.gz`.
3. Creates a GitHub Release using the tag and attaches the archive.
4. Populates the release notes from `CHANGELOG.md` (the section matching the
   tag version).

No secrets beyond the default `GITHUB_TOKEN` are required.

---

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, always-releasable code. Direct commits for small fixes; PRs for features. |
| `feature/*` | Feature branches; merged via PR into `main`. |
| `hotfix/*` | Emergency fixes against the latest release tag; merged into `main` and re-tagged. |

Release tags are always cut from `main`.
