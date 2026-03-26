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
import { CreateStudentDto } from "./dto/create-student.dto";
import { UpdateStudentDto } from "./dto/update-student.dto";

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
    archivedAt: student.archivedAt,
    createdAt: student.createdAt,
    updatedAt: student.updatedAt,
  };
}

@Controller("students")
@UseGuards(JwtAuthGuard)
export class StudentsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async create(@Req() req: Request, @Body() body: CreateStudentDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);
    const normalizedClassName = body.className?.trim();
    const normalizedClassId = body.classId?.trim();
    const normalizedLessonId = body.lessonId?.trim();
    const normalizedDocumentId = body.documentId?.trim();
    const normalizedDocumentName = body.documentName?.trim();

    const student = await this.prisma.withTenant(tenantId, (tx) =>
      tx.studentProfile.create({
        data: {
          tenantId,
          id: randomUUID(),
          name: body.name.trim(),
          classId:
            normalizedClassId != null && normalizedClassId.length > 0
              ? normalizedClassId
              : null,
          className:
            normalizedClassName != null && normalizedClassName.length > 0
              ? normalizedClassName
              : null,
          lessonId:
            normalizedLessonId != null && normalizedLessonId.length > 0
              ? normalizedLessonId
              : null,
          documentId:
            normalizedDocumentId != null && normalizedDocumentId.length > 0
              ? normalizedDocumentId
              : null,
          documentName:
            normalizedDocumentName != null && normalizedDocumentName.length > 0
              ? normalizedDocumentName
              : null,
          gradeLabel: body.gradeLabel.trim(),
          subjectLabel: body.subjectLabel.trim(),
          textbookLabel: body.textbookLabel.trim(),
          trendLabel: "新建档案",
          habitTag: "待观察",
          habitInsight: "等待补充学习习惯、课堂反馈与课后跟进情况。",
          followUpLevel: "常规关注",
          summary: "新建学生档案，等待补充成绩、错题与课堂反馈。",
          scoreLabel: "暂无成绩",
          historyTrendLabel: "待记录",
          wrongCountLabel: "0 道",
          wrongCount: 0,
          scoreRecords: [],
          feedbackRecords: [],
          wrongQuestionRecords: [],
          highlights: ["已创建学生档案，可继续补充班级、课堂与资料承接。"],
          nextStep: "补充最近一次测评、课堂反馈和错题跟进。",
          archivedAt: null,
        },
      }),
    );

    return { student: mapStudentRecord(student) };
  }

  @Get()
  async list(
    @Req() req: Request,
    @Query("q") query?: string,
    @Query("classId") classId?: string,
    @Query("lessonId") lessonId?: string,
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
          archivedAt: null,
          ...(normalizedClassId == null || normalizedClassId === ""
            ? {}
            : { classId: normalizedClassId }),
          ...(normalizedLessonId == null || normalizedLessonId === ""
            ? {}
            : { lessonId: normalizedLessonId }),
          ...(keyword == null || keyword === ""
            ? {}
            : {
                OR: [
                  { name: { contains: keyword, mode: "insensitive" } },
                  { className: { contains: keyword, mode: "insensitive" } },
                  { documentName: { contains: keyword, mode: "insensitive" } },
                  { summary: { contains: keyword, mode: "insensitive" } },
                ],
              }),
        },
        orderBy: [{ updatedAt: "desc" }, { name: "asc" }],
      }),
    );

    return { students: students.map(mapStudentRecord) };
  }

  @Patch(":id")
  async update(
    @Req() req: Request,
    @Param("id") id: string,
    @Body() body: UpdateStudentDto,
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const current = await this.prisma.withTenant(tenantId, (tx) =>
      tx.studentProfile.findUnique({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
      }),
    );

    if (!current) {
      throw new NotFoundException("Student not found");
    }

    const normalizedName = body.name?.trim();
    const normalizedGradeLabel = body.gradeLabel?.trim();
    const normalizedSubjectLabel = body.subjectLabel?.trim();
    const normalizedTextbookLabel = body.textbookLabel?.trim();
    const normalizedClassName = body.className?.trim();
    const normalizedClassId = body.classId?.trim();
    const normalizedLessonId = body.lessonId?.trim();
    const normalizedDocumentId = body.documentId?.trim();
    const normalizedDocumentName = body.documentName?.trim();

    const student = await this.prisma.withTenant(tenantId, (tx) =>
      tx.studentProfile.update({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
        data: {
          name:
            normalizedName != null && normalizedName.length > 0
              ? normalizedName
              : current.name,
          gradeLabel:
            normalizedGradeLabel != null && normalizedGradeLabel.length > 0
              ? normalizedGradeLabel
              : current.gradeLabel,
          subjectLabel:
            normalizedSubjectLabel != null && normalizedSubjectLabel.length > 0
              ? normalizedSubjectLabel
              : current.subjectLabel,
          textbookLabel:
            normalizedTextbookLabel != null &&
            normalizedTextbookLabel.length > 0
              ? normalizedTextbookLabel
              : current.textbookLabel,
          classId:
            body.classId == null
              ? current.classId
              : normalizedClassId != null && normalizedClassId.length > 0
                ? normalizedClassId
                : null,
          className:
            body.className == null
              ? body.classId == null
                ? current.className
                : normalizedClassId != null && normalizedClassId.length > 0
                  ? current.className
                  : null
              : normalizedClassName != null && normalizedClassName.length > 0
                ? normalizedClassName
                : null,
          lessonId:
            body.lessonId == null
              ? current.lessonId
              : normalizedLessonId != null && normalizedLessonId.length > 0
                ? normalizedLessonId
                : null,
          documentId:
            body.documentId == null
              ? current.documentId
              : normalizedDocumentId != null && normalizedDocumentId.length > 0
                ? normalizedDocumentId
                : null,
          documentName:
            body.documentId == null
              ? body.documentName == null
                ? current.documentName
                : normalizedDocumentName != null &&
                    normalizedDocumentName.length > 0
                  ? normalizedDocumentName
                  : null
              : normalizedDocumentId != null && normalizedDocumentId.length > 0
                ? normalizedDocumentName != null &&
                        normalizedDocumentName.length > 0
                    ? normalizedDocumentName
                    : current.documentName
                : null,
          archivedAt:
            body.archived == null
              ? current.archivedAt
              : body.archived
                ? current.archivedAt ?? new Date()
                : null,
        },
      }),
    );

    return { student: mapStudentRecord(student) };
  }

  @Delete(":id")
  async remove(@Req() req: Request, @Param("id") id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const current = await this.prisma.withTenant(tenantId, (tx) =>
      tx.studentProfile.findUnique({
        where: {
          tenantId_id: {
            tenantId,
            id,
          },
        },
      }),
    );

    if (!current) {
      throw new NotFoundException("Student not found");
    }

    await this.prisma.withTenant(tenantId, (tx) =>
      tx.studentProfile.delete({
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
      throw new NotFoundException("Student not found");
    }

    return { student: mapStudentRecord(student) };
  }
}
