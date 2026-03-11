import { randomUUID } from 'node:crypto';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const ensureStage = async (code: string, name: string, order: number) => {
    const existing = await prisma.stage.findFirst({ where: { tenantId: null, code } });
    if (existing) {
      return prisma.stage.update({
        where: { id: existing.id },
        data: { name, order, isSystem: true }
      });
    }

    return prisma.stage.create({
      data: {
        id: randomUUID(),
        tenantId: null,
        code,
        name,
        order,
        isSystem: true
      }
    });
  };

  const ensureGrade = async (stageId: string, code: string, name: string, order: number) => {
    const existing = await prisma.grade.findFirst({ where: { tenantId: null, stageId, code } });
    if (existing) {
      return prisma.grade.update({
        where: { id: existing.id },
        data: { name, order, isSystem: true }
      });
    }

    return prisma.grade.create({
      data: {
        id: randomUUID(),
        tenantId: null,
        stageId,
        code,
        name,
        order,
        isSystem: true
      }
    });
  };

  const primaryStage = await ensureStage('primary', '小学', 10);
  const middleStage = await ensureStage('middle', '初中', 20);
  const highStage = await ensureStage('high', '高中', 30);
  const undergraduateStage = await ensureStage('undergraduate', '本科', 40);
  const postgraduateStage = await ensureStage('postgraduate', '考研', 50);
  const topUpStage = await ensureStage('top-up', '专升本', 60);
  const examStage = await ensureStage('exam', '考试', 70);

  for (let grade = 1; grade <= 6; grade += 1) {
    await ensureGrade(primaryStage.id, `p${grade}-up`, `${grade}年级上`, grade * 10);
    await ensureGrade(primaryStage.id, `p${grade}-down`, `${grade}年级下`, grade * 10 + 1);
  }

  for (let grade = 7; grade <= 9; grade += 1) {
    await ensureGrade(middleStage.id, `m${grade}-up`, `${grade}年级上`, grade * 10);
    await ensureGrade(middleStage.id, `m${grade}-down`, `${grade}年级下`, grade * 10 + 1);
  }

  await ensureGrade(highStage.id, 'g10', '高一', 100);
  await ensureGrade(highStage.id, 'g11', '高二', 110);
  await ensureGrade(highStage.id, 'g12', '高三', 120);
  await ensureGrade(examStage.id, 'zhongkao', '中考', 10);
  await ensureGrade(examStage.id, 'gaokao', '高考', 20);

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
