# Schema Migration Plan

Last updated: 2026-03-09

This document converts the schema gap checklist into an execution sequence.

The goal is to migrate the current schema toward the target domain model without breaking the running backend.

## 1. Migration Rules

- prefer additive changes before destructive changes
- keep backward-compatible reads during intermediate phases
- preserve tenant isolation and RLS at every step
- do not migrate ambiguous business rules before the product decision is frozen

## 2. Decision Gate Before Runtime Changes

These questions must be answered before changing the runtime schema:

1. Subject cardinality is frozen: a question has one subject via `subjectId`.
2. Should explanation overview and commentary be block-based?
3. Should solution final answer become block-based?
4. Is a global user access level required, or are tenant roles sufficient?
5. Is personal workspace implemented as a special tenant kind? Decision: yes.

If a decision is not frozen, do not migrate that area yet.

## 3. Phase Plan

### Phase 1: Additive schema support

Safe first moves:

- add new optional fields or tables
- do not remove old fields
- keep current APIs readable

Typical examples:

- add `overviewBlocks` before removing `overviewLatex`
- add relation tables before removing scalar foreign keys

### Phase 2: Dual-read / dual-write support

Once additive schema exists:

- read both old and new shapes
- write new rows into the new shape
- keep old rows valid

This phase should be temporary, not permanent architecture.

### Phase 3: Backfill

After the write path stabilizes:

- migrate historical rows
- validate counts and integrity
- compare before/after data shape

### Phase 4: Cleanup

Only after backfill and compatibility testing:

- remove deprecated fields
- tighten constraints
- simplify service logic

## 4. Topic-by-Topic Migration Order

## 4.0 Personal workspace / organization split

Recommended first tenant-model migration.

Current state:

- users may exist without tenant membership
- business tables mostly require `tenantId`
- no durable personal workspace root exists

Target state:

- every user owns exactly one personal tenant
- organization membership remains many-to-many
- personal and organization workspaces share the same `tenantId`-based business tables

Migration path:

1. add `Tenant.kind`
2. add `Tenant.personalOwnerUserId`
3. backfill all existing tenants as `organization`
4. on registration/login bootstrap a personal tenant if missing
5. update tenant list/switch APIs to return both personal and organization workspaces
6. enforce that personal tenants do not accept extra members
7. add application-level organization membership limits and admin limits

Why first:

- it unlocks the target product model
- it avoids later rewriting all tenant-scoped content tables

## 4.1 Question-bank permission boundary

Current state:

- `Question` is directly tenant-scoped
- question access is effectively tenant-wide
- no question-bank container or ACL exists

Target state:

- every question belongs to one `QuestionBank`
- `tenantId` remains the workspace root
- question access resolves through question-bank ownership or grants
- personal local banks remain desktop-local
- personal cloud banks and organization banks use explicit `read / write` grants

Migration path:

1. add `QuestionBank`
2. add `QuestionBankGrant`
3. add nullable `Question.questionBankId`
4. backfill one default cloud bank per existing tenant
5. attach historical questions to that default bank
6. keep tenant-wide compatibility by granting existing organization members access to the default bank
7. update question APIs to accept `questionBankId`
8. later tighten `questionBankId` to required
9. later evolve RLS and guards from tenant-wide question access toward bank-aware access

Important compatibility rule:

- initial backend runtime should focus on cloud banks
- desktop-local bank support may begin in the Flutter desktop app without blocking server migration

Why now:

- personal cloud sharing and organization per-bank authorization both require this layer
- without `questionBankId`, tenant-level ACL is too coarse

## 4.2 Explanation block unification

Recommended first runtime migration.

Current state:

- `stepsBlocks` is already structured
- `overviewLatex` and `commentaryLatex` are plain strings

Migration path:

1. add `overviewBlocks` and `commentaryBlocks`
2. update services to prefer block fields when present
3. write new updates into block fields
4. backfill plain latex strings into simple block wrappers
5. remove old string fields later

Why first:

- low risk
- high consistency payoff
- useful for future Flutter editing experience

## 4.3 Solution answer normalization

Current state:

- `finalAnswerLatex`
- `scoringPoints`

Migration path:

1. add `referenceAnswerBlocks`
2. optionally evolve `scoringPoints` toward block-compatible structure
3. write new shape
4. backfill old shape
5. clean up old fields

Risk:

- low to medium

## 4.4 Subject cardinality

Current state:

- single `subjectId` on `Question`

Frozen decision:

- keep `subjectId`
- do not migrate to a many-to-many subject relation

Reason:

- single-subject is the intended business rule for this product version

Action:

- remove subject cardinality from runtime migration scope
- express cross-discipline discoverability through tags and other taxonomy dimensions instead

## 4.5 Grade and seed refinement

Current state:

- stage/grade structure exists and is close to target

Migration path:

1. refine seed data only
2. add missing grade codes for semester or exam-style grades
3. backfill only if business meaning changes

Risk:

- low

## 4.6 Composite integrity tightening

Current state:

- many tenant-aware composite relations already exist

Migration path:

1. review each relation table
2. classify which links are already safe enough
3. only tighten high-value relations first

Priority candidates:

- question-chapter
- question-textbook
- document-item references
- export result references

Risk:

- medium

## 5. Work Packages

## 5.1 Planning package

- freeze business decisions
- define field-level migration targets
- define compatibility behavior per API route

## 5.2 Schema package

- additive Prisma changes
- migration scripts
- new constraints added only after backfill

## 5.3 Service package

- compatibility reads
- new-shape writes
- fallback rules

## 5.4 Data package

- backfill scripts
- verification queries
- rollback notes

## 5.5 Validation package

- unit tests for compatibility logic
- e2e tests for changed endpoints
- tenant-isolation regression coverage

## 6. Recommended Immediate Next Action

Start with:

1. freeze decisions on explanation shape and global access-level usage
2. implement explanation-block migration first

This is the safest first runtime step.

## 7. What Should Not Be First

Do not start with:

- global role-model rewrite
- full tenant-model rewrite
- broad composite-key rewrite across every table
- document item abstraction rewrite

Those are too wide for a first migration step.
