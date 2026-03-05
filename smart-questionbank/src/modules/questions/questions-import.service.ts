import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

export type ImportQuestionItem = {
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
};

@Injectable()
export class QuestionsImportService {
  constructor(private readonly prisma: PrismaService) {}

  async importQuestions(params: {
    tenantId: string;
    ownerUserId: string;
    dryRun?: boolean;
    items: ImportQuestionItem[];
  }) {
    const { tenantId, ownerUserId, items } = params;

    if (!items?.length) throw new BadRequestException('Missing items');
    if (items.length > 200) throw new BadRequestException('Too many items (max 200)');

    const fallbackSubjectId = await this.prisma.subject
      .findFirst({ where: { tenantId: null, isSystem: true }, orderBy: { createdAt: 'asc' } })
      .then((s) => s?.id);

    if (!fallbackSubjectId) throw new Error('No system subject found; run prisma seed');

    if (params.dryRun) {
      return { ok: true, dryRun: true, count: items.length };
    }

    const result = await this.prisma.withTenant(tenantId, async (tx) => {
      const createdQuestionIds: string[] = [];

      for (const item of items) {
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
}
