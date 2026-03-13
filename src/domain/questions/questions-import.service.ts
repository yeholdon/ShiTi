import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ensureTenantOrSystemSubject } from './subject-access';
import {
  ensureTenantChapter,
  ensureTenantOrSystemGrade,
  ensureTenantOrSystemStage,
  ensureTenantOrSystemTextbook
} from './taxonomy-access';
import { validateAssetReferences } from '../assets/asset-reference-validation';
import { wrapLatexAsBlocks } from './explanation-blocks';

export type ImportQuestionItem = {
  type?: 'single_choice' | 'fill_blank' | 'solution';
  difficulty?: number;
  defaultScore?: string;
  subjectId?: string;
  visibility?: 'private' | 'tenant_shared';
  tags?: string[];
  stageIds?: string[];
  gradeIds?: string[];
  textbookIds?: string[];
  chapterIds?: string[];
  content?: { stemBlocks: Prisma.InputJsonValue };
  explanation?: {
    overviewLatex?: string | null;
    overviewBlocks?: Prisma.InputJsonValue;
    stepsBlocks: Prisma.InputJsonValue;
    commentaryLatex?: string | null;
    commentaryBlocks?: Prisma.InputJsonValue;
  };
  choiceAnswer?: { optionsBlocks: Prisma.InputJsonValue; correct: Prisma.InputJsonValue };
  blankAnswer?: { blanks: Prisma.InputJsonValue };
  solutionAnswer?: {
    finalAnswerLatex?: string | null;
    referenceAnswerBlocks?: Prisma.InputJsonValue;
    scoringPoints: Prisma.InputJsonValue;
    scoringPointsBlocks?: Prisma.InputJsonValue;
  };
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
        const subjectId = item.subjectId
          ? await ensureTenantOrSystemSubject(this.prisma, tenantId, item.subjectId)
          : fallbackSubjectId;
        const visibility = item.visibility || 'private';
        const stageIds = Array.from(new Set((item.stageIds || []).filter(Boolean)));
        const gradeIds = Array.from(new Set((item.gradeIds || []).filter(Boolean)));
        const textbookIds = Array.from(new Set((item.textbookIds || []).filter(Boolean)));
        const chapterIds = Array.from(new Set((item.chapterIds || []).filter(Boolean)));

        if (difficulty < 1 || difficulty > 5) throw new BadRequestException('difficulty must be 1..5');
        await validateAssetReferences(
          this.prisma,
          tenantId,
          item.content?.stemBlocks,
          item.explanation?.overviewBlocks ?? wrapLatexAsBlocks(item.explanation?.overviewLatex),
          item.explanation?.stepsBlocks,
          item.explanation?.commentaryBlocks ?? wrapLatexAsBlocks(item.explanation?.commentaryLatex),
          item.choiceAnswer?.optionsBlocks,
          item.solutionAnswer?.referenceAnswerBlocks ?? wrapLatexAsBlocks(item.solutionAnswer?.finalAnswerLatex),
          item.solutionAnswer?.scoringPointsBlocks
        );

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
          const overviewBlocks = item.explanation.overviewBlocks ?? wrapLatexAsBlocks(item.explanation.overviewLatex);
          const commentaryBlocks = item.explanation.commentaryBlocks ?? wrapLatexAsBlocks(item.explanation.commentaryLatex);
          await tx.questionExplanation.create({
            data: {
              tenantId,
              questionId: question.id,
              overviewLatex: item.explanation.overviewLatex ?? null,
              overviewBlocks: overviewBlocks ?? Prisma.JsonNull,
              stepsBlocks: item.explanation.stepsBlocks,
              commentaryLatex: item.explanation.commentaryLatex ?? null,
              commentaryBlocks: commentaryBlocks ?? Prisma.JsonNull
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
          const referenceAnswerBlocks =
            item.solutionAnswer.referenceAnswerBlocks ?? wrapLatexAsBlocks(item.solutionAnswer.finalAnswerLatex);
          await tx.questionAnswerSolution.create({
            data: {
              tenantId,
              questionId: question.id,
              finalAnswerLatex: item.solutionAnswer.finalAnswerLatex ?? null,
              referenceAnswerBlocks: referenceAnswerBlocks ?? Prisma.JsonNull,
              scoringPoints: item.solutionAnswer.scoringPoints,
              scoringPointsBlocks: item.solutionAnswer.scoringPointsBlocks ?? Prisma.JsonNull
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

        if (stageIds.length) {
          await tx.questionStage.createMany({
            data: stageIds.map((currentStageId) => ({ tenantId, questionId: question.id, stageId: currentStageId })),
            skipDuplicates: true
          });
        }

        if (gradeIds.length) {
          await tx.questionGrade.createMany({
            data: gradeIds.map((currentGradeId) => ({ tenantId, questionId: question.id, gradeId: currentGradeId })),
            skipDuplicates: true
          });
        }

        if (textbookIds.length) {
          await tx.questionTextbook.createMany({
            data: textbookIds.map((currentTextbookId) => ({ tenantId, questionId: question.id, textbookId: currentTextbookId })),
            skipDuplicates: true
          });
        }

        if (chapterIds.length) {
          await tx.questionChapter.createMany({
            data: chapterIds.map((currentChapterId) => ({ tenantId, questionId: question.id, chapterId: currentChapterId })),
            skipDuplicates: true
          });
        }
      }

      return { createdQuestionIds };
    });

    return { ok: true, createdCount: result.createdQuestionIds.length, questionIds: result.createdQuestionIds };
  }
}
