# Question Bank Domain Model

Last updated: 2026-03-09

This document refines the question-bank product requirements based on the latest domain description.

## 1. Scope

ShiTi is a structured question-bank and teaching-material system.
Its core business objects are:

- questions
- question explanations
- taxonomy and tags
- documents
- layout elements
- users

## 2. Core Modeling Decision

Question content, explanation content, and layout content should all use a unified block-based LaTeX content model instead of many scattered text/image/table columns.

Reason:

- easier multi-end rendering
- easier PDF export
- easier future extension
- more consistent editing behavior across question and document flows

## 3. Question Model

Each question should include:

- question type
- difficulty
- default score
- source information
- subject / stage / grade / textbook / chapter / tags
- created/updated timestamps

## 3.1 Question content

Question stem should support:

- text, required
- image, optional, multiple
- table, optional, multiple

Storage direction:

- stored as LaTeX-oriented structured blocks

## 3.2 Explanation model

Explanation should include:

- overall analysis, optional
- detailed solution process, required
- commentary, optional

The detailed solution process uses the same block structure as the question stem.

## 3.3 Question types

Fixed question types:

- choice
- blank
- solution

This fixed type should be distinct from user-defined question tags.

## 3.4 Difficulty

Store as numeric level `1-5`.

Suggested semantic mapping:

- `1` = 极难
- `2` = 难
- `3` = 中难
- `4` = 中等
- `5` = 易

Implementation note:

- store integer in DB
- map label in client/backend display layer

## 3.5 Source

Question source should support:

- year, optional
- month, optional
- source text, optional

Use cases:

- content traceability
- optional display during document generation

## 4. Taxonomy Model

The question-bank must support both built-in defaults and user-defined additions where appropriate.

Taxonomy families:

- subjects
- stages
- grades
- textbooks
- chapters
- question tags

## 4.1 Subject

Business rule:

- each question has exactly one subject
- subject is intentionally single-valued, unlike stage/grade/textbook/chapter/tag relations

Built-in defaults:

- 语文
- 数学
- 英语
- 物理
- 化学
- 生物
- 科学
- 政治
- 历史
- 地理
- 文综
- 理综
- 技术

Users may add custom subjects.

## 4.2 Stage

Built-in defaults:

- 小学
- 初中
- 高中
- 本科
- 考研
- 专升本

## 4.3 Grade

Grade should be modeled separately from stage.

Recommended direction:

- 小学和初中支持上下学期
- 高中可独立 grade
- 中考和高考作为特殊 grade
- 高等阶段可仅使用 stage without forcing detailed grade

Important business note:

- one question may belong to multiple stage/grade values

## 4.4 Textbook

Built-in defaults:

- 浙教版
- 人教版
- 通用版

Users may add custom textbooks.

## 4.5 Chapter

Chapters are user-defined and must belong to a textbook.

This relationship is mandatory.

## 4.6 Question tags

Question tags are user-defined fine-grained labels such as:

- 尺规作图
- 手拉手全等模型

These are not the same as fixed question type.

## 5. Document Model

Documents are divided into:

- paper
- handout

## 5.1 Common fields

Each document should include:

- unique id
- name
- kind
- item list

## 5.2 Layout elements

Layout elements should:

- use the same LaTeX-oriented block model
- support text
- support images

Constraint:

- papers cannot include layout elements
- handouts can include layout elements

## 5.3 Derived document stats

The following should be treated as derived system stats, not user-maintained fields:

- question count
- average difficulty
- question counts by tag/type

## 6. User Model

User model should include:

- id
- username
- password hash
- access level
- last login timestamp

## 6.1 Access levels

Current business roles:

- normal user
- member (reserved)
- administrator

Security correction:

- passwords must never be stored in plaintext

## 7. Platform Direction

The product should support:

- mobile
- web
- desktop

Recommended direction:

- Flutter for the user-facing app
- backend management surface designed separately from the user-facing app

## 8. Product Surface Separation

User-facing workspace should emphasize:

- question search
- question reuse
- document composition
- export result access

Backend management should emphasize:

- governance
- maintenance
- audit
- system operations

## 9. Design Constraints That Follow From This Model

- question content must be reusable across app, web, desktop, and export
- taxonomy must support many-to-many linking
- chapters must always bind to textbooks
- question type and question tag must remain distinct
- document stats should be system-derived
- management and user surfaces should not collapse into one UI
