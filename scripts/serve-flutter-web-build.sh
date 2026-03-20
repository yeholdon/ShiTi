#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="${1:-$repo_root/apps/flutter_app/build/web}"
port="${2:-7361}"
host="${3:-127.0.0.1}"

if [[ ! -d "$build_dir" ]]; then
  echo "build directory not found: $build_dir" >&2
  exit 1
fi

echo "Serving Flutter web build from: $build_dir"
echo "URL: http://$host:$port/"

exec env \
  -u http_proxy \
  -u https_proxy \
  -u HTTP_PROXY \
  -u HTTPS_PROXY \
  -u all_proxy \
  -u ALL_PROXY \
  python3 -m http.server "$port" --bind "$host" --directory "$build_dir"
