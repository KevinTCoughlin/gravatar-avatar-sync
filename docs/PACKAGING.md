# Packaging Roadmap

This document tracks the plan for distributing `gravatar-avatar-sync` through
system package managers.  The goal is to let users install and update the tool
without manually cloning the repository.

---

## Priority Order

| Priority | Target | Audience | Effort |
|----------|--------|----------|--------|
| 1 | [COPR (Fedora/RHEL)](#1-copr-fedorarhel) | Fedora, RHEL, CentOS Stream, AlmaLinux | Low |
| 2 | [AUR (Arch Linux)](#2-aur-arch-linux) | Arch Linux, Manjaro, EndeavourOS | Very low |
| 3 | [Homebrew / Linuxbrew](#3-homebrew--linuxbrew) | macOS + Linux Homebrew users | Low–medium |
| 4 | [DEB package (Debian/Ubuntu)](#4-deb-package-debianubuntu) | Debian, Ubuntu, Mint, Pop!_OS | Medium |
| 5 | [RPM (independent SPEC)](#5-rpm-independent-spec) | Fedora/RHEL without COPR, openSUSE | Medium |

### Rationale

1. **COPR first** – The install instructions already call out Fedora by name
   and the tooling (`systemd --user`, `gdbus`) maps directly onto a Fedora
   workstation.  COPR hosting is free, automated by pushing a `.spec` file, and
   requires no distro maintainer sponsorship.

2. **AUR second** – An `AUR` `PKGBUILD` is a single file and is trivially
   maintained.  Arch users are early adopters who benefit from a utility like
   this; an AUR package signals community legitimacy.

3. **Homebrew / Linuxbrew third** – Homebrew reaches macOS users (future
   support) and Linuxbrew users on non-Fedora/Arch distros.  A formula is a
   single Ruby file.  Currently the project has some Linux-only dependencies
   (`systemd`, `gdbus`), so the formula would need a Linux guard or a
   follow-up macOS port.

4. **DEB fourth** – Large user base but higher packaging overhead (debian/
   directory structure, lintian compliance, potential Debian NEW queue if
   targeting official repos).  A PPA on Launchpad or a self-hosted apt repo is
   a pragmatic first step before official inclusion.

5. **RPM SPEC (standalone)** – The COPR workflow already produces an RPM; a
   standalone `.spec` file lets other RPM-based distros (openSUSE, Amazon
   Linux) build from source.  Extract from the COPR work with minimal
   additional effort.

---

## Package Targets

### 1. COPR (Fedora/RHEL)

**Tracking issue/milestone:** `packaging: COPR`

**Deliverables**
- `packaging/rpm/gravatar-avatar-sync.spec` – RPM spec file.
- COPR project created at
  `https://copr.fedorainfracloud.org/coprs/KevinTCoughlin/gravatar-avatar-sync/`.
- GitHub Actions workflow (`.github/workflows/copr.yml`) that submits a new
  build to COPR on each tagged release.

**Steps**
1. Write `.spec` file that:
   - Sets `Source0` to the GitHub release tarball URL.
   - Installs the script to `/usr/bin/gravatar-avatar-sync`.
   - Installs the systemd units to `/usr/lib/systemd/user/`.
   - Declares `Requires: bash curl gdbus-tools file`.
2. Test locally with `rpmbuild` or `mock`.
3. Create the COPR project and enable GitHub webhook or add a CI step.
4. Tag `v0.1.0` → verify COPR build succeeds and the package installs cleanly.

---

### 2. AUR (Arch Linux)

**Tracking issue/milestone:** `packaging: AUR`

**Deliverables**
- `packaging/aur/PKGBUILD` – Arch `PKGBUILD`.
- Published to the AUR under the package name `gravatar-avatar-sync`.

**Steps**
1. Write `PKGBUILD` that:
   - Uses the GitHub release tarball as the source.
   - Installs the script, systemd units, and documentation.
   - Sets `depends=('bash' 'curl' 'dbus-utils' 'file')`.
2. Generate `.SRCINFO` with `makepkg --printsrcinfo > .SRCINFO`.
3. Push to the AUR (requires an AUR account and SSH key).
4. Add a manual update step to the release checklist.

---

### 3. Homebrew / Linuxbrew

**Tracking issue/milestone:** `packaging: Homebrew`

**Deliverables**
- `packaging/homebrew/gravatar-avatar-sync.rb` – Homebrew formula.
- Published as a tap: `KevinTCoughlin/homebrew-tap` (or upstream `homebrew-core` later).

**Steps**
1. Write formula that:
   - Points `url` at the GitHub release tarball.
   - Installs only the script (systemd units are Linux-only; guard with
     `on_linux` block).
   - Declares `depends_on` for any missing tools on macOS.
2. Create the `KevinTCoughlin/homebrew-tap` GitHub repository.
3. Add a CI step to bump the formula version on each tagged release (e.g.,
   using `brew bump-formula-pr` or a GitHub Action).
4. Document tap installation in `README.md`:
   ```bash
   brew tap KevinTCoughlin/tap
   brew install gravatar-avatar-sync
   ```

---

### 4. DEB package (Debian/Ubuntu)

**Tracking issue/milestone:** `packaging: DEB`

**Deliverables**
- `packaging/deb/` – Debian source package directory (control, rules, etc.).
- Published via a Launchpad PPA or a self-hosted apt repository.

**Steps**
1. Create `packaging/deb/debian/` directory with:
   - `control` – package metadata and `Depends: bash, curl, dbus-x11, file`.
   - `rules` – simple `dh $@` with install overrides.
   - `install` – file list mapping to `/usr/bin/` and
     `/lib/systemd/user/`.
   - `changelog` – Debian-format changelog entry.
2. Build locally with `dpkg-buildpackage -us -uc` or `debuild`.
3. Register a Launchpad PPA and upload the source package.
4. Add a GitHub Actions job to build and upload on each tagged release.

---

### 5. RPM (independent SPEC)

**Tracking issue/milestone:** `packaging: RPM SPEC`

**Deliverables**
- `packaging/rpm/gravatar-avatar-sync.spec` – shared with the COPR target.
- Documentation on building locally with `rpmbuild`.

**Steps**
1. Reuse/refine the spec from the COPR work.
2. Add a section to `docs/RELEASING.md` for manual RPM builds:
   ```bash
   rpmbuild -ba packaging/rpm/gravatar-avatar-sync.spec \
     --define "_sourcedir ." \
     --define "_version X.Y.Z"
   ```
3. Verify the built RPM on Fedora and openSUSE Leap.

---

## Milestone Structure

Create the following GitHub milestones to track packaging work:

| Milestone | Goal |
|-----------|------|
| `v0.2.0 – COPR & AUR` | COPR and AUR packages available; update `README.md` install instructions. |
| `v0.3.0 – Homebrew tap` | Homebrew tap published; macOS compatibility evaluated. |
| `v0.4.0 – DEB / RPM` | DEB (PPA) and standalone RPM SPEC available. |

---

## Notes

- All packaging artifacts live under `packaging/` in the repository root so
  they ship with the source tarball and can be reviewed alongside code changes.
- Each packaging target should have its own GitHub issue (linked to the
  corresponding milestone) with the label `packaging`.
- The release workflow (`.github/workflows/release.yml`) publishes the
  canonical source tarball that all downstream packages should reference.
