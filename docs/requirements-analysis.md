# Requirements Analysis

Last updated: 2026-03-09

This document captures the product requirements for ShiTi as a cross-platform teaching and question-bank system.

## 1. Product Positioning

ShiTi is not only a backend service or admin panel.
It is intended to become a cross-platform teaching-research product with:

- a user-facing teaching workspace for lesson preparation and content organization
- a separate backend management surface for governance and operations
- a strong multi-tenant backend with hard isolation guarantees

## 2. Product Goals

ShiTi should help teaching teams:

- collect and accumulate reusable questions
- classify questions by textbook, stage, grade, chapter, tags, and source
- compose handouts and papers from structured question data
- manage teaching assets such as images and supporting materials
- export teaching materials in a reliable and traceable way
- collaborate within tenant boundaries without cross-tenant leakage

## 3. Platforms

### 3.1 User-facing client

The user-facing product must support:

- mobile
- desktop

Preferred implementation direction:

- Flutter as the unified cross-platform client

### 3.2 Backend management surface

The backend management surface is a separate product surface intended for:

- tenant management
- audit review
- export maintenance
- system governance

This surface does not need to share the same UX language as the user-facing teaching workspace.

## 4. Core Users

### 4.1 Teacher / teaching staff

Primary needs:

- find questions quickly
- build handouts and papers
- reuse existing material
- work with textbook and chapter structure

### 4.2 Teaching-research operator / content editor

Primary needs:

- maintain high-quality structured question content
- tag and classify questions
- prepare reusable documents
- review imported content

### 4.3 Tenant administrator

Primary needs:

- manage tenant members and roles
- govern taxonomy and shared resources
- view audit trails
- manage high-risk operations

### 4.4 Platform operator / maintainer

Primary needs:

- observe system health
- handle queue/storage failures
- maintain export flows
- validate security and tenant isolation behavior

## 5. Functional Requirements

## 5.1 Authentication and tenant membership

The system must support:

- user registration and login
- one user always having one personal workspace
- one user optionally joining multiple organization tenants
- switching workspace context between personal and organization scopes
- per-tenant roles:
  - member
  - admin
  - owner

Additional expectations:

- a user may remain outside all organizations and still use the product through the personal workspace
- an organization may represent a school or a training institution
- one user may join multiple organizations
  - initial product recommendation: up to 5 organizations
- organization owners may create multiple organizations
- organization owners may designate multiple admins, with limits enforced by product policy if needed

## 5.2 Question bank

The system must support:

- question create, update, read, delete
- question content blocks
- explanation blocks
- source metadata
- answer modes:
  - choice
  - blank
  - solution
- question search and filtering
- import questions in batch

## 5.3 Taxonomy and tags

The system must support:

- subjects
- stages
- grades
- textbooks
- chapters
- question tags

Taxonomy requirements:

- questions must be bindable to the above dimensions
- system defaults and tenant-owned values must coexist where appropriate
- chapter and textbook constraints must remain valid inside one tenant scope

## 5.4 Documents

The system must support:

- paper documents
- handout documents
- document items
- layout elements
- reordering and removal
- bulk composition flows

## 5.5 Assets

The system must support:

- direct upload via presigned URLs
- tenant-scoped storage ownership
- safe deletion checks
- orphan cleanup
- original filename retention

## 5.6 Exports

The system must support:

- export job creation
- job status query
- result download
- retry
- cancel
- cleanup

## 5.7 Audit and governance

The system must support:

- persistent audit logs
- audit filtering by time, user, action, and target type
- audit statistics
- admin and owner restricted audit visibility

## 5.8 Admin operations

The backend management surface must support:

- tenant governance
- taxonomy maintenance
- asset maintenance
- export maintenance
- audit review
- role management
- health/readiness/metrics viewing

## 6. Separation of Product Surfaces

The product must be intentionally split into two surfaces:

### 6.1 User-facing teaching workspace

Characteristics:

- simple
- task-first
- low terminology load
- content-centered

Primary objects:

- personal workspace context
- organization workspace context
- recent materials
- question search
- question basket
- textbook/chapter navigation
- handout/paper composition
- export results

### 6.2 Backend management surface

Characteristics:

- governance-focused
- operational
- audit-friendly
- high-risk actions visible and controlled

Primary objects:

- organization identity
- roles
- exports
- audit logs
- system status
- cleanup operations

## 7. Multi-tenant Security Requirements

These are non-negotiable:

- every tenant-owned business table includes `tenant_id`
- cross-tenant access must be denied even if application filtering is accidentally missed
- child-to-parent references must not permit cross-tenant linkage
- asset paths and export results must remain tenant-scoped
- audit data must remain tenant-scoped

## 8. Non-functional Requirements

ShiTi must satisfy:

- strong tenant isolation
- traceability of sensitive actions
- observable runtime health
- recoverable export workflows
- reliable storage failure behavior
- rate limiting for abuse-prone endpoints
- contract clarity for future Flutter client consumption

## 9. Acceptance Themes

The following themes are acceptance-level requirements:

- cross-tenant reads do not leak
- cross-tenant references cannot be created
- role restrictions are enforced
- export results cannot cross tenant boundaries
- assets stay tenant-scoped in metadata and object storage paths
- system remains diagnosable during Redis, queue, and MinIO degradation

## 10. Delivery Direction

The target delivery shape is:

- NestJS API
- worker app
- PostgreSQL with RLS
- Redis and BullMQ
- MinIO
- Flutter full-end client

Static web pages inside this repository are transitional surfaces, not the final user-facing product architecture.
