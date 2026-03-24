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
bright_threshold="${CAPTURE_BRIGHT_THRESHOLD:-0.95}"
window_left="${CAPTURE_WINDOW_LEFT:-160}"
window_top="${CAPTURE_WINDOW_TOP:-96}"
window_right="${CAPTURE_WINDOW_RIGHT:-1520}"
window_bottom="${CAPTURE_WINDOW_BOTTOM:-1040}"
maximize_window="${CAPTURE_WINDOW_MAXIMIZE:-0}"
window_margin_left="${CAPTURE_WINDOW_MARGIN_LEFT:-0}"
window_margin_top="${CAPTURE_WINDOW_MARGIN_TOP:-24}"
window_margin_right="${CAPTURE_WINDOW_MARGIN_RIGHT:-0}"
window_margin_bottom="${CAPTURE_WINDOW_MARGIN_BOTTOM:-0}"
screencapture_bin="${CAPTURE_SCREENCAPTURE_BIN:-/usr/sbin/screencapture}"
lock_dir="${CAPTURE_LOCK_DIR:-/tmp/shiti-edge-capture.lock}"
lock_pid_file="$lock_dir/pid"
osascript_timeout_seconds="${CAPTURE_OSASCRIPT_TIMEOUT_SECONDS:-20}"

mkdir -p "$(dirname "$output_path")"

while ! mkdir "$lock_dir" 2>/dev/null; do
  if [[ -f "$lock_pid_file" ]]; then
    lock_holder_pid="$(cat "$lock_pid_file" 2>/dev/null || true)"
    if [[ -n "$lock_holder_pid" ]] && ! kill -0 "$lock_holder_pid" 2>/dev/null; then
      rm -rf "$lock_dir"
      continue
    fi
  fi
  sleep 0.2
done
echo "$$" >"$lock_pid_file"

cleanup() {
  if [[ ! -f "$lock_pid_file" ]] || [[ "$(cat "$lock_pid_file" 2>/dev/null || true)" == "$$" ]]; then
    rm -rf "$lock_dir"
  fi
}

run_osascript() {
  local timeout_seconds="$1"
  local script_file
  script_file="$(mktemp -t shiti-edge-osascript.XXXXXX)"
  cat >"$script_file"
  python3 - "$timeout_seconds" "$script_file" <<'PY'
import subprocess
import sys

timeout_seconds = float(sys.argv[1])
script_file = sys.argv[2]
try:
    completed = subprocess.run(
        ['osascript', script_file],
        capture_output=True,
        text=True,
        timeout=timeout_seconds,
        check=True,
    )
except subprocess.TimeoutExpired:
    print(f'osascript timed out after {timeout_seconds:.0f}s', file=sys.stderr)
    sys.exit(124)
except subprocess.CalledProcessError as error:
    sys.stderr.write(error.stderr)
    sys.exit(error.returncode)
else:
    sys.stdout.write(completed.stdout)
PY
  rm -f "$script_file"
}

trap cleanup EXIT

