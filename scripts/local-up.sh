#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

RUN_DIR="tmp/local-run"
mkdir -p "$RUN_DIR"

if [ ! -f .env ]; then
  echo ".env not found; relying on current shell and compose defaults" >&2
else
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${DATABASE_URL:=postgresql://qb_app:qb_app@localhost:5432/qb?schema=public}"
: "${RLS_ADMIN_DATABASE_URL:=postgresql://postgres:postgres@localhost:5432/qb?schema=public}"
: "${REDIS_URL:=redis://localhost:6379}"
: "${MINIO_ENDPOINT:=localhost}"
: "${MINIO_PORT:=9000}"
: "${MINIO_USE_SSL:=false}"
: "${MINIO_ACCESS_KEY:=minioadmin}"
: "${MINIO_SECRET_KEY:=minioadmin}"
: "${MINIO_BUCKET:=questionbank}"
: "${JWT_SECRET:=dev-secret-change-me}"
export DATABASE_URL RLS_ADMIN_DATABASE_URL REDIS_URL MINIO_ENDPOINT MINIO_PORT MINIO_USE_SSL MINIO_ACCESS_KEY MINIO_SECRET_KEY MINIO_BUCKET JWT_SECRET

start_service() {
  local name="$1"
  local command="$2"
  local port="${3:-}"
  local pattern="${4:-}"
  local log_file="$RUN_DIR/${name}.log"
  local pid_file="$RUN_DIR/${name}.pid"

  if [ -f "$pid_file" ]; then
    local existing_pid
    existing_pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
      echo "$name already running with pid $existing_pid"
      return
    fi
    rm -f "$pid_file"
  fi

  if [ -n "$port" ] && lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    local port_pids
    port_pids="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
    if [ -n "$port_pids" ]; then
      for pid in $port_pids; do
        if [ -z "$pattern" ] || ps -p "$pid" -o command= | grep -F "$pattern" >/dev/null 2>&1; then
          echo "Stopping stale $name listener on port $port (pid $pid)"
          kill "$pid" 2>/dev/null || true
          sleep 1
        fi
      done
    fi
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "$name already listening on port $port"
      return
    fi
  fi

  if [ -n "$pattern" ] && pgrep -f "$pattern" >/dev/null 2>&1; then
    echo "$name already running ($pattern)"
    return
  fi

  nohup bash -lc "$command" >"$log_file" 2>&1 &
  echo $! >"$pid_file"
  echo "Started $name (pid $(cat "$pid_file"))"
}

wait_for_url() {
  local name="$1"
  local url="$2"
  local curl_prefix="$3"

  for _ in $(seq 1 60); do
    if bash -lc "$curl_prefix curl -sSf '$url' >/dev/null" >/dev/null 2>&1; then
      echo "$name ready: $url"
      return 0
    fi
    sleep 1
  done

  echo "$name failed to become ready: $url" >&2
  return 1
}

detect_lan_ip() {
  ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
}

echo "Starting infrastructure (postgres, redis, minio)..."
docker compose up -d postgres redis minio

echo "Starting API / worker / Flutter web..."
start_service "api" "cd '$PWD' && exec env HOST=0.0.0.0 ./node_modules/.bin/ts-node apps/api/main.ts" "3000" "ts-node apps/api/main.ts"
start_service "worker" "cd '$PWD' && exec ./node_modules/.bin/ts-node apps/worker/main.ts" "" "ts-node apps/worker/main.ts"
start_service "flutter_web" "cd '$PWD/apps/flutter_app' && exec env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY flutter run -d web-server --web-hostname 0.0.0.0 --web-port 4111 --dart-define=SHITI_USE_MOCK_DATA=false --dart-define=SHITI_API_BASE_URL=http://127.0.0.1:3000" "4111" "flutter run -d web-server --web-hostname 0.0.0.0 --web-port 4111"

wait_for_url "API" "http://127.0.0.1:3000/health" ""
wait_for_url "Flutter web" "http://127.0.0.1:4111/" "env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY "

LAN_IP="$(detect_lan_ip)"

echo
echo "Local URLs:"
echo "  User app:    http://127.0.0.1:4111"
echo "  Admin:       http://127.0.0.1:3000/admin"
echo "  Docs:        http://127.0.0.1:3000/docs"
echo "  Health:      http://127.0.0.1:3000/health"

if [ -n "$LAN_IP" ]; then
  echo
  echo "LAN URLs:"
  echo "  User app:    http://$LAN_IP:4111"
  echo "  Admin:       http://$LAN_IP:3000/admin"
  echo "  Docs:        http://$LAN_IP:3000/docs"
fi

echo
echo "Logs:"
echo "  API:         $RUN_DIR/api.log"
echo "  Worker:      $RUN_DIR/worker.log"
echo "  Flutter web: $RUN_DIR/flutter_web.log"
