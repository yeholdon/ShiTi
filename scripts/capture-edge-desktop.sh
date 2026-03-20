#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <url> <output-path>" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"

export CAPTURE_WINDOW_LEFT="${CAPTURE_WINDOW_LEFT:-120}"
export CAPTURE_WINDOW_TOP="${CAPTURE_WINDOW_TOP:-72}"
export CAPTURE_WINDOW_RIGHT="${CAPTURE_WINDOW_RIGHT:-1640}"
export CAPTURE_WINDOW_BOTTOM="${CAPTURE_WINDOW_BOTTOM:-1320}"
export CAPTURE_POST_LOAD_DELAY_SECONDS="${CAPTURE_POST_LOAD_DELAY_SECONDS:-3}"

exec "$script_dir/capture-edge-window.sh" "$1" "$2"
