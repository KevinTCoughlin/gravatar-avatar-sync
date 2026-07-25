#!/usr/bin/env bash
# providers/gravatar.sh — Gravatar avatar URL provider
#
# Provider interface contract
# ===========================
# Every provider script placed in lib/gravatar-avatar-sync/providers/ must
# implement exactly one public function following this signature:
#
#   <provider_name>_resolve_url <username> <email> <size> <default_style>
#
# Arguments:
#   username      — Gravatar username (may be empty)
#   email         — Normalized (lower-case, trimmed) e-mail address (may be empty
#                   when username is provided)
#   size          — Integer pixel size requested from the CDN
#   default_style — Gravatar default-image style (e.g. "mp", "identicon")
#
# Contract:
#   • Set the global variable PROVIDER_URL to the resolved image URL on success.
#   • Set the global variable SOURCE_LABEL to a human-readable identity string
#     (shown in the completion message).
#   • Return exit code 0 on success.
#   • Print a human-readable error message to stderr and return non-zero on failure.
#   • Perform all HTTP requests via http_get_body/http_curl (lib/fetch.sh) so the
#     shared timeout, retry and TLS policy applies.
#
# To add a new provider (e.g. "libravatar"):
#   1. Create lib/gravatar-avatar-sync/providers/libravatar.sh
#   2. Implement libravatar_resolve_url() following the contract above.
#   3. Set GRAVATAR_PROVIDER=libravatar in the environment or a config file.

# Appends the size and default-style query parameters to an arbitrary photo URL.
_gravatar_append_params() {
  local url="$1" size="$2" default_style="$3"
  if [[ "$url" == *\?* ]]; then
    printf '%s&s=%s&d=%s' "$url" "$size" "$default_style"
  else
    printf '%s?s=%s&d=%s' "$url" "$size" "$default_style"
  fi
}

# Extracts the photo URL from a Gravatar profile JSON document.
# Prefers the explicit photos[].value, falling back to thumbnailUrl.
# Returns non-zero when the document is not parseable JSON.
_gravatar_photo_url_from_profile() {
  local profile_json="$1" url
  url="$(printf '%s' "$profile_json" |
    jq -r '.entry[0] | (.photos[0].value? // .thumbnailUrl? // empty)' 2>/dev/null)" || return 1
  printf '%s' "$url"
}

gravatar_resolve_url() {
  local username="$1"
  local email="$2"
  local size="$3"
  local default_style="$4"
  local url=""

  if [[ -n "$username" ]]; then
    local profile_url profile_json
    profile_url="https://gravatar.com/${username}.json"
    if ! profile_json="$(http_get_body "$profile_url")"; then
      echo "Failed to fetch Gravatar profile for username: $username" >&2
      return 1
    fi

    if ! url="$(_gravatar_photo_url_from_profile "$profile_json")"; then
      echo "Could not parse Gravatar profile JSON for username: $username" >&2
      return 1
    fi
    if [[ -z "$url" ]]; then
      echo "Could not find photo URL in Gravatar profile for username: $username" >&2
      return 1
    fi
    if [[ "$url" != https://* ]]; then
      echo "Refusing non-HTTPS photo URL from Gravatar profile: $url" >&2
      return 1
    fi

    url="$(_gravatar_append_params "$url" "$size" "$default_style")"
    SOURCE_LABEL="$username"
  else
    if [[ -z "$email" ]]; then
      echo "No identity found. Set GRAVATAR_USERNAME, GRAVATAR_EMAIL, or config files." >&2
      return 1
    fi
    local hash
    hash="$(printf '%s' "$email" | md5sum | awk '{print $1}')"
    url="https://www.gravatar.com/avatar/${hash}?s=${size}&d=${default_style}"
    # shellcheck disable=SC2034
    SOURCE_LABEL="$email"
  fi

  # shellcheck disable=SC2034
  PROVIDER_URL="$url"
}
