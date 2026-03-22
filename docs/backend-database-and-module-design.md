# Backend Database and Module Design

Last updated: 2026-03-09

This document translates the optimized question-bank domain requirements into a backend-oriented design draft.

## 1. Recommended Backend Stack

- NestJS
- PostgreSQL
- Redis + BullMQ
- MinIO
- Prisma

## 2. Core Database Table Families

## 2.1 Users

Suggested table:

- `users`
  - `id`
  - `username`
  - `password_hash`
  - `access_level`
  - `last_login_at`
  - `created_at`
  - `updated_at`

## 2.2 Tenants and membership

Recommended if multi-tenant direction remains:

- `tenants`
- `tenant_members`

Why keep this:

- aligns with strong isolation strategy
- supports organization-level data separation
- supports future paid/workspace-based product packaging

Recommended evolution:

- keep `tenants` as the only workspace root model
- add `tenants.kind = personal | organization`
- add `tenants.personal_owner_user_id` nullable unique

This lets one user own a private personal workspace while still joining multiple organizations, without introducing a second root workspace table.

## 2.3 Question banks

Suggested tables:

- `question_banks`
  - `id`
  - `tenant_id`
  - `name`
  - `storage_mode`
    - `cloud`
    - `local`
  - `owner_user_id`
  - `description`
  - `created_at`
  - `updated_at`

- `question_bank_grants`
  - `tenant_id`
  - `question_bank_id`
  - `user_id`
  - `access_level`
    - `read`
    - `write`
  - `granted_by_user_id`
  - `created_at`
  - `updated_at`

Design intent:

- `tenant_id` remains the workspace root boundary
- `question_bank_id` becomes the collaboration and permission boundary
- personal local banks stay desktop-local and do not depend on remote ACL
- personal cloud banks and organization banks use explicit grants

## 2.4 Questions

Suggested tables:

- `questions`
  - `id`
  - `tenant_id`
  - `question_bank_id`
  - `type`
  - `difficulty`
  - `default_score`
  - `visibility`
  - `created_at`
  - `updated_at`
  - `created_by`
  - `updated_by`

- `question_contents`
  - `question_id`
  - `tenant_id`
  - `stem_blocks`
  - `analysis_blocks`
  - `solution_blocks`
  - `comment_blocks`
  - `source_year`
  - `source_month`
  - `source_text`

Important note:

- `questions.visibility` should no longer be treated as the primary permission boundary once question-bank ACL exists
- actual access should resolve through:
  - workspace context
  - question-bank grants

## 2.5 Answer tables

Recommended split:

- `question_choice_answers`
  - `question_id`
  - `tenant_id`
  - `options_blocks`
  - `correct_keys`

- `question_blank_answers`
  - `question_id`
  - `tenant_id`
  - `answers`

- `question_solution_answers`
  - `question_id`
  - `tenant_id`
  - `reference_answer_blocks`
  - `scoring_points_blocks`

## 2.6 Taxonomy tables

Suggested:

- `subjects`
- `stages`
- `grades`
- `textbooks`
- `chapters`
- `question_tags`

Recommended relationships:

- `grades.stage_id -> stages.id`
- `chapters.textbook_id -> textbooks.id`
- question subject remains scalar via `questions.subject_id`; it is not modeled as many-to-many

## 2.7 Question relation tables

Suggested many-to-many tables:

- `question_stages`
- `question_grades`
- `question_textbooks`
- `question_chapters`
- `question_tag_maps`

Note:

- subject is intentionally excluded here because the product rule is one question -> one subject

## 2.8 Documents

Suggested tables:

- `documents`
  - `id`
  - `tenant_id`
  - `name`
  - `kind`
  - `created_at`
  - `updated_at`

- `document_items`
  - `id`
  - `tenant_id`
  - `document_id`
  - `item_type`
  - `ref_id`
  - `sort_order`

- `layout_elements`
  - `id`
  - `tenant_id`
  - `name`
  - `blocks`
  - `created_at`
  - `updated_at`

## 2.9 Assets and exports

Suggested tables:

- `assets`
  - `id`
  - `tenant_id`
  - `original_filename`
  - `mime_type`
  - `size_bytes`
  - `storage_key`
  - `created_at`

- `export_jobs`
  - `id`
  - `tenant_id`
  - `document_id`
  - `status`
  - `result_asset_id`
  - `error_message`
  - `created_at`
  - `updated_at`

## 2.10 Audit

Suggested table:

- `audit_logs`
  - `id`
  - `tenant_id`
  - `user_id`
  - `action`
  - `target_type`
  - `target_id`
  - `details`
  - `created_at`

## 3. Modeling Rules

## 3.1 LaTeX block model

Recommended block shape direction:

```json
{
  "type": "text | image | table | latex",
  "content": "...",
  "assetId": "optional",
  "meta": {}
}
```

Use this consistently for:

- question stem
- detailed solution blocks
- analysis/comment blocks
- choice options
- layout elements

## 3.2 Derived stats

Do not treat these as manually authored fields:

- document question count
- document average difficulty
- document question-tag or type counts

These should be computed from document items and question relations.

## 3.3 Security rules

- password must be hashed
- tenant-owned objects must remain tenant-scoped
- chapter must not exist without textbook
- paper must reject layout elements

## 4. NestJS Module Design

Recommended module boundaries:

- `auth`
- `users`
- `tenants`
- `tenant-members`
- `questions`
- `question-tags`
- `taxonomy`
- `documents`
- `layout-elements`
- `assets`
- `export-jobs`
- `audit`
- `health`
- `metrics`

## 5. Module Responsibilities

## 5.1 auth

- register
- login
- token validation

## 5.2 questions

- CRUD
- content update
- answer update
- source update
- taxonomy binding
- tag binding
- import
- search/list filters

## 5.3 taxonomy

- subject management
- stage management
- grade management
- textbook management
- chapter management

## 5.4 documents

- create/list/detail
- item add/bulk add/reorder/remove
- doc summary stats

## 5.5 layout-elements

- CRUD for handout-only layout content

## 5.6 assets

- upload metadata creation
- presigned upload
- list/detail/delete
- reference checks

## 5.7 export-jobs

- create
- list
- detail
- result fetch
- retry
- cancel
- cleanup

## 5.8 audit

- write sensitive operation logs
- list and aggregate audit history

## 6. API Design Direction

Key API groups:

- auth
- tenant context
- questions
- taxonomy
- question tags
- documents
- layout elements
- assets
- exports
- audit

The existing Swagger endpoint should remain the contract source for implementation details, while product-facing contract summaries live in repo docs.

## 7. Multi-platform Support Design

For Flutter all-end support, backend design should preserve:

- stable DTOs
- normalized list meta
- predictable error envelopes
- upload flows usable from mobile and desktop
- reusable question/document summary payloads

## 8. Orbstack and Local Environment Direction

Recommended local stack:

- PostgreSQL
- Redis
- MinIO
- API
- worker

Use Docker Compose under Orbstack for infra and integration testing.

## 9. Testing Direction

Priority coverage:

- question content validation
- answer mode validation
- taxonomy reference validity
- document constraints
- export lifecycle
- tenant isolation
- asset safety
- Flutter-facing list/detail contract stability
