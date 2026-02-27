# Smart Questionbank  Requirements Analysis & System Design

Last updated: 2026-02-28 (Asia/Shanghai)

This document translates the provided product/data-model requirements into an implementable system design for a multi-tenant intelligent question bank system.

## 0. Goals / Non-goals

### Goals (MVP)

- Manage questions with rich content (text/images/tables) authored and stored as LaTeX.
- Support 3 question types: single/multiple choice, fill-in-the-blank, and solution/essay.
- Support difficulty levels 1-5.
- Support explanation/solution content with required step-by-step solution and optional overview + comments.
- Support flexible tagging taxonomy: subject, stage, grade, textbook, chapter, question-type tags, and source.
- Support document composition: exam paper and handout; handout can include layout elements.
- Provide authentication/authorization for normal/admin (membership reserved).
- Deliver cross-platform apps: mobile + web + desktop with a shared codebase.
- Provide automated tests (unit + integration/e2e) for core flows.

### Non-goals (deferred)

- Full AI generation/grading pipeline (can be layered later).
- Collaborative real-time editing.
- Complex math/diagram editors beyond LaTeX input + preview.
- Payment/subscription enforcement (membership is reserved).

## 1. Product Requirement Breakdown

### 1.1 Question Core Model

Required:

- Question content (LaTeX) with multiple blocks; at least one text block required.
- Question type: `choice | blank | solution`.
- Difficulty: integer 1-5.
- Default score: number.
- Explanation: step-by-step solution required; overview + comments optional.
- Upload time and update time.

Optional / multi-value:

- Content blocks can be of type text, image, table; each can appear multiple times.
- Source (year, month, description) all optional; can be attached to question and optionally displayed in a composed document.
- Subject / stage / grade / textbook / chapter / question-type-tags are all tag dimensions; the system ships defaults but is user-extensible.
- One question can belong to multiple stages/grades.

### 1.2 Tag Model

Tag dimensions:

- Subject (default list + user custom)
- Stage (default list + user custom)
- Grade (rules: 1-9 with term up/down for primary+middle, plus standalone grade values: Zhongkao, Gaokao; other stages unsegmented)
- Textbook (default list + user custom)
- Chapter (user-defined, must reference textbook)
- QuestionTypeTag (user-defined)
- Source (year/month/desc)

Design note: treat most as tenant-scoped taxonomy tables rather than fixed enums to enable custom additions.

### 1.3 Document Model

- Document kinds: `paper` and `handout`.
- `paper` cannot include layout elements (only question list).
- `handout` can include layout elements (LaTeX blocks with text/images).
- Document has:
  - unique identifier
  - name (searchable)
  - tags used in document (question-type tag list)
  - derived stats: question count, average difficulty, per-type counts

### 1.4 User Model

- Internal user id
- Username unique, case-sensitive
- Password (currently plaintext per requirement; see Security note)
- Role: normal/member/admin
- last_login_at

Security note: storing plaintext passwords is strongly discouraged. Even for MVP, we should hash (argon2/bcrypt). If the plaintext requirement is strict for prototyping, restrict usage to isolated dev environments.

## 2. High-Level Architecture

### 2.1 Components

- Backend API (Node.js/TypeScript)
  - REST API for CRUD and composition
  - Auth + RBAC
  - Background jobs for export and heavy tasks
- Database: Postgres
  - Multi-tenant (tenant_id) + RLS enforced
- Cache/queue: Redis
  - Jobs, rate limiting, cache
- Object storage: MinIO (S3 compatible)
  - Store uploaded images, generated PDFs, and other artifacts
- Client apps (single codebase)
  - Flutter (recommended) targeting iOS/Android/Web/macOS/Windows

Why Flutter:

- One UI toolkit across mobile/web/desktop
- Mature state management and routing
- Easier consistent LaTeX rendering via webview/canvas approach where needed

Alternative: React + React Native + Tauri/Electron. That is viable but usually becomes multiple build surfaces.

### 2.2 Data Flow (typical)

- Author creates question -> client sends LaTeX blocks + tags -> API validates -> Postgres stores -> images go to MinIO
- User composes document -> API stores document structure -> background job generates PDF -> artifact stored in MinIO -> API returns download URL

## 3. Backend Domain Design

### 3.1 Multi-tenant Boundary

- Every tenant-scoped table includes `tenant_id`.
- API identifies tenant from JWT claims or request header (existing project likely already has this).
- Postgres RLS ensures tenant isolation even if application bugs occur.

### 3.2 Core Entities (proposed)

This is expressed at the conceptual level; implementation can use Prisma models.

#### Question

Fields:

- id (uuid)
- tenant_id
- type: `CHOICE | BLANK | SOLUTION`
- difficulty: int (1..5)
- default_score: numeric
- source_year?: int
- source_month?: int
- source_desc?: text
- created_at / updated_at

Relations:

- `question_contents` (1..n)
- `question_explanations` (1..1)
- many-to-many with tag dimensions:
  - subjects
  - stages
  - grades
  - textbooks
  - chapters
  - question_type_tags

#### ContentBlock (QuestionContent)

- id
- tenant_id
- question_id
- kind: `TEXT | IMAGE | TABLE`
- latex: text (LaTeX snippet; for image/table blocks, this may be a wrapper macro)
- asset_id?: uuid (for IMAGE)
- order: int

Design note: "text required" can be enforced by API validation: at least 1 ContentBlock with kind TEXT.

#### Explanation

