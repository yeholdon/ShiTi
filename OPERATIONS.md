# ShiTi Operations Runbook

Last updated: 2026-03-09

This runbook is the operator-facing guide for production-oriented backend operations.

## Runtime Services

ShiTi backend depends on:

- Postgres
- Redis
- MinIO
- NestJS API process
- Export worker process

## Core Environment Variables

Required:

- `DATABASE_URL`
- `REDIS_URL`
- `JWT_SECRET`
- `MINIO_ENDPOINT`
- `MINIO_PORT`
- `MINIO_USE_SSL`
- `MINIO_ACCESS_KEY`
- `MINIO_SECRET_KEY`
- `MINIO_BUCKET`

Recommended:

- `PORT`
- `EXPORT_JOBS_WORKER_ENABLED`
- `NODE_ENV`

## Deployment Order

1. Start or verify `postgres`, `redis`, and `minio`.
2. Confirm MinIO bucket credentials are correct.
3. Run schema and policy sync:

```bash
npx prisma generate
npx prisma db push
npm run prisma:seed
npm run prisma:rls
```

4. Start the API process.
5. Start at least one export worker process with `EXPORT_JOBS_WORKER_ENABLED=1`.
6. Verify health endpoints:

```bash
curl -fsS http://localhost:3000/health
curl -fsS http://localhost:3000/health/ready
curl -fsS http://localhost:3000/metrics
```

## Smoke Checks After Deploy

Check these before declaring the environment healthy:

- `GET /health` returns `200`
- `GET /health/ready` returns `200` with database, Redis, and MinIO checks marked `ok`
- `GET /metrics` returns Prometheus-style text output
- `GET /docs` returns the built-in docs page
- `GET /admin` loads the admin console
- Create a test export job and confirm it leaves `pending`

## Database Ownership Repair

If Prisma reports `must be owner of table ...` or `must be owner of type ...`, repair ownership before running `db push`:

```bash
npm run db:fix-ownership
```

Then re-run:

```bash
npx prisma db push
npm run prisma:rls
```

## Backup

### Postgres

Create a logical backup:

```bash
pg_dump "$DATABASE_URL" > shiti-backup-$(date +%F-%H%M%S).sql
```

Recommended cadence:

- Daily logical backup
- Pre-deploy backup before schema changes

### MinIO

Back up the object bucket contents separately from Postgres. The database only stores metadata and references.

At minimum:

- Snapshot the `MINIO_BUCKET`
- Keep the snapshot timestamp aligned with the database backup window

## Restore

### Postgres restore

Restore into an empty target database:

```bash
psql "$DATABASE_URL" < shiti-backup-YYYY-MM-DD-HHMMSS.sql
```

Then re-apply generated client and RLS:

```bash
npx prisma generate
npm run prisma:rls
```

### MinIO restore

Restore the bucket snapshot that matches the database backup window. If database rows reference assets that are not restored, asset downloads and export embedding can fail.

## Migration Guidance

ShiTi currently uses Prisma schema push for development-style schema sync. Treat production schema changes carefully.

Recommended production procedure:

1. Take a fresh Postgres backup.
2. Review the Prisma diff on a staging clone first.
3. Apply `npx prisma db push` during a low-traffic window.
4. Re-run `npm run prisma:rls`.
5. Validate `/health/ready`, `/metrics`, and one end-to-end export flow.

## Failure Handling

### `/health/ready` returns non-200

Check:

- Postgres reachability and credentials
- Redis reachability and auth
- MinIO reachability, credentials, and bucket existence

### Export jobs stay `pending`

Check:

- `EXPORT_JOBS_WORKER_ENABLED`
- Redis connectivity
- Worker process logs
- BullMQ queue health

### Asset upload succeeds but files are missing

Check:

- presigned URL target bucket
- MinIO credentials
- client-side `PUT` completion
- bucket backup/restore integrity if after an incident

## Logs and Tracing

- Every API response includes `X-Request-Id`
- Error bodies include `requestId`
- Request logs are emitted as JSON lines with request id, status, duration, and tenant context

Use `requestId` to correlate a client error with backend logs.
