#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -eq 0 && "${GRAVATAR_ALLOW_ROOT:-}" != "1" ]]; then
  echo "Refusing to uninstall as root: this would target root's home." >&2
  echo "Run as your own user, or set GRAVATAR_ALLOW_ROOT=1 to override." >&2
  exit 1
fi

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SYSTEMD_USER_DIR="$XDG_CONFIG_HOME/systemd/user"

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now gravatar-avatar-sync.timer || true
  systemctl --user disable --now gravatar-avatar-sync.service || true
fi

rm -f \
  "$HOME/.local/bin/gravatar-avatar-sync" \
  "$SYSTEMD_USER_DIR/gravatar-avatar-sync.service" \
  "$SYSTEMD_USER_DIR/gravatar-avatar-sync.timer"

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload || true
  systemctl --user reset-failed gravatar-avatar-sync.service >/dev/null 2>&1 || true
fi
rm -rf "$HOME/.local/lib/gravatar-avatar-sync"

echo "Uninstalled gravatar-avatar-sync files."
