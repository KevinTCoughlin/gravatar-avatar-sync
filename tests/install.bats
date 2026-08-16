#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_ROOT="$(mktemp -d)"
  TEST_HOME="$TEST_ROOT/home"
  MOCK_BIN="$TEST_ROOT/bin"
  SYSTEMCTL_LOG="$TEST_ROOT/systemctl.log"
  mkdir -p "$TEST_HOME" "$MOCK_BIN"

  cat >"$MOCK_BIN/id" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-u" ]]; then
  printf '%s\n' "${MOCK_UID:-1000}"
  exit 0
fi
exec /usr/bin/id "$@"
EOF
  cat >"$MOCK_BIN/systemctl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$SYSTEMCTL_LOG"
EOF
  chmod +x "$MOCK_BIN/id" "$MOCK_BIN/systemctl"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "installer honors XDG_CONFIG_HOME and secures config directory" {
  local xdg_config="$TEST_ROOT/xdg-config"

  run env \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$xdg_config" \
    PATH="$MOCK_BIN:$PATH" \
    bash "$REPO_ROOT/install.sh"

  [ "$status" -eq 0 ]
  [ -x "$TEST_HOME/.local/bin/gravatar-avatar-sync" ]
  [ -f "$TEST_HOME/.local/lib/gravatar-avatar-sync/providers/gravatar.sh" ]
  [ -f "$xdg_config/systemd/user/gravatar-avatar-sync.service" ]
  [ -f "$xdg_config/systemd/user/gravatar-avatar-sync.timer" ]
  [ "$(stat -c '%a' "$xdg_config/gravatar-avatar-sync")" = "700" ]
  grep -Fq -- "--user daemon-reload" "$SYSTEMCTL_LOG"
  grep -Fq -- "--user enable --now gravatar-avatar-sync.timer" "$SYSTEMCTL_LOG"
}

@test "uninstaller honors XDG_CONFIG_HOME and preserves user data" {
  local xdg_config="$TEST_ROOT/xdg-config"
  local data_dir="$TEST_HOME/.local/share/avatars"
  mkdir -p "$xdg_config/gravatar-avatar-sync" "$data_dir"
  printf '%s\n' "user@example.com" >"$xdg_config/gravatar-avatar-sync/email"
  printf '%s\n' "avatar" >"$data_dir/gravatar-avatar.png"

  env HOME="$TEST_HOME" XDG_CONFIG_HOME="$xdg_config" PATH="$MOCK_BIN:$PATH" \
    bash "$REPO_ROOT/install.sh"

  run env \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$xdg_config" \
    PATH="$MOCK_BIN:$PATH" \
    bash "$REPO_ROOT/uninstall.sh"

  [ "$status" -eq 0 ]
  [ ! -e "$TEST_HOME/.local/bin/gravatar-avatar-sync" ]
  [ ! -e "$TEST_HOME/.local/lib/gravatar-avatar-sync" ]
  [ ! -e "$xdg_config/systemd/user/gravatar-avatar-sync.service" ]
  [ ! -e "$xdg_config/systemd/user/gravatar-avatar-sync.timer" ]
  [ -f "$xdg_config/gravatar-avatar-sync/email" ]
  [ -f "$data_dir/gravatar-avatar.png" ]
}

@test "root override must be exactly 1" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_UID=0 \
    GRAVATAR_ALLOW_ROOT=0 \
    bash "$REPO_ROOT/install.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Refusing to install as root"* ]]
}

@test "uninstaller refuses root without an explicit override" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_UID=0 \
    bash "$REPO_ROOT/uninstall.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Refusing to uninstall as root"* ]]
}

@test "installer detects a missing awk dependency" {
  local limited_path="$TEST_ROOT/no-awk"
  mkdir -p "$limited_path"
  ln -s /usr/bin/dirname "$limited_path/dirname"
  ln -s /usr/bin/id "$limited_path/id"

  run env HOME="$TEST_HOME" PATH="$limited_path" /usr/bin/bash "$REPO_ROOT/install.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required tool: awk"* ]]
}

@test "installer detects a missing realpath dependency" {
  local limited_path="$TEST_ROOT/no-realpath"
  mkdir -p "$limited_path"
  ln -s /usr/bin/awk "$limited_path/awk"
  ln -s /usr/bin/dirname "$limited_path/dirname"
  ln -s /usr/bin/id "$limited_path/id"

  run env HOME="$TEST_HOME" PATH="$limited_path" /usr/bin/bash "$REPO_ROOT/install.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required tool: realpath"* ]]
}
