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
- Tenant members:
  - Missing `tenantCode` returns `400`
  - Unknown tenant returns `404`
  - Re-joining the same tenant upserts and updates membership role
- Questions:
  - Question content/explanation/source/choice-answer upserts round-trip through detail view
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
