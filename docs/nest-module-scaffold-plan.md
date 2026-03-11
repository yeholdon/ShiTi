# Nest Module Scaffold Plan

Last updated: 2026-03-09

This document describes the recommended NestJS scaffold layout for the next stage of ShiTi backend work.

## 1. Goal

Convert the current feature set into a cleaner module scaffold that is easier to maintain and eventually extract into:

- `apps/api`
- `apps/worker`

## 2. Recommended Structure

```text
src/
  common/
    audit/
    auth/
    dto/
    filters/
    guards/
    metrics/
    rate-limit/
  modules/
    auth/
    users/
    tenants/
    tenant-members/
    questions/
    taxonomy/
    question-tags/
    documents/
    layout-elements/
    assets/
    export-jobs/
    health/
  worker/
    exports/
```

## 3. Module Responsibilities

### auth

- register
- login
- JWT validation

Files expected:

- controller
- service
- DTOs
- guards if module-local

### users

- user profile
- last login tracking
- future account settings

### tenants

- tenant create
- tenant resolution
- future tenant settings

### tenant-members

- join tenant
- role update
- membership constraints

### questions

- CRUD
- content update
- source update
- answer modes
- import
- taxonomy and tag binding
- list filtering

Suggested internal folders:

- `dto/`
- `services/`
- `validators/`

### taxonomy

This can be one umbrella module or remain split by domain.

If merged:

- subjects
- stages
- grades
- textbooks
- chapters

### question-tags

- create/list/delete
- tenant/system distinction logic

### documents

- CRUD
- item add
- item bulk add
- item reorder
- item remove
- summary generation

### layout-elements

- CRUD
- handout-only constraints

### assets

- upload request
- list/detail
- safe delete
- cleanup
- reference validation

### export-jobs

- create/list/detail
- retry/cancel/cleanup
- result fetch
- worker handoff contract

### health

- liveness
- readiness

## 4. Cross-cutting Components

## 4.1 Guards

Recommended shared guards:

- auth guard
- tenant membership guard
- tenant role guard

## 4.2 Filters

- shared HTTP exception filter

## 4.3 Request context

- request ID
- tenant resolution
- DB transaction-local tenant setup

## 4.4 Audit

- shared service
- event recording helpers

## 4.5 Metrics

- HTTP request metrics
- process/runtime signals

## 5. Worker Split Direction

The worker should eventually leave the main runtime bootstrap path.

Suggested worker responsibilities:

- export queue consumption
- export rendering
- result persistence
- queue failure handling

Suggested worker folder direction:

```text
src/worker/exports/
  export.worker.ts
  export.renderer.ts
  export.storage.ts
```

## 6. API DTO Direction

DTOs should continue to be grouped close to each module:

```text
modules/questions/dto/
modules/documents/dto/
modules/assets/dto/
```

Validation rules should remain at DTO boundaries where possible.

## 7. Migration Advice

Do not rewrite the entire backend in one step.

Recommended order:

1. stabilize docs and target structure
2. separate worker bootstrap concerns
3. consolidate taxonomy scaffold
4. prepare API contracts for Flutter consumption
5. only then move source into `apps/api`

