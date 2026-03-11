#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo ".env not found; creating from .env.example" >&2
  cp .env.example .env
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

DB_NAME="${DB_NAME:-qb}"
APP_DB_USER="${APP_DB_USER:-qb_app}"

echo "Ensuring postgres is up..."
docker compose up -d postgres >/dev/null

echo "Reassigning public schema objects to ${APP_DB_USER}..."
docker compose exec -T postgres psql -U postgres -d "${DB_NAME}" <<SQL
DO \$\$
DECLARE
  obj RECORD;
BEGIN
  EXECUTE format('ALTER SCHEMA public OWNER TO %I', '${APP_DB_USER}');

  FOR obj IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE public.%I OWNER TO %I', obj.tablename, '${APP_DB_USER}');
  END LOOP;

  FOR obj IN
    SELECT sequencename
    FROM pg_sequences
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER SEQUENCE public.%I OWNER TO %I', obj.sequencename, '${APP_DB_USER}');
  END LOOP;

  FOR obj IN
    SELECT t.typname
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typtype IN ('e', 'd')
  LOOP
    EXECUTE format('ALTER TYPE public.%I OWNER TO %I', obj.typname, '${APP_DB_USER}');
  END LOOP;
END \$\$;
SQL

echo "Done."
