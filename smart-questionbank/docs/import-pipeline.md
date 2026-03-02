# Question Import Pipeline (MVP)

Last updated: 2026-03-02 (Asia/Shanghai)

This document defines the MVP import architecture for Smart Questionbank.

## Goals

- Support importing questions from:
  - manual input (structured)
  - Word / PDF (text-first)
  - images (OCR)
- Normalize all sources into a single internal representation (QuestionIR) and a single LaTeX storage format.
- Keep the pipeline pluggable: OCR/provider can be swapped later.

## Key Idea: Normalize -> Store

All import sources are converted into **QuestionIR** first. Then QuestionIR is persisted using existing tables:

- `question`
- `question_content.stem_blocks`
- `question_explanation.steps_blocks`
- `question_answer_choice.options_blocks` / `correct`
- `question_answer_blank.blanks`
- `question_answer_solution.final_answer_latex` / `scoring_points`
- `question_source`
- tags

The API surface for persistence is `POST /questions/import`.

## QuestionIR (conceptual)

```ts
type QuestionIR = {
  type: 'single_choice' | 'fill_blank' | 'solution';
  difficulty?: number; // 1..5
  defaultScore?: string;
  visibility?: 'private' | 'tenant_shared';

  stemBlocks: any[];

  // choice
  optionsBlocks?: any[];
  correct?: any;

  // blank
  blanks?: any;

  // solution
  finalAnswerLatex?: string | null;
  scoringPoints?: any;

  // explanation
  overviewLatex?: string | null;
  stepsBlocks?: any[];
  commentaryLatex?: string | null;

  // meta
  tags?: string[];
  source?: { year?: number | null; month?: number | null; sourceText?: string | null };
};
```

## Canonical LaTeX Storage Format (proposal)

We standardize LaTeX into a single macro-based format.

- `\stq{...}` question stem
- `\stchoices{ ... }` choice options
- `\stopt{A}{...}` option item
- `\stanswer{...}` answer payload (type-specific)
- `\stanalysis{...}` explanation / solution

Notes:

- MVP focuses on correctness and consistency; formatting niceties can be improved later.
- The system should treat this canonical LaTeX as **generated** from QuestionIR (source of truth is structured JSON).

## Import Stages

### Stage 1: Manual / Structured

- Client submits QuestionIR-like JSON directly.
- Backend validates and persists via `/questions/import`.

### Stage 2: Word / PDF

- Extract:
  - Word: paragraphs, runs, tables, embedded images
  - PDF: text layer first; fallback to OCR if needed
- Segment into candidate questions using heuristics (question number patterns, option markers A/B/C/D, answer markers).
- Convert to QuestionIR.

### Stage 3: Images (OCR)

- OCR returns text + bounding boxes.
- Normalize into lines/blocks.
- Apply the same segmentation + conversion logic as Stage 2.

## Error Handling

- Persist imports as jobs (future): `import_job` table + bullmq queue.
- MVP: synchronous import for small batches; later: async jobs for big files.

## Next Implementation Steps

1. Add a dedicated `ImportJobsModule` (async pipeline) with:
   - upload endpoint (multipart)
   - job tracking
   - worker that parses to QuestionIR then calls the same persistence logic
2. Define a minimal segmentation spec (how we detect stem/options/answer/explanation from extracted text)
3. Choose default OCR approach: local/open-source first, provider pluggable
