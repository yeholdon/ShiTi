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

function mapLessonRecord(lesson: any) {
  return {
    id: lesson.id,
    tenantId: lesson.tenantId,
    title: lesson.title,
    classId: lesson.classId,
    className: lesson.className,
    focusStudentId: lesson.focusStudentId,
    focusStudentName: lesson.focusStudentName,
    teacherLabel: lesson.teacherLabel,
    scheduleLabel: lesson.scheduleLabel,
    scheduleTag: lesson.scheduleTag,
    classScopeLabel: lesson.classScopeLabel,
    documentFocus: lesson.documentFocus,
    documentId: lesson.documentId,
    feedbackStatus: lesson.feedbackStatus,
    followUpLabel: lesson.followUpLabel,
    feedbackInsight: lesson.feedbackInsight,
    feedbackRecords: lesson.feedbackRecords,
    assetRecords: lesson.assetRecords,
    taskRecords: lesson.taskRecords,
    summary: lesson.summary,
    highlights: lesson.highlights,
    nextStep: lesson.nextStep,
    createdAt: lesson.createdAt,
    updatedAt: lesson.updatedAt,
  };
}

@Controller('lessons')
@UseGuards(JwtAuthGuard)
export class LessonsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(
    @Req() req: Request,
    @Query('q') query?: string,
    @Query('studentId') studentId?: string,
    @Query('classId') classId?: string,
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const keyword = query?.trim();
    const normalizedStudentId = studentId?.trim();
    const normalizedClassId = classId?.trim();
    const lessons = await this.prisma.withTenant(tenantId, (tx) =>
      tx.lessonSession.findMany({
        where: {
          tenantId,
          ...(normalizedStudentId != null && normalizedStudentId.length > 0
              ? { focusStudentId: normalizedStudentId }
              : {}),
          ...(normalizedClassId != null && normalizedClassId.length > 0
              ? { classId: normalizedClassId }
              : {}),
          ...(keyword != null && keyword.length > 0
              ? {
                  OR: [
                    { title: { contains: keyword, mode: 'insensitive' } },
                    { className: { contains: keyword, mode: 'insensitive' } },
                    {
                      documentFocus: {
                        contains: keyword,
                        mode: 'insensitive',
                      },
                    },
                    { summary: { contains: keyword, mode: 'insensitive' } },
                  ],
                }
              : {}),
        },
        orderBy: [{ updatedAt: 'desc' }, { title: 'asc' }],
      }),
    );

    return { lessons: lessons.map(mapLessonRecord) };
  }

  @Get(':id')
  async detail(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const lesson = await this.prisma.withTenant(tenantId, (tx) =>
      tx.lessonSession.findUnique({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
      }),
    );

    if (!lesson) {
      throw new NotFoundException('Lesson not found');
    }

    return { lesson: mapLessonRecord(lesson) };
  }
}
