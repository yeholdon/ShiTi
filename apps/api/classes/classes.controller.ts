import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PrismaService } from '../../../src/prisma/prisma.service';
import {
  requireActiveTenantMember,
  requireTenantId,
  requireUserId,
} from '../../../src/tenant/tenant-guards';
import { CreateClassDto } from './dto/create-class.dto';
import { UpdateClassDto } from './dto/update-class.dto';

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

  @Post()
  async create(@Req() req: Request, @Body() body: CreateClassDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);
    const normalizedFocusLabel = body.focusLabel?.trim();

    const classroom = await this.prisma.withTenant(tenantId, (tx) =>
      tx.teachingClass.create({
        data: {
          tenantId,
          id: randomUUID(),
          name: body.name.trim(),
          lessonId: null,
          documentId: null,
          focusStudentId: null,
          focusStudentName: null,
          stageLabel: body.stageLabel.trim(),
          teacherLabel: body.teacherLabel.trim(),
          textbookLabel: body.textbookLabel.trim(),
          focusLabel: normalizedFocusLabel != null && normalizedFocusLabel.length > 0
              ? normalizedFocusLabel
              : '讲义整理',
          activityLabel: '新建档案',
          classSizeLabel: '0 人 · 待补充',
          lessonFocusLabel: '待安排课堂',
          structureInsight: '新建班级档案，等待补充学生、课堂时间线与资料联动。',
          studentCount: 0,
          weeklyLessonCount: 0,
          latestDocLabel: '暂无资料',
          assetLinks: [],
          memberTiers: [],
          lessonTimeline: [],
          summary: '新建班级档案，等待补充成员、课堂安排与资料联动。',
          highlights: ['已创建班级档案，可继续补充学生、课堂和资料。'],
          nextStep: '补充班级成员、安排第一堂课并关联资料。',
        },
      }),
    );

    return { class: mapClassRecord(classroom) };
  }

  @Get()
  async list(
    @Req() req: Request,
    @Query('q') query?: string,
    @Query('studentId') studentId?: string,
    @Query('lessonId') lessonId?: string,
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const keyword = query?.trim();
    const normalizedStudentId = studentId?.trim();
    const normalizedLessonId = lessonId?.trim();
    const classes = await this.prisma.withTenant(tenantId, (tx) =>
      tx.teachingClass.findMany({
        where: {
          tenantId,
          ...(normalizedStudentId != null && normalizedStudentId.length > 0
              ? { focusStudentId: normalizedStudentId }
              : {}),
          ...(normalizedLessonId != null && normalizedLessonId.length > 0
              ? { lessonId: normalizedLessonId }
              : {}),
          ...(keyword != null && keyword.length > 0
              ? {
                  OR: [
                    { name: { contains: keyword, mode: 'insensitive' } },
                    {
                      teacherLabel: { contains: keyword, mode: 'insensitive' },
                    },
                    {
                      latestDocLabel: {
                        contains: keyword,
                        mode: 'insensitive',
                      },
                    },
                    { summary: { contains: keyword, mode: 'insensitive' } },
                  ],
                }
              : {}),
        },
        orderBy: [{ updatedAt: 'desc' }, { name: 'asc' }],
      }),
    );

    return { classes: classes.map(mapClassRecord) };
  }

  @Patch(':id')
  async update(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() body: UpdateClassDto,
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const current = await this.prisma.withTenant(tenantId, (tx) =>
      tx.teachingClass.findUnique({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
      }),
    );

    if (!current) {
      throw new NotFoundException('Class not found');
    }

    const normalizedName = body.name?.trim();
    const normalizedStageLabel = body.stageLabel?.trim();
    const normalizedTeacherLabel = body.teacherLabel?.trim();
    const normalizedTextbookLabel = body.textbookLabel?.trim();
    const normalizedFocusLabel = body.focusLabel?.trim();

    const classroom = await this.prisma.withTenant(tenantId, (tx) =>
      tx.teachingClass.update({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
        data: {
          name: normalizedName != null && normalizedName.length > 0
              ? normalizedName
              : current.name,
          stageLabel:
              normalizedStageLabel != null && normalizedStageLabel.length > 0
                  ? normalizedStageLabel
                  : current.stageLabel,
          teacherLabel: normalizedTeacherLabel != null &&
                  normalizedTeacherLabel.length > 0
              ? normalizedTeacherLabel
              : current.teacherLabel,
          textbookLabel: normalizedTextbookLabel != null &&
                  normalizedTextbookLabel.length > 0
              ? normalizedTextbookLabel
              : current.textbookLabel,
          focusLabel:
              normalizedFocusLabel != null && normalizedFocusLabel.length > 0
                  ? normalizedFocusLabel
                  : current.focusLabel,
        },
      }),
    );

    return { class: mapClassRecord(classroom) };
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
