import { PrismaClient } from '@prisma/client';

function inferAdminDatabaseUrl() {
  const explicit = process.env.RLS_ADMIN_DATABASE_URL;
  if (explicit && explicit.trim()) return explicit;

  const raw = process.env.DATABASE_URL;
  if (!raw) return undefined;

  try {
    const url = new URL(raw);

    // In dev we run the API as a non-superuser (qb_app) to ensure RLS is effective.
    // But applying RLS policies requires a table owner / elevated role.
    if (url.username && url.username !== 'postgres') {
      url.username = 'postgres';
      // Default docker-compose password.
      url.password = 'postgres';
    }

    return url.toString();
  } catch {
    return undefined;
  }
}

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: inferAdminDatabaseUrl()
    }
  }
});

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
  { table: 'QuestionStage', policy: 'tenant_isolation_question_stage' },
  { table: 'QuestionGrade', policy: 'tenant_isolation_question_grade' },
  { table: 'QuestionTextbook', policy: 'tenant_isolation_question_textbook' },
  { table: 'QuestionChapter', policy: 'tenant_isolation_question_chapter' },
  { table: 'Chapter', policy: 'tenant_isolation_chapter' },
  { table: 'Asset', policy: 'tenant_isolation_asset' },
  { table: 'ExportJob', policy: 'tenant_isolation_export_job' },
  { table: 'AuditLog', policy: 'tenant_isolation_audit_log' }
];

async function main() {
  for (const { table, policy } of TABLES) {
    await prisma.$executeRawUnsafe(`ALTER TABLE "${table}" ENABLE ROW LEVEL SECURITY;`);
    await prisma.$executeRawUnsafe(`ALTER TABLE "${table}" FORCE ROW LEVEL SECURITY;`);
    await prisma.$executeRawUnsafe(`DROP POLICY IF EXISTS ${policy} ON "${table}";`);
    await prisma.$executeRawUnsafe(
      `CREATE POLICY ${policy} ON "${table}" USING ("tenantId" = current_setting('app.tenant_id', true)::uuid) WITH CHECK ("tenantId" = current_setting('app.tenant_id', true)::uuid);`
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
