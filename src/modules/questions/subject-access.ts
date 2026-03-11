import { BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export async function ensureTenantOrSystemSubject(
  prisma: PrismaService,
  tenantId: string,
  subjectId: string
): Promise<string> {
  const id = String(subjectId || '').trim();
  if (!id) throw new BadRequestException('Missing subjectId');

  const subject = await prisma.subject.findFirst({
    where: {
      id,
      OR: [{ tenantId: null, isSystem: true }, { tenantId }]
    },
    select: { id: true }
  });

  if (!subject) throw new BadRequestException('Invalid subjectId for current tenant');
  return subject.id;
}
