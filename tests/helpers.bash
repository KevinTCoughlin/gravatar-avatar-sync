#!/usr/bin/env bash
# Shared test helpers for gravatar-avatar-sync bats tests

SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/gravatar-avatar-sync"

# Default profile JSON returned by the mock curl for .json requests
DEFAULT_PROFILE_JSON='{"entry":[{"photos":[{"value":"https:\/\/example.com\/photo.jpg","type":"thumbnail"}],"thumbnailUrl":"https:\/\/example.com\/thumb.jpg"}]}'

setup_mocks() {
  export TEST_HOME
  TEST_HOME="$(mktemp -d)"
  export MOCK_BIN
  MOCK_BIN="$(mktemp -d)"

  export HOME="$TEST_HOME"
  export XDG_CONFIG_HOME="$TEST_HOME/.config"
  export XDG_DATA_HOME="$TEST_HOME/.local/share"
  export GRAVATAR_SIZE="256"
  unset DISPLAY || true
  unset GRAVATAR_USERNAME || true
  unset GRAVATAR_EMAIL || true
  unset GRAVATAR_DEFAULT || true
  unset MOCK_GIT_EMAIL || true

  _create_mock_curl
  _create_mock_git
  _create_mock_gdbus
  _create_mock_file
  _create_mock_install

  export PATH="$MOCK_BIN:$PATH"

  # Write the default profile JSON for username-based lookups
  printf '%s' "$DEFAULT_PROFILE_JSON" > "$MOCK_BIN/profile_json"
  rm -f "$MOCK_BIN/curl_calls"
}

teardown_mocks() {
  rm -rf "$TEST_HOME" "$MOCK_BIN"
}

# Return all URLs that the mock curl was called with, one per line
curl_calls() {
  cat "$MOCK_BIN/curl_calls" 2>/dev/null || true
}

_create_mock_curl() {
  # MOCK_BIN must be visible inside the script; embed its value at creation time
  local mb="$MOCK_BIN"
  cat > "$mb/curl" << CURLEOF
#!/usr/bin/env bash
url="" output=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -f|-s|-S|-L|-fsSL|-fsSl) ;;
    -o) shift; output="\$1" ;;
    http*) url="\$1" ;;
  esac
  shift
done
printf '%s\n' "\$url" >> "${mb}/curl_calls"
if [[ -n "\$output" ]]; then
  # Write a minimal valid-looking file for the avatar download path
  printf '\x89PNG\r\n\x1a\n' > "\$output"
else
  # Return the profile JSON for username .json requests
  cat "${mb}/profile_json"
fi
CURLEOF
  chmod +x "$mb/curl"
}

_create_mock_git() {
  local mb="$MOCK_BIN"
  cat > "$mb/git" << GITEOF
#!/usr/bin/env bash
if [[ "\$*" == *"user.email"* ]]; then
  if [[ -n "\${MOCK_GIT_EMAIL:-}" ]]; then
    printf '%s\n' "\$MOCK_GIT_EMAIL"
    exit 0
  fi
  exit 1
fi
exit 1
GITEOF
  chmod +x "$mb/git"
}

_create_mock_gdbus() {
  cat > "$MOCK_BIN/gdbus" << 'GDBUSEOF'
#!/usr/bin/env bash
exit 0
GDBUSEOF
  chmod +x "$MOCK_BIN/gdbus"
}

_create_mock_file() {
  cat > "$MOCK_BIN/file" << 'FILEEOF'
#!/usr/bin/env bash
echo "image/png"
FILEEOF
  chmod +x "$MOCK_BIN/file"
}

_create_mock_install() {
  cat > "$MOCK_BIN/install" << 'INSTALLEOF'
#!/usr/bin/env bash
# Minimal mock for: install -m 0644 src dst
src="" dst="" skip=0
for arg in "$@"; do
  if [[ $skip -eq 1 ]]; then skip=0; continue; fi
  case "$arg" in
    -m) skip=1 ;;
    -m[0-9]*) ;;
    *) if [[ -z "$src" ]]; then src="$arg"; else dst="$arg"; fi ;;
  esac
done
if [[ -n "$src" && -n "$dst" ]]; then
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
fi
INSTALLEOF
  chmod +x "$MOCK_BIN/install"
}
