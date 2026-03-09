# ShiTi（拾题）Backend

ShiTi（拾题）是一个多租户题库后端，基于 NestJS、Prisma、Postgres、Redis 和 MinIO 构建。

## What Works

- Auth and tenant membership
- Multi-tenant isolation with application checks plus Postgres RLS
- Questions with content, explanations, source, answer modes, tags, and taxonomy
- Taxonomy management for subjects, stages, grades, textbooks, chapters, and question tags
- Documents for papers and handouts
- Layout elements for handouts
- Asset metadata plus presigned MinIO upload URLs
- Question import
- Export jobs with PDF generation, handout layout rendering, and image embedding
- Persistent audit logs for sensitive management actions
- Health and readiness probes
- Request IDs and structured JSON request logs for API traffic
- Redis-backed rate limiting with in-memory fallback for protected endpoints
- Tenant-role-aware write controls for management APIs

## Quick Start

1. Start infrastructure:

```bash
docker compose up -d postgres redis minio
```

2. Initialize database and seed defaults:

```bash
npx prisma generate
npx prisma db push
npm run prisma:seed
npm run prisma:rls
npm run prisma:backfill:block-fields
```

3. Start the API:

```bash
npm install
npm run start:dev
```

Or use the one-shot dev entrypoint:

```bash
npm run dev:up
```

This starts `postgres`, `redis`, and `minio` via Docker Compose, prepares Prisma, seeds defaults, reapplies RLS, then runs the API locally. It avoids relying on the Dockerized `api` service, which can be blocked by image pull/network issues.

If Prisma reports `must be owner of table ...`, repair ownership first:

```bash
npm run db:fix-ownership
```

Admin console:

```text
http://localhost:3000/admin
```

Public landing page:

```text
http://localhost:3000/
```

The admin console includes tenant-scoped audit log search for persistent `/audit-logs` records, with quick time presets, readable summaries for common actions, username display when a user can be resolved, and action/user/target-type aggregates for the current filter window.
The `/admin` UI has also been reshaped into a more operational console layout: a command deck at the top keeps the current user, tenant, and selected question/document/layout visible, and the workspace is split into clearer sections for question operations, document composition, taxonomy control, and audit review.
The root `/` page now serves as a lightweight frontend entry point for the project, introducing ShiTi’s core backend capabilities and linking operators into `/admin`, `/docs`, and the supporting `/site/*` content pages.
The public frontend now includes:

- `/site/workspace.html` for the user-facing teaching workspace prototype and interaction direction
- `/site/product.html` for the capability map
- `/site/architecture.html` for the runtime architecture view
- `/site/console.html` for `/admin` operator guidance
- `/site/operations.html` for runbook-style operator flow
- `/site/get-started.html` for handoff and onboarding
- `/site/status.html` for lightweight live status, dependency state, metrics summary, recent snapshots, and simple trend charts

The public-facing `/`, `/site/workspace.html`, and `/site/product.html` pages are now written more like a teaching-research tool than an infrastructure showcase: the primary story is question curation, taxonomy-driven reuse, document composition, and teacher workflow, while operator and observability views remain available as separate secondary routes.

Role model:

- Active `member` users can read tenant-scoped resources.
- `admin` and `owner` users can mutate management resources such as questions, documents, taxonomy, tags, assets, layout elements, and export job lifecycle operations.
- `owner` users can additionally update other tenant-member roles and run destructive maintenance flows such as asset cleanup and export cleanup.
- Non-owner users cannot self-grant elevated tenant roles through `POST /tenant-members`.
- Owners can grant or adjust tenant roles through `PATCH /tenant-members/:id/role`, while owners cannot demote themselves or remove the last owner role from a tenant.
- Audit log queries are restricted to `admin` and `owner` because they expose tenant-wide operator activity.

API docs:

```text
http://localhost:3000/docs
```

OpenAPI JSON:

```text
http://localhost:3000/docs/openapi.json
```

Operations runbook:

- `./OPERATIONS.md`
- Target architecture and migration direction:
  - `./docs/target-architecture.md`
- Requirements analysis:
  - `./docs/requirements-analysis.md`
- System design:
  - `./docs/system-design.md`
- API contract outline:
  - `./docs/api-contract-outline.md`
- Flutter information architecture:
  - `./docs/flutter-information-architecture.md`
- Database DDL appendix:
  - `./docs/database-ddl-appendix.md`
- Optimized question-bank domain model:
  - `./docs/question-bank-domain-model.md`
- Backend database and Nest module design draft:
  - `./docs/backend-database-and-module-design.md`
- Prisma domain draft:
  - `./docs/prisma-domain-draft.prisma`
- Nest module scaffold plan:
  - `./docs/nest-module-scaffold-plan.md`
- Schema migration plan:
  - `./docs/schema-migration-plan.md`
- Current schema vs target gap checklist:
  - `./docs/schema-gap-checklist.md`

4. Run tests:

```bash
npm run test:unit -- --runInBand
npm run test:e2e
```

## Core Endpoints

