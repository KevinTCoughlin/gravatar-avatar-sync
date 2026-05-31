# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
