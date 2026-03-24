import {
  Controller,
  Get,
  NotFoundException,
  Param,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PrismaService } from '../../../src/prisma/prisma.service';
import {
  requireActiveTenantMember,
  requireTenantId,
  requireUserId,
} from '../../../src/tenant/tenant-guards';

function mapClassRecord(classroom: any) {
  return {
    id: classroom.id,
    tenantId: classroom.tenantId,
    name: classroom.name,
    lessonId: classroom.lessonId,
    documentId: classroom.documentId,
    focusStudentId: classroom.focusStudentId,
    focusStudentName: classroom.focusStudentName,
    stageLabel: classroom.stageLabel,
    teacherLabel: classroom.teacherLabel,
    textbookLabel: classroom.textbookLabel,
    focusLabel: classroom.focusLabel,
    activityLabel: classroom.activityLabel,
    classSizeLabel: classroom.classSizeLabel,
    lessonFocusLabel: classroom.lessonFocusLabel,
    structureInsight: classroom.structureInsight,
    studentCount: classroom.studentCount,
    weeklyLessonCount: classroom.weeklyLessonCount,
    latestDocLabel: classroom.latestDocLabel,
    assetLinks: classroom.assetLinks,
    memberTiers: classroom.memberTiers,
    lessonTimeline: classroom.lessonTimeline,
    summary: classroom.summary,
    highlights: classroom.highlights,
    nextStep: classroom.nextStep,
    createdAt: classroom.createdAt,
    updatedAt: classroom.updatedAt,
  };
}

@Controller('classes')
@UseGuards(JwtAuthGuard)
export class ClassesController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Req() req: Request, @Query('q') query?: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const keyword = query?.trim();
    const classes = await this.prisma.withTenant(tenantId, (tx) =>
      tx.teachingClass.findMany({
        where: keyword
          ? {
              tenantId,
              OR: [
                { name: { contains: keyword, mode: 'insensitive' } },
                { teacherLabel: { contains: keyword, mode: 'insensitive' } },
                { latestDocLabel: { contains: keyword, mode: 'insensitive' } },
                { summary: { contains: keyword, mode: 'insensitive' } },
              ],
            }
          : { tenantId },
        orderBy: [{ updatedAt: 'desc' }, { name: 'asc' }],
      }),
    );

    return { classes: classes.map(mapClassRecord) };
  }

  @Get(':id')
  async detail(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const classroom = await this.prisma.withTenant(tenantId, (tx) =>
      tx.teachingClass.findUnique({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
      }),
    );

    if (!classroom) {
      throw new NotFoundException('Class not found');
    }

    return { class: mapClassRecord(classroom) };
  }
}
