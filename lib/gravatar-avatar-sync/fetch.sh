#!/usr/bin/env bash
# fetch.sh — HTTP transport policy and image validation
#
# All outbound HTTP in this project goes through http_curl so that timeout,
# retry, TLS and size limits are applied uniformly.
#
# Exports:
#   http_curl <curl args...>       Hardened curl invocation (HTTPS only).
#   http_get_body <url>            Downloads <url> and prints the body.
#   fetch_avatar <url> <out_file>  Downloads <url> into <out_file>.
#   validate_mime <file>           Prints png|jpg|gif|webp for the detected
#                                  MIME type; returns non-zero otherwise.
#
# Tunables (environment):
#   GRAVATAR_CURL_CONNECT_TIMEOUT, GRAVATAR_CURL_MAX_TIME,
#   GRAVATAR_CURL_RETRY, GRAVATAR_CURL_RETRY_DELAY, GRAVATAR_CURL_MAX_FILESIZE

http_curl() {
  curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --proto '=https' \
    --proto-redir '=https' \
    --connect-timeout "${GRAVATAR_CURL_CONNECT_TIMEOUT:-10}" \
    --max-time "${GRAVATAR_CURL_MAX_TIME:-45}" \
    --max-filesize "${GRAVATAR_CURL_MAX_FILESIZE:-10485760}" \
    --retry "${GRAVATAR_CURL_RETRY:-3}" \
    --retry-delay "${GRAVATAR_CURL_RETRY_DELAY:-2}" \
    --retry-all-errors \
    "$@"
}

http_get_body() {
  local url="$1"
  http_curl "$url"
}

fetch_avatar() {
  local url="$1"
  local output_file="$2"
  http_curl "$url" -o "$output_file"
}

validate_mime() {
  local file="$1"
  local mime_type ext
  mime_type="$(file --mime-type -b "$file")"
  case "$mime_type" in
    image/png)  ext="png"  ;;
    image/jpeg) ext="jpg"  ;;
    image/gif)  ext="gif"  ;;
    image/webp) ext="webp" ;;
    *)
      echo "Unsupported image type: $mime_type" >&2
      return 1
      ;;
  esac
  printf '%s' "$ext"
}
