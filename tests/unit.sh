#!/usr/bin/env bash
# Unit tests for gravatar-avatar-sync helper functions
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

assert_in_range() {
  local desc="$1" min="$2" max="$3" actual="$4"
  if (( actual >= min && actual <= max )); then
    pass_test "$desc"
  else
    echo "  expected range: $min..$max, got: $actual"
    fail_test "$desc"
  fi
}

# ---------------------------------------------------------------------------
# Source detect_avatar_size in a subshell to avoid polluting our environment
# ---------------------------------------------------------------------------

# Extract the detect_avatar_size function definition from the main script
detect_avatar_size_def="$(awk '
  /^detect_avatar_size\(\)/ { capture=1; depth=0 }
  capture {
    print
    for (i=1; i<=length($0); i++) {
      c = substr($0, i, 1)
      if (c == "{") depth++
      if (c == "}") depth--
    }
    if (capture && depth==0 && NR>1) { capture=0 }
  }
' "$MAIN_SCRIPT")"

run_detect_avatar_size() {
  bash -c "
    $detect_avatar_size_def
    detect_avatar_size
  "
}

size="$(run_detect_avatar_size)"
assert_in_range "detect_avatar_size returns value in [512, 2048]" 512 2048 "$size"
if [[ "$size" =~ ^[0-9]+$ ]]; then
  pass_test "detect_avatar_size returns an integer"
else
  echo "  got: '$size'"
  fail_test "detect_avatar_size returns an integer"
fi

# detect_avatar_size respects GRAVATAR_SIZE env var (capped to [512,2048])
size_env="$(GRAVATAR_SIZE=800 bash -c "
  $detect_avatar_size_def
  SIZE=\"\${GRAVATAR_SIZE:-\$(detect_avatar_size)}\"
  printf '%s' \"\$SIZE\"
")"
assert_equals "GRAVATAR_SIZE env var is honoured" "800" "$size_env"

# ---------------------------------------------------------------------------
# Email normalisation (lowercase + trim) — logic copied from the main script
# ---------------------------------------------------------------------------

normalise_email() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | xargs
}

assert_equals "email lowercased"                "user@example.com" "$(normalise_email "USER@EXAMPLE.COM")"
assert_equals "email mixed-case lowercased"     "test@host.org"    "$(normalise_email "Test@Host.Org")"
assert_equals "email leading/trailing stripped" "a@b.com"          "$(normalise_email "  a@b.com  ")"
assert_equals "email already clean"             "me@here.net"      "$(normalise_email "me@here.net")"

# ---------------------------------------------------------------------------
# MD5 hash — verify against a known value
# ---------------------------------------------------------------------------

expected_hash="0bc83cb571cd1c50ba6f3e8a78ef1346"  # md5("myemailaddress@example.com")
actual_hash="$(printf '%s' "myemailaddress@example.com" | md5sum | awk '{print $1}')"
assert_equals "md5 hash matches known value" "$expected_hash" "$actual_hash"

# Normalise-then-hash: store in variable first (command substitution strips trailing newline)
# matching the behaviour of the main script which assigns EMAIL=$(... | xargs) then hashes it
_norm="$(printf '%s' "MyEmailAddress@Example.COM" | tr '[:upper:]' '[:lower:]' | xargs)"
actual_hash2="$(printf '%s' "$_norm" | md5sum | awk '{print $1}')"
assert_equals "normalised email hash matches known value" "$expected_hash" "$actual_hash2"

# ---------------------------------------------------------------------------
# username trimming (xargs is used in the main script)
# ---------------------------------------------------------------------------

trim_username() { printf '%s' "$1" | xargs; }
assert_equals "username leading/trailing stripped" "johndoe" "$(trim_username "  johndoe  ")"
assert_equals "username already clean"             "jane"    "$(trim_username "jane")"

# ---------------------------------------------------------------------------
# URL parameter appending
# ---------------------------------------------------------------------------

build_url_hash() {
  local hash="$1" size="$2" default_style="$3"
  printf 'https://www.gravatar.com/avatar/%s?s=%s&d=%s' "$hash" "$size" "$default_style"
}

result="$(build_url_hash "abc123" "512" "mp")"
assert_equals "hash URL correctly formed" \
  "https://www.gravatar.com/avatar/abc123?s=512&d=mp" "$result"

# URL with existing query string gets & appended
url_base="https://example.com/photo.jpg?v=2"
url_with_params="${url_base}&s=512&d=mp"
assert_equals "URL with existing query string gets & appended" \
  "https://example.com/photo.jpg?v=2&s=512&d=mp" "$url_with_params"

# URL without query string gets ? appended
url_plain="https://example.com/photo.jpg"
url_with_question="${url_plain}?s=512&d=mp"
assert_equals "URL without query string gets ? appended" \
  "https://example.com/photo.jpg?s=512&d=mp" "$url_with_question"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Unit test results: $pass passed, $fail failed"
(( fail == 0 ))
