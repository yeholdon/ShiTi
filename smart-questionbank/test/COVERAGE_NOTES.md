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
