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
#
# To add a new provider (e.g. "libravatar"):
#   1. Create lib/gravatar-avatar-sync/providers/libravatar.sh
#   2. Implement libravatar_resolve_url() following the contract above.
#   3. Set GRAVATAR_PROVIDER=libravatar in the environment or a config file.

gravatar_resolve_url() {
  local username="$1"
  local email="$2"
  local size="$3"
  local default_style="$4"
  local url=""

  if [[ -n "$username" ]]; then
    local profile_url profile_json
    profile_url="https://gravatar.com/${username}.json"
    profile_json="$(curl -fsSL "$profile_url")"

    # Prefer the explicit photo value; fall back to thumbnailUrl.
    # || true prevents pipefail from aborting when grep finds no match.
    url="$(printf '%s' "$profile_json" | grep -o '"value":"[^"]*"' | head -n 1 | cut -d '"' -f 4 | sed 's#\\/#/#g')" || true
    if [[ -z "$url" ]]; then
      url="$(printf '%s' "$profile_json" | grep -o '"thumbnailUrl":"[^"]*"' | head -n 1 | cut -d '"' -f 4 | sed 's#\\/#/#g')" || true
    fi

    if [[ -z "$url" ]]; then
      echo "Could not find photo URL in Gravatar profile for username: $username" >&2
      return 1
    fi

    if [[ "$url" == *\?* ]]; then
      url="${url}&s=${size}&d=${default_style}"
    else
      url="${url}?s=${size}&d=${default_style}"
    fi
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

