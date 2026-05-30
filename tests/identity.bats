#!/usr/bin/env bats
# Tests for identity source precedence in gravatar-avatar-sync.
#
# Priority order (highest to lowest):
#   1. GRAVATAR_USERNAME env var
#   2. ~/.config/gravatar-avatar-sync/username file
#   3. CLI email argument (first positional arg)
#   4. GRAVATAR_EMAIL env var
#   5. ~/.config/gravatar-avatar-sync/email file
#   6. git config --global user.email

load helpers

setup() { setup_mocks; }
teardown() { teardown_mocks; }

# ---------------------------------------------------------------------------
# Positive identity-source tests
# ---------------------------------------------------------------------------

@test "identity: GRAVATAR_USERNAME env var selects username path" {
  export GRAVATAR_USERNAME="envuser"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(curl_calls)" == *"https://gravatar.com/envuser.json"* ]]
}

@test "identity: username config file used when GRAVATAR_USERNAME is unset" {
  mkdir -p "$TEST_HOME/.config/gravatar-avatar-sync"
  printf '%s\n' 'fileuser' > "$TEST_HOME/.config/gravatar-avatar-sync/username"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(curl_calls)" == *"https://gravatar.com/fileuser.json"* ]]
}

@test "identity: CLI email arg selects email path when no username is set" {
  run "$SCRIPT" "cli@example.com"
  [ "$status" -eq 0 ]
  local expected_hash
  expected_hash="$(printf '%s' "cli@example.com" | md5sum | awk '{print $1}')"
  [[ "$(curl_calls)" == *"gravatar.com/avatar/$expected_hash"* ]]
}

@test "identity: GRAVATAR_EMAIL env var used when no username and no CLI arg" {
  export GRAVATAR_EMAIL="env@example.com"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local expected_hash
  expected_hash="$(printf '%s' "env@example.com" | md5sum | awk '{print $1}')"
  [[ "$(curl_calls)" == *"gravatar.com/avatar/$expected_hash"* ]]
}

@test "identity: email config file used when no higher-priority source" {
  mkdir -p "$TEST_HOME/.config/gravatar-avatar-sync"
  printf '%s\n' 'cfg@example.com' > "$TEST_HOME/.config/gravatar-avatar-sync/email"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local expected_hash
  expected_hash="$(printf '%s' "cfg@example.com" | md5sum | awk '{print $1}')"
  [[ "$(curl_calls)" == *"gravatar.com/avatar/$expected_hash"* ]]
}

@test "identity: git config email used as last-resort fallback" {
  export MOCK_GIT_EMAIL="git@example.com"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local expected_hash
  expected_hash="$(printf '%s' "git@example.com" | md5sum | awk '{print $1}')"
  [[ "$(curl_calls)" == *"gravatar.com/avatar/$expected_hash"* ]]
}

# ---------------------------------------------------------------------------
# Priority override tests
# ---------------------------------------------------------------------------

@test "identity: GRAVATAR_USERNAME overrides all email sources" {
  export GRAVATAR_USERNAME="topuser"
  export GRAVATAR_EMAIL="lower@example.com"
  mkdir -p "$TEST_HOME/.config/gravatar-avatar-sync"
  printf '%s\n' 'cfg@example.com' > "$TEST_HOME/.config/gravatar-avatar-sync/email"
  export MOCK_GIT_EMAIL="git@example.com"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(curl_calls)" == *"https://gravatar.com/topuser.json"* ]]
  [[ "$(curl_calls)" != *"gravatar.com/avatar/"* ]]
}

@test "identity: username config file overrides all email sources" {
  mkdir -p "$TEST_HOME/.config/gravatar-avatar-sync"
  printf '%s\n' 'fileuser' > "$TEST_HOME/.config/gravatar-avatar-sync/username"
  export GRAVATAR_EMAIL="lower@example.com"
  export MOCK_GIT_EMAIL="git@example.com"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(curl_calls)" == *"https://gravatar.com/fileuser.json"* ]]
  [[ "$(curl_calls)" != *"gravatar.com/avatar/"* ]]
}

@test "identity: CLI email arg takes priority over GRAVATAR_EMAIL" {
  export GRAVATAR_EMAIL="env@example.com"
  run "$SCRIPT" "cli@example.com"
  [ "$status" -eq 0 ]
  local cli_hash env_hash
  cli_hash="$(printf '%s' "cli@example.com" | md5sum | awk '{print $1}')"
  env_hash="$(printf '%s' "env@example.com" | md5sum | awk '{print $1}')"
  [[ "$(curl_calls)" == *"gravatar.com/avatar/$cli_hash"* ]]
  [[ "$(curl_calls)" != *"gravatar.com/avatar/$env_hash"* ]]
}

@test "identity: GRAVATAR_EMAIL takes priority over email config file" {
  export GRAVATAR_EMAIL="env@example.com"
  mkdir -p "$TEST_HOME/.config/gravatar-avatar-sync"
  printf '%s\n' 'cfg@example.com' > "$TEST_HOME/.config/gravatar-avatar-sync/email"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local env_hash cfg_hash
  env_hash="$(printf '%s' "env@example.com" | md5sum | awk '{print $1}')"
  cfg_hash="$(printf '%s' "cfg@example.com" | md5sum | awk '{print $1}')"
  [[ "$(curl_calls)" == *"gravatar.com/avatar/$env_hash"* ]]
  [[ "$(curl_calls)" != *"gravatar.com/avatar/$cfg_hash"* ]]
}

@test "identity: email config file takes priority over git config email" {
  mkdir -p "$TEST_HOME/.config/gravatar-avatar-sync"
  printf '%s\n' 'cfg@example.com' > "$TEST_HOME/.config/gravatar-avatar-sync/email"
  export MOCK_GIT_EMAIL="git@example.com"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local cfg_hash git_hash
  cfg_hash="$(printf '%s' "cfg@example.com" | md5sum | awk '{print $1}')"
  git_hash="$(printf '%s' "git@example.com" | md5sum | awk '{print $1}')"
  [[ "$(curl_calls)" == *"gravatar.com/avatar/$cfg_hash"* ]]
  [[ "$(curl_calls)" != *"gravatar.com/avatar/$git_hash"* ]]
}

# ---------------------------------------------------------------------------
# Negative-case test
# ---------------------------------------------------------------------------

@test "identity: exits with error when no identity source is available" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No identity found"* ]]
}
