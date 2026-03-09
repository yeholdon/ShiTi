import { Prisma } from '@prisma/client';

export function wrapLatexAsBlocks(value?: string | null): Prisma.InputJsonValue | null {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!text) return null;

  return [
    {
      type: 'latex',
      children: [{ text }]
    }
  ] as Prisma.InputJsonValue;
}

export function normalizeExplanationRecord<T extends Record<string, any> | null | undefined>(value: T): T {
  if (!value) return value;

  return {
    ...value,
    overviewBlocks: value.overviewBlocks ?? wrapLatexAsBlocks(value.overviewLatex),
    commentaryBlocks: value.commentaryBlocks ?? wrapLatexAsBlocks(value.commentaryLatex)
  };
}

export function normalizeSolutionAnswerRecord<T extends Record<string, any> | null | undefined>(value: T): T {
  if (!value) return value;

  return {
    ...value,
    referenceAnswerBlocks: value.referenceAnswerBlocks ?? wrapLatexAsBlocks(value.finalAnswerLatex)
  };
}
