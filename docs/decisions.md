# Decisions

## 2026-03-09

- Decision 2026-03-09: subject保持单值（`questions.subjectId`），不迁多对多。

  - 原因：
    - 当前题库工作流里，学科更像题目的主归属维度，而不是和学段、教材、章节同级的多值筛选维度。
    - 保持单值可以维持现有创建、编辑、筛选、导入和权限校验路径的简单性，避免为了少量交叉学科场景把整个题目模型复杂化。
    - 现有系统已经围绕 `questions.subjectId` 形成稳定实现，改成多对多会引入 schema、接口、管理端和未来 Flutter 客户端的联动迁移成本。

  - 影响：
    - 运行时 schema 继续保留 `questions.subjectId`。
    - 不新增 `question_subjects` 关系表，也不执行 subject 多对多迁移。
    - 题目创建、更新、筛选、导入接口继续按单学科设计。
    - 如果未来出现明确且高频的跨学科归属需求，再单独开启新一轮决策和迁移。

## 2026-03-21

- Decision 2026-03-21: 个人工作区不引入独立 `workspace` 主模型，而是落成特殊的 `tenant` 类型。

  - 方案：
    - `Tenant.kind = personal | organization`
    - 每个用户自动拥有一个 `personal` tenant，作为个人工作区
    - 用户可额外加入多个 `organization` tenant，作为机构工作区
    - 个人工作区不允许额外成员；机构工作区继续使用 `member / admin / owner`

  - 原因：
    - 当前题库、文档、导出、资产、审计和 RLS 都已经围绕 `tenantId` 建模。
    - 如果并行新增一套 `workspace` 主模型，运行时会出现双主语，迁移成本和风险都明显更高。
    - 把个人工作区落成特殊 tenant，可以直接复用现有 tenant 隔离和复合主键设计。

  - 影响：
    - 后续 schema 朝“tenant 类型化”演进，而不是“tenant + workspace 双根模型”演进。
    - 机构数量上限、管理员数量上限等约束先放应用层。
    - Flutter 和 API 的“上下文切换”需要逐步升级为“个人工作区 / 机构工作区”统一切换。
