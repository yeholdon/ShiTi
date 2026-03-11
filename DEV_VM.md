# qb-dev VM dev workflow

This repo is developed directly inside the `qb-dev` OrbStack VM.

Goal: avoid Docker bind-mounting host paths (which can make the running API read a different code copy).

## Services

- Postgres/Redis/MinIO: run via Docker Compose (inside the VM)
- API: run as a VM local process (ts-node)

## 0) Prereqs

- VM: `orb run -m qb-dev ...`
- In VM, repo path: `~/ .openclaw/workspace/smart-questionbank`

## 1) Start dependencies

Recommended first-time init (idempotent):

```bash
cd smart-questionbank
./scripts/init-db.sh
```

```bash
cd smart-questionbank
cp -n .env.example .env
# Ensure DATABASE_URL uses a non-superuser to make RLS effective:
# DATABASE_URL="postgresql://qb_app:qb_app@localhost:5432/qb?schema=public"

docker compose up -d postgres redis minio
```

If `qb_app` role doesn't exist yet:

```bash
# run once
cat prisma/create_app_role.sql | docker compose exec -T postgres psql -U postgres -d qb
```

## 2) Generate Prisma client

```bash
cd smart-questionbank
npx prisma generate
```

## 3) Run API (VM local)

```bash
cd smart-questionbank
set -a
. ./.env
set +a
npm run start:dev
```

## 4) Tests

Unit:

```bash
npm run test:unit
```

E2E (expects API listening on `http://localhost:3000`):

```bash
npm run test:e2e
```

All:

```bash
npm test
```

## Notes

- RLS: if the API connects as `postgres` (superuser), Postgres bypasses RLS and tenant isolation tests become meaningless.
- E2E uses unique tenant codes (timestamp suffix) to avoid cross-test data collisions.

## Recommended quick start

```bash
cd smart-questionbank
./scripts/dev-vm.sh
```
