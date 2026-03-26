import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from "@nestjs/common";
import { randomUUID } from "crypto";
import type { Request } from "express";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { PrismaService } from "../../../src/prisma/prisma.service";
import {
  requireActiveTenantMember,
  requireTenantId,
  requireUserId,
} from "../../../src/tenant/tenant-guards";
import { CreateLessonDto } from "./dto/create-lesson.dto";
import { UpdateLessonDto } from "./dto/update-lesson.dto";

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
    archivedAt: lesson.archivedAt,
    createdAt: lesson.createdAt,
    updatedAt: lesson.updatedAt,
  };
}

function formatLessonFeedbackStatus(studentCount: number) {
  if (studentCount <= 0) {
    return "待回收";
  }
  return `${studentCount} 人已承接`;
}

@Controller("lessons")
@UseGuards(JwtAuthGuard)
export class LessonsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async create(@Req() req: Request, @Body() body: CreateLessonDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);
    const normalizedClassScopeLabel = body.classScopeLabel?.trim();
    const normalizedFocusStudentId = body.focusStudentId?.trim();
    const normalizedFocusStudentName = body.focusStudentName?.trim();
    const normalizedClassId = body.classId?.trim();
    const normalizedDocumentId = body.documentId?.trim();
    const normalizedDocumentFocus = body.documentFocus?.trim();
    const normalizedFeedbackStudentIds = [
      ...new Set(
        (body.feedbackStudentIds ?? [])
            .map((id) => id.trim())
            .filter((id) => id.length > 0),
      ),
    ];
    const lessonId = randomUUID();

    const lesson = await this.prisma.withTenant(tenantId, async (tx) => {
      if (normalizedFeedbackStudentIds.length > 0) {
        await tx.studentProfile.updateMany({
          where: {
            tenantId,
            id: {
              in: normalizedFeedbackStudentIds,
            },
          },
          data: {
            lessonId,
          },
        });
      }

      return tx.lessonSession.create({
        data: {
          tenantId,
          id: lessonId,
          title: body.title.trim(),
          classId:
            normalizedClassId != null && normalizedClassId.length > 0
              ? normalizedClassId
              : null,
          className:
            normalizedClassScopeLabel != null &&
            normalizedClassScopeLabel.length > 0 &&
            normalizedClassScopeLabel != "未绑定班级"
              ? normalizedClassScopeLabel
              : null,
          focusStudentId:
            normalizedFocusStudentId != null &&
            normalizedFocusStudentId.length > 0
              ? normalizedFocusStudentId
              : null,
          focusStudentName:
            normalizedFocusStudentId != null &&
            normalizedFocusStudentId.length > 0 &&
            normalizedFocusStudentName != null &&
            normalizedFocusStudentName.length > 0
              ? normalizedFocusStudentName
              : null,
          teacherLabel: body.teacherLabel.trim(),
          scheduleLabel: body.scheduleLabel.trim(),
          scheduleTag: "待安排",
          classScopeLabel:
            normalizedClassScopeLabel != null &&
            normalizedClassScopeLabel.length > 0
              ? normalizedClassScopeLabel
              : "未绑定班级",
          documentFocus:
            normalizedDocumentId != null &&
            normalizedDocumentId.length > 0 &&
            normalizedDocumentFocus != null &&
            normalizedDocumentFocus.length > 0
              ? normalizedDocumentFocus
              : "未绑定资料",
          documentId:
            normalizedDocumentId != null && normalizedDocumentId.length > 0
              ? normalizedDocumentId
              : null,
          feedbackStatus:
            normalizedFeedbackStudentIds.length === 0
              ? "待回收"
              : `${normalizedFeedbackStudentIds.length} 人已承接`,
          followUpLabel: "待安排",
          feedbackInsight: "新建课堂档案，等待补充资料、反馈明细与课后任务。",
          feedbackRecords: [],
          assetRecords: [],
          taskRecords: [],
          summary: "新建课堂档案，等待补充班级、资料和课后反馈。",
          highlights: ["已创建课堂档案，可继续补充班级、资料与反馈任务。"],
          nextStep: "绑定班级、安排主资料并补充首轮课后反馈。",
          archivedAt: null,
        },
      });
    });

    return { lesson: mapLessonRecord(lesson) };
  }

  @Get()
  async list(
    @Req() req: Request,
    @Query("q") query?: string,
    @Query("studentId") studentId?: string,
    @Query("classId") classId?: string,
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
          archivedAt: null,
          ...(normalizedStudentId != null && normalizedStudentId.length > 0
            ? { focusStudentId: normalizedStudentId }
            : {}),
          ...(normalizedClassId != null && normalizedClassId.length > 0
            ? { classId: normalizedClassId }
            : {}),
          ...(keyword != null && keyword.length > 0
            ? {
                OR: [
                  { title: { contains: keyword, mode: "insensitive" } },
                  { className: { contains: keyword, mode: "insensitive" } },
                  {
                    documentFocus: {
                      contains: keyword,
                      mode: "insensitive",
                    },
                  },
                  { summary: { contains: keyword, mode: "insensitive" } },
                ],
              }
            : {}),
        },
        orderBy: [{ updatedAt: "desc" }, { title: "asc" }],
      }),
    );

    return { lessons: lessons.map(mapLessonRecord) };
  }

  @Patch(":id")
  async update(
    @Req() req: Request,
    @Param("id") id: string,
    @Body() body: UpdateLessonDto,
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const current = await this.prisma.withTenant(tenantId, (tx) =>
      tx.lessonSession.findUnique({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
      }),
    );

    if (!current) {
      throw new NotFoundException("Lesson not found");
    }

    const normalizedTitle = body.title?.trim();
    const normalizedTeacherLabel = body.teacherLabel?.trim();
    const normalizedScheduleLabel = body.scheduleLabel?.trim();
    const normalizedClassScopeLabel = body.classScopeLabel?.trim();
    const normalizedFocusStudentId = body.focusStudentId?.trim();
    const normalizedFocusStudentName = body.focusStudentName?.trim();
    const normalizedClassId = body.classId?.trim();
    const normalizedDocumentId = body.documentId?.trim();
    const normalizedDocumentFocus = body.documentFocus?.trim();
    const normalizedFeedbackStudentIds =
      body.feedbackStudentIds
        ?.map((studentId) => studentId.trim())
        .filter((studentId) => studentId.length > 0)
        .filter(
          (studentId, index, values) => values.indexOf(studentId) === index,
        ) ?? null;
    const nextFocusStudentId =
      body.focusStudentId == null
        ? current.focusStudentId
        : normalizedFocusStudentId != null &&
            normalizedFocusStudentId.length > 0
          ? normalizedFocusStudentId
          : null;
    const nextFocusStudentName =
      body.focusStudentId == null
        ? current.focusStudentName
        : normalizedFocusStudentId != null &&
            normalizedFocusStudentId.length > 0 &&
            normalizedFocusStudentName != null &&
            normalizedFocusStudentName.length > 0
          ? normalizedFocusStudentName
          : null;
    const focusStudentStillIncluded =
      normalizedFeedbackStudentIds == null ||
      nextFocusStudentId == null ||
      normalizedFeedbackStudentIds.includes(nextFocusStudentId);

    const lesson = await this.prisma.withTenant(tenantId, async (tx) => {
      if (normalizedFeedbackStudentIds != null) {
        await tx.studentProfile.updateMany({
          where: {
            tenantId,
            lessonId: id,
            ...(normalizedFeedbackStudentIds.length === 0
              ? {}
              : { id: { notIn: normalizedFeedbackStudentIds } }),
          },
          data: {
            lessonId: null,
          },
        });
        if (normalizedFeedbackStudentIds.length > 0) {
          await tx.studentProfile.updateMany({
            where: {
              tenantId,
              id: { in: normalizedFeedbackStudentIds },
            },
            data: {
              lessonId: id,
            },
          });
        }
      }

      return tx.lessonSession.update({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
        data: {
          title:
            normalizedTitle != null && normalizedTitle.length > 0
              ? normalizedTitle
              : current.title,
          teacherLabel:
            normalizedTeacherLabel != null && normalizedTeacherLabel.length > 0
              ? normalizedTeacherLabel
              : current.teacherLabel,
          scheduleLabel:
            normalizedScheduleLabel != null &&
            normalizedScheduleLabel.length > 0
              ? normalizedScheduleLabel
              : current.scheduleLabel,
          classScopeLabel:
            normalizedClassScopeLabel != null &&
            normalizedClassScopeLabel.length > 0
              ? normalizedClassScopeLabel
              : current.classScopeLabel,
          className:
            body.classScopeLabel == null
              ? body.classId == null
                ? current.className
                : normalizedClassId != null &&
                    normalizedClassId.length > 0 &&
                    normalizedClassScopeLabel != null &&
                    normalizedClassScopeLabel.length > 0 &&
                    normalizedClassScopeLabel != "未绑定班级"
                  ? normalizedClassScopeLabel
                  : null
              : normalizedClassScopeLabel != null &&
                  normalizedClassScopeLabel.length > 0 &&
                  normalizedClassScopeLabel != "未绑定班级"
                ? normalizedClassScopeLabel
                : null,
          classId:
            body.classId == null
              ? current.classId
              : normalizedClassId != null && normalizedClassId.length > 0
                ? normalizedClassId
                : null,
          documentId:
            body.documentId == null
              ? current.documentId
              : normalizedDocumentId != null && normalizedDocumentId.length > 0
                ? normalizedDocumentId
                : null,
          documentFocus:
            body.documentId == null
              ? body.documentFocus == null
                ? current.documentFocus
                : normalizedDocumentFocus != null &&
                    normalizedDocumentFocus.length > 0
                  ? normalizedDocumentFocus
                  : current.documentFocus
              : normalizedDocumentId != null && normalizedDocumentId.length > 0
                ? normalizedDocumentFocus != null &&
                  normalizedDocumentFocus.length > 0
                  ? normalizedDocumentFocus
                  : current.documentFocus
                : "未绑定资料",
          focusStudentId: focusStudentStillIncluded ? nextFocusStudentId : null,
          focusStudentName: focusStudentStillIncluded
            ? nextFocusStudentName
            : null,
          feedbackStatus:
            normalizedFeedbackStudentIds == null
              ? current.feedbackStatus
              : formatLessonFeedbackStatus(normalizedFeedbackStudentIds.length),
          archivedAt:
            body.archived == null
              ? current.archivedAt
              : body.archived
                ? current.archivedAt ?? new Date()
                : null,
        },
      });
    });

    return { lesson: mapLessonRecord(lesson) };
  }

  @Delete(":id")
  async remove(@Req() req: Request, @Param("id") id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const current = await this.prisma.withTenant(tenantId, (tx) =>
      tx.lessonSession.findUnique({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
      }),
    );

    if (!current) {
      throw new NotFoundException("Lesson not found");
    }

    await this.prisma.withTenant(tenantId, (tx) =>
      tx.lessonSession.delete({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
      }),
    );

    return { removedId: id };
  }

  @Get(":id")
  async detail(@Req() req: Request, @Param("id") id: string) {
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
      throw new NotFoundException("Lesson not found");
    }

    return { lesson: mapLessonRecord(lesson) };
  }
}
