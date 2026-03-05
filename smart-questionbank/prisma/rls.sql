-- RLS bootstrap for multi-tenant isolation.
-- Apply after `prisma migrate` has created tables.
--
-- Usage (example):
--   psql "$DATABASE_URL" -f prisma/rls.sql
--
-- The application must set:
--   SET LOCAL app.tenant_id = '<tenant-uuid>';

DO $$
BEGIN
  PERFORM set_config('app.tenant_id', '00000000-0000-0000-0000-000000000000', true);
EXCEPTION
  WHEN OTHERS THEN
    -- ignore
    NULL;
END $$;

-- Helper: enable RLS for a tenant-scoped table.
-- Note: we keep global tables (tenants, users, subjects/textbooks with tenant_id NULL) without RLS.

ALTER TABLE "TenantMember" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "TenantMember" FORCE ROW LEVEL SECURITY;
ALTER TABLE "Question" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Question" FORCE ROW LEVEL SECURITY;
ALTER TABLE "QuestionContent" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "QuestionContent" FORCE ROW LEVEL SECURITY;
ALTER TABLE "QuestionExplanation" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "QuestionExplanation" FORCE ROW LEVEL SECURITY;
ALTER TABLE "QuestionSource" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "QuestionSource" FORCE ROW LEVEL SECURITY;
ALTER TABLE "QuestionAnswerChoice" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "QuestionAnswerChoice" FORCE ROW LEVEL SECURITY;
ALTER TABLE "QuestionAnswerBlank" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "QuestionAnswerBlank" FORCE ROW LEVEL SECURITY;
ALTER TABLE "QuestionAnswerSolution" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "QuestionAnswerSolution" FORCE ROW LEVEL SECURITY;
ALTER TABLE "Document" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Document" FORCE ROW LEVEL SECURITY;
ALTER TABLE "LayoutElement" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "LayoutElement" FORCE ROW LEVEL SECURITY;
ALTER TABLE "DocumentItem" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "DocumentItem" FORCE ROW LEVEL SECURITY;
ALTER TABLE "QuestionTag" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "QuestionTag" FORCE ROW LEVEL SECURITY;
ALTER TABLE "QuestionTagging" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "QuestionTagging" FORCE ROW LEVEL SECURITY;
ALTER TABLE "Chapter" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Chapter" FORCE ROW LEVEL SECURITY;
ALTER TABLE "Asset" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Asset" FORCE ROW LEVEL SECURITY;
ALTER TABLE "ExportJob" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ExportJob" FORCE ROW LEVEL SECURITY;

-- Policies: tenant_id must match session setting.

DROP POLICY IF EXISTS tenant_isolation_tenant_member ON "TenantMember";
CREATE POLICY tenant_isolation_tenant_member ON "TenantMember"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_question ON "Question";
CREATE POLICY tenant_isolation_question ON "Question"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_question_content ON "QuestionContent";
CREATE POLICY tenant_isolation_question_content ON "QuestionContent"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_question_explanation ON "QuestionExplanation";
CREATE POLICY tenant_isolation_question_explanation ON "QuestionExplanation"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_question_source ON "QuestionSource";
CREATE POLICY tenant_isolation_question_source ON "QuestionSource"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_question_answer_choice ON "QuestionAnswerChoice";
CREATE POLICY tenant_isolation_question_answer_choice ON "QuestionAnswerChoice"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_question_answer_blank ON "QuestionAnswerBlank";
CREATE POLICY tenant_isolation_question_answer_blank ON "QuestionAnswerBlank"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_question_answer_solution ON "QuestionAnswerSolution";
CREATE POLICY tenant_isolation_question_answer_solution ON "QuestionAnswerSolution"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_document ON "Document";
CREATE POLICY tenant_isolation_document ON "Document"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_layout_element ON "LayoutElement";
CREATE POLICY tenant_isolation_layout_element ON "LayoutElement"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_document_item ON "DocumentItem";
CREATE POLICY tenant_isolation_document_item ON "DocumentItem"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_question_tag ON "QuestionTag";
CREATE POLICY tenant_isolation_question_tag ON "QuestionTag"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_question_tagging ON "QuestionTagging";
CREATE POLICY tenant_isolation_question_tagging ON "QuestionTagging"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_chapter ON "Chapter";
CREATE POLICY tenant_isolation_chapter ON "Chapter"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_asset ON "Asset";
CREATE POLICY tenant_isolation_asset ON "Asset"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);

DROP POLICY IF EXISTS tenant_isolation_export_job ON "ExportJob";
CREATE POLICY tenant_isolation_export_job ON "ExportJob"
  USING ("tenantId" = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);
