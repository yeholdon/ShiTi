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

## 4.1 Explanation block unification

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

## 4.2 Solution answer normalization

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

## 4.3 Subject cardinality

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

## 4.4 Grade and seed refinement

Current state:

- stage/grade structure exists and is close to target

Migration path:

1. refine seed data only
2. add missing grade codes for semester or exam-style grades
3. backfill only if business meaning changes

Risk:

- low

## 4.5 Composite integrity tightening

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
