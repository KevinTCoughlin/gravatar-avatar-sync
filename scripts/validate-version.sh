#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
numeric='(0|[1-9][0-9]*)'
prerelease_identifier='(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)'

if [[ ! "$version" =~ ^${numeric}\.${numeric}\.${numeric}(-${prerelease_identifier}(\.${prerelease_identifier})*)?$ ]]; then
  echo "Invalid semantic version: $version" >&2
  exit 1
fi
