#!/usr/bin/env bash
# identity.sh — resolve the caller's avatar identity from environment / config / git
#
# Reads globals (must be set before calling resolve_identity):
#   USERNAME (seeded from GRAVATAR_USERNAME), GRAVATAR_EMAIL
#   USERNAME_CONFIG_FILE, EMAIL_CONFIG_FILE
#
# Exports:
#   trim <value>            Prints <value> without leading/trailing whitespace.
#   normalize_email <value> Prints the trimmed, lower-cased e-mail address.
#   resolve_identity [email_arg]
#     Populates globals: USERNAME  EMAIL
#     (SOURCE_LABEL is set later by the active provider.)
#
# Precedence (highest first):
#   GRAVATAR_USERNAME → username config file → CLI email arg → GRAVATAR_EMAIL
#   → email config file → git config --global user.email

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize_email() {
  local value
  value="$(trim "$1")"
  printf '%s' "${value,,}"
}

# Reject values that would be interpolated into a URL or shell-visible context.
validate_username() {
  local username="$1"
  if [[ ! "$username" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid username: '$username' (allowed: letters, digits, '.', '_', '-')." >&2
    return 1
  fi
}

validate_email() {
  local email="$1"
  if [[ ! "$email" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
    echo "Invalid e-mail address: '$email'." >&2
    return 1
  fi
}

resolve_identity() {
  local email_arg="${1:-}"

  # USERNAME: env var already assigned by caller → config file fallback
  if [[ -z "${USERNAME:-}" && -f "${USERNAME_CONFIG_FILE:-}" ]]; then
    USERNAME="$(<"$USERNAME_CONFIG_FILE")"
  fi
  USERNAME="$(trim "${USERNAME:-}")"

  if [[ -n "$USERNAME" ]]; then
    validate_username "$USERNAME" || return 1
    return 0
  fi

  # EMAIL is only needed when USERNAME is empty
  if [[ -n "$email_arg" ]]; then
    EMAIL="$email_arg"
  elif [[ -n "${GRAVATAR_EMAIL:-}" ]]; then
    EMAIL="$GRAVATAR_EMAIL"
  elif [[ -f "${EMAIL_CONFIG_FILE:-}" ]]; then
    EMAIL="$(<"$EMAIL_CONFIG_FILE")"
  else
    EMAIL="$(git config --global --get user.email || true)"
  fi
  EMAIL="$(normalize_email "${EMAIL:-}")"

  if [[ -n "$EMAIL" ]]; then
    validate_email "$EMAIL" || return 1
  fi
}
