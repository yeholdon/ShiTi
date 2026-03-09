# Schema Gap Checklist

Last updated: 2026-03-09

This document compares the current runtime Prisma schema with the target optimized question-bank model.

It is the immediate migration checklist before any real schema refactor begins.

## 1. Already Aligned

The current schema already matches the target direction in several important ways:

- tenant-aware tables are already widespread
- many relation tables already use tenant-aware composite IDs
- question content is already block-based
- question answers are already separated by answer mode
- source information is already separated
- documents, layout elements, assets, exports, and audit logs already exist
- RBAC and audit assumptions already exist at the application layer

## 2. Gaps in the Question Model

## 2.1 Question subject relation

Current state:

- `Question` stores a single `subjectId`

Frozen product decision:

- subject remains single-valued
- do not introduce `question_subjects`

Reasoning:

- most questions have one primary subject
- cross-discipline cases can still be expressed through tags and other taxonomy dimensions
- keeping subject scalar avoids unnecessary API, migration, and client complexity

Recommendation:

- keep `subjectId` as intentional product design
- remove this topic from future schema-migration scope unless product requirements change later

## 2.2 Explanation structure

Current state:

- `QuestionExplanation.overviewLatex`
- `QuestionExplanation.stepsBlocks`
- `QuestionExplanation.commentaryLatex`

Target direction:

- all three explanation parts should converge toward block-based structure for consistency

Recommendation:

- keep `stepsBlocks`
- consider upgrading `overviewLatex` and `commentaryLatex` to optional block JSON later

## 2.3 Solution answer structure

Current state:

- `finalAnswerLatex`
- `scoringPoints`

Target direction:

- closer alignment with block-based content for future client/editor consistency

Recommendation:

- keep current model in short term
- consider evolving `finalAnswerLatex` into `referenceAnswerBlocks`

## 3. Gaps in User and Access Model

## 3.1 User access level

Current state:

- `User` does not store a global `accessLevel`

Target direction:

- domain draft includes `accessLevel`

Recommendation:

- decide whether global access level is truly needed
- tenant-scoped roles may already be sufficient for most business flows

## 3.2 Password model

Current state:

- `passwordHash` already exists

Target requirement:

- no plaintext passwords

Status:

- already aligned

## 4. Gaps in Taxonomy

## 4.1 Stage / grade richness

Current state:

- `Stage` and `Grade` already exist with `code`, `name`, `order`, `isSystem`

Target direction:

- this is already close to the intended design

Remaining question:

- whether current seed/default data fully represents semester-based grades and special grades like 中考 / 高考

## 4.2 Textbook / chapter constraints

Current state:

- `Chapter` already uses tenant-aware composite id
- `QuestionChapter` already references `Chapter` by `(tenantId, chapterId)`

Status:

- strong alignment

Remaining gap:

- parent/child chapter hierarchy semantics may need clearer documentation

## 4.3 Subject system/default handling

Current state:

- `Subject` already has `tenantId?` and `isSystem`

Status:

- aligned

## 5. Gaps in Documents

## 5.1 Derived stats persistence

Current state:

- document stats are not persisted as authored fields

Target direction:

- stats should remain derived

Status:

- aligned

## 5.2 Document item references

Current state:

- `DocumentItem` stores nullable `questionId` / `layoutElementId`

Target direction:

- still valid

Potential future change:

- this could be normalized into `refId`, but current explicit columns are clearer and easier to validate

Recommendation:

- keep current shape unless Flutter/editor needs generic item handling strongly enough to justify abstraction

## 6. Gaps in Assets and Exports

## 6.1 Asset metadata

Current state:

- already stores original filename, mime, size, and storage key

Status:

- aligned

## 6.2 Export lifecycle

Current state:

- already supports pending/running/succeeded/failed/canceled

Status:

- aligned

## 7. Gaps in Structural Integrity

## 7.1 Composite integrity coverage

Current state:

- many relations already include tenant-aware composite references
- not every taxonomy relation uses a composite reference to the parent table

Target direction:

- tenant-aware structural guarantees everywhere feasible

Recommendation:

- do not rewrite everything immediately
- improve composite integrity incrementally where cross-tenant reference risk is real

## 7.2 Runtime tenant context

Current state:

- tenant-aware schema and RLS already exist

Remaining migration work:

- keep verifying that request-level DB session tenant context stays mandatory during future app extraction into `apps/api`

## 8. Priority Migration Checklist

Priority 1:

- formalize explanation block strategy
- confirm global `accessLevel` necessity

Priority 2:

- align solution answer structure more closely with block model
- document grade seed conventions for semester and exam grades

Priority 3:

- review composite integrity opportunities table by table

## 9. Recommendation

The current schema is not far from the target.
Migration should be evolutionary, not a rewrite.

The safest next step is:

1. confirm business decisions on the remaining ambiguous fields
2. create a model-by-model migration plan
3. only then change the runtime Prisma schema
