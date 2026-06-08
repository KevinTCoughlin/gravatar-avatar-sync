#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$REPO_ROOT/bin/gravatar-avatar-sync"
MOCK_DIR="$SCRIPT_DIR/mocks"
SOCKET_READY_MAX_ATTEMPTS=10
SOCKET_READY_SLEEP_SECONDS=0.1

pass_count=0
fail_count=0

assert_file_exists() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Expected file to exist: $path"
    return 1
  fi
}

assert_contains() {
  local needle="$1"
  local haystack_file="$2"
  if ! grep -Fq "$needle" "$haystack_file"; then
    echo "Expected to find '$needle' in $haystack_file"
    echo "--- $haystack_file ---"
    cat "$haystack_file"
    return 1
  fi
}

setup_case_env() {
  CASE_ROOT="$(mktemp -d)"
  export HOME="$CASE_ROOT/home"
  export XDG_DATA_HOME="$CASE_ROOT/data"
  export PATH="$MOCK_DIR:$PATH"
  export MOCK_STATE_DIR="$CASE_ROOT/state"
  export GRAVATAR_USERNAME="integration-user"
  export GRAVATAR_SIZE="512"
  export MOCK_PROFILE_JSON='{"entry":[{"photos":[{"value":"https://cdn.example/avatar.png"}]}]}'
  mkdir -p "$HOME" "$XDG_DATA_HOME" "$MOCK_STATE_DIR"
  STDOUT_FILE="$CASE_ROOT/stdout.log"
  STDERR_FILE="$CASE_ROOT/stderr.log"
}

teardown_case_env() {
  if [[ -n "${SOCKET_PID:-}" ]]; then
    kill "$SOCKET_PID" >/dev/null 2>&1 || true
    wait "$SOCKET_PID" 2>/dev/null || true
    unset SOCKET_PID
  fi
  rm -rf "$CASE_ROOT"
  unset HOST_DBUS_SOCKET MOCK_MIME_TYPE MOCK_GDBUS_PRIMARY_RESULT MOCK_GDBUS_FALLBACK_RESULT
}

run_sync() {
  local rc
  set +e
  "$TARGET_SCRIPT" >"$STDOUT_FILE" 2>"$STDERR_FILE"
  rc=$?
  set -e
  return "$rc"
}

test_success_primary_dbus_and_file_writes() {
  setup_case_env
  export MOCK_MIME_TYPE="image/png"
  export MOCK_GDBUS_PRIMARY_RESULT="success"

  run_sync

  assert_file_exists "$XDG_DATA_HOME/avatars/gravatar-avatar.png"
  assert_file_exists "$HOME/.face"
  assert_file_exists "$HOME/.face.icon"
  assert_contains "primary|" "$MOCK_STATE_DIR/gdbus-calls.log"
  if grep -Fq "fallback|" "$MOCK_STATE_DIR/gdbus-calls.log"; then
    echo "Did not expect fallback gdbus call on primary success"
    return 1
  fi
  assert_contains "Updated avatar from Gravatar for integration-user" "$STDOUT_FILE"
}

start_unix_socket() {
  export HOST_DBUS_SOCKET="$CASE_ROOT/system_bus_socket"
  TEST_SOCKET_PATH="$HOST_DBUS_SOCKET" python - <<'PY' &
import os
import socket
import time

path = os.environ["TEST_SOCKET_PATH"]
try:
    os.unlink(path)
except FileNotFoundError:
    pass
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.bind(path)
s.listen(1)
while True:
    time.sleep(1)
PY
  SOCKET_PID=$!
  for ((attempt=0; attempt<SOCKET_READY_MAX_ATTEMPTS; attempt++)); do
    [[ -S "$HOST_DBUS_SOCKET" ]] && return 0
    sleep "$SOCKET_READY_SLEEP_SECONDS"
  done
  echo "Timed out waiting for fallback D-Bus socket to be ready"
  return 1
}

test_success_fallback_dbus() {
  setup_case_env
  export MOCK_MIME_TYPE="image/jpeg"
  export MOCK_GDBUS_PRIMARY_RESULT="fail"
  export MOCK_GDBUS_FALLBACK_RESULT="success"
  start_unix_socket

  run_sync

  assert_file_exists "$XDG_DATA_HOME/avatars/gravatar-avatar.jpg"
  assert_contains "primary|" "$MOCK_STATE_DIR/gdbus-calls.log"
  assert_contains "fallback|" "$MOCK_STATE_DIR/gdbus-calls.log"
}

test_failure_unsupported_mime() {
  setup_case_env
  export MOCK_MIME_TYPE="text/plain"
  export MOCK_GDBUS_PRIMARY_RESULT="success"

  if run_sync; then
    echo "Expected sync to fail for unsupported MIME type"
    return 1
  fi

  assert_contains "Unsupported image type: text/plain" "$STDERR_FILE"
}

test_failure_unreachable_dbus() {
  setup_case_env
  export MOCK_MIME_TYPE="image/png"
  export MOCK_GDBUS_PRIMARY_RESULT="fail"

  if run_sync; then
    echo "Expected sync to fail when system D-Bus is unreachable"
    return 1
  fi

  assert_contains "Unable to reach system D-Bus to set AccountsService icon." "$STDERR_FILE"
}

run_test() {
  local test_name="$1"
  if "$test_name"; then
    echo "PASS: $test_name"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $test_name"
    fail_count=$((fail_count + 1))
  fi
  teardown_case_env
}

run_test test_success_primary_dbus_and_file_writes
run_test test_success_fallback_dbus
run_test test_failure_unsupported_mime
run_test test_failure_unreachable_dbus

if [[ "$fail_count" -gt 0 ]]; then
  echo
  echo "Integration tests failed: $fail_count failed, $pass_count passed"
  exit 1
fi

echo
echo "Integration tests passed: $pass_count passed"