- id
- tenant_id
- question_id (unique)
- overview_latex?: text
- steps_latex: text (required)
- comment_latex?: text

The requirement says steps follow the same standard format as question content (text/image/table multiple). If we want perfect symmetry, model steps as blocks too:

Option A (simpler): store `steps_latex` as one LaTeX document.

Option B (more structured, recommended): `explanation_blocks` same schema as ContentBlock with `section = OVERVIEW|STEPS|COMMENT` and `order`.

#### Taxonomy Tables (tenant-scoped)

- Subject(id, tenant_id, name)
- Stage(id, tenant_id, name)
- Grade(id, tenant_id, code, display_name, stage_rule)
- Textbook(id, tenant_id, name)
- Chapter(id, tenant_id, textbook_id, name, parent_id?)
- QuestionTypeTag(id, tenant_id, name)

And join tables:

- question_subjects(question_id, subject_id)
- question_stages(question_id, stage_id)
- question_grades(question_id, grade_id)
- question_textbooks(question_id, textbook_id)
- question_chapters(question_id, chapter_id)
- question_type_tags(question_id, tag_id)

#### Asset

- id
- tenant_id
- kind: `IMAGE | OTHER`
- storage_provider: `MINIO`
- bucket
- object_key
- mime
- size
- created_at

#### Document

- id (uuid)
- tenant_id
- kind: `PAPER | HANDOUT`
- name
- created_at / updated_at

#### DocumentItem

- id
- tenant_id
- document_id
- kind: `QUESTION | LAYOUT`
- question_id?: uuid
- layout_latex?: text
- order: int

Rule: for `PAPER`, only `QUESTION` items allowed; enforce in API.

#### DocumentDerivedStats

Derived values can be stored or computed:

- total_questions
- avg_difficulty
- per_question_type_counts (json)

Recommendation:

- For MVP, compute on read (SQL) to reduce complexity.
- If needed for performance, maintain via triggers or background recalculation.

### 3.3 API Surface (MVP)

- Auth
  - POST `/auth/register`
  - POST `/auth/login`
- Questions
  - POST `/questions`
  - GET `/questions` (filter by tags, type, difficulty, keyword)
  - GET `/questions/:id`
  - PATCH `/questions/:id`
  - DELETE `/questions/:id`
- Taxonomy
  - GET/POST for each dimension: `/subjects`, `/stages`, `/grades`, `/textbooks`, `/chapters`, `/question-type-tags`
- Assets
  - POST `/assets/upload` (presigned URL or multipart)
- Documents
  - POST `/documents`
  - GET `/documents` (search)
  - GET `/documents/:id`
  - PATCH `/documents/:id`
  - POST `/documents/:id/items`
  - DELETE `/documents/:id/items/:itemId`
- Export
  - POST `/exports` (document_id)
  - GET `/exports/:id` (status + artifact URL)

## 4. Client App Design (Flutter)

### 4.1 App Modules

- Auth (login/register)
- Question editor
  - Block editor: add text/image/table blocks
  - LaTeX preview
  - Tag selector
- Question list + search
- Document builder
  - Paper: question ordering
  - Handout: question + layout blocks
- Export center
  - export jobs list + download

### 4.2 LaTeX Rendering

- For preview:
  - Web: render via KaTeX/MathJax in a widget (webview or custom HTML)
  - Mobile/desktop: webview-based renderer for consistent output
- For PDF export:
  - Backend uses LaTeX engine or HTML->PDF pipeline (depends on existing implementation in this repo).

## 5. Testing Strategy

Backend:

- Unit tests
  - validation for question content rules
  - tag creation and uniqueness per tenant
- Integration tests
  - CRUD flows against test Postgres with RLS enabled
- E2E tests
  - register/login
  - create question with blocks + tags
  - compose document
  - export document and verify artifact

Client:

- Widget tests for key screens
- Integration tests (Flutter integration_test) for login + create question + export

CI:

- Run backend tests on every PR.
- Nightly job can run longer export tests.

## 6. Implementation Plan (Incremental)

Phase 0 (align scope)

- Confirm MVP scope and acceptance tests (what "done" means).

Phase 1 (data model + migrations)

- Implement taxonomy tables + question core tables in Prisma.
- Add RLS policies for new tables.

Phase 2 (API endpoints)

- CRUD for questions + tags.
- Asset upload and referencing.
- Document composition endpoints.

Phase 3 (export and formatting)

- Ensure export pipeline supports blocks (text/image/table) and explanation sections.
- Add robust E2E verification.

Phase 4 (clients)

- Bootstrap Flutter app(s) with shared API client.
- Implement main flows.

## 7. Open Questions (need product decisions)

- Choice question details: single vs multiple choice? option count? correct answer representation?
- Blank question: single blank vs multiple blanks? acceptable answers (set vs regex)?
- Solution question scoring rubric?
- Table block format: how is the LaTeX structured? do we allow custom environments?
- Image storage: do we embed via `\\includegraphics{}` macro pointing to signed URL, or custom macro resolved during export?
- Plaintext password requirement: can we switch to hashing?

## 8. Next Task Recommendation

To move forward efficiently, the next concrete task should be:

1. Convert the above conceptual schema into Prisma models + migrations (including join tables).
2. Add API validation rules for required blocks and explanation sections.
3. Add an E2E test that creates each question type with tags and verifies retrieval.

If you confirm the MVP scope, I can start with Phase 1 in the existing `smart-questionbank` backend.
