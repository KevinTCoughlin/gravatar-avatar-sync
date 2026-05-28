#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -Dm755 "$ROOT_DIR/bin/gravatar-avatar-sync" "$HOME/.local/bin/gravatar-avatar-sync"
install -Dm644 "$ROOT_DIR/systemd/gravatar-avatar-sync.service" "$HOME/.config/systemd/user/gravatar-avatar-sync.service"
install -Dm644 "$ROOT_DIR/systemd/gravatar-avatar-sync.timer" "$HOME/.config/systemd/user/gravatar-avatar-sync.timer"
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/gravatar-avatar-sync"

systemctl --user daemon-reload
systemctl --user enable --now gravatar-avatar-sync.timer
systemctl --user start gravatar-avatar-sync.service

echo "Installed and started gravatar-avatar-sync."
