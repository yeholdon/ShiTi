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
