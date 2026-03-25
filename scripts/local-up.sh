#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

RUN_DIR="tmp/local-run"
mkdir -p "$RUN_DIR"

if [ ! -f .env ] && [ -f .env.example ]; then
  echo ".env not found; loading defaults from .env.example" >&2
  set -a
  # shellcheck disable=SC1091
  source .env.example
  set +a
elif [ ! -f .env ]; then
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
: "${DB_NAME:=qb}"
: "${APP_DB_USER:=qb_app}"
: "${APP_DB_PASS:=qb_app}"
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

  local started_pid
  started_pid="$(
    python3 - "$name" "$command" "$log_file" <<'PY'
import subprocess
import sys

name = sys.argv[1]
command = sys.argv[2]
log_file = sys.argv[3]

with open(log_file, "ab", buffering=0) as handle:
    process = subprocess.Popen(
        ["/Users/honcy/Project/ShiTi/scripts/local-supervise.sh", name, command],
        stdin=subprocess.DEVNULL,
        stdout=handle,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )

print(process.pid)
PY
  )"
  echo "$started_pid" >"$pid_file"
  echo "Started $name (pid $started_pid)"
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

wait_for_postgres_container() {
  for _ in $(seq 1 60); do
    if docker compose exec -T postgres pg_isready -U postgres -d qb >/dev/null 2>&1; then
      echo "Postgres ready: localhost:5432/qb"
      return 0
    fi
    sleep 1
  done

  echo "Postgres failed to become ready: localhost:5432/qb" >&2
  return 1
}

ensure_app_db_role() {
  echo "Ensuring app DB role exists: ${APP_DB_USER}"
  docker compose exec -T postgres psql -U postgres -d "${DB_NAME}" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${APP_DB_USER}') THEN
    CREATE ROLE ${APP_DB_USER} LOGIN PASSWORD '${APP_DB_PASS}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
  END IF;
END \$\$;

ALTER ROLE ${APP_DB_USER} WITH PASSWORD '${APP_DB_PASS}';
GRANT CONNECT ON DATABASE ${DB_NAME} TO ${APP_DB_USER};
GRANT USAGE, CREATE ON SCHEMA public TO ${APP_DB_USER};
ALTER SCHEMA public OWNER TO ${APP_DB_USER};
ALTER DATABASE ${DB_NAME} OWNER TO ${APP_DB_USER};
SQL
}

echo "Starting infrastructure (postgres, redis, minio)..."
docker compose up -d postgres redis minio

wait_for_postgres_container
ensure_app_db_role

echo "Syncing Prisma schema and seeds..."
npx prisma db push --skip-generate
npx prisma generate
npm run prisma:seed
npm run prisma:rls

echo "Building Flutter web preview..."
(
  cd "$PWD/apps/flutter_app"
  env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
    flutter build web --release --no-web-resources-cdn \
    --dart-define=SHITI_USE_MOCK_DATA=false \
    --dart-define=SHITI_API_BASE_URL=http://127.0.0.1:3000
)

echo "Starting API / worker / Flutter web..."
start_service "api" "cd '$PWD' && exec env HOST=0.0.0.0 ./node_modules/.bin/ts-node apps/api/main.ts" "3000" "ts-node apps/api/main.ts"
start_service "worker" "cd '$PWD' && exec ./node_modules/.bin/ts-node apps/worker/main.ts" "" "ts-node apps/worker/main.ts"
start_service "flutter_web" "cd '$PWD' && exec env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY /Users/honcy/Project/ShiTi/scripts/serve-flutter-web-build.sh '$PWD/apps/flutter_app/build/web' 4111" "4111" "serve-flutter-web-build.sh '$PWD/apps/flutter_app/build/web' 4111"

wait_for_url "API" "http://127.0.0.1:3000/health" ""
wait_for_url "Flutter web" "http://127.0.0.1:4111/" "env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY "

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
echo
echo "Supervisor status:"
echo "  API:         $RUN_DIR/api.status"
echo "  Worker:      $RUN_DIR/worker.status"
echo "  Flutter web: $RUN_DIR/flutter_web.status"