- `POST /auth/register`
- `POST /auth/login`
- `POST /tenant-members`
- `PATCH /tenant-members/:id/role`
- `GET /audit-logs`
- `GET /audit-logs/stats`
- `GET /health`
- `GET /health/ready`
- `GET /metrics`
- `GET/POST /subjects`
- `GET/POST /stages`
- `GET/POST /grades`
- `GET/POST /textbooks`
- `GET/POST /chapters`
- `GET/POST/DELETE /question-tags`
- `GET/POST/PATCH/DELETE /layout-elements`
- `GET /assets`
- `GET /assets/:id`
- `POST /assets/upload`
- `POST /assets/cleanup`
- `DELETE /assets/:id`
- `POST /questions`
- `POST /questions/import`
- `GET /questions`
- `GET /questions/:id`
- `PATCH /questions/:id`
- `PUT /questions/:id/content`
- `PUT /questions/:id/explanation`
- `PUT /questions/:id/source`
- `PUT /questions/:id/answer-choice`
- `PUT /questions/:id/answer-blank`
- `PUT /questions/:id/answer-solution`
- `PUT /questions/:id/tags`
- `PUT /questions/:id/taxonomy`
- `POST /documents`
- `GET /documents`
- `GET /documents/:id`
- `PATCH /documents/:id`
- `POST /documents/:id/items`
- `POST /documents/:id/items/bulk`
- `PATCH /documents/:id/items/reorder`
- `DELETE /documents/:id`
- `POST /export-jobs`
- `GET /export-jobs`
- `GET /export-jobs/:id`
- `POST /export-jobs/:id/cancel`
- `POST /export-jobs/:id/retry`
- `POST /export-jobs/cleanup`
- `GET /export-jobs/:id/result`

## Important Environment Variables

- `DATABASE_URL`
- `REDIS_URL`
- `JWT_SECRET`
- `MINIO_ENDPOINT`
- `MINIO_PORT`
- `MINIO_USE_SSL`
- `MINIO_ACCESS_KEY`
- `MINIO_SECRET_KEY`
- `MINIO_BUCKET`
- `EXPORT_JOBS_WORKER_ENABLED`

## Operational Notes

- `/health` is a liveness probe.
- `/health/ready` checks database, Redis, and MinIO connectivity.
- `/metrics` exposes Prometheus-style process uptime plus HTTP request counters grouped by status and method/status.
- `/docs` now serves Swagger UI, and `/docs/openapi.json` serves the generated OpenAPI document.
- Every API response carries `X-Request-Id`; clients can also supply it for trace correlation.
- Error responses include the same `requestId` as the response header.
- API requests are emitted as structured JSON logs with method, path, status code, duration, tenant code, and tenant id when available.
- Process lifecycle is also emitted as structured logs: startup now records `bootstrap_start` and `bootstrap_ready`, startup failures record `bootstrap_failed`, unhandled crashes record `uncaught_exception` / `unhandled_rejection`, and graceful termination records `process_shutdown`.
- `POST /questions/import` now rejects missing or oversized `items` payloads at the API entrypoint with the shared `validation_failed` error envelope.
- `npm run prisma:backfill:block-fields` backfills the additive explanation and solution block fields from legacy latex values for historical rows.
- Protected high-churn endpoints use Redis-backed rate limiting when Redis is available, and fall back to process-local buckets if Redis is temporarily unavailable.
- Tenant write-heavy management routes now require `admin` or `owner`; plain `member` remains read-capable for tenant-scoped resources.
- Asset upload is a two-step flow: create metadata via `POST /assets/upload`, then `PUT` bytes to the returned presigned URL.
- Asset metadata now preserves the caller-supplied `originalFilename` so editors and downstream export flows can retain user-facing file names.
- If MinIO bucket setup or presign generation fails during `POST /assets/upload`, the API now returns `503` and rolls back the just-created asset metadata row instead of leaving an unusable asset record behind.
- `POST /assets/cleanup` deletes stale unreferenced assets while preserving anything still referenced by questions, layouts, or export results.
- `POST /assets/cleanup` and `POST /export-jobs/cleanup` are restricted to tenant `owner` users because they perform destructive maintenance across tenant resources.
- Handout exports can render layout elements and embedded images.
- Audit logs are stored in Postgres, remain available across API restarts, can be filtered by action, target type, user, and time range via `GET /audit-logs`, and are restricted to `admin` / `owner`.
- Export jobs now support history listing, queued-job cancel, retry for failed/canceled jobs, and cleanup for stale or expired jobs; write-side export management also requires `admin` / `owner`.
- `/documents/:id/items/bulk` lets admins and owners append multiple question/layout items in one request while preserving per-item validation.
- Export result downloads now return `503` when the backing local file or object-storage read is temporarily unavailable, instead of exposing a generic storage error as a normal client-side failure.
- Export job control endpoints now also return `503` when queue access itself is temporarily unavailable, instead of partially mutating job state during `cancel`, `retry`, or `cleanup`.
- In test mode, queue fault injection is now exercised end-to-end so export creation has coverage for the full `503 + failed job persisted` path when the queue is unavailable.
- The repository currently focuses on backend APIs and integration coverage rather than a frontend app.
- Production-oriented deployment, backup, restore, and migration notes are collected in `OPERATIONS.md`.
