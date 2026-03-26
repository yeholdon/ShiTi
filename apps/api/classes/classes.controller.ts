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
import { CreateClassDto } from "./dto/create-class.dto";
import { UpdateClassDto } from "./dto/update-class.dto";

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
    archivedAt: classroom.archivedAt,
    createdAt: classroom.createdAt,
    updatedAt: classroom.updatedAt,
  };
}

function formatClassSizeLabel(studentCount: number) {
  if (studentCount <= 0) {
    return "0 人 · 待补充";
  }
  return `${studentCount} 人 · 实时关联`;
}

@Controller("classes")
@UseGuards(JwtAuthGuard)
export class ClassesController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async create(@Req() req: Request, @Body() body: CreateClassDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);
    const normalizedFocusLabel = body.focusLabel?.trim();
    const normalizedFocusStudentId = body.focusStudentId?.trim();
    const normalizedFocusStudentName = body.focusStudentName?.trim();
    const normalizedLessonId = body.lessonId?.trim();
    const normalizedLessonFocusLabel = body.lessonFocusLabel?.trim();
    const normalizedDocumentId = body.documentId?.trim();
    const normalizedLatestDocLabel = body.latestDocLabel?.trim();
    const normalizedMemberStudentIds = [
      ...new Set(
        (body.memberStudentIds ?? [])
            .map((id) => id.trim())
            .filter((id) => id.length > 0),
      ),
    ];
    const classId = randomUUID();
    const className = body.name.trim();

    const classroom = await this.prisma.withTenant(tenantId, async (tx) => {
      if (normalizedMemberStudentIds.length > 0) {
        await tx.studentProfile.updateMany({
          where: {
            tenantId,
            id: {
              in: normalizedMemberStudentIds,
            },
          },
          data: {
            classId,
            className,
          },
        });
      }

      return tx.teachingClass.create({
        data: {
          tenantId,
          id: classId,
          name: className,
          lessonId:
            normalizedLessonId != null && normalizedLessonId.length > 0
              ? normalizedLessonId
              : null,
          documentId:
            normalizedDocumentId != null && normalizedDocumentId.length > 0
              ? normalizedDocumentId
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
          stageLabel: body.stageLabel.trim(),
          teacherLabel: body.teacherLabel.trim(),
          textbookLabel: body.textbookLabel.trim(),
          focusLabel:
            normalizedFocusLabel != null && normalizedFocusLabel.length > 0
              ? normalizedFocusLabel
              : "讲义整理",
          activityLabel: "新建档案",
          classSizeLabel:
            normalizedMemberStudentIds.length === 0
              ? "0 人 · 待补充"
              : `${normalizedMemberStudentIds.length} 人 · 实时关联`,
          lessonFocusLabel:
            normalizedLessonId != null &&
            normalizedLessonId.length > 0 &&
            normalizedLessonFocusLabel != null &&
            normalizedLessonFocusLabel.length > 0
              ? normalizedLessonFocusLabel
              : "待安排课堂",
          structureInsight:
            "新建班级档案，等待补充学生、课堂时间线与资料联动。",
          studentCount: normalizedMemberStudentIds.length,
          weeklyLessonCount: 0,
          latestDocLabel:
            normalizedDocumentId != null &&
            normalizedDocumentId.length > 0 &&
            normalizedLatestDocLabel != null &&
            normalizedLatestDocLabel.length > 0
              ? normalizedLatestDocLabel
              : "暂无资料",
          assetLinks: [],
          memberTiers: [],
          lessonTimeline: [],
          summary: "新建班级档案，等待补充成员、课堂安排与资料联动。",
          highlights: ["已创建班级档案，可继续补充学生、课堂和资料。"],
          nextStep: "补充班级成员、安排第一堂课并关联资料。",
          archivedAt: null,
        },
      });
    });

    return { class: mapClassRecord(classroom) };
  }

  @Get()
  async list(
    @Req() req: Request,
    @Query("q") query?: string,
    @Query("studentId") studentId?: string,
    @Query("lessonId") lessonId?: string,
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
          archivedAt: null,
          ...(normalizedStudentId != null && normalizedStudentId.length > 0
            ? { focusStudentId: normalizedStudentId }
            : {}),
          ...(normalizedLessonId != null && normalizedLessonId.length > 0
            ? { lessonId: normalizedLessonId }
            : {}),
          ...(keyword != null && keyword.length > 0
            ? {
                OR: [
                  { name: { contains: keyword, mode: "insensitive" } },
                  {
                    teacherLabel: { contains: keyword, mode: "insensitive" },
                  },
                  {
                    latestDocLabel: {
                      contains: keyword,
                      mode: "insensitive",
                    },
                  },
                  { summary: { contains: keyword, mode: "insensitive" } },
                ],
              }
            : {}),
        },
        orderBy: [{ updatedAt: "desc" }, { name: "asc" }],
      }),
    );

    return { classes: classes.map(mapClassRecord) };
  }

  @Patch(":id")
  async update(
    @Req() req: Request,
    @Param("id") id: string,
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
      throw new NotFoundException("Class not found");
    }

    const normalizedName = body.name?.trim();
    const normalizedStageLabel = body.stageLabel?.trim();
    const normalizedTeacherLabel = body.teacherLabel?.trim();
    const normalizedTextbookLabel = body.textbookLabel?.trim();
    const normalizedFocusLabel = body.focusLabel?.trim();
    const normalizedFocusStudentId = body.focusStudentId?.trim();
    const normalizedFocusStudentName = body.focusStudentName?.trim();
    const normalizedLessonId = body.lessonId?.trim();
    const normalizedLessonFocusLabel = body.lessonFocusLabel?.trim();
    const normalizedDocumentId = body.documentId?.trim();
    const normalizedLatestDocLabel = body.latestDocLabel?.trim();
    const normalizedMemberStudentIds =
      body.memberStudentIds
        ?.map((studentId) => studentId.trim())
        .filter((studentId) => studentId.length > 0)
        .filter(
          (studentId, index, values) => values.indexOf(studentId) === index,
        ) ?? null;
    const effectiveClassName =
      normalizedName != null && normalizedName.length > 0
        ? normalizedName
        : current.name;
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
    const focusStudentStillMember =
      normalizedMemberStudentIds == null ||
      nextFocusStudentId == null ||
      normalizedMemberStudentIds.includes(nextFocusStudentId);

    const classroom = await this.prisma.withTenant(tenantId, async (tx) => {
      if (normalizedMemberStudentIds != null) {
        await tx.studentProfile.updateMany({
          where: {
            tenantId,
            classId: id,
            ...(normalizedMemberStudentIds.length === 0
              ? {}
              : { id: { notIn: normalizedMemberStudentIds } }),
          },
          data: {
            classId: null,
            className: null,
          },
        });
        if (normalizedMemberStudentIds.length > 0) {
          await tx.studentProfile.updateMany({
            where: {
              tenantId,
              id: { in: normalizedMemberStudentIds },
            },
            data: {
              classId: id,
              className: effectiveClassName,
            },
          });
        }
      } else if (effectiveClassName != current.name) {
        await tx.studentProfile.updateMany({
          where: {
            tenantId,
            classId: id,
          },
          data: {
            className: effectiveClassName,
          },
        });
      }

      return tx.teachingClass.update({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
        data: {
          name: effectiveClassName,
          stageLabel:
            normalizedStageLabel != null && normalizedStageLabel.length > 0
              ? normalizedStageLabel
              : current.stageLabel,
          teacherLabel:
            normalizedTeacherLabel != null && normalizedTeacherLabel.length > 0
              ? normalizedTeacherLabel
              : current.teacherLabel,
          textbookLabel:
            normalizedTextbookLabel != null &&
            normalizedTextbookLabel.length > 0
              ? normalizedTextbookLabel
              : current.textbookLabel,
          focusLabel:
            normalizedFocusLabel != null && normalizedFocusLabel.length > 0
              ? normalizedFocusLabel
              : current.focusLabel,
          focusStudentId: focusStudentStillMember ? nextFocusStudentId : null,
          focusStudentName: focusStudentStillMember
            ? nextFocusStudentName
            : null,
          lessonId:
            body.lessonId == null
              ? current.lessonId
              : normalizedLessonId != null && normalizedLessonId.length > 0
                ? normalizedLessonId
                : null,
          lessonFocusLabel:
            body.lessonId == null
              ? body.lessonFocusLabel == null
                ? current.lessonFocusLabel
                : normalizedLessonFocusLabel != null &&
                    normalizedLessonFocusLabel.length > 0
                  ? normalizedLessonFocusLabel
                  : current.lessonFocusLabel
              : normalizedLessonId != null && normalizedLessonId.length > 0
                ? normalizedLessonFocusLabel != null &&
                  normalizedLessonFocusLabel.length > 0
                  ? normalizedLessonFocusLabel
                  : current.lessonFocusLabel
                : "待安排课堂",
          documentId:
            body.documentId == null
              ? current.documentId
              : normalizedDocumentId != null && normalizedDocumentId.length > 0
                ? normalizedDocumentId
                : null,
          latestDocLabel:
            body.documentId == null
              ? body.latestDocLabel == null
                ? current.latestDocLabel
                : normalizedLatestDocLabel != null &&
                    normalizedLatestDocLabel.length > 0
                  ? normalizedLatestDocLabel
                  : current.latestDocLabel
              : normalizedDocumentId != null && normalizedDocumentId.length > 0
                ? normalizedLatestDocLabel != null &&
                  normalizedLatestDocLabel.length > 0
                  ? normalizedLatestDocLabel
                  : current.latestDocLabel
                : "暂无资料",
          studentCount:
            normalizedMemberStudentIds == null
              ? current.studentCount
              : normalizedMemberStudentIds.length,
          classSizeLabel:
            normalizedMemberStudentIds == null
              ? current.classSizeLabel
              : formatClassSizeLabel(normalizedMemberStudentIds.length),
          archivedAt:
            body.archived == null
              ? current.archivedAt
              : body.archived
                ? current.archivedAt ?? new Date()
                : null,
        },
      });
    });

    return { class: mapClassRecord(classroom) };
  }

  @Delete(":id")
  async remove(@Req() req: Request, @Param("id") id: string) {
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
      throw new NotFoundException("Class not found");
    }

    await this.prisma.withTenant(tenantId, (tx) =>
      tx.teachingClass.delete({
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
      throw new NotFoundException("Class not found");
    }

    return { class: mapClassRecord(classroom) };
  }
}
