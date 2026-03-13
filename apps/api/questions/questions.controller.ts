import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Put,
  Req,
  UseGuards
} from '@nestjs/common';
import type { Request } from 'express';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../src/prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import {
  requireActiveTenantMember,
  requireTenantId,
  requireTenantRole,
  requireUserId
} from '../../../src/tenant/tenant-guards';
import { UuidIdParamDto } from '../../../src/common/dto/uuid-id-param.dto';
import { AuditLogService } from '../../../src/common/audit/audit-log.service';
import { QuestionsImportService } from '../../../src/domain/questions/questions-import.service';
import { CreateQuestionDto } from './dto/create-question.dto';
import { ImportQuestionsDto } from './dto/import-questions.dto';
import { SetQuestionTagsDto } from './dto/set-question-tags.dto';
import { SetQuestionTaxonomyDto } from './dto/set-question-taxonomy.dto';
import { UpsertQuestionBlankAnswerDto } from './dto/upsert-question-blank-answer.dto';
import { UpsertQuestionChoiceAnswerDto } from './dto/upsert-question-choice-answer.dto';
import { UpsertQuestionContentDto } from './dto/upsert-question-content.dto';
import { UpsertQuestionExplanationDto } from './dto/upsert-question-explanation.dto';
import { UpsertQuestionSolutionAnswerDto } from './dto/upsert-question-solution-answer.dto';
import { UpsertQuestionSourceDto } from './dto/upsert-question-source.dto';
import { UpdateQuestionDto } from './dto/update-question.dto';
import { ensureTenantOrSystemSubject } from '../../../src/domain/questions/subject-access';
import {
  ensureTenantChapter,
  ensureTenantOrSystemGrade,
  ensureTenantOrSystemStage,
  ensureTenantOrSystemTextbook
} from '../../../src/domain/questions/taxonomy-access';
import { validateAssetReferences } from '../../../src/domain/assets/asset-reference-validation';
import {
  normalizeExplanationRecord,
  normalizeSolutionAnswerRecord,
  wrapLatexAsBlocks
} from '../../../src/domain/questions/explanation-blocks';

function extractBlockText(value: unknown): string[] {
  if (typeof value === 'string') return [value];
  if (Array.isArray(value)) return value.flatMap((item) => extractBlockText(item));
  if (value && typeof value === 'object') {
    return Object.values(value as Record<string, unknown>).flatMap((item) => extractBlockText(item));
  }
  return [];
}

