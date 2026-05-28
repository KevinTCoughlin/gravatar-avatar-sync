#!/usr/bin/env bash
# Integration tests for gravatar-avatar-sync — CI-safe (no real network or D-Bus calls)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN_SCRIPT="$REPO_ROOT/bin/gravatar-avatar-sync"

pass=0
fail=0

pass_test() { echo "PASS: $1"; (( pass++ )) || true; }
fail_test() { echo "FAIL: $1"; (( fail++ )) || true; }

assert_equals() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass_test "$desc"
  else
    echo "  expected: '$expected'"
    echo "  actual:   '$actual'"
    fail_test "$desc"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass_test "$desc"
  else
    echo "  expected to contain: '$needle'"
    echo "  got: '$haystack'"
    fail_test "$desc"
  fi
}

# ---------------------------------------------------------------------------
# Shared setup: create a temp mock directory and a temp home directory
# ---------------------------------------------------------------------------

MOCK_DIR="$(mktemp -d)"
FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "$MOCK_DIR" "$FAKE_HOME"' EXIT

# Helper: run the main script with mocked PATH prepended and an isolated HOME
run_script() {
  HOME="$FAKE_HOME" PATH="$MOCK_DIR:$PATH" bash "$MAIN_SCRIPT" "$@"
}

# ---------------------------------------------------------------------------
# Mock helper: write a simple executable to MOCK_DIR
# ---------------------------------------------------------------------------

install_mock() {
  local name="$1" body="$2"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$MOCK_DIR/$name"
  chmod +x "$MOCK_DIR/$name"
}

# ---------------------------------------------------------------------------
# Scenario 1: no identity supplied → script exits with a clear error message
# ---------------------------------------------------------------------------

unset GRAVATAR_EMAIL GRAVATAR_USERNAME || true

# Provide a curl stub so we don't hit the network; the script should exit
# before it ever calls curl, but have it available just in case.
install_mock curl 'echo "{}" ; exit 0'
install_mock gdbus 'exit 0'
install_mock file 'echo "image/jpeg"'

error_output="$(
  GRAVATAR_EMAIL="" GRAVATAR_USERNAME="" \
  HOME="$FAKE_HOME" PATH="$MOCK_DIR:$PATH" \
  bash "$MAIN_SCRIPT" 2>&1 || true
)"

assert_contains "no identity: exits with helpful message" "No identity found" "$error_output"

# ---------------------------------------------------------------------------
# Scenario 2: email provided via GRAVATAR_EMAIL → builds correct Gravatar URL
# ---------------------------------------------------------------------------

# Mock curl: first call (avatar download) writes a fake JPEG
# shellcheck disable=SC2016
install_mock curl '
  # Capture all arguments
  args=("$@")
  for i in "${!args[@]}"; do
    if [[ "${args[$i]}" == "-o" ]]; then
      outfile="${args[$((i+1))]}"
      # Minimal JPEG magic bytes
      printf "\xff\xd8\xff\xe0" > "$outfile"
      exit 0
    fi
  done
  # Profile JSON fallback (not needed for email path)
  echo "{}"
'

install_mock file 'echo "image/jpeg"'

# Stub commands that the script will call at the end but we cannot use in CI
install_mock gdbus 'exit 0'

output="$(
  GRAVATAR_EMAIL="test@example.com" \
  GRAVATAR_SIZE="256" \
  HOME="$FAKE_HOME" PATH="$MOCK_DIR:$PATH" \
  bash "$MAIN_SCRIPT" 2>&1
)"

assert_contains "email path: success message shown"      "Updated avatar from Gravatar" "$output"
assert_contains "email path: source label in output"     "test@example.com"             "$output"
assert_contains "email path: size shown in output"       "size=256"                     "$output"

# Verify the avatar files were placed in the fake home
if [[ -f "$FAKE_HOME/.face" ]]; then
  pass_test "email path: ~/.face created"
else
  fail_test "email path: ~/.face created"
fi
if [[ -f "$FAKE_HOME/.face.icon" ]]; then
  pass_test "email path: ~/.face.icon created"
else
  fail_test "email path: ~/.face.icon created"
fi

# ---------------------------------------------------------------------------
# Scenario 3: username provided via GRAVATAR_USERNAME → uses profile JSON
# ---------------------------------------------------------------------------

# Reset fake home so previous avatar files don't interfere
rm -rf "$FAKE_HOME"
FAKE_HOME="$(mktemp -d)"

# Mock curl: returns a profile JSON containing a photo URL on the first call,
# then writes a fake image on the second call (avatar download).
CALL_COUNT_FILE="$(mktemp)"
printf '0' > "$CALL_COUNT_FILE"

install_mock curl "
  count=\$(cat '$CALL_COUNT_FILE')
  count=\$(( count + 1 ))
  printf '%s' \"\$count\" > '$CALL_COUNT_FILE'

  args=(\"\$@\")
  for i in \"\${!args[@]}\"; do
    if [[ \"\${args[\$i]}\" == \"-o\" ]]; then
      outfile=\"\${args[\$(( i + 1 ))]}\"
      printf '\xff\xd8\xff\xe0' > \"\$outfile\"
      exit 0
    fi
  done

  # Profile JSON call
  printf '%s' '{\"entry\":[{\"photos\":[{\"value\":\"https://example.com/photo.jpg\"}],\"thumbnailUrl\":\"https://example.com/photo.jpg\"}]}'
"

install_mock file 'echo "image/jpeg"'
install_mock gdbus 'exit 0'

output="$(
  GRAVATAR_USERNAME="testuser" \
  GRAVATAR_SIZE="128" \
  HOME="$FAKE_HOME" PATH="$MOCK_DIR:$PATH" \
  bash "$MAIN_SCRIPT" 2>&1
)"

assert_contains "username path: success message shown"  "Updated avatar from Gravatar" "$output"
assert_contains "username path: source label in output" "testuser"                     "$output"

rm -f "$CALL_COUNT_FILE"

# ---------------------------------------------------------------------------
# Scenario 4: unsupported MIME type → script exits with error
# ---------------------------------------------------------------------------

# shellcheck disable=SC2016
install_mock curl '
  args=("$@")
  for i in "${!args[@]}"; do
    if [[ "${args[$i]}" == "-o" ]]; then
      printf "not an image" > "${args[$((i+1))]}"
      exit 0
    fi
  done
  echo "{}"
'
install_mock file 'echo "text/plain"'
install_mock gdbus 'exit 0'

mime_error="$(
  GRAVATAR_EMAIL="test@example.com" \
  GRAVATAR_SIZE="256" \
  HOME="$FAKE_HOME" PATH="$MOCK_DIR:$PATH" \
  bash "$MAIN_SCRIPT" 2>&1 || true
)"

assert_contains "unsupported MIME type: exits with error" "Unsupported image type" "$mime_error"

# ---------------------------------------------------------------------------
# Scenario 5: ShellCheck passes on all scripts (lint check as integration test)
# ---------------------------------------------------------------------------

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$MAIN_SCRIPT" "$REPO_ROOT/install.sh" "$REPO_ROOT/uninstall.sh" 2>&1; then
    pass_test "shellcheck passes on all shell scripts"
  else
    fail_test "shellcheck passes on all shell scripts"
  fi
else
  echo "SKIP: shellcheck not available"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Integration test results: $pass passed, $fail failed"
(( fail == 0 ))
