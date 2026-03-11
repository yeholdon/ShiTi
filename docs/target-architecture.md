# Target Architecture

Last updated: 2026-03-09

This document defines the intended end-state architecture for ShiTi.
It is the migration target, not the current repository shape.

## Goal

Build ShiTi as:

- `NestJS` API
- `PostgreSQL` with `RLS`
- `Redis` with `BullMQ`
- `MinIO`
- `Flutter` for user-facing clients across mobile and desktop

## Product Surfaces

ShiTi should evolve into two clearly separated surfaces:

1. User-facing teaching workspace
   - lesson preparation
   - question search and reuse
   - document composition
   - export result access
   - simple, task-first UI

2. Backend admin console
   - tenant operations
   - taxonomy and system governance
   - export maintenance
   - assets cleanup
   - audit and observability

These two surfaces should not share the same UX language, navigation weight, or default priorities.

## Target Repository Shape

```text
apps/
  api/              NestJS HTTP API
  worker/           BullMQ workers, export jobs, background processors
  flutter_app/      Flutter mobile + desktop client
infra/
  compose/          docker-compose and local infra scripts
packages/
  contracts/        OpenAPI snapshots, DTO schema exports, shared API contracts
  docs/             generated docs or shared product/technical references
```

## Current State vs Target

Current repository state:

- single NestJS application in root
- worker logic still shares the same app codebase
- static `/admin` and `/site` pages are useful prototypes, not the final client architecture

Target state:

- API and worker become explicit apps
- Flutter becomes the primary user-facing client
- static pages become transitional documentation/prototype surfaces only

## Backend Rules That Must Survive Migration

- Every tenant-owned table keeps `tenant_id`
- Composite foreign keys are preferred for tenant-owned references
- RLS remains a hard isolation boundary
- request-scoped tenant context must still set DB session tenant state before business queries
- auditability, RBAC, and export isolation remain mandatory

## Migration Phases

### Phase 1

- keep current backend running
- document target architecture
- create future app folders
- stop expanding static pages as if they were the final client

### Phase 2

- extract API-specific runtime assumptions into `apps/api`
- extract worker bootstrap and job handling into `apps/worker`
- move local infra files toward `infra/compose`

### Phase 3

- scaffold `apps/flutter_app`
- define API client layer from OpenAPI
- start user-facing flows in Flutter:
  - auth
  - tenant switch
  - question browse/search
  - question basket
  - document list/detail

### Phase 4

- trim static `/site` pages into a lighter landing/prototype role
- keep `/admin` as backend admin surface until a more formal admin app is needed

## Immediate Next Build Priority

If execution starts on this target, the next engineering step should be:

1. scaffold `apps/flutter_app`
2. lock API contract shape for Flutter consumption
3. separate worker bootstrap from API bootstrap

