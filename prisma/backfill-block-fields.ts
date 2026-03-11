import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

function wrapLatexAsBlocks(value?: string | null): Prisma.InputJsonValue | null {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!text) return null;

  return [
    {
      type: 'latex',
      children: [{ text }]
    }
  ] as Prisma.InputJsonValue;
}

async function backfillExplanationBlocks() {
  const rows = await prisma.questionExplanation.findMany({
    where: {
      OR: [
        { overviewLatex: { not: null } },
        { commentaryLatex: { not: null } }
      ]
    },
    select: {
      tenantId: true,
      questionId: true,
      overviewLatex: true,
      overviewBlocks: true,
      commentaryLatex: true,
      commentaryBlocks: true
    }
  });

  let updated = 0;

  for (const row of rows) {
    const needsOverview = row.overviewBlocks == null && typeof row.overviewLatex === 'string' && row.overviewLatex.trim();
    const needsCommentary =
      row.commentaryBlocks == null && typeof row.commentaryLatex === 'string' && row.commentaryLatex.trim();
    if (!needsOverview && !needsCommentary) {
      continue;
    }

    const overviewBlocks = row.overviewBlocks ?? wrapLatexAsBlocks(row.overviewLatex);
    const commentaryBlocks = row.commentaryBlocks ?? wrapLatexAsBlocks(row.commentaryLatex);

    await prisma.questionExplanation.update({
      where: {
        tenantId_questionId: {
          tenantId: row.tenantId,
          questionId: row.questionId
        }
      },
      data: {
        overviewBlocks: overviewBlocks ?? Prisma.JsonNull,
        commentaryBlocks: commentaryBlocks ?? Prisma.JsonNull
      }
    });

    updated += 1;
  }

  return { matched: rows.length, updated };
}

async function backfillSolutionAnswerBlocks() {
  const rows = await prisma.questionAnswerSolution.findMany({
    where: {
      finalAnswerLatex: { not: null }
    },
    select: {
      tenantId: true,
      questionId: true,
      finalAnswerLatex: true,
      referenceAnswerBlocks: true
    }
  });

  let updated = 0;

  for (const row of rows) {
    const needsReferenceAnswer =
      row.referenceAnswerBlocks == null && typeof row.finalAnswerLatex === 'string' && row.finalAnswerLatex.trim();
    if (!needsReferenceAnswer) {
      continue;
    }

    const referenceAnswerBlocks = row.referenceAnswerBlocks ?? wrapLatexAsBlocks(row.finalAnswerLatex);

    await prisma.questionAnswerSolution.update({
      where: {
        tenantId_questionId: {
          tenantId: row.tenantId,
          questionId: row.questionId
        }
      },
      data: {
        referenceAnswerBlocks: referenceAnswerBlocks ?? Prisma.JsonNull
      }
    });

    updated += 1;
  }

  return { matched: rows.length, updated };
}

async function main() {
  const explanation = await backfillExplanationBlocks();
  const solution = await backfillSolutionAnswerBlocks();

  // eslint-disable-next-line no-console
  console.log(
    JSON.stringify({
      explanation,
      solution
    })
  );
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    // eslint-disable-next-line no-console
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
