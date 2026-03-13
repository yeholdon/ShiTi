# ShiTi Todo

Last updated: 2026-03-09

This file is the project progress source of truth for ongoing work.
When work status changes, update this file in the same change.

## Status legend

- `[x]` Completed
- `[-]` In progress
- `[ ]` Pending

## Completed

- `[x]` Multi-tenant foundation: auth, tenants, tenant members, tenant isolation, and Postgres RLS
- `[x]` Subject and taxonomy APIs: subjects, stages, grades, textbooks, chapters
- `[x]` Question core APIs: create, patch, detail, delete
- `[x]` Question content flows: stem, explanation, source
- `[x]` Question answer modes: single choice, fill blank, solution
- `[x]` Question tags: create/list/delete tags and assign tags to questions
- `[x]` Question taxonomy assignment and list filtering by taxonomy
- `[x]` Question import with taxonomy persistence
- `[x]` Asset upload flow with presigned MinIO URLs
- `[x]` Asset reference validation across questions, imports, and layout elements
- `[x]` Layout elements CRUD for handout documents
- `[x]` Documents: create, list, detail, rename, delete
- `[x]` Document items: add, bulk add, reorder, remove
- `[x]` Export jobs with PDF generation, layout rendering, and image embedding
- `[x]` Health and readiness probes
- `[x]` Dev bootstrap scripts and DB ownership repair script
- `[x]` README and test coverage notes
- `[x]` Swagger UI and generated OpenAPI JSON at `/docs`
- `[x]` Public frontend landing page at `/` linking into `/admin` and `/docs`
- `[x]` Public frontend now separates user-facing teaching workspace pages from the backend admin console narrative
- `[x]` User-facing workspace page now includes a lightweight product-style prototype layout instead of only explanatory copy
- `[x]` Public frontend content pages for capability map, architecture, console guide, quick start, operations flow, and live status
- `[x]` Public status page enhancements: dependency board, recent snapshots, and lightweight trend view
- `[x]` Public frontend repositioned toward a cleaner teaching-research tool narrative instead of a pure infrastructure showcase
- `[x]` Detailed requirements-analysis and system-design documents are now stored in `docs/`
- `[x]` API contract outline, Flutter information architecture, and database DDL appendix are now stored in `docs/`
- `[x]` Optimized question-bank domain model and backend database/module design draft are now stored in `docs/`
- `[x]` Prisma domain draft and Nest module scaffold plan are now stored in `docs/`
- `[x]` Current Prisma schema vs target domain gap checklist is now stored in `docs/`
- `[x]` Phased schema migration plan is now stored in `docs/`
- `[x]` First runtime schema migration started: `QuestionExplanation` now supports additive `overviewBlocks` / `commentaryBlocks` fields alongside legacy latex fields
- `[x]` Second runtime schema migration started: `QuestionAnswerSolution` now supports additive `referenceAnswerBlocks` / `scoringPointsBlocks` fields alongside legacy answer fields
- `[x]` Backfill command now exists for explanation and solution latex-to-block migration of historical rows
- `[x]` Question detail reads now normalize legacy explanation/solution rows into the new block fields even before cleanup
- `[x]` System stage seed now aligns with the documented defaults, including 本科、考研、专升本
- `[x]` Subject decision is frozen: keep single-value `questions.subjectId`, and do not migrate to `question_subjects`
- `[x]` Admin console for tenant setup, question management, taxonomy management, assets, layout elements, documents, exports
- `[x]` Admin console improvements: question filters, question summaries, document summaries, document rename/delete
- `[x]` Admin console audit panel for tenant-scoped persistent audit log search, time presets, readable action summaries, username display, action/user aggregates, and target-type distribution

## In progress

- `[-]` Keep this TODO current as project work continues
- `[-]` Migrate from single-root Nest app toward target `apps/api + apps/worker + apps/flutter_app` structure without breaking the current backend
  - `apps/api` and `apps/worker` now have runnable entrypoints
  - e2e and Docker Compose now run API and worker as separate processes
  - e2e now seeds local default env vars for Postgres, Redis, and MinIO instead of relying on pre-exported shell state
  - `WorkerAppModule` now lives under `apps/worker`
  - `AppModule` now lives under `apps/api`
  - API and worker bootstrap implementations now live under `apps/api` and `apps/worker`
  - package scripts now expose explicit `api:*` and `worker:*` entrypoints while keeping legacy `start*` aliases for compatibility
  - API-only bootstrap shims now also live under `apps/api`; `src/bootstrap/` is down to shared lifecycle helpers
  - worker-only Nest module composition now also lives under `apps/worker`
  - API-only tenant resolve middleware and Express tenant type augmentation now live under `apps/api`, and their unit specs moved with them
  - the old root `src/main.ts` compatibility entry has been removed; runtime entrypoints are now `apps/api/main.ts` and `apps/worker/main.ts`
  - API-only `agent-team` module has moved under `apps/api/agent-team`
  - API-only `health` module has moved under `apps/api/health`
  - API-only `subjects` module has moved under `apps/api/subjects`
  - API-only `stages` module has moved under `apps/api/stages`
  - API-only `grades` module has moved under `apps/api/grades`
  - API-only `textbooks` module has moved under `apps/api/textbooks`
  - API-only `chapters` module has moved under `apps/api/chapters`
  - API-only `question-tags` module has moved under `apps/api/question-tags`
  - API-only `layout-elements` module has moved under `apps/api/layout-elements`
  - API-only `assets` module has moved under `apps/api/assets`
  - API-only `tenants`, `tenant-members`, and `auth` modules have moved under `apps/api`
  - API-only `documents`, `export-jobs`, and `questions` modules have moved under `apps/api`
  - shared question implementation (`questions-import.service`, `subject-access`, `taxonomy-access`, `explanation-blocks`) has moved under `src/domain/questions`
  - shared asset validation, taxonomy list helpers, and export-jobs worker implementation have moved under `src/domain/assets`, `src/domain/taxonomy`, and `src/domain/export-jobs`
  - API-only `metrics` module and request-context middleware have moved under `apps/api`
  - API-only audit controller/module composition has moved under `apps/api/audit`; shared `AuditLogService` remains in `src/common`
  - API-only `HttpErrorFilter` has moved under `apps/api`
  - export-jobs test fault injection helper now lives with the export-jobs shared domain implementation instead of root `src/common`
  - root `src/modules/` has been emptied; shared implementations now live under `src/domain/*`
  - remaining work is deeper module extraction and moving more shared implementation files out of `src/` when it creates real value
