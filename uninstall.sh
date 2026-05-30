#!/usr/bin/env bash
set -euo pipefail

systemctl --user disable --now gravatar-avatar-sync.timer || true
systemctl --user daemon-reload

rm -f \
  "$HOME/.local/bin/gravatar-avatar-sync" \
  "$HOME/.config/systemd/user/gravatar-avatar-sync.service" \
  "$HOME/.config/systemd/user/gravatar-avatar-sync.timer"

rm -rf "$HOME/.local/lib/gravatar-avatar-sync"

echo "Uninstalled gravatar-avatar-sync files."
