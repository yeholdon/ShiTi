#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

RUN_DIR="tmp/local-run"

stop_service() {
  local name="$1"
  local pattern="${2:-}"
  local port="${3:-}"
  local pid_file="$RUN_DIR/${name}.pid"

  if [ ! -f "$pid_file" ]; then
    echo "$name not running"
  else
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo "Stopped $name (pid $pid)"
    else
      echo "$name pid file existed, but process was not running"
    fi

    rm -f "$pid_file"
  fi

  if [ -n "$pattern" ]; then
    local pattern_pids
    pattern_pids="$(pgrep -f "$pattern" 2>/dev/null || true)"
    if [ -n "$pattern_pids" ]; then
      for pid in $pattern_pids; do
        kill "$pid" 2>/dev/null || true
      done
      echo "Stopped stale $name process(es) matching $pattern"
    fi
  fi

  if [ -n "$port" ]; then
    local port_pids
    port_pids="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
    if [ -n "$port_pids" ]; then
      for pid in $port_pids; do
        kill "$pid" 2>/dev/null || true
      done
      echo "Stopped stale $name listener(s) on port $port"
    fi
  fi
}

stop_service "flutter_web" "flutter run -d web-server --web-hostname 0.0.0.0 --web-port 4111" "4111"
stop_service "worker" "ts-node apps/worker/main.ts"
stop_service "api" "ts-node apps/api/main.ts" "3000"