@Controller('questions')
@UseGuards(JwtAuthGuard)
export class QuestionsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly questionsImport: QuestionsImportService,
    private readonly audit: AuditLogService
  ) {}

  private validateImportBody(body: ImportQuestionsDto) {
    if (!Array.isArray(body?.items) || body.items.length === 0) {
      throw new BadRequestException({
        code: 'validation_failed',
        message: 'Missing items',
        details: [{ field: 'items', messages: ['Missing items'] }]
      });
    }

    if (body.items.length > 200) {
      throw new BadRequestException({
        code: 'validation_failed',
        message: 'Too many items (max 200)',
        details: [{ field: 'items', messages: ['Too many items (max 200)'] }]
      });
    }
  }

  @Post()
  async create(@Req() req: Request, @Body() body: CreateQuestionDto) {
    const tenantId = requireTenantId(req);
    const ownerUserId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, ownerUserId, ['admin', 'owner']);

    const subjectId = body.subjectId
      ? await ensureTenantOrSystemSubject(this.prisma, tenantId, body.subjectId)
      : await this.prisma.subject
          .findFirst({ where: { tenantId: null, isSystem: true }, orderBy: { createdAt: 'asc' } })
          .then((s) => s?.id);

    if (!subjectId) throw new Error('No system subject found; run prisma seed');

    const question = await this.prisma.withTenant(tenantId, (tx) =>
      tx.question.create({
        data: {
          tenantId,
          type: 'single_choice',
          difficulty: 3,
          defaultScore: '5.00',
          subjectId,
          ownerUserId,
          visibility: 'private'
        }
      })
    );

    await this.audit.record({
      tenantId,
      userId: ownerUserId,
      action: 'question.created',
      targetType: 'question',
      targetId: question.id
    });

    return { question };
  }

  @Post('import')
  async importQuestions(
    @Req() req: Request,
    @Body() body: ImportQuestionsDto
  ) {
    const tenantId = requireTenantId(req);
    const ownerUserId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, ownerUserId, ['admin', 'owner']);
    this.validateImportBody(body);

    return this.questionsImport.importQuestions({
      tenantId,
      ownerUserId,
      dryRun: body?.dryRun,
      items: body.items as any
    });
  }

  @Get()
  async list(@Req() req: Request) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const query = (req as any)?.query || {};
    const includeParam = String(query.include || '');
    const include = includeParam
      .split(',')
      .map((v) => v.trim())
      .filter(Boolean);

    const includeTags = include.includes('tags');
    const includeSummary = include.includes('summary');
    const tagId = typeof query.tagId === 'string' && query.tagId.trim() ? query.tagId.trim() : undefined;
    const stageId = typeof query.stageId === 'string' && query.stageId.trim() ? query.stageId.trim() : undefined;
    const gradeId = typeof query.gradeId === 'string' && query.gradeId.trim() ? query.gradeId.trim() : undefined;
    const textbookId = typeof query.textbookId === 'string' && query.textbookId.trim() ? query.textbookId.trim() : undefined;
    const chapterId = typeof query.chapterId === 'string' && query.chapterId.trim() ? query.chapterId.trim() : undefined;
    const type = typeof query.type === 'string' && query.type.trim() ? query.type.trim() : undefined;
    const visibility = typeof query.visibility === 'string' && query.visibility.trim() ? query.visibility.trim() : undefined;
    const subjectId = typeof query.subjectId === 'string' && query.subjectId.trim() ? query.subjectId.trim() : undefined;
    const keyword = typeof query.q === 'string' && query.q.trim() ? query.q.trim().toLowerCase() : undefined;
    const difficulty =
      typeof query.difficulty === 'string' && query.difficulty.trim() ? Number(query.difficulty.trim()) : undefined;
    const offsetRaw = typeof query.offset === 'string' && query.offset.trim() ? Number(query.offset.trim()) : 0;
    const limitRaw = typeof query.limit === 'string' && query.limit.trim() ? Number(query.limit.trim()) : 50;
    const sortByRaw = typeof query.sortBy === 'string' && query.sortBy.trim() ? query.sortBy.trim() : 'createdAt';
    const sortOrderRaw = typeof query.sortOrder === 'string' && query.sortOrder.trim() ? query.sortOrder.trim() : 'desc';
    const offset = Number.isFinite(offsetRaw) ? Math.max(Math.trunc(offsetRaw), 0) : 0;
    const take = Number.isFinite(limitRaw) ? Math.min(Math.max(Math.trunc(limitRaw), 1), 100) : 50;
    const sortBy = ['createdAt', 'updatedAt', 'difficulty'].includes(sortByRaw) ? sortByRaw : 'createdAt';
    const sortOrder = sortOrderRaw === 'asc' ? 'asc' : 'desc';
    const orderBy = { [sortBy]: sortOrder } as Prisma.QuestionOrderByWithRelationInput;

    const where: Prisma.QuestionWhereInput = { tenantId };
    if (type) where.type = type as any;
    if (visibility) where.visibility = visibility as any;
    if (subjectId) where.subjectId = subjectId;
    if (typeof difficulty === 'number' && Number.isFinite(difficulty)) where.difficulty = difficulty;

    const result = await this.prisma.withTenant(tenantId, async (tx) => {
      let filteredQuestionIds: string[] | undefined;
      const intersectQuestionIds = (ids: string[]) => {
        filteredQuestionIds = filteredQuestionIds
          ? filteredQuestionIds.filter((existingId) => ids.includes(existingId))
          : ids;
      };

      if (stageId) {
        await ensureTenantOrSystemStage(this.prisma, tenantId, stageId);
        const rows = await tx.questionStage.findMany({ where: { tenantId, stageId }, select: { questionId: true } });
        intersectQuestionIds(rows.map((row) => row.questionId));
      }

      if (tagId) {
        const tag = await tx.questionTag.findUnique({ where: { tenantId_id: { tenantId, id: tagId } } });
        if (!tag) throw new BadRequestException('Tag not found');
        const rows = await tx.questionTagging.findMany({ where: { tenantId, tagId }, select: { questionId: true } });
        intersectQuestionIds(rows.map((row) => row.questionId));
      }

      if (gradeId) {
        await ensureTenantOrSystemGrade(this.prisma, tenantId, gradeId);
        const rows = await tx.questionGrade.findMany({ where: { tenantId, gradeId }, select: { questionId: true } });
        intersectQuestionIds(rows.map((row) => row.questionId));
      }

      if (textbookId) {
        await ensureTenantOrSystemTextbook(this.prisma, tenantId, textbookId);
        const rows = await tx.questionTextbook.findMany({ where: { tenantId, textbookId }, select: { questionId: true } });
        intersectQuestionIds(rows.map((row) => row.questionId));
      }

      if (chapterId) {
        await ensureTenantChapter(this.prisma, tenantId, chapterId);
        const rows = await tx.questionChapter.findMany({ where: { tenantId, chapterId }, select: { questionId: true } });
        intersectQuestionIds(rows.map((row) => row.questionId));
      }

      if (filteredQuestionIds && filteredQuestionIds.length === 0) {
        return {
          questions: [],
          meta: { limit: take, offset, returned: 0, total: 0, hasMore: false, sortBy, sortOrder }
        };
      }

      const scopedWhere = filteredQuestionIds ? { ...where, id: { in: filteredQuestionIds } } : where;
      let pagedQuestions: any[] = [];
      let total = 0;
      if (keyword) {
        const baseQuestions = await tx.question.findMany({
          where: scopedWhere,
          orderBy
        });
        const contents = await tx.questionContent.findMany({
          where: { tenantId, questionId: { in: baseQuestions.map((question: any) => question.id) } }
        });
        const textByQuestionId = new Map<string, string>();
        for (const content of contents) {
          textByQuestionId.set(content.questionId, JSON.stringify(content.stemBlocks).toLowerCase());
        }
        const filteredQuestions = baseQuestions.filter((question: any) =>
          (textByQuestionId.get(question.id) || '').includes(keyword)
        );
        total = filteredQuestions.length;
        pagedQuestions = filteredQuestions.slice(offset, offset + take);
      } else {
        total = await tx.question.count({ where: scopedWhere });
        pagedQuestions = await tx.question.findMany({
          where: scopedWhere,
          skip: offset,
          take,
          orderBy
        });
      }
      const questionIds = pagedQuestions.map((q: any) => q.id);
      const meta = {
        limit: take,
        offset,
        returned: pagedQuestions.length,
        total,
        hasMore: offset + pagedQuestions.length < total,
        sortBy,
        sortOrder
      };
      if (!includeTags && !includeSummary) return { questions: pagedQuestions, meta };

      const [taggings, contents, questionStages, questionGrades, questionTextbooks, questionChapters] = await Promise.all([
        includeTags || includeSummary
          ? tx.questionTagging.findMany({
              where: { tenantId, questionId: { in: questionIds } },
              include: { tag: true },
              orderBy: { createdAt: 'asc' }
            })
          : Promise.resolve([]),
        includeSummary
          ? tx.questionContent.findMany({
              where: { tenantId, questionId: { in: questionIds } },
              select: { questionId: true, stemBlocks: true }
            })
          : Promise.resolve([]),
        includeSummary
          ? tx.questionStage.findMany({
              where: { tenantId, questionId: { in: questionIds } },
              include: { stage: true },
              orderBy: { createdAt: 'asc' }
            })
          : Promise.resolve([]),
        includeSummary
          ? tx.questionGrade.findMany({
              where: { tenantId, questionId: { in: questionIds } },
              include: { grade: true },
              orderBy: { createdAt: 'asc' }
            })
          : Promise.resolve([]),
        includeSummary
          ? tx.questionTextbook.findMany({
              where: { tenantId, questionId: { in: questionIds } },
              include: { textbook: true },
              orderBy: { createdAt: 'asc' }
            })
          : Promise.resolve([]),
        includeSummary
          ? tx.questionChapter.findMany({
              where: { tenantId, questionId: { in: questionIds } },
              include: { chapter: true },
              orderBy: { createdAt: 'asc' }
            })
          : Promise.resolve([])
      ]);

      const tagsByQuestionId = new Map<string, any[]>();
      for (const tagging of taggings as any[]) {
        const list = tagsByQuestionId.get(tagging.questionId) || [];
        list.push(tagging.tag);
        tagsByQuestionId.set(tagging.questionId, list);
      }

      const summaryByQuestionId = new Map<string, any>();
      const ensureSummary = (questionId: string) => {
        if (!summaryByQuestionId.has(questionId)) {
          summaryByQuestionId.set(questionId, {
            stemPreview: '',
            stages: [],
            grades: [],
            textbooks: [],
            chapters: []
          });
        }
        return summaryByQuestionId.get(questionId);
      };

      for (const content of contents as any[]) {
        ensureSummary(content.questionId).stemPreview = extractBlockText(content.stemBlocks)
          .map((item) => item.trim())
          .filter(Boolean)
          .join(' ')
          .slice(0, 120);
      }
      for (const entry of questionStages as any[]) ensureSummary(entry.questionId).stages.push(entry.stage);
      for (const entry of questionGrades as any[]) ensureSummary(entry.questionId).grades.push(entry.grade);
      for (const entry of questionTextbooks as any[]) ensureSummary(entry.questionId).textbooks.push(entry.textbook);
      for (const entry of questionChapters as any[]) ensureSummary(entry.questionId).chapters.push(entry.chapter);

      return {
        questions: pagedQuestions.map((q: any) => ({
          ...q,
          tags: tagsByQuestionId.get(q.id) || [],
          summary: includeSummary
            ? summaryByQuestionId.get(q.id) || {
                stemPreview: '',
                stages: [],
                grades: [],
                textbooks: [],
                chapters: []
              }
            : undefined
        })),
        meta
      };
    });

    return result;
  }

  @Get(':id')
  async getOne(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const questionId = params.id;
    const question = await this.prisma.withTenant(tenantId, (tx) =>
      tx.question.findUnique({ where: { tenantId_id: { tenantId, id: questionId } } })
    );
    if (!question) throw new NotFoundException('Question not found');

    const [
      content,
      explanation,
      source,
      choiceAnswer,
      blankAnswer,
      solutionAnswer,
      taggings,
      questionStages,
      questionGrades,
      questionTextbooks,
      questionChapters
    ] = await this.prisma.withTenant(
      tenantId,
      async (tx) => {
        const result = await Promise.all([
          tx.questionContent.findUnique({ where: { tenantId_questionId: { tenantId, questionId } } }),
          tx.questionExplanation.findUnique({ where: { tenantId_questionId: { tenantId, questionId } } }),
          tx.questionSource.findUnique({ where: { tenantId_questionId: { tenantId, questionId } } }),
          tx.questionAnswerChoice.findUnique({ where: { tenantId_questionId: { tenantId, questionId } } }),
          tx.questionAnswerBlank.findUnique({ where: { tenantId_questionId: { tenantId, questionId } } }),
          tx.questionAnswerSolution.findUnique({ where: { tenantId_questionId: { tenantId, questionId } } }),
          tx.questionTagging.findMany({
            where: { tenantId, questionId },
            include: { tag: true },
            orderBy: { createdAt: 'asc' }
          }),
          tx.questionStage.findMany({
            where: { tenantId, questionId },
            include: { stage: true },
            orderBy: { createdAt: 'asc' }
          }),
          tx.questionGrade.findMany({
            where: { tenantId, questionId },
            include: { grade: true },
            orderBy: { createdAt: 'asc' }
          }),
          tx.questionTextbook.findMany({
            where: { tenantId, questionId },
            include: { textbook: true },
            orderBy: { createdAt: 'asc' }
          }),
          tx.questionChapter.findMany({
            where: { tenantId, questionId },
            include: { chapter: true },
            orderBy: { createdAt: 'asc' }
          })
        ]);
        return result;
      }
    );

    const tags = taggings.map((t: any) => t.tag);
    const stages = questionStages.map((entry: any) => entry.stage);
    const grades = questionGrades.map((entry: any) => entry.grade);
    const textbooks = questionTextbooks.map((entry: any) => entry.textbook);
    const chapters = questionChapters.map((entry: any) => entry.chapter);

    return {
      question,
      content,
      explanation: normalizeExplanationRecord(explanation),
      source,
      choiceAnswer,
      blankAnswer,
      solutionAnswer: normalizeSolutionAnswerRecord(solutionAnswer),
      tags,
      stages,
      grades,
      textbooks,
      chapters
    };
  }

  @Patch(':id')
  async update(@Req() req: Request, @Param() params: UuidIdParamDto, @Body() body: UpdateQuestionDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const data: any = {};
    if (body.type) data.type = body.type;
    if (typeof body.difficulty === 'number') data.difficulty = body.difficulty;
    if (body.defaultScore != null) data.defaultScore = body.defaultScore;
    if (body.subjectId) {
      data.subjectId = await ensureTenantOrSystemSubject(this.prisma, tenantId, body.subjectId);
    }
    if (body.visibility) data.visibility = body.visibility;

    const question = await this.prisma.withTenant(tenantId, (tx) =>
      tx.question.update({
        where: { tenantId_id: { tenantId, id: params.id } },
        data
      })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'question.updated',
      targetType: 'question',
      targetId: question.id,
      details: { fields: Object.keys(data) }
    });

    return { question };
  }

  @Delete(':id')
  async remove(@Req() req: Request, @Param() params: UuidIdParamDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    await this.prisma.withTenant(tenantId, (tx) =>
      tx.question.delete({ where: { tenantId_id: { tenantId, id: params.id } } })
    );

    await this.audit.record({
      tenantId,
      userId,
      action: 'question.deleted',
      targetType: 'question',
      targetId: params.id
    });

    return { ok: true };
  }

  @Put(':id/content')
  async upsertContent(
    @Req() req: Request,
    @Param() params: UuidIdParamDto,
    @Body() body: UpsertQuestionContentDto
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const questionId = params.id;
    await validateAssetReferences(this.prisma, tenantId, body.stemBlocks);

    const content = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id: questionId } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionContent.upsert({
        where: { tenantId_questionId: { tenantId, questionId } },
        create: { tenantId, questionId, stemBlocks: body.stemBlocks as Prisma.InputJsonValue },
        update: { stemBlocks: body.stemBlocks as Prisma.InputJsonValue }
      });
    });

    await this.audit.record({
      tenantId,
      userId,
      action: 'question.content_updated',
      targetType: 'question',
      targetId: questionId
    });

    return { content };
  }

  @Put(':id/explanation')
  async upsertExplanation(
    @Req() req: Request,
    @Param() params: UuidIdParamDto,
    @Body() body: UpsertQuestionExplanationDto
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const questionId = params.id;
    await validateAssetReferences(
      this.prisma,
      tenantId,
      body.overviewBlocks,
      body.stepsBlocks,
      body.commentaryBlocks
    );
    const overviewBlocks = (body.overviewBlocks as Prisma.InputJsonValue | undefined) ?? wrapLatexAsBlocks(body.overviewLatex);
    const commentaryBlocks =
      (body.commentaryBlocks as Prisma.InputJsonValue | undefined) ?? wrapLatexAsBlocks(body.commentaryLatex);

    const explanation = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id: questionId } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionExplanation.upsert({
        where: { tenantId_questionId: { tenantId, questionId } },
        create: {
          tenantId,
          questionId,
          overviewLatex: body.overviewLatex ?? null,
          overviewBlocks: overviewBlocks ?? Prisma.JsonNull,
          stepsBlocks: body.stepsBlocks as Prisma.InputJsonValue,
          commentaryLatex: body.commentaryLatex ?? null,
          commentaryBlocks: commentaryBlocks ?? Prisma.JsonNull
        },
        update: {
          overviewLatex: body.overviewLatex ?? null,
          overviewBlocks: overviewBlocks ?? Prisma.JsonNull,
          stepsBlocks: body.stepsBlocks as Prisma.InputJsonValue,
          commentaryLatex: body.commentaryLatex ?? null,
          commentaryBlocks: commentaryBlocks ?? Prisma.JsonNull
        }
      });
    });

    await this.audit.record({
      tenantId,
      userId,
      action: 'question.explanation_updated',
      targetType: 'question',
      targetId: questionId
    });

    return { explanation: normalizeExplanationRecord(explanation) };
  }

  @Put(':id/source')
  async upsertSource(
    @Req() req: Request,
    @Param() params: UuidIdParamDto,
    @Body() body: UpsertQuestionSourceDto
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const questionId = params.id;

    const source = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id: questionId } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionSource.upsert({
        where: { tenantId_questionId: { tenantId, questionId } },
        create: {
          tenantId,
          questionId,
          year: body.year ?? null,
          month: body.month ?? null,
          sourceText: body.sourceText ?? null
        },
        update: {
          year: body.year ?? null,
          month: body.month ?? null,
          sourceText: body.sourceText ?? null
        }
      });
    });

    await this.audit.record({
      tenantId,
      userId,
      action: 'question.source_updated',
      targetType: 'question',
      targetId: questionId
    });

    return { source };
  }

  @Put(':id/answer-choice')
  async upsertChoiceAnswer(
    @Req() req: Request,
    @Param() params: UuidIdParamDto,
    @Body() body: UpsertQuestionChoiceAnswerDto
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const questionId = params.id;
    await validateAssetReferences(this.prisma, tenantId, body.optionsBlocks);

    const choiceAnswer = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id: questionId } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionAnswerChoice.upsert({
        where: { tenantId_questionId: { tenantId, questionId } },
        create: {
          tenantId,
          questionId,
          optionsBlocks: body.optionsBlocks as Prisma.InputJsonValue,
          correct: body.correct as Prisma.InputJsonValue
        },
        update: {
          optionsBlocks: body.optionsBlocks as Prisma.InputJsonValue,
          correct: body.correct as Prisma.InputJsonValue
        }
      });
    });

    await this.audit.record({
      tenantId,
      userId,
      action: 'question.choice_answer_updated',
      targetType: 'question',
      targetId: questionId
    });

    return { choiceAnswer };
  }

  @Put(':id/answer-blank')
  async upsertBlankAnswer(
    @Req() req: Request,
    @Param() params: UuidIdParamDto,
    @Body() body: UpsertQuestionBlankAnswerDto
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const questionId = params.id;
    const blankAnswer = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id: questionId } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionAnswerBlank.upsert({
        where: { tenantId_questionId: { tenantId, questionId } },
        create: { tenantId, questionId, blanks: body.blanks as Prisma.InputJsonValue },
        update: { blanks: body.blanks as Prisma.InputJsonValue }
      });
    });

    await this.audit.record({
      tenantId,
      userId,
      action: 'question.blank_answer_updated',
      targetType: 'question',
      targetId: questionId
    });

    return { blankAnswer };
  }

  @Put(':id/tags')
  async setTags(@Req() req: Request, @Param() params: UuidIdParamDto, @Body() body: SetQuestionTagsDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const questionId = params.id;
    const result = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id: questionId } } });
      if (!question) throw new NotFoundException('Question not found');

      const tagIds = Array.from(new Set(body.tagIds.filter(Boolean)));
      const existing = await tx.questionTag.findMany({ where: { tenantId, id: { in: tagIds } } });

      if (existing.length !== tagIds.length) {
        throw new BadRequestException('Some tags not found');
      }

      await tx.questionTagging.deleteMany({ where: { tenantId, questionId } });

      if (tagIds.length) {
        await tx.questionTagging.createMany({
          data: tagIds.map((tagId) => ({ tenantId, questionId, tagId })),
          skipDuplicates: true
        });
      }

      const taggings = await tx.questionTagging.findMany({
        where: { tenantId, questionId },
        include: { tag: true },
        orderBy: { createdAt: 'asc' }
      });

      return { tags: taggings.map((t: any) => t.tag) };
    });

    await this.audit.record({
      tenantId,
      userId,
      action: 'question.tags_updated',
      targetType: 'question',
      targetId: questionId,
      details: { tagCount: body.tagIds.length }
    });

    return result;
  }

  @Put(':id/taxonomy')
  async setTaxonomy(@Req() req: Request, @Param() params: UuidIdParamDto, @Body() body: SetQuestionTaxonomyDto) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const questionId = params.id;
    const stageIds = Array.from(new Set((body?.stageIds || []).filter(Boolean)));
    const gradeIds = Array.from(new Set((body?.gradeIds || []).filter(Boolean)));
    const textbookIds = Array.from(new Set((body?.textbookIds || []).filter(Boolean)));
    const chapterIds = Array.from(new Set((body?.chapterIds || []).filter(Boolean)));

    for (const currentStageId of stageIds) {
      await ensureTenantOrSystemStage(this.prisma, tenantId, currentStageId);
    }
    for (const currentGradeId of gradeIds) {
      await ensureTenantOrSystemGrade(this.prisma, tenantId, currentGradeId);
    }
    for (const currentTextbookId of textbookIds) {
      await ensureTenantOrSystemTextbook(this.prisma, tenantId, currentTextbookId);
    }

    const chapters = [];
    for (const currentChapterId of chapterIds) {
      chapters.push(await ensureTenantChapter(this.prisma, tenantId, currentChapterId));
    }

    if (textbookIds.length > 0 && chapters.some((chapter: any) => !textbookIds.includes(chapter.textbookId))) {
      throw new BadRequestException('Some chapters do not belong to the selected textbooks');
    }

    const result = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id: questionId } } });
      if (!question) throw new NotFoundException('Question not found');

      await Promise.all([
        tx.questionStage.deleteMany({ where: { tenantId, questionId } }),
        tx.questionGrade.deleteMany({ where: { tenantId, questionId } }),
        tx.questionTextbook.deleteMany({ where: { tenantId, questionId } }),
        tx.questionChapter.deleteMany({ where: { tenantId, questionId } })
      ]);

      if (stageIds.length) {
        await tx.questionStage.createMany({
          data: stageIds.map((currentStageId) => ({ tenantId, questionId, stageId: currentStageId })),
          skipDuplicates: true
        });
      }

      if (gradeIds.length) {
        await tx.questionGrade.createMany({
          data: gradeIds.map((currentGradeId) => ({ tenantId, questionId, gradeId: currentGradeId })),
          skipDuplicates: true
        });
      }

      if (textbookIds.length) {
        await tx.questionTextbook.createMany({
          data: textbookIds.map((currentTextbookId) => ({ tenantId, questionId, textbookId: currentTextbookId })),
          skipDuplicates: true
        });
      }

      if (chapterIds.length) {
        await tx.questionChapter.createMany({
          data: chapterIds.map((currentChapterId) => ({ tenantId, questionId, chapterId: currentChapterId })),
          skipDuplicates: true
        });
      }

      const [questionStages, questionGrades, questionTextbooks, questionChapters] = await Promise.all([
        tx.questionStage.findMany({ where: { tenantId, questionId }, include: { stage: true }, orderBy: { createdAt: 'asc' } }),
        tx.questionGrade.findMany({ where: { tenantId, questionId }, include: { grade: true }, orderBy: { createdAt: 'asc' } }),
        tx.questionTextbook.findMany({
          where: { tenantId, questionId },
          include: { textbook: true },
          orderBy: { createdAt: 'asc' }
        }),
        tx.questionChapter.findMany({ where: { tenantId, questionId }, include: { chapter: true }, orderBy: { createdAt: 'asc' } })
      ]);

      return {
        stages: questionStages.map((entry: any) => entry.stage),
        grades: questionGrades.map((entry: any) => entry.grade),
        textbooks: questionTextbooks.map((entry: any) => entry.textbook),
        chapters: questionChapters.map((entry: any) => entry.chapter)
      };
    });

    await this.audit.record({
      tenantId,
      userId,
      action: 'question.taxonomy_updated',
      targetType: 'question',
      targetId: questionId,
      details: {
        stageCount: stageIds.length,
        gradeCount: gradeIds.length,
        textbookCount: textbookIds.length,
        chapterCount: chapterIds.length
      }
    });

    return result;
  }

  @Put(':id/answer-solution')
  async upsertSolutionAnswer(
    @Req() req: Request,
    @Param() params: UuidIdParamDto,
    @Body() body: UpsertQuestionSolutionAnswerDto
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireTenantRole(this.prisma, tenantId, userId, ['admin', 'owner']);

    const questionId = params.id;
    await validateAssetReferences(
      this.prisma,
      tenantId,
      body.referenceAnswerBlocks ?? wrapLatexAsBlocks(body.finalAnswerLatex),
      body.scoringPointsBlocks
    );
    const referenceAnswerBlocks =
      (body.referenceAnswerBlocks as Prisma.InputJsonValue | undefined) ?? wrapLatexAsBlocks(body.finalAnswerLatex);
    const scoringPointsBlocks = (body.scoringPointsBlocks as Prisma.InputJsonValue | undefined) ?? null;
    const solutionAnswer = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id: questionId } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionAnswerSolution.upsert({
        where: { tenantId_questionId: { tenantId, questionId } },
        create: {
          tenantId,
          questionId,
          finalAnswerLatex: body.finalAnswerLatex ?? null,
          referenceAnswerBlocks: referenceAnswerBlocks ?? Prisma.JsonNull,
          scoringPoints: body.scoringPoints as Prisma.InputJsonValue,
          scoringPointsBlocks: scoringPointsBlocks ?? Prisma.JsonNull
        },
        update: {
          finalAnswerLatex: body.finalAnswerLatex ?? null,
          referenceAnswerBlocks: referenceAnswerBlocks ?? Prisma.JsonNull,
          scoringPoints: body.scoringPoints as Prisma.InputJsonValue,
          scoringPointsBlocks: scoringPointsBlocks ?? Prisma.JsonNull
        }
      });
    });

    await this.audit.record({
      tenantId,
      userId,
      action: 'question.solution_answer_updated',
      targetType: 'question',
      targetId: questionId
    });

    return { solutionAnswer: normalizeSolutionAnswerRecord(solutionAnswer) };
  }
}
