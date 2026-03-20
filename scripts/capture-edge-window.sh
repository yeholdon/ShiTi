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
post_load_delay_seconds="${CAPTURE_POST_LOAD_DELAY_SECONDS:-2}"
max_capture_attempts="${CAPTURE_MAX_CAPTURE_ATTEMPTS:-4}"
retry_delay_seconds="${CAPTURE_RETRY_DELAY_SECONDS:-2}"
blank_threshold="${CAPTURE_BLANK_THRESHOLD:-0.8}"
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
  tell front window
    set bounds to {${window_left}, ${window_top}, ${window_right}, ${window_bottom}}
    make new tab
    set active tab index to (count of tabs)
    set URL of active tab to "$url"
  end tell
  delay ${delay_seconds}
  repeat ${max_poll_attempts} times
    if loading of active tab of front window is false then
      exit repeat
    end if
    delay 0.5
  end repeat
  delay ${post_load_delay_seconds}
  get bounds of front window
end tell
APPLESCRIPT
)"

tmp_capture="$(mktemp -t edge-window-full)"
for ((capture_attempt = 1; capture_attempt <= max_capture_attempts; capture_attempt++)); do
  screencapture -x "$tmp_capture"

  capture_status="$(
    python3 - "$tmp_capture" "$output_path" "$bounds" "$blank_threshold" <<'PY'
import sys
from pathlib import Path

from PIL import Image

src_path = Path(sys.argv[1])
dest_path = Path(sys.argv[2])
bounds = [int(part.strip()) for part in sys.argv[3].split(",")]
blank_threshold = float(sys.argv[4])
left, top, right, bottom = bounds

with Image.open(src_path) as image:
    cropped = image.crop((left, top, right, bottom))
    sampled = cropped.convert("RGB").resize((120, 80))
    pixels = sampled.load()
    near_white = 0
    total_pixels = sampled.width * sampled.height
    for y in range(sampled.height):
        for x in range(sampled.width):
            red, green, blue = pixels[x, y]
            if red > 245 and green > 245 and blue > 245:
                near_white += 1
    near_white_ratio = near_white / total_pixels
    cropped.save(dest_path)

print("retry" if near_white_ratio >= blank_threshold else "ok")
PY
  )"

  if [[ "$capture_status" == "ok" ]]; then
    break
  fi

  if (( capture_attempt < max_capture_attempts )); then
    sleep "$retry_delay_seconds"
  fi
done

rm -f "$tmp_capture"
echo "$output_path"