normalized_url="$url"
expected_hash=""
if [[ "$url" == http://* || "$url" == https://* ]]; then
  url_prefix="$url"
  url_hash=""
  if [[ "$url" == *"#"* ]]; then
    url_prefix="${url%%#*}"
    url_hash="#${url#*#}"
    expected_hash="${url#*#}"
  fi

  separator='?'
  if [[ "$url_prefix" == *"?"* ]]; then
    separator='&'
  fi

  normalized_url="${url_prefix}${separator}codex_capture_ts=$(date +%s%N)${url_hash}"
fi

window_payload="$(
  run_osascript "$osascript_timeout_seconds" <<APPLESCRIPT
tell application "Finder"
  set desktopBounds to bounds of window of desktop
end tell

set desktopLeft to item 1 of desktopBounds
set desktopTop to item 2 of desktopBounds
set desktopRight to item 3 of desktopBounds
set desktopBottom to item 4 of desktopBounds
set desktopWindowBounds to {desktopLeft + ${window_margin_left}, desktopTop + ${window_margin_top}, desktopRight - ${window_margin_right}, desktopBottom - ${window_margin_bottom}}

tell application "Microsoft Edge"
  activate
  set targetWindow to make new window
  if "${maximize_window}" is "1" then
    set bounds of targetWindow to desktopWindowBounds
  else
    set bounds of targetWindow to {${window_left}, ${window_top}, ${window_right}, ${window_bottom}}
  end if
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
  set finalUrl to URL of active tab of targetWindow
  return (id of targetWindow as text) & "|" & (item 1 of targetBounds as text) & "," & (item 2 of targetBounds as text) & "," & (item 3 of targetBounds as text) & "," & (item 4 of targetBounds as text) & "|" & finalUrl
end tell
APPLESCRIPT
)"

window_id="${window_payload%%|*}"
remaining_payload="${window_payload#*|}"
bounds="${remaining_payload%%|*}"
final_url="${remaining_payload#*|}"

tmp_capture="$(mktemp -t edge-window-full)"
for ((capture_attempt = 1; capture_attempt <= max_capture_attempts; capture_attempt++)); do
  run_osascript "$osascript_timeout_seconds" <<'APPLESCRIPT' >/dev/null
tell application "Microsoft Edge"
  activate
end tell
APPLESCRIPT
  sleep 0.2
  "$screencapture_bin" -x "$tmp_capture"

  capture_status="$(
    python3 - "$tmp_capture" "$output_path" "$bounds" "$blank_threshold" "$bright_threshold" "$expected_hash" "$final_url" <<'PY'
import sys
from pathlib import Path

from PIL import Image
from PIL import ImageStat

src_path = Path(sys.argv[1])
dest_path = Path(sys.argv[2])
bounds = [int(part.strip()) for part in sys.argv[3].split(",")]
blank_threshold = float(sys.argv[4])
bright_threshold = float(sys.argv[5])
expected_hash = sys.argv[6].strip()
final_url = sys.argv[7].strip()
left, top, right, bottom = bounds

with Image.open(src_path) as image:
    cropped = image.crop((left, top, right, bottom))
    analysis_top = min(max(88, int(cropped.height * 0.08)), max(cropped.height - 1, 1))
    analysis_region = cropped.crop((0, analysis_top, cropped.width, cropped.height))
    sampled = analysis_region.convert("RGB").resize((120, 80))
    pixels = sampled.load()
    near_white = 0
    total_pixels = sampled.width * sampled.height
    for y in range(sampled.height):
        for x in range(sampled.width):
            red, green, blue = pixels[x, y]
            if red > 245 and green > 245 and blue > 245:
                near_white += 1
    near_white_ratio = near_white / total_pixels
    grayscale = sampled.convert("L")
    stat = ImageStat.Stat(grayscale)
    pixels = list(grayscale.tobytes())
    stddev = stat.stddev[0]
    bright_ratio = sum(1 for value in pixels if value > 235) / len(pixels)
    cropped.save(dest_path)

hash_mismatch = bool(expected_hash) and f"#{expected_hash}" not in final_url
blank_like = (
    near_white_ratio >= blank_threshold
    or (near_white_ratio >= 0.6 and stddev < 12)
    or (bright_ratio >= bright_threshold and stddev < 10)
)
print("retry" if blank_like or hash_mismatch else "ok")
PY
  )"

  if [[ "$capture_status" == "ok" ]]; then
    break
  fi

  if (( capture_attempt < max_capture_attempts )); then
    run_osascript "$osascript_timeout_seconds" <<APPLESCRIPT >/dev/null
tell application "Microsoft Edge"
  activate
  repeat with browserWindow in windows
    if (id of browserWindow as text) is "$window_id" then
      tell active tab of browserWindow to reload
      repeat ${max_poll_attempts} times
        if loading of active tab of browserWindow is false then
          exit repeat
        end if
        delay 0.5
      end repeat
      exit repeat
    end if
  end repeat
end tell
APPLESCRIPT
    sleep "$post_load_delay_seconds"
    sleep "$retry_delay_seconds"
  fi
done

rm -f "$tmp_capture"
run_osascript "$osascript_timeout_seconds" <<APPLESCRIPT >/dev/null
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
