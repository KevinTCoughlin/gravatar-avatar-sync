#!/usr/bin/env bash
# Unit tests for gravatar-avatar-sync library functions.
#
# These tests source the production modules directly — they must never
# re-implement the logic under test, otherwise they stay green while the
# shipped code diverges.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$REPO_ROOT/lib/gravatar-avatar-sync"
DISPLAY_LIB="$LIB_DIR/display.sh"

# shellcheck source=../lib/gravatar-avatar-sync/display.sh
source "$DISPLAY_LIB"
# shellcheck source=../lib/gravatar-avatar-sync/identity.sh
source "$LIB_DIR/identity.sh"
# shellcheck source=../lib/gravatar-avatar-sync/providers/gravatar.sh
source "$LIB_DIR/providers/gravatar.sh"

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

assert_succeeds() {
  local desc="$1"
  shift
  if "$@" 2>/dev/null; then
    pass_test "$desc"
  else
    fail_test "$desc"
  fi
}

assert_fails() {
  local desc="$1"
  shift
  if "$@" 2>/dev/null; then
    fail_test "$desc"
  else
    pass_test "$desc"
  fi
}

# ---------------------------------------------------------------------------
# display.sh — detect_avatar_size
# ---------------------------------------------------------------------------

size="$(bash -c "source '$DISPLAY_LIB'; detect_avatar_size")"
assert_in_range "detect_avatar_size returns value in [512, 2048]" 512 2048 "$size"
if [[ "$size" =~ ^[0-9]+$ ]]; then
  pass_test "detect_avatar_size returns an integer"
else
  echo "  got: '$size'"
  fail_test "detect_avatar_size returns an integer"
fi

# ---------------------------------------------------------------------------
# identity.sh — trim / normalize_email
# ---------------------------------------------------------------------------

assert_equals "trim strips leading/trailing whitespace" "johndoe" "$(trim "  johndoe  ")"
assert_equals "trim leaves clean values untouched"      "jane"    "$(trim "jane")"
assert_equals "trim strips tabs and newlines"           "user"    "$(trim "$(printf '\t user \n')")"
assert_equals "trim preserves inner spaces"             "a b"     "$(trim "  a b  ")"

assert_equals "email lowercased"                "user@example.com" "$(normalize_email "USER@EXAMPLE.COM")"
assert_equals "email mixed-case lowercased"     "test@host.org"    "$(normalize_email "Test@Host.Org")"
assert_equals "email leading/trailing stripped" "a@b.com"          "$(normalize_email "  a@b.com  ")"
assert_equals "email already clean"             "me@here.net"      "$(normalize_email "me@here.net")"
# xargs-based trimming used to abort on unbalanced quotes; the pure-bash
# implementation must not.
assert_equals "email with a quote is not mangled" "o'brien@example.com" \
  "$(normalize_email "  O'Brien@Example.com ")"

# ---------------------------------------------------------------------------
# identity.sh — validation guards against URL/path injection
# ---------------------------------------------------------------------------

assert_succeeds "valid username accepted"            validate_username "john.doe-1_x"
assert_fails    "username with slash rejected"       validate_username "john/../admin"
assert_fails    "username with space rejected"       validate_username "john doe"
assert_fails    "empty username rejected"            validate_username ""
assert_succeeds "valid email accepted"               validate_email "user@example.com"
assert_fails    "email without domain dot rejected"  validate_email "user@example"
assert_fails    "email with space rejected"          validate_email "user @example.com"

# ---------------------------------------------------------------------------
# providers/gravatar.sh — URL construction
# ---------------------------------------------------------------------------

assert_equals "params appended with ? when URL has no query" \
  "https://example.com/photo.jpg?s=512&d=mp" \
  "$(_gravatar_append_params "https://example.com/photo.jpg" 512 mp)"

assert_equals "params appended with & when URL already has a query" \
  "https://example.com/photo.jpg?v=2&s=512&d=mp" \
  "$(_gravatar_append_params "https://example.com/photo.jpg?v=2" 512 mp)"

# ---------------------------------------------------------------------------
# providers/gravatar.sh — profile JSON parsing
# ---------------------------------------------------------------------------

assert_equals "photo value preferred over thumbnailUrl" \
  "https://example.com/photo.jpg" \
  "$(_gravatar_photo_url_from_profile \
    '{"entry":[{"photos":[{"value":"https:\/\/example.com\/photo.jpg"}],"thumbnailUrl":"https:\/\/example.com\/thumb.jpg"}]}')"

assert_equals "falls back to thumbnailUrl when photos are absent" \
  "https://example.com/thumb.jpg" \
  "$(_gravatar_photo_url_from_profile '{"entry":[{"thumbnailUrl":"https:\/\/example.com\/thumb.jpg"}]}')"

# Pretty-printed JSON broke the previous grep-based parser.
assert_equals "pretty-printed profile JSON is parsed" \
  "https://example.com/photo.jpg" \
  "$(_gravatar_photo_url_from_profile '{
     "entry": [
       {
         "hash": "abc",
         "photos": [ { "value": "https://example.com/photo.jpg", "type": "thumbnail" } ]
       }
     ]
   }')"

# An unrelated "value" key must not be mistaken for the photo URL.
assert_equals "unrelated value keys are ignored" \
  "https://example.com/photo.jpg" \
  "$(_gravatar_photo_url_from_profile '{
     "entry": [
       {
         "emails": [ { "primary": "true", "value": "someone@example.com" } ],
         "photos": [ { "value": "https://example.com/photo.jpg" } ]
       }
     ]
   }')"

assert_equals "profile without any photo yields empty string" \
  "" "$(_gravatar_photo_url_from_profile '{"entry":[{}]}')"

assert_fails "invalid profile JSON reports failure" \
  _gravatar_photo_url_from_profile 'not json at all'

# ---------------------------------------------------------------------------
# providers/gravatar.sh — email path builds the hashed avatar URL
# ---------------------------------------------------------------------------

expected_hash="0bc83cb571cd1c50ba6f3e8a78ef1346"  # md5("myemailaddress@example.com")
PROVIDER_URL=""
SOURCE_LABEL=""
gravatar_resolve_url "" "$(normalize_email "MyEmailAddress@Example.COM")" 512 mp
assert_equals "email path builds hashed avatar URL" \
  "https://www.gravatar.com/avatar/${expected_hash}?s=512&d=mp" "$PROVIDER_URL"
assert_equals "email path sets SOURCE_LABEL" "myemailaddress@example.com" "$SOURCE_LABEL"

PROVIDER_URL=""
assert_fails "empty identity reports failure" gravatar_resolve_url "" "" 512 mp

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Unit test results: $pass passed, $fail failed"
(( fail == 0 ))
