# Flutter Information Architecture

Last updated: 2026-03-09

This document describes the intended Flutter app structure for ShiTi.

## 1. Design Goal

The Flutter app is the user-facing teaching workspace.
It should feel different from the backend admin console:

- less operational
- more task-oriented
- more focused on lesson preparation and reusable materials

## 2. Primary Navigation

Recommended main tabs:

1. Home
2. Questions
3. Documents
4. Exports
5. Me

## 3. Page Tree

## 3.1 Home

- home dashboard
  - recent materials
  - recent exports
  - common textbook filters
  - quick entry to question search
  - quick entry to create handout/paper

## 3.2 Questions

- question list
- question filters sheet
- question detail
- question edit
- question basket
- import entry

## 3.3 Documents

- document list
- document detail
- compose document
- reorder items
- add question to document
- add layout element to document

## 3.4 Exports

- export list
- export detail
- export result preview/download

## 3.5 Me

- current workspace context
- personal / organization switch
- profile
- sign out

## 4. Secondary Flows

Secondary routes:

- textbook/chapter picker
- tag picker
- asset picker
- search history
- favorite filters

## 5. Screen Priorities

The first mobile and desktop iterations should prioritize:

1. auth
2. tenant switch
3. question list and detail
4. question basket
5. document list and detail

The tenant switch flow should evolve into a unified workspace switch:

- personal workspace
- joined organizations
6. export list and result access

## 6. What Should Stay Out of the Flutter App Initially

These should remain in the admin console first:

- audit review
- member role management
- cleanup operations
- deep operational metrics
- maintenance-only governance flows

## 7. UX Rules

- search and filters should be easy to reach
- textbook/chapter navigation should be first-class
- recent materials should be visible on home
- export status should be understandable without operational jargon
- admin-only terms should not dominate the user experience

## 8. Desktop Considerations

Desktop Flutter should emphasize:

- larger split-view layouts
- persistent question basket
- side-by-side document composition
- stronger keyboard support

## 9. Mobile Considerations

Mobile Flutter should emphasize:

- bottom-tab navigation
- search-first entry points
- lightweight detail screens
- fast add-to-basket and add-to-document actions
