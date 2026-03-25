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

function mapStudentRecord(student: any) {
  return {
    id: student.id,
    tenantId: student.tenantId,
    name: student.name,
    classId: student.classId,
    className: student.className,
    lessonId: student.lessonId,
    documentId: student.documentId,
    documentName: student.documentName,
    gradeLabel: student.gradeLabel,
    subjectLabel: student.subjectLabel,
    textbookLabel: student.textbookLabel,
    trendLabel: student.trendLabel,
    habitTag: student.habitTag,
    habitInsight: student.habitInsight,
    followUpLevel: student.followUpLevel,
    summary: student.summary,
    scoreLabel: student.scoreLabel,
    historyTrendLabel: student.historyTrendLabel,
    wrongCountLabel: student.wrongCountLabel,
    wrongCount: student.wrongCount,
    scoreRecords: student.scoreRecords,
    feedbackRecords: student.feedbackRecords,
    wrongQuestionRecords: student.wrongQuestionRecords,
    highlights: student.highlights,
    nextStep: student.nextStep,
    createdAt: student.createdAt,
    updatedAt: student.updatedAt,
  };
}

@Controller('students')
@UseGuards(JwtAuthGuard)
export class StudentsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(
    @Req() req: Request,
    @Query('q') query?: string,
    @Query('classId') classId?: string,
    @Query('lessonId') lessonId?: string,
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const keyword = query?.trim();
    const normalizedClassId = classId?.trim();
    const normalizedLessonId = lessonId?.trim();
    const students = await this.prisma.withTenant(tenantId, (tx) =>
      tx.studentProfile.findMany({
        where: {
          tenantId,
          ...(normalizedClassId == null || normalizedClassId === ''
              ? {}
              : {'classId': normalizedClassId}),
          ...(normalizedLessonId == null || normalizedLessonId === ''
              ? {}
              : {'lessonId': normalizedLessonId}),
          ...(keyword == null || keyword === ''
              ? {}
              : {
                  'OR': [
                    { name: { contains: keyword, mode: 'insensitive' } },
                    { className: { contains: keyword, mode: 'insensitive' } },
                    { documentName: { contains: keyword, mode: 'insensitive' } },
                    { summary: { contains: keyword, mode: 'insensitive' } },
                  ],
                }),
        },
        orderBy: [{ updatedAt: 'desc' }, { name: 'asc' }],
      }),
    );

    return { students: students.map(mapStudentRecord) };
  }

  @Get(':id')
  async detail(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const student = await this.prisma.withTenant(tenantId, (tx) =>
      tx.studentProfile.findUnique({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
      }),
    );

    if (!student) {
      throw new NotFoundException('Student not found');
    }

    return { student: mapStudentRecord(student) };
  }
}
