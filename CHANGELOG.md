# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- `bin/gravatar-avatar-sync` is now a true orchestrator: the fetch, write and
  AccountsService logic it previously duplicated is gone, so the library
  modules under `lib/gravatar-avatar-sync/` are the only implementations (and
  the ones covered by tests).
- All HTTP requests, including the Gravatar profile lookup, now go through one
  hardened `curl` wrapper: HTTPS-only (including redirects), shared
  timeout/retry settings, and a maximum download size.
- Gravatar profile JSON is parsed with `jq` instead of `grep`/`cut`/`sed`, so
  pretty-printed responses and unrelated `value` keys are handled correctly.
- The AccountsService icon is re-applied on every successful run instead of
  only when the image bytes change, repairing externally reset avatars.
- Avatar files are staged in a temporary file and renamed into place, so an
  interrupted run can no longer leave a truncated `~/.face`.
- `install.sh` now installs every library module it finds, so adding a module
  no longer requires editing the installer.
- Installer and uninstaller paths now honor `XDG_CONFIG_HOME`; the installer
  also validates runtime dependencies and secures the identity config
  directory with mode `0700`.
- The systemd unit is sandboxed (`NoNewPrivileges`, `PrivateTmp`,
  `SystemCallFilter=@system-service`, restricted address families, …), the
  timer applies a randomized delay, and the unusable `network-online.target`
  ordering was removed from the user unit.

### Fixed

- A failing host-D-Bus fallback (`/run/host/run/dbus/system_bus_socket`) was
  reported as success; the real status is now propagated and errors go to
  stderr.
- Errors (`Unsupported image type`, missing tools, invalid `GRAVATAR_SIZE`) are
  written to stderr instead of stdout.
- Usernames and e-mail addresses are validated before being interpolated into a
  URL.
- Whitespace trimming no longer uses `xargs`, which mangled or failed on values
  containing quotes.
- Running as root (for example via `sudo`) is refused by default; it silently
  updated root's avatar instead of the invoking user's. The override must now
  be set explicitly to `GRAVATAR_ALLOW_ROOT=1`, including for uninstall.
- Integration tests isolate `XDG_CONFIG_HOME`/`XDG_DATA_HOME` in addition to
  `HOME`; previously they overwrote the real user's avatar cache.
- Release automation now rejects malformed tags or missing changelog sections,
  including SemVer numeric identifiers with leading zeroes, and GitHub Actions
  dependencies are pinned to immutable commits.
- Installation now checks for the `awk` and `realpath` runtime dependencies
  before enabling the timer.

## [0.1.0] - 2026-05-28

### Added

- Initial release of `gravatar-avatar-sync`.
- `bin/gravatar-avatar-sync` shell script: fetches avatar from Gravatar and
  writes it to `~/.face`, `~/.face.icon`, and AccountsService via D-Bus.
- Identity resolution priority (username env var → username config file → CLI
  arg → email env var → email config file → `git config user.email`).
- Auto-detection of avatar size from `xrandr` and GNOME scaling settings,
  capped at `2048 px`.
- `install.sh` / `uninstall.sh` helpers.
- `systemd` user service + timer (first run 2 min after boot, repeat every
  12 hours, persistent across missed runs).

[Unreleased]: https://github.com/KevinTCoughlin/gravatar-avatar-sync/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/KevinTCoughlin/gravatar-avatar-sync/releases/tag/v0.1.0
