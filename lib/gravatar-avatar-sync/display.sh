#!/usr/bin/env bash
# display.sh — screen and DPI detection for avatar size selection
#
# Exports:
#   detect_avatar_size  → prints an integer pixel size to stdout

detect_avatar_size() {
  local max_dim scale_factor text_scale base_size detected_size
  max_dim=""
  scale_factor="1"
  text_scale="1"

  if command -v xrandr >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    max_dim="$(xrandr --current 2>/dev/null | awk '
      / connected/ {
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^[0-9]+x[0-9]+\+/) {
            split($i, a, /x|\+/)
            w = a[1] + 0
            h = a[2] + 0
            if (w > m) m = w
            if (h > m) m = h
          }
        }
      }
      END { if (m > 0) print m }
    ')"
  fi

  if command -v gsettings >/dev/null 2>&1; then
    scale_factor="$(gsettings get org.gnome.desktop.interface scaling-factor 2>/dev/null | awk '{print $NF}' || true)"
    text_scale="$(gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null | awk '{print $NF}' || true)"
    [[ "$scale_factor" =~ ^[0-9]+$ ]] || scale_factor="1"
    (( scale_factor < 1 )) && scale_factor="1"
    [[ "$text_scale" =~ ^[0-9]+([.][0-9]+)?$ ]] || text_scale="1"
    [[ -z "$scale_factor" ]] && scale_factor="1"
    [[ -z "$text_scale" ]] && text_scale="1"
  fi

  if [[ -n "$max_dim" ]]; then
    if (( max_dim >= 3840 )); then
      base_size=1536
    elif (( max_dim >= 2560 )); then
      base_size=1280
    elif (( max_dim >= 1920 )); then
      base_size=1024
    else
      base_size=768
    fi
  else
    base_size=1024
  fi

  detected_size="$(awk -v b="$base_size" -v s="$scale_factor" -v t="$text_scale" 'BEGIN {
    v = int((b * s * t) + 0.5)
    if (v < 512) v = 512
    if (v > 2048) v = 2048
    print v
  }')"
  printf '%s' "$detected_size"
}
