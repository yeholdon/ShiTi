import { BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

async function ensureTenantOrSystemEntity<T>(
  prisma: PrismaService,
  tenantId: string,
  id: string,
  findSystem: () => Promise<T | null>,
  findTenant: () => Promise<T | null>,
  fieldName: string
) {
  const normalizedId = String(id || '').trim();
  if (!normalizedId) throw new BadRequestException(`Missing ${fieldName}`);

  const systemEntity = await findSystem();
  if (systemEntity) return systemEntity;

  const tenantEntity = await findTenant();
  if (tenantEntity) return tenantEntity;

  throw new BadRequestException(`Invalid ${fieldName} for current tenant`);
}

export async function ensureTenantOrSystemStage(prisma: PrismaService, tenantId: string, stageId: string) {
  return ensureTenantOrSystemEntity(
    prisma,
    tenantId,
    stageId,
    () => prisma.stage.findFirst({ where: { id: stageId, tenantId: null } }),
    () => prisma.withTenant(tenantId, (tx) => tx.stage.findFirst({ where: { id: stageId, tenantId } })),
    'stageId'
  );
}

export async function ensureTenantOrSystemGrade(prisma: PrismaService, tenantId: string, gradeId: string) {
  return ensureTenantOrSystemEntity(
    prisma,
    tenantId,
    gradeId,
    () => prisma.grade.findFirst({ where: { id: gradeId, tenantId: null } }),
    () => prisma.withTenant(tenantId, (tx) => tx.grade.findFirst({ where: { id: gradeId, tenantId } })),
    'gradeId'
  );
}

export async function ensureTenantOrSystemTextbook(prisma: PrismaService, tenantId: string, textbookId: string) {
  return ensureTenantOrSystemEntity(
    prisma,
    tenantId,
    textbookId,
    () => prisma.textbook.findFirst({ where: { id: textbookId, tenantId: null } }),
    () => prisma.withTenant(tenantId, (tx) => tx.textbook.findFirst({ where: { id: textbookId, tenantId } })),
    'textbookId'
  );
}

export async function ensureTenantChapter(prisma: PrismaService, tenantId: string, chapterId: string) {
  const normalizedId = String(chapterId || '').trim();
  if (!normalizedId) throw new BadRequestException('Missing chapterId');

  const chapter = await prisma.withTenant(tenantId, (tx) =>
    tx.chapter.findUnique({ where: { tenantId_id: { tenantId, id: normalizedId } } })
  );
  if (!chapter) throw new BadRequestException('Invalid chapterId for current tenant');

  return chapter;
}
