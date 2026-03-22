# API Contract Outline

Last updated: 2026-03-09

This document is not a replacement for Swagger.
It is the product-facing API contract outline for the planned Flutter client and admin integrations.

## 1. Contract Principles

- all tenant-scoped requests carry authenticated user context
- tenant selection must be explicit
- list responses should keep normalized pagination meta
- errors should keep a shared envelope
- high-risk operations must expose role expectations clearly

## 2. Shared Response Shapes

## 2.1 List response

Expected shape:

```json
{
  "items": [],
  "meta": {
    "limit": 20,
    "offset": 0,
    "returned": 20,
    "total": 120,
    "hasMore": true,
    "sortBy": "createdAt",
    "sortOrder": "desc"
  }
}
```

## 2.2 Error envelope

Expected shape:

```json
{
  "statusCode": 400,
  "message": "Validation failed",
  "error": {
    "code": "validation_failed",
    "message": "Validation failed",
    "details": []
  },
  "path": "/questions",
  "timestamp": "2026-03-09T00:00:00.000Z",
  "requestId": "..."
}
```

## 3. Auth and Tenant

Key contracts:

- `POST /auth/register`
- `POST /auth/login`
- `POST /tenants`
- `GET /tenants/resolve`
- `POST /tenant-members`
- `PATCH /tenant-members/:id/role`

Flutter needs these for:

- authentication
- workspace list and workspace switch
- onboarding

Expected evolution:

- `GET /tenants` should return both personal and organization workspaces
- `POST /tenants` should create organization tenants only
- registration/login flow should ensure one personal tenant exists for the user

## 4. Question Domain

Key contracts:

- `GET /questions`
- `POST /questions`
- `GET /questions/:id`
- `PATCH /questions/:id`
- `PUT /questions/:id/content`
- `PUT /questions/:id/explanation`
- `PUT /questions/:id/source`
- `PUT /questions/:id/answer-choice`
- `PUT /questions/:id/answer-blank`
- `PUT /questions/:id/answer-solution`
- `PUT /questions/:id/tags`
- `PUT /questions/:id/taxonomy`
- `POST /questions/import`

Flutter expectations:

- question summary list for browse/search
- detail view for editing and review
- question basket selection
- question-bank-aware browse and switch

Expected evolution:

- add `GET /question-banks`
- add `POST /question-banks` for cloud-bank creation
- add `PATCH /question-banks/:id`
- add `POST /question-banks/:id/grants`
- add `PATCH /question-banks/:id/grants/:userId`
- add `DELETE /question-banks/:id/grants/:userId`
- add `questionBankId` filter to `GET /questions`
- require `questionBankId` on question create/import once migration completes
- desktop-local banks remain outside initial HTTP contracts and are handled by the desktop client

## 5. Taxonomy and Tags

Key contracts:

- `GET /subjects`
- `GET /stages`
- `GET /grades`
- `GET /textbooks`
- `GET /chapters`
- `GET /question-tags`

Flutter expectations:

- lightweight selectors and filters
- lazy-loaded search/filter options

## 6. Documents

Key contracts:

- `GET /documents`
- `POST /documents`
- `GET /documents/:id`
- `PATCH /documents/:id`
- `POST /documents/:id/items`
- `POST /documents/:id/items/bulk`
- `PATCH /documents/:id/items/reorder`
- `DELETE /documents/:id/items/:itemId`

Flutter expectations:

- recent materials
- document detail
- composition actions

## 7. Assets

Key contracts:

- `POST /assets/upload`
- `GET /assets`
- `GET /assets/:id`
- `DELETE /assets/:id`

Flutter expectations:

- media selection
- upload feedback
- image attachment in question/document flows

## 8. Exports

Key contracts:

- `POST /export-jobs`
- `GET /export-jobs`
- `GET /export-jobs/:id`
- `GET /export-jobs/:id/result`
- `POST /export-jobs/:id/retry`
- `POST /export-jobs/:id/cancel`

Flutter expectations:

- export progress
- recent export results
- result access

## 9. Admin-only Operational Contracts

Key contracts:

- `GET /audit-logs`
- `GET /audit-logs/stats`
- `POST /assets/cleanup`
- `POST /export-jobs/cleanup`

These are not primary user-facing client flows.

## 10. Contract Work Still Needed

- tag exact Flutter payload needs
- formalize tenant-switch transport
- define stable field subsets for mobile list screens
- define upload/result URL lifetime assumptions
