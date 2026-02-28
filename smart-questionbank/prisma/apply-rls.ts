import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type TenantScopedTable = {
  table: string;
  policy: string;
};

const TABLES: TenantScopedTable[] = [
  { table: 'TenantMember', policy: 'tenant_isolation_tenant_member' },
  { table: 'Question', policy: 'tenant_isolation_question' },
  { table: 'QuestionContent', policy: 'tenant_isolation_question_content' },
  { table: 'QuestionExplanation', policy: 'tenant_isolation_question_explanation' },
  { table: 'QuestionSource', policy: 'tenant_isolation_question_source' },
  { table: 'QuestionAnswerChoice', policy: 'tenant_isolation_question_answer_choice' },
  { table: 'QuestionAnswerBlank', policy: 'tenant_isolation_question_answer_blank' },
  { table: 'QuestionAnswerSolution', policy: 'tenant_isolation_question_answer_solution' },
  { table: 'Document', policy: 'tenant_isolation_document' },
  { table: 'LayoutElement', policy: 'tenant_isolation_layout_element' },
  { table: 'DocumentItem', policy: 'tenant_isolation_document_item' },
  { table: 'QuestionTag', policy: 'tenant_isolation_question_tag' },
  { table: 'QuestionTagging', policy: 'tenant_isolation_question_tagging' },
  { table: 'Chapter', policy: 'tenant_isolation_chapter' },
  { table: 'Asset', policy: 'tenant_isolation_asset' },
  { table: 'ExportJob', policy: 'tenant_isolation_export_job' }
];

async function main() {
  for (const { table, policy } of TABLES) {
    await prisma.$executeRawUnsafe(`ALTER TABLE "${table}" ENABLE ROW LEVEL SECURITY;`);
    await prisma.$executeRawUnsafe(`DROP POLICY IF EXISTS ${policy} ON "${table}";`);
    await prisma.$executeRawUnsafe(
      `CREATE POLICY ${policy} ON "${table}" USING ("tenantId" = current_setting('app.tenant_id', true)::uuid);`
    );
  }
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    // eslint-disable-next-line no-console
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
