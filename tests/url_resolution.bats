#!/usr/bin/env bats
# Tests for Gravatar URL resolution in gravatar-avatar-sync.
#
# Covers:
#   - Username path: uses "value" field from profile JSON photos array
#   - Username path: falls back to "thumbnailUrl" when "value" is absent
#   - Email path: builds avatar URL with MD5 hash, GRAVATAR_SIZE, GRAVATAR_DEFAULT
#   - Email address is lower-cased before hashing
#   - Negative: profile JSON with no photo URLs exits non-zero
#   - Negative: no identity exits non-zero

load helpers

setup() { setup_mocks; }
teardown() { teardown_mocks; }

# ---------------------------------------------------------------------------
# Username-based URL resolution
# ---------------------------------------------------------------------------

@test "url: username path uses 'value' field from profile JSON" {
  export GRAVATAR_USERNAME="testuser"
  # profile_json already contains a value field (set by helpers.bash)
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(curl_calls)" == *"https://example.com/photo.jpg?s=256&d=mp"* ]]
}

@test "url: username path falls back to thumbnailUrl when value field is absent" {
  export GRAVATAR_USERNAME="testuser"
  # Provide a profile JSON that has only thumbnailUrl, no photos.value
  printf '%s' '{"entry":[{"thumbnailUrl":"https:\/\/example.com\/thumb.jpg"}]}' \
    > "$MOCK_BIN/profile_json"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(curl_calls)" == *"https://example.com/thumb.jpg?s=256&d=mp"* ]]
}

@test "url: username path appends size and default style to photo URL (no existing query)" {
  export GRAVATAR_USERNAME="testuser"
  printf '%s' '{"entry":[{"photos":[{"value":"https:\/\/example.com\/photo.jpg","type":"thumbnail"}]}]}' \
    > "$MOCK_BIN/profile_json"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(curl_calls)" == *"?s=256&d=mp"* ]]
}

@test "url: username path appends size and default style with & when URL already has query" {
  export GRAVATAR_USERNAME="testuser"
  printf '%s' '{"entry":[{"photos":[{"value":"https:\/\/example.com\/photo.jpg?existing=1","type":"thumbnail"}]}]}' \
    > "$MOCK_BIN/profile_json"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(curl_calls)" == *"&s=256&d=mp"* ]]
}

# ---------------------------------------------------------------------------
# Email-based URL resolution
# ---------------------------------------------------------------------------

@test "url: email path builds avatar URL with MD5 hash of email" {
  export GRAVATAR_EMAIL="user@example.com"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local expected_hash
  expected_hash="$(printf '%s' "user@example.com" | md5sum | awk '{print $1}')"
  [[ "$(curl_calls)" == *"https://www.gravatar.com/avatar/$expected_hash"* ]]
}

@test "url: email path respects GRAVATAR_SIZE" {
  export GRAVATAR_EMAIL="user@example.com"
  export GRAVATAR_SIZE="512"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(curl_calls)" == *"?s=512&"* ]]
}

@test "url: email path respects GRAVATAR_DEFAULT" {
  export GRAVATAR_EMAIL="user@example.com"
  export GRAVATAR_DEFAULT="identicon"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(curl_calls)" == *"&d=identicon"* ]]
}

@test "url: email address is lower-cased before hashing" {
  run "$SCRIPT" "UPPER@EXAMPLE.COM"
  [ "$status" -eq 0 ]
  local lower_hash upper_hash
  lower_hash="$(printf '%s' "upper@example.com" | md5sum | awk '{print $1}')"
  upper_hash="$(printf '%s' "UPPER@EXAMPLE.COM" | md5sum | awk '{print $1}')"
  [[ "$(curl_calls)" == *"gravatar.com/avatar/$lower_hash"* ]]
  [[ "$(curl_calls)" != *"gravatar.com/avatar/$upper_hash"* ]]
}

# ---------------------------------------------------------------------------
# Negative cases
# ---------------------------------------------------------------------------

@test "url: exits with error when profile JSON contains no photo URLs" {
  export GRAVATAR_USERNAME="testuser"
  printf '%s' '{"entry":[{}]}' > "$MOCK_BIN/profile_json"
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Could not find photo URL"* ]]
}

@test "url: exits with error when no identity is available" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No identity found"* ]]
}
