# System Design

Last updated: 2026-03-09

This document describes the intended system design for ShiTi based on the current product direction.

## 1. Architecture Overview

ShiTi is designed as a tenant-isolated content platform with separate user and admin surfaces.

It should support two workspace modes under one shared context model:

- personal workspace
- organization workspace

Target components:

- `apps/api`: NestJS HTTP API
- `apps/worker`: BullMQ workers for exports and background jobs
- `apps/flutter_app`: Flutter mobile and desktop client
- PostgreSQL: primary data store
- Redis: queue and rate limiting
- MinIO: object storage

## 2. Core Design Principles

### 2.1 Strong tenant isolation

Tenant isolation must be enforced at multiple layers:

- request context
- application authorization
- composite relational integrity where possible
- PostgreSQL RLS

### 2.2 Separate product surfaces

- User-facing Flutter app is task-oriented and content-oriented
- Admin surface is governance-oriented and operational

### 2.3 Structured content

Question content, explanations, options, and layout-related content should favor block-based structured storage so the same data can be reused across:

- mobile
- desktop
- handouts
- papers
- export pipelines

## 3. Data Design

## 3.1 Tenant kinds

Tenant context should distinguish two modes:

- `personal`
  - exactly one per user
  - no extra members
  - private workspace for individual work
- `organization`
  - standard multi-member tenant
  - supports `member / admin / owner`
  - represents a school or training institution

Recommended additive fields on `tenants`:

- `kind`
- `personal_owner_user_id` nullable unique

This keeps one isolation model while allowing both personal and organization workspaces.

## 3.2 Tenant-owned tables

All tenant-owned tables should carry `tenant_id`.

Examples:

- questions
- question relations
- textbooks
- chapters
- documents
- document items
- assets
- export jobs
- audit logs

## 3.3 Relationship integrity

Where feasible, foreign keys should be tenant-aware so tenant scope is preserved structurally.

Preferred direction:

- composite uniqueness or composite foreign keys using tenant context
- application validation as the first guard
- DB structure as the last guard

## 3.4 System-level vs tenant-level data

Some data may have system-owned rows, such as default tags or default taxonomies.

Recommended approach:

- clearly distinguish system-owned rows from tenant-owned rows
- keep read rules explicit
- avoid ambiguous shared ownership semantics

## 3.5 RLS

Tenant-owned tables should use PostgreSQL RLS.

Expected runtime pattern:

1. request resolves tenant context
2. service opens a DB transaction
3. transaction sets request-local tenant state in the DB session
4. all business queries for that request run inside that same transaction scope

This makes RLS a real safety boundary instead of documentation.

The same runtime pattern should apply to both personal and organization tenants.

## 4. Backend Module Design

Recommended module boundaries:

- `auth`
- `tenants`
- `tenant-members`
- `questions`
- `taxonomy`
- `documents`
- `assets`
- `export-jobs`
- `audit`
- `health`
- `metrics`
- `tenant-context`

## 5. Request Flow

Typical request path:

1. client sends auth token and tenant context
2. Nest guard verifies identity and membership
3. tenant context is resolved
4. DB transaction is opened
5. transaction-local tenant session state is set
6. service logic runs
7. audit and metrics are emitted where relevant

## 6. Roles and Authorization

Tenant roles:

- `member`
- `admin`
- `owner`

Expected authorization split:

- `member`: tenant-scoped read flows
- `admin`: most tenant management write flows
- `owner`: destructive maintenance and role governance

Sensitive operations should remain owner-only where appropriate:

- cleanup operations
- role adjustment
- other broad-impact maintenance flows

Additional rules for tenant kinds:

- personal tenant:
  - owner is the same user as `personal_owner_user_id`
  - no additional members
  - no admin assignment
- organization tenant:
  - normal `member / admin / owner` rules apply

## 7. Question Model

Question design should support:

- stem blocks
- explanation blocks
- source metadata
- difficulty
- visibility
- tags
- taxonomy links
- typed answer data

Answer models should remain separated enough to preserve validation clarity:

- choice answer
- blank answer
- solution answer

## 8. Document Model

Documents should support:

- kind:
  - paper
  - handout
- ordered items
- layout elements
- batch insertion
- reordering
- export linkage

Business rules should remain explicit:

- paper and handout do not have identical layout behavior
- invalid document-item mixes should fail before export time

## 9. Asset Design

Assets should support:

- metadata row creation
- object storage upload via presigned URL
- tenant-prefixed storage keys
- reference validation
- safe deletion rules
- orphan cleanup

## 10. Export Design

Exports should run through BullMQ-backed jobs.

Expected job lifecycle:

- pending
- running
- succeeded
- failed
- canceled

Export control design should support:

- create
- list
- detail
- retry
- cancel
- cleanup
- result retrieval

Queue and storage failures should produce explicit, diagnosable failure semantics instead of partial state mutation.

## 11. Observability Design

The system design should retain:

- `/health`
- `/health/ready`
- `/metrics`
- request IDs
- structured request logs
- lifecycle logs
- audit logs

These are required both for operations and for validating tenant-sensitive actions.

## 12. Local Development Design

Local development is intended to run with Docker Compose-backed infrastructure:

- PostgreSQL
- Redis
- MinIO

The API and worker may run locally or in containers depending on the migration phase, but infrastructure services should remain easy to bootstrap consistently.

## 13. Testing Design

Testing must cover:

- unit tests for failure paths and validation
- e2e tests for API contracts
- tenant isolation tests
- queue/storage degradation tests
- concurrency smoke tests for critical flows

The acceptance focus should remain:

- no cross-tenant leakage
- no cross-tenant reference creation
- controlled role behavior
- explicit degradation under Redis/queue/MinIO failures

## 14. Repository Migration Direction

Current repository shape is transitional.

Migration direction:

1. keep current backend stable
2. formalize docs and target structure
3. extract API app
4. extract worker app
5. scaffold Flutter app
6. treat current static pages as prototype and documentation surfaces only
