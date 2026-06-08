#!/usr/bin/env bash
set -euo pipefail

systemctl --user disable --now gravatar-avatar-sync.timer || true
systemctl --user disable --now gravatar-avatar-sync.service || true

rm -f \
  "$HOME/.local/bin/gravatar-avatar-sync" \
  "$HOME/.config/systemd/user/gravatar-avatar-sync.service" \
  "$HOME/.config/systemd/user/gravatar-avatar-sync.timer"

systemctl --user daemon-reload
systemctl --user reset-failed gravatar-avatar-sync.service >/dev/null 2>&1 || true

echo "Uninstalled gravatar-avatar-sync files."
