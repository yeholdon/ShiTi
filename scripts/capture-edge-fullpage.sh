#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <url> <output-path>" >&2
  exit 1
fi

url="$1"
output_path="$2"
edge_executable="${EDGE_EXECUTABLE:-/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge}"
post_load_delay_ms="${CAPTURE_FULLPAGE_POST_LOAD_DELAY_MS:-2500}"
window_margin_left="${CAPTURE_WINDOW_MARGIN_LEFT:-0}"
window_margin_top="${CAPTURE_WINDOW_MARGIN_TOP:-24}"
window_margin_right="${CAPTURE_WINDOW_MARGIN_RIGHT:-0}"
window_margin_bottom="${CAPTURE_WINDOW_MARGIN_BOTTOM:-0}"
tmp_profile_dir="$(mktemp -d /tmp/shiti-edge-fullpage-profile.XXXXXX)"
debug_port="$(
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

cleanup() {
  if [[ -n "${edge_pid:-}" ]]; then
    kill "${edge_pid}" >/dev/null 2>&1 || true
    wait "${edge_pid}" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_profile_dir"
}

trap cleanup EXIT

mkdir -p "$(dirname "$output_path")"

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

"$edge_executable" \
  --remote-debugging-port="$debug_port" \
  --user-data-dir="$tmp_profile_dir" \
  --no-first-run \
  --no-default-browser-check \
  --new-window \
  about:blank >/dev/null 2>&1 &
edge_pid=$!

for _ in {1..40}; do
  if curl -fsS "http://127.0.0.1:${debug_port}/json/version" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

osascript <<APPLESCRIPT >/dev/null
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
  delay 0.6
  if (count of windows) > 0 then
    set bounds of front window to desktopWindowBounds
  end if
end tell
APPLESCRIPT

node /Users/honcy/Project/ShiTi/scripts/capture-edge-fullpage.js \
  "http://127.0.0.1:${debug_port}" \
  "$normalized_url" \
  "$output_path" \
  "$expected_hash" \
  "$post_load_delay_ms"

echo "$output_path"
