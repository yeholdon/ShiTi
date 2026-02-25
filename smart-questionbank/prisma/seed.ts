import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // System defaults (tenantId = null)
  const subjects = [
    '语文',
    '数学',
    '英语',
    '物理',
    '化学',
    '生物',
    '科学',
    '政治',
    '历史',
    '地理',
    '文综',
    '理综',
    '技术'
  ];

  for (const name of subjects) {
    const existing = await prisma.subject.findFirst({ where: { tenantId: null, name } });
    if (!existing) {
      await prisma.subject.create({ data: { tenantId: null, name, isSystem: true } });
    } else if (!existing.isSystem) {
      await prisma.subject.update({ where: { id: existing.id }, data: { isSystem: true } });
    }
  }

  const textbooks = ['浙教版', '人教版', '通用版'];
  for (const name of textbooks) {
    const existing = await prisma.textbook.findFirst({ where: { tenantId: null, name } });
    if (!existing) {
      await prisma.textbook.create({ data: { tenantId: null, name, isSystem: true } });
    } else if (!existing.isSystem) {
      await prisma.textbook.update({ where: { id: existing.id }, data: { isSystem: true } });
    }
  }

  // Optional: keep the old fixed-id subject for backwards compatibility with early tests.
  await prisma.subject.upsert({
    where: { id: '00000000-0000-0000-0000-000000000010' },
    update: { tenantId: null, name: 'math', isSystem: true },
    create: { id: '00000000-0000-0000-0000-000000000010', tenantId: null, name: 'math', isSystem: true }
  });
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
