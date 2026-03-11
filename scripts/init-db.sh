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
APP_DB_PASS="${APP_DB_PASS:-qb_app}"

if [ -z "${APP_DB_PASS}" ]; then
  echo "APP_DB_PASS is empty" >&2
  exit 1
fi

echo "Ensuring dependencies are up (postgres)..."
docker compose up -d postgres

echo "Creating/updating app DB role: ${APP_DB_USER}"
# Use escaped $$ to avoid bash PID expansion.
docker compose exec -T postgres psql -U postgres -d "${DB_NAME}" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${APP_DB_USER}') THEN
    CREATE ROLE ${APP_DB_USER} LOGIN PASSWORD '${APP_DB_PASS}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
  END IF;
END \$\$;

ALTER ROLE ${APP_DB_USER} WITH PASSWORD '${APP_DB_PASS}';

GRANT CONNECT ON DATABASE ${DB_NAME} TO ${APP_DB_USER};
GRANT USAGE ON SCHEMA public TO ${APP_DB_USER};
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${APP_DB_USER};
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO ${APP_DB_USER};

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${APP_DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO ${APP_DB_USER};
SQL

echo "Applying RLS policies (prisma/rls.sql)"
cat prisma/rls.sql | docker compose exec -T postgres psql -U postgres -d "${DB_NAME}"

echo "FORCE RLS on key tenant tables"
docker compose exec -T postgres psql -U postgres -d "${DB_NAME}" <<SQL
ALTER TABLE "Question" FORCE ROW LEVEL SECURITY;
ALTER TABLE "TenantMember" FORCE ROW LEVEL SECURITY;
SQL

echo "Done. Ensure DATABASE_URL uses ${APP_DB_USER} (non-superuser) for RLS to be effective."
