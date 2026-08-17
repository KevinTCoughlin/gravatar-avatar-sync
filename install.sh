#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(id -u)" -eq 0 && "${GRAVATAR_ALLOW_ROOT:-}" != "1" ]]; then
  echo "Refusing to install as root: this installs into root's home." >&2
  echo "Run as your own user, or set GRAVATAR_ALLOW_ROOT=1 to override." >&2
  exit 1
fi

for tool in awk realpath curl file find gdbus install jq md5sum systemctl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SYSTEMD_USER_DIR="$XDG_CONFIG_HOME/systemd/user"
CONFIG_DIR="$XDG_CONFIG_HOME/gravatar-avatar-sync"

install -Dm755 "$ROOT_DIR/bin/gravatar-avatar-sync" "$HOME/.local/bin/gravatar-avatar-sync"
install -Dm644 "$ROOT_DIR/systemd/gravatar-avatar-sync.service" "$SYSTEMD_USER_DIR/gravatar-avatar-sync.service"
install -Dm644 "$ROOT_DIR/systemd/gravatar-avatar-sync.timer" "$SYSTEMD_USER_DIR/gravatar-avatar-sync.timer"

# Install every library module (including providers) so that adding a module
# never requires editing this script.
LIB_SRC="$ROOT_DIR/lib/gravatar-avatar-sync"
LIB_DEST="$HOME/.local/lib/gravatar-avatar-sync"
rm -rf "$LIB_DEST"
while IFS= read -r -d '' module; do
  install -Dm644 "$module" "$LIB_DEST/${module#"$LIB_SRC/"}"
done < <(find "$LIB_SRC" -type f -name '*.sh' -print0)

install -d -m 0700 "$CONFIG_DIR"

systemctl --user daemon-reload
systemctl --user enable --now gravatar-avatar-sync.timer

echo "Installed gravatar-avatar-sync and enabled timer."
