#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <url> <output-path>" >&2
  exit 1
fi

url="$1"
output_path="$2"
delay_seconds="${CAPTURE_DELAY_SECONDS:-1}"
max_poll_attempts="${CAPTURE_MAX_POLL_ATTEMPTS:-20}"
window_left="${CAPTURE_WINDOW_LEFT:-160}"
window_top="${CAPTURE_WINDOW_TOP:-96}"
window_right="${CAPTURE_WINDOW_RIGHT:-1520}"
window_bottom="${CAPTURE_WINDOW_BOTTOM:-1040}"

mkdir -p "$(dirname "$output_path")"

bounds="$(
  osascript <<APPLESCRIPT
tell application "Microsoft Edge"
  activate
  if (count of windows) = 0 then
    make new window
  end if
  set bounds of front window to {${window_left}, ${window_top}, ${window_right}, ${window_bottom}}
  set URL of active tab of front window to "$url"
  delay ${delay_seconds}
  repeat ${max_poll_attempts} times
    if loading of active tab of front window is false then
      exit repeat
    end if
    delay 0.5
  end repeat
  delay 0.5
  get bounds of front window
end tell
APPLESCRIPT
)"

tmp_capture="$(mktemp "/tmp/edge-window-full.XXXXXX.png")"
screencapture -x "$tmp_capture"

python3 - "$tmp_capture" "$output_path" "$bounds" <<'PY'
import sys
from pathlib import Path

from PIL import Image

src_path = Path(sys.argv[1])
dest_path = Path(sys.argv[2])
bounds = [int(part.strip()) for part in sys.argv[3].split(",")]
left, top, right, bottom = bounds

with Image.open(src_path) as image:
    image.crop((left, top, right, bottom)).save(dest_path)
PY

rm -f "$tmp_capture"
echo "$output_path"
