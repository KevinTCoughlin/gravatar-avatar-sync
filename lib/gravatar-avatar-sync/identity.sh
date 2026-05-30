#!/usr/bin/env bash
# identity.sh — resolve the caller's Gravatar identity from environment / config / git
#
# Reads globals (must be set before sourcing the main script):
#   GRAVATAR_USERNAME, GRAVATAR_EMAIL
#   USERNAME_CONFIG_FILE, EMAIL_CONFIG_FILE
#
# Exports:
#   resolve_identity [email_arg]
#     Populates globals: USERNAME  EMAIL
#     (SOURCE_LABEL is set later by the active provider.)

resolve_identity() {
  local email_arg="${1:-}"

  # USERNAME: env var already assigned by caller → config file fallback
  if [[ -z "${USERNAME:-}" && -f "${USERNAME_CONFIG_FILE:-}" ]]; then
    USERNAME="$(<"$USERNAME_CONFIG_FILE")"
  fi
  USERNAME="$(printf '%s' "${USERNAME:-}" | xargs)"

  # EMAIL is only needed when USERNAME is empty
  if [[ -z "$USERNAME" ]]; then
    if [[ -n "$email_arg" ]]; then
      EMAIL="$email_arg"
    elif [[ -n "${GRAVATAR_EMAIL:-}" ]]; then
      EMAIL="$GRAVATAR_EMAIL"
    elif [[ -f "${EMAIL_CONFIG_FILE:-}" ]]; then
      EMAIL="$(<"$EMAIL_CONFIG_FILE")"
    else
      EMAIL="$(git config --global --get user.email || true)"
    fi
    EMAIL="$(printf '%s' "${EMAIL:-}" | tr '[:upper:]' '[:lower:]' | xargs)"
  fi
}
