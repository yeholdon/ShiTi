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
lock_dir="${CAPTURE_LOCK_DIR:-/tmp/shiti-edge-capture.lock}"

mkdir -p "$(dirname "$output_path")"

while ! mkdir "$lock_dir" 2>/dev/null; do
  sleep 0.2
done

cleanup() {
  rm -rf "$lock_dir"
}

trap cleanup EXIT

normalized_url="$url"
if [[ "$url" == http://* || "$url" == https://* ]]; then
  url_prefix="$url"
  url_hash=""
  if [[ "$url" == *"#"* ]]; then
    url_prefix="${url%%#*}"
    url_hash="#${url#*#}"
  fi

  separator='?'
  if [[ "$url_prefix" == *"?"* ]]; then
    separator='&'
  fi

  normalized_url="${url_prefix}${separator}codex_capture_ts=$(date +%s%N)${url_hash}"
fi

window_payload="$(
  osascript <<APPLESCRIPT
tell application "Microsoft Edge"
  activate
  set targetWindow to make new window
  set bounds of targetWindow to {${window_left}, ${window_top}, ${window_right}, ${window_bottom}}
  set URL of active tab of targetWindow to "$normalized_url"
  set activeTabId to id of active tab of targetWindow
  repeat while (count of tabs of targetWindow) > 1
    repeat with candidateTab in tabs of targetWindow
      if (id of candidateTab) is not activeTabId then
        close candidateTab
        exit repeat
      end if
    end repeat
  end repeat
  delay ${delay_seconds}
  repeat ${max_poll_attempts} times
    if loading of active tab of targetWindow is false then
      exit repeat
    end if
    delay 0.5
  end repeat
  delay ${post_load_delay_seconds}
  set targetBounds to get bounds of targetWindow
  return (id of targetWindow as text) & "|" & (item 1 of targetBounds as text) & "," & (item 2 of targetBounds as text) & "," & (item 3 of targetBounds as text) & "," & (item 4 of targetBounds as text)
end tell
APPLESCRIPT
)"

window_id="${window_payload%%|*}"
bounds="${window_payload#*|}"

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
osascript <<APPLESCRIPT >/dev/null
tell application "Microsoft Edge"
  repeat with browserWindow in windows
    if (id of browserWindow as text) is "$window_id" then
      close browserWindow
      exit repeat
    end if
  end repeat
end tell
APPLESCRIPT
echo "$output_path"
