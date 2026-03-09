#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo ".env not found; creating from .env.example" >&2
  cp .env.example .env
fi

echo "Starting infrastructure (postgres, redis, minio)..."
docker compose up -d postgres redis minio

echo "Installing dependencies..."
npm install

echo "Repairing database object ownership..."
bash scripts/fix-db-ownership.sh

echo "Preparing Prisma client and database..."
npx prisma generate
npx prisma db push
npm run prisma:seed
npm run prisma:rls

echo "Starting API on http://localhost:${PORT:-3000}"
exec npm run start:dev
