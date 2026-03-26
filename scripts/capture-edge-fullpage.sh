#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <url> <output-path> [storage-state-path]" >&2
  exit 1
fi

url="$1"
output_path="$2"
storage_state_path="${3:-}"
edge_executable="${EDGE_EXECUTABLE:-/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge}"
post_load_delay_ms="${CAPTURE_FULLPAGE_POST_LOAD_DELAY_MS:-2500}"
max_blank_retries="${CAPTURE_FULLPAGE_BLANK_RETRIES:-4}"
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

proxyless_env=(
  env
  -u http_proxy
  -u https_proxy
  -u HTTP_PROXY
  -u HTTPS_PROXY
  -u all_proxy
  -u ALL_PROXY
)

capture_is_blank() {
  local image_path="$1"
  python3 - "$image_path" <<'PY'
import sys

try:
    from PIL import Image
except ModuleNotFoundError:
    sys.exit(2)

image_path = sys.argv[1]
image = Image.open(image_path).convert("RGB")
samples_x = 40
samples_y = 40
darkish = 0

for xi in range(samples_x):
    for yi in range(samples_y):
        x = round((image.width - 1) * (xi / max(1, samples_x - 1)))
        y = round((image.height - 1) * (yi / max(1, samples_y - 1)))
        r, g, b = image.getpixel((x, y))
        if min(r, g, b) < 248:
            darkish += 1

sys.exit(0 if darkish == 0 else 1)
PY
}

reload_active_tab() {
  sleep 1
}

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
  if "${proxyless_env[@]}" curl -fsS "http://127.0.0.1:${debug_port}/json/version" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

for ((attempt = 1; attempt <= max_blank_retries; attempt += 1)); do
  "${proxyless_env[@]}" node /Users/honcy/Project/ShiTi/scripts/capture-edge-fullpage.js \
    "http://127.0.0.1:${debug_port}" \
    "$normalized_url" \
    "$output_path" \
    "$expected_hash" \
    "$post_load_delay_ms" \
    "$storage_state_path"

  blank_check_status=0
  capture_is_blank "$output_path" || blank_check_status=$?

  if (( blank_check_status == 0 || blank_check_status == 2 )); then
    echo "$output_path"
    exit 0
  fi

  if (( attempt < max_blank_retries )); then
    reload_active_tab
    sleep 1
  fi
done

echo "captured screenshot remained blank after ${max_blank_retries} attempts" >&2
exit 1