- `[-]` Start the real `apps/flutter_app` client scaffold for the cross-platform teaching workspace
  - manual Flutter app skeleton now exists under `apps/flutter_app` with `pubspec.yaml`, `lib/main.dart`, router, and initial workspace/library pages
  - Flutter client skeleton now also includes login, tenant-switch, app config, local API client, and session/tenant models so the app has a real page tree and data boundary
  - library state, local filter models, and question-detail route skeleton now exist so the client can progress toward real question list/detail API integration
  - question basket and documents workspace skeleton now exist so the user-facing Flutter app has a first end-to-end teaching workflow shape
  - document-detail and export-list skeleton pages now exist so the Flutter app covers the first pass of search -> collect -> compose -> export
  - document-detail now also renders local document items and composition hints, so the client has started to model reorder/add-item style document workflows
  - local add-to-document and move-item actions now exist in the Flutter skeleton, so composition is no longer read-only
  - question-detail now also supports a first local “add to default document” flow, and documents workspace now supports local document creation
  - document-detail now supports a first local layout-element insertion flow, so handout composition is no longer limited to question items
  - repository interfaces plus fake/remote adapters now exist in the Flutter app, but `AppConfig.useMockData` still defaults to local fake data until Flutter runtime verification is available
  - remote document adapters now better match the current backend API shapes for create, reorder, and remove item flows
  - AppServices now holds the active auth session and selected tenant, and the remote HTTP client can inject `Authorization` and `x-tenant-code` headers from that state
  - tenant selection now supports resolving a tenant by code, matching the current backend `GET /tenants/resolve` capability better than the earlier placeholder list-only flow
  - Flutter runtime mode is now switchable with `--dart-define=SHITI_USE_MOCK_DATA=true|false` instead of a hardcoded constant
  - remote HTTP failures are now surfaced as typed client exceptions, and login, tenant selection, and library pages show explicit remote-mode error states instead of failing silently
  - home, documents, and exports pages now also surface current mode/session/tenant context and explicit remote-mode failure/empty states
  - adding a question now goes through a shared “choose target document” picker instead of always forcing the default local handout
  - document detail now surfaces current mode/session/tenant context and explicit remote-mode load/action failures for reorder, remove, layout insertion, and export creation
  - home, library, and documents pages now expose direct “登录 / 选择租户” guidance actions in remote mode instead of only passive status text
  - remote question lists now also apply client-side subject/stage/textbook/query filtering after backend loads, and the library page exposes a clear-filters action so mock and remote filtering behavior stay aligned
  - login page now supports both “登录” and “注册并继续”, and tenant switch now supports creating a new tenant directly from the Flutter remote-mode flow
  - successful login/register now redirects straight into tenant selection, and the home page now probes real question/document loading in remote mode so users can immediately see whether backend workspace access is healthy
  - document creation dialog is now shared between the documents workspace and the target-document picker, so adding a question to a document no longer blocks when the workspace is still empty
  - Flutter CLI is now installed locally, and `flutter create` has generated `android/`, `ios/`, `macos/`, `web/`, and `windows/` project directories under `apps/flutter_app`
  - `flutter analyze` now passes
  - `flutter test` now passes when local proxy environment variables are unset for the test process
  - local machine still has Flutter doctor gaps for Android cmdline-tools/licenses, CocoaPods, Simulator runtimes, and Chrome path

## Backend completion notes

- `[x]` `/docs` now serves generated Swagger UI and `/docs/openapi.json`
- `[x]` List APIs across questions, documents, assets, layout elements, tags, taxonomy, audit logs, and export jobs now expose normalized pagination and sorting meta
- `[x]` Shared error envelopes, ValidationPipe, DTO validation, and UUID param validation now cover the primary write and detail routes
- `[x]` Export operations now cover history, retry, cancel, cleanup, queue-unavailable failure handling, and storage-read failure handling
- `[x]` Document composition now supports single add, bulk add, reorder, and remove
- `[x]` Asset lifecycle now covers upload rollback, reference-safe deletion, orphan cleanup, and persisted `originalFilename` metadata
- `[x]` Tenant RBAC now distinguishes `member`, `admin`, and `owner` across management APIs
- `[x]` Owners can now update tenant member roles via `PATCH /tenant-members/:id/role`
- `[x]` Sensitive maintenance operations such as asset cleanup and export cleanup are now owner-only
- `[x]` Redis-backed rate limiting now protects auth, asset upload creation, and export creation, with in-memory fallback during Redis outages
- `[x]` Observability now includes request IDs, structured request logs, Prometheus-style `/metrics`, health/readiness probes, and an operations runbook
- `[x]` Startup and shutdown lifecycle logging now emits structured `bootstrap_start`, `bootstrap_ready`, `bootstrap_failed`, `uncaught_exception`, `unhandled_rejection`, and `process_shutdown` events
- `[x]` Test depth now covers concurrency smoke tests plus degraded Redis, MinIO, queue, worker, and export-result failure paths
