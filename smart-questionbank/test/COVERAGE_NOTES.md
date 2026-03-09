# ShiTi test coverage notes

## What is covered (unit)

- Tenant typing: `TenantContext` accepts nullable values
- Tenant resolve middleware:
  - Missing header -> tenant nulls
  - Header trimmed -> resolves tenant id
  - Unknown code -> tenantId stays null
- Tenants controller:
  - createTenant returns existing tenant when code already exists
  - createTenant creates tenant when not exists
  - resolve returns null when header missing
  - resolve queries by code when provided
- Questions controller:
  - Missing tenant errors for list/create
  - create with provided subjectId avoids system subject query
  - create without subjectId errors when system subject missing

## What is covered (e2e)

- Health probe: `/health` returns `{ status: 'ok' }`
- Readiness probe: `/health/ready` checks database, Redis, and MinIO connectivity
- Documents:
  - Document list supports name search, kind filter, and limit
  - Document list/detail return derived stats (question count, average difficulty, per-type counts)
  - Document detail returns items and reorder persists order
  - Handout export includes layout elements and asset placeholders
- Assets:
  - Tenant can request presigned upload URLs and persist asset metadata
  - Other tenants cannot list or fetch that tenant's assets
  - Content, import, and layout blocks reject cross-tenant asset references
- Layout elements:
  - Tenant can CRUD its own layout elements
  - Handout documents can include layout elements
  - Paper documents reject layout elements
- Tenant members:
  - Missing `tenantCode` returns `400`
  - Unknown tenant returns `404`
  - Re-joining the same tenant upserts and updates membership role
- Questions:
  - Question blank-answer and solution-answer upserts round-trip through detail view
  - Question content/explanation/source/choice-answer upserts round-trip through detail view
  - Question import can persist taxonomy assignments
  - Question list filters support type, difficulty, subject, visibility, keyword, and limit
  - Question taxonomy assignments round-trip through detail view
  - Question list filters support stage, grade, textbook, and chapter ids
  - Setting question tags rejects unknown tag IDs
  - Question list with `include=tags` returns assigned tags
  - Question detail returns assigned tags
  - Replacing tags overwrites prior tag assignments
- Question tags:
  - Tenant can create/list/delete its own tags
  - Other tenants cannot list or delete that tenant's tags
- Subjects:
  - Authenticated request without tenant header sees seeded system subjects
  - Tenant request sees system subjects plus its own tenant-created subjects
  - Other tenants cannot see that tenant-specific subject
- Stages:
  - Authenticated request without tenant header sees seeded system stages
  - Tenant request sees system stages plus its own tenant-created stages
  - Other tenants cannot see that tenant-specific stage
- Grades:
  - Authenticated request sees seeded grades and can filter by stage
  - Tenant can create grades under system stages or its own stages
  - Other tenants cannot list or create grades against another tenant's stage
- Textbooks:
  - Authenticated request without tenant header sees seeded system textbooks
  - Tenant request sees system textbooks plus its own tenant-created textbooks
  - Other tenants cannot see that tenant-specific textbook
- Chapters:
  - Tenant can create chapters under system or tenant-accessible textbooks
  - Child chapters must stay within the same textbook as the parent
  - Other tenants cannot list or create chapters against another tenant's textbook
- Tenant isolation: tenant A cannot see tenant B questions
- Cross-tenant hard isolation:
  - Question creation rejects subjectId from another tenant
  - Question import/patch rejects subjectId from another tenant
  - Document item rejects questionId from another tenant
  - Export jobs cannot be fetched/downloaded from another tenant

## Test entrypoints

- `npm run test:unit`
- `npm run test:e2e`
- `npm test` (runs unit + e2e)
