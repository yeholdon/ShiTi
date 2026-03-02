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
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { requireActiveTenantMember, requireTenantId, requireUserId } from '../../tenant/tenant-guards';

@Controller('questions')
@UseGuards(JwtAuthGuard)
export class QuestionsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async create(@Req() req: Request, @Body() body: { subjectId?: string }) {
    const tenantId = requireTenantId(req);
    const ownerUserId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, ownerUserId);

    const subjectId =
      body.subjectId ||
      (await this.prisma.subject
        .findFirst({ where: { tenantId: null, isSystem: true }, orderBy: { createdAt: 'asc' } })
        .then((s) => s?.id));

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

    return { question };
  }

  @Post('import')
  async importQuestions(
    @Req() req: Request,
    @Body()
    body: {
      dryRun?: boolean;
      items: Array<{
        type?: 'single_choice' | 'fill_blank' | 'solution';
        difficulty?: number;
        defaultScore?: string;
        subjectId?: string;
        visibility?: 'private' | 'tenant_shared';
        tags?: string[];
        content?: { stemBlocks: Prisma.InputJsonValue };
        explanation?: {
          overviewLatex?: string | null;
          stepsBlocks: Prisma.InputJsonValue;
          commentaryLatex?: string | null;
        };
        choiceAnswer?: { optionsBlocks: Prisma.InputJsonValue; correct: Prisma.InputJsonValue };
        blankAnswer?: { blanks: Prisma.InputJsonValue };
        solutionAnswer?: { finalAnswerLatex?: string | null; scoringPoints: Prisma.InputJsonValue };
        source?: { year?: number | null; month?: number | null; sourceText?: string | null };
      }>;
    }
  ) {
    const tenantId = requireTenantId(req);
    const ownerUserId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, ownerUserId);

    if (!body?.items?.length) throw new BadRequestException('Missing items');
    if (body.items.length > 200) throw new BadRequestException('Too many items (max 200)');

    const fallbackSubjectId = await this.prisma.subject
      .findFirst({ where: { tenantId: null, isSystem: true }, orderBy: { createdAt: 'asc' } })
      .then((s) => s?.id);

    if (!fallbackSubjectId) throw new Error('No system subject found; run prisma seed');

    if (body.dryRun) {
      return { ok: true, dryRun: true, count: body.items.length };
    }

    const result = await this.prisma.withTenant(tenantId, async (tx) => {
      const createdQuestionIds: string[] = [];

      for (const item of body.items) {
        const type = item.type || 'single_choice';
        const difficulty = typeof item.difficulty === 'number' ? item.difficulty : 3;
        const defaultScore = item.defaultScore ?? '5.00';
        const subjectId = item.subjectId || fallbackSubjectId;
        const visibility = item.visibility || 'private';

        if (difficulty < 1 || difficulty > 5) throw new BadRequestException('difficulty must be 1..5');

        const question = await tx.question.create({
          data: {
            tenantId,
            type,
            difficulty,
            defaultScore,
            subjectId,
            ownerUserId,
            visibility
          }
        });

        createdQuestionIds.push(question.id);

        if (item.content?.stemBlocks != null) {
          await tx.questionContent.create({
            data: { tenantId, questionId: question.id, stemBlocks: item.content.stemBlocks }
          });
        }

        if (item.explanation?.stepsBlocks != null) {
          await tx.questionExplanation.create({
            data: {
              tenantId,
              questionId: question.id,
              overviewLatex: item.explanation.overviewLatex ?? null,
              stepsBlocks: item.explanation.stepsBlocks,
              commentaryLatex: item.explanation.commentaryLatex ?? null
            }
          });
        }

        if (item.source) {
          await tx.questionSource.create({
            data: {
              tenantId,
              questionId: question.id,
              year: item.source.year ?? null,
              month: item.source.month ?? null,
              sourceText: item.source.sourceText ?? null
            }
          });
        }

        if (item.choiceAnswer) {
          await tx.questionAnswerChoice.create({
            data: {
              tenantId,
              questionId: question.id,
              optionsBlocks: item.choiceAnswer.optionsBlocks,
              correct: item.choiceAnswer.correct
            }
          });
        }

        if (item.blankAnswer) {
          await tx.questionAnswerBlank.create({
            data: {
              tenantId,
              questionId: question.id,
              blanks: item.blankAnswer.blanks
            }
          });
        }

        if (item.solutionAnswer) {
          await tx.questionAnswerSolution.create({
            data: {
              tenantId,
              questionId: question.id,
              finalAnswerLatex: item.solutionAnswer.finalAnswerLatex ?? null,
              scoringPoints: item.solutionAnswer.scoringPoints
            }
          });
        }

        if (item.tags?.length) {
          for (const rawName of item.tags) {
            const name = String(rawName || '').trim();
            if (!name) continue;

            const tag = await tx.questionTag.upsert({
              where: { tenantId_name: { tenantId, name } },
              create: { tenantId, name },
              update: {}
            });

            await tx.questionTagging.upsert({
              where: { tenantId_questionId_tagId: { tenantId, questionId: question.id, tagId: tag.id } },
              create: { tenantId, questionId: question.id, tagId: tag.id },
              update: {}
            });
          }
        }
      }

      return { createdQuestionIds };
    });

    return { ok: true, createdCount: result.createdQuestionIds.length, questionIds: result.createdQuestionIds };
  }

  @Get()
  async list(@Req() req: Request) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    const includeParam = String((req as any)?.query?.include || '');
    const include = includeParam
      .split(',')
      .map((v) => v.trim())
      .filter(Boolean);

    const includeTags = include.includes('tags');

    const result = await this.prisma.withTenant(tenantId, async (tx) => {
      const questions = await tx.question.findMany({
        where: { tenantId },
        take: 50,
        orderBy: { createdAt: 'desc' }
      });

      if (!includeTags) return { questions };

      const questionIds = questions.map((q: any) => q.id);
      const taggings = await tx.questionTagging.findMany({
        where: { tenantId, questionId: { in: questionIds } },
        include: { tag: true },
        orderBy: { createdAt: 'asc' }
      });

      const tagsByQuestionId = new Map<string, any[]>();
      for (const tagging of taggings) {
        const list = tagsByQuestionId.get(tagging.questionId) || [];
        list.push(tagging.tag);
        tagsByQuestionId.set(tagging.questionId, list);
      }

      const questionsWithTags = questions.map((q: any) => ({
        ...q,
        tags: tagsByQuestionId.get(q.id) || []
      }));

      return { questions: questionsWithTags };
    });

    return result;
  }

  @Get(':id')
  async getOne(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const question = await this.prisma.withTenant(tenantId, (tx) => tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } }));
    if (!question) throw new NotFoundException('Question not found');

    const [content, explanation, source, choiceAnswer, blankAnswer, solutionAnswer, taggings] = await this.prisma.withTenant(
      tenantId,
      async (tx) => {
        const result = await Promise.all([
          tx.questionContent.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionExplanation.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionSource.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionAnswerChoice.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionAnswerBlank.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionAnswerSolution.findUnique({ where: { tenantId_questionId: { tenantId, questionId: id } } }),
          tx.questionTagging.findMany({
            where: { tenantId, questionId: id },
            include: { tag: true },
            orderBy: { createdAt: 'asc' }
          })
        ]);
        return result;
      }
    );

    const tags = taggings.map((t: any) => t.tag);

    return { question, content, explanation, source, choiceAnswer, blankAnswer, solutionAnswer, tags };
  }

  @Patch(':id')
  async update(@Req() req: Request, @Param('id') id: string, @Body() body: any) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const data: any = {};
    if (body.type) data.type = body.type;
    if (typeof body.difficulty === 'number') data.difficulty = body.difficulty;
    if (body.defaultScore != null) data.defaultScore = body.defaultScore;
    if (body.subjectId) data.subjectId = body.subjectId;
    if (body.visibility) data.visibility = body.visibility;

    const question = await this.prisma.withTenant(tenantId, (tx) =>
      tx.question.update({
        where: { tenantId_id: { tenantId, id } },
        data
      })
    );

    return { question };
  }

  @Delete(':id')
  async remove(@Req() req: Request, @Param('id') id: string) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    await this.prisma.withTenant(tenantId, (tx) => tx.question.delete({ where: { tenantId_id: { tenantId, id } } }));

    return { ok: true };
  }

  @Put(':id/content')
  async upsertContent(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() body: { stemBlocks: Prisma.InputJsonValue }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');
    if (body?.stemBlocks == null) throw new BadRequestException('Missing stemBlocks');

    const content = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionContent.upsert({
        where: { tenantId_questionId: { tenantId, questionId: id } },
        create: { tenantId, questionId: id, stemBlocks: body.stemBlocks },
        update: { stemBlocks: body.stemBlocks }
      });
    });

    return { content };
  }

  @Put(':id/explanation')
  async upsertExplanation(
    @Req() req: Request,
    @Param('id') id: string,
    @Body()
    body: {
      overviewLatex?: string | null;
      stepsBlocks: Prisma.InputJsonValue;
      commentaryLatex?: string | null;
    }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');
    if (body?.stepsBlocks == null) throw new BadRequestException('Missing stepsBlocks');

    const explanation = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionExplanation.upsert({
        where: { tenantId_questionId: { tenantId, questionId: id } },
        create: {
          tenantId,
          questionId: id,
          overviewLatex: body.overviewLatex ?? null,
          stepsBlocks: body.stepsBlocks,
          commentaryLatex: body.commentaryLatex ?? null
        },
        update: {
          overviewLatex: body.overviewLatex ?? null,
          stepsBlocks: body.stepsBlocks,
          commentaryLatex: body.commentaryLatex ?? null
        }
      });
    });

    return { explanation };
  }

  @Put(':id/source')
  async upsertSource(
    @Req() req: Request,
    @Param('id') id: string,
    @Body()
    body: {
      year?: number | null;
      month?: number | null;
      sourceText?: string | null;
    }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');

    const source = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionSource.upsert({
        where: { tenantId_questionId: { tenantId, questionId: id } },
        create: {
          tenantId,
          questionId: id,
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

    return { source };
  }

  @Put(':id/answer-choice')
  async upsertChoiceAnswer(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() body: { optionsBlocks: Prisma.InputJsonValue; correct: Prisma.InputJsonValue }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');
    if (body?.optionsBlocks == null) throw new BadRequestException('Missing optionsBlocks');
    if (body?.correct == null) throw new BadRequestException('Missing correct');

    const choiceAnswer = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionAnswerChoice.upsert({
        where: { tenantId_questionId: { tenantId, questionId: id } },
        create: { tenantId, questionId: id, optionsBlocks: body.optionsBlocks, correct: body.correct },
        update: { optionsBlocks: body.optionsBlocks, correct: body.correct }
      });
    });

    return { choiceAnswer };
  }

  @Put(':id/answer-blank')
  async upsertBlankAnswer(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() body: { blanks: Prisma.InputJsonValue }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');
    if (body?.blanks == null) throw new BadRequestException('Missing blanks');

    const blankAnswer = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionAnswerBlank.upsert({
        where: { tenantId_questionId: { tenantId, questionId: id } },
        create: { tenantId, questionId: id, blanks: body.blanks },
        update: { blanks: body.blanks }
      });
    });

    return { blankAnswer };
  }

  @Put(':id/tags')
  async setTags(@Req() req: Request, @Param('id') id: string, @Body() body: { tagIds: string[] }) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');
    if (!Array.isArray(body?.tagIds)) throw new BadRequestException('Missing tagIds');

    const result = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!question) throw new NotFoundException('Question not found');

      const tagIds = Array.from(new Set(body.tagIds.filter(Boolean)));
      const existing = await tx.questionTag.findMany({ where: { tenantId, id: { in: tagIds } } });

      if (existing.length !== tagIds.length) {
        throw new BadRequestException('Some tags not found');
      }

      await tx.questionTagging.deleteMany({ where: { tenantId, questionId: id } });

      if (tagIds.length) {
        await tx.questionTagging.createMany({
          data: tagIds.map((tagId) => ({ tenantId, questionId: id, tagId })),
          skipDuplicates: true
        });
      }

      const taggings = await tx.questionTagging.findMany({
        where: { tenantId, questionId: id },
        include: { tag: true },
        orderBy: { createdAt: 'asc' }
      });

      return { tags: taggings.map((t: any) => t.tag) };
    });

    return result;
  }

  @Put(':id/answer-solution')
  async upsertSolutionAnswer(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() body: { finalAnswerLatex?: string | null; scoringPoints: Prisma.InputJsonValue }
  ) {
    const tenantId = requireTenantId(req);
    const userId = requireUserId(req);
    await requireActiveTenantMember(this.prisma, tenantId, userId);

    if (!id) throw new BadRequestException('Missing id');
    if (body?.scoringPoints == null) throw new BadRequestException('Missing scoringPoints');

    const solutionAnswer = await this.prisma.withTenant(tenantId, async (tx) => {
      const question = await tx.question.findUnique({ where: { tenantId_id: { tenantId, id } } });
      if (!question) throw new NotFoundException('Question not found');

      return tx.questionAnswerSolution.upsert({
        where: { tenantId_questionId: { tenantId, questionId: id } },
        create: {
          tenantId,
          questionId: id,
          finalAnswerLatex: body.finalAnswerLatex ?? null,
          scoringPoints: body.scoringPoints
        },
        update: {
          finalAnswerLatex: body.finalAnswerLatex ?? null,
          scoringPoints: body.scoringPoints
        }
      });
    });

    return { solutionAnswer };
  }
}
