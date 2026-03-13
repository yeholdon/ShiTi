#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example"
fi

# Load env vars for this shell.
set -a
# shellcheck disable=SC1091
. ./.env
set +a

echo "Starting dependencies (postgres/redis/minio)..."
docker compose up -d postgres redis minio

echo "Generating Prisma client..."
npx prisma generate

echo "Starting API (ts-node)..."
exec npm run api:dev
