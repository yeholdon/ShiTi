# Database DDL Appendix

Last updated: 2026-03-09

This appendix captures the intended database design rules and table families for the target ShiTi architecture.

It is not a complete executable migration file yet.
It is the structural reference that future schema work should align with.

## 1. Global Rules

- tenant-owned business tables include `tenant_id`
- tenant isolation must be enforceable through RLS
- cross-tenant references should be blocked structurally where possible
- system-owned rows and tenant-owned rows should be clearly separated

## 2. Tenant and User Family

Core tables:

- `users`
- `tenants`
- `tenant_members`

Key expectations:

- one user always owns one personal tenant
- one user can additionally belong to many organization tenants
- role is tenant-scoped
- one membership row per `(tenant_id, user_id)`

Recommended additive tenant fields:

- `kind`
  - `personal`
  - `organization`
- `personal_owner_user_id` nullable unique

Behavior rules:

- personal tenants do not accept extra tenant members
- organization tenants continue to use normal membership rows

## 3. Question Family

Core tables:

- `question_banks`
- `question_bank_grants`
- `questions`
- `question_contents`
- `question_choice_answers`
- `question_blank_answers`
- `question_solution_answers`

Associated relation tables:

- `question_tags`
- `question_stages`
- `question_grades`
- `question_textbooks`
- `question_chapters`

Design intent:

- `tenant_id` remains the workspace isolation root
- `question_bank_id` becomes the permission and collaboration boundary
- one question belongs to exactly one question bank
- personal cloud banks may be shared directly to specified users
- organization banks may be granted to organization members with `read / write`
- personal local banks are desktop-local and do not depend on server-side ACL

## 4. Taxonomy Family

Core tables:

- `subjects`
- `stages`
- `grades`
- `textbooks`
- `chapters`
- `tags`

Design intent:

- some taxonomy can be system-owned
- chapters are typically tenant-owned
- relation tables must respect tenant boundaries

## 5. Document Family

Core tables:

- `documents`
- `document_items`
- `layout_elements`

Design intent:

- ordered composition
- support for handout and paper
- no invalid cross-kind item composition

## 6. Asset and Export Family

Core tables:

- `assets`
- `export_jobs`

Design intent:

- assets map to MinIO objects
- object keys remain tenant-prefixed
- export jobs remain tenant-scoped
- result access remains tenant-scoped

## 7. Audit Family

Core table:

- `audit_logs`

Design intent:

- persistent
- tenant-scoped
- queryable by action, user, target type, and time range

## 8. RLS Appendix

Tenant-owned tables should follow the same RLS shape:

- enable RLS
- use request-local tenant state set by the app
- deny rows outside current tenant context

The backend request flow must keep DB session tenant context aligned with the authenticated tenant for every request transaction.

## 9. Composite Integrity Direction

When schema refactors are made toward the final architecture, prefer:

- tenant-aware unique keys
- composite foreign keys for tenant-owned child-parent links

Examples of intended direction:

- question-to-chapter
- question-to-textbook
- document-item-to-document
- export-result-to-export-job

## 10. Migration Note

Current Prisma schema is already tenant-aware and RLS-backed, but it should continue evolving toward this stricter composite-integrity model instead of relaxing away from it.
