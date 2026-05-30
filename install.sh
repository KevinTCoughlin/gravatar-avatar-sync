#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -Dm755 "$ROOT_DIR/bin/gravatar-avatar-sync" "$HOME/.local/bin/gravatar-avatar-sync"
install -Dm644 "$ROOT_DIR/systemd/gravatar-avatar-sync.service" "$HOME/.config/systemd/user/gravatar-avatar-sync.service"
install -Dm644 "$ROOT_DIR/systemd/gravatar-avatar-sync.timer" "$HOME/.config/systemd/user/gravatar-avatar-sync.timer"

# Install library modules
install -Dm644 "$ROOT_DIR/lib/gravatar-avatar-sync/display.sh"  "$HOME/.local/lib/gravatar-avatar-sync/display.sh"
install -Dm644 "$ROOT_DIR/lib/gravatar-avatar-sync/identity.sh" "$HOME/.local/lib/gravatar-avatar-sync/identity.sh"
install -Dm644 "$ROOT_DIR/lib/gravatar-avatar-sync/fetch.sh"    "$HOME/.local/lib/gravatar-avatar-sync/fetch.sh"
install -Dm644 "$ROOT_DIR/lib/gravatar-avatar-sync/update.sh"   "$HOME/.local/lib/gravatar-avatar-sync/update.sh"
install -Dm644 "$ROOT_DIR/lib/gravatar-avatar-sync/providers/gravatar.sh" \
               "$HOME/.local/lib/gravatar-avatar-sync/providers/gravatar.sh"

mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/gravatar-avatar-sync"

systemctl --user daemon-reload
systemctl --user enable --now gravatar-avatar-sync.timer
systemctl --user start gravatar-avatar-sync.service

echo "Installed and started gravatar-avatar-sync."
