#!/usr/bin/env bash
# fetch.sh — download an avatar image and validate its MIME type
#
# Exports:
#   fetch_avatar <url> <output_file>
#     Downloads the image at <url> into <output_file>.
#
#   validate_mime <file>
#     Prints the file extension (png|jpg|gif|webp) for the detected MIME type.
#     Exits non-zero for unsupported types.

fetch_avatar() {
  local url="$1"
  local output_file="$2"
  curl -fsSL "$url" -o "$output_file"
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
