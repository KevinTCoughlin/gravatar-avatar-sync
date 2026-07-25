#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(id -u)" -eq 0 && -z "${GRAVATAR_ALLOW_ROOT:-}" ]]; then
  echo "Refusing to install as root: this installs into root's home." >&2
  echo "Run as your own user, or set GRAVATAR_ALLOW_ROOT=1 to override." >&2
  exit 1
fi

install -Dm755 "$ROOT_DIR/bin/gravatar-avatar-sync" "$HOME/.local/bin/gravatar-avatar-sync"
install -Dm644 "$ROOT_DIR/systemd/gravatar-avatar-sync.service" "$HOME/.config/systemd/user/gravatar-avatar-sync.service"
install -Dm644 "$ROOT_DIR/systemd/gravatar-avatar-sync.timer" "$HOME/.config/systemd/user/gravatar-avatar-sync.timer"

# Install every library module (including providers) so that adding a module
# never requires editing this script.
LIB_SRC="$ROOT_DIR/lib/gravatar-avatar-sync"
LIB_DEST="$HOME/.local/lib/gravatar-avatar-sync"
rm -rf "$LIB_DEST"
while IFS= read -r -d '' module; do
  install -Dm644 "$module" "$LIB_DEST/${module#"$LIB_SRC/"}"
done < <(find "$LIB_SRC" -type f -name '*.sh' -print0)

mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/gravatar-avatar-sync"

systemctl --user daemon-reload
systemctl --user enable --now gravatar-avatar-sync.timer

echo "Installed gravatar-avatar-sync and enabled timer."
