import { StudentsController } from './students.controller';

function makePrisma(overrides: Partial<any> = {}) {
  const tenantMember = overrides.tenantMember ?? {
    findFirst: jest.fn().mockResolvedValue({ role: 'member', status: 'active' }),
  };
  const studentProfile = overrides.studentProfile ?? {
    findMany: jest.fn(),
    findUnique: jest.fn(),
  };

  return {
    studentProfile,
    tenantMember,
    withTenant: jest.fn(async (_tenantId: string, fn: any) =>
      fn({
        studentProfile,
        tenantMember,
      }),
    ),
    ...overrides,
  } as any;
}

describe('StudentsController', () => {
  it('lists students under current tenant', async () => {
    const prisma = makePrisma({
      studentProfile: {
        findMany: jest.fn().mockResolvedValue([
          {
            tenantId: 't1',
            id: 'student-1',
            name: '林之涵',
            classId: 'class-1',
            className: '九年级尖子班',
            lessonId: 'lesson-1',
            documentId: 'doc-2',
            documentName: '二次函数周测卷',
            gradeLabel: '初中',
            subjectLabel: '数学',
            textbookLabel: '浙教版',
            trendLabel: '近期进步',
            habitTag: '订正及时',
            habitInsight: 'detail',
            followUpLevel: '常规关注',
            summary: 'summary',
            scoreLabel: '92 / 100',
            historyTrendLabel: '86 → 89 → 92',
            wrongCountLabel: '6 道',
            wrongCount: 6,
            scoreRecords: [],
            feedbackRecords: [],
            wrongQuestionRecords: [],
            highlights: [],
            nextStep: 'next',
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        ]),
      },
    });

    const ctrl = new StudentsController(prisma);
    const result = await ctrl.list(
      { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
      undefined,
    );

    expect(result.students).toHaveLength(1);
    expect(result.students[0].id).toBe('student-1');
  });

  it('passes classId and lessonId filters to student list query', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = makePrisma({
      studentProfile: {
        findMany,
        findUnique: jest.fn(),
      },
    });

    const ctrl = new StudentsController(prisma);
    await ctrl.list(
      { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
      '林',
      'class-3',
      'lesson-3',
    );

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: 't1',
          classId: 'class-3',
          lessonId: 'lesson-3',
        }),
      }),
    );
  });

  it('returns student detail by composite id', async () => {
    const prisma = makePrisma({
      studentProfile: {
        findUnique: jest.fn().mockResolvedValue({
          tenantId: 't1',
          id: 'student-1',
          name: '林之涵',
          classId: 'class-1',
          className: '九年级尖子班',
          lessonId: 'lesson-1',
          documentId: 'doc-2',
          documentName: '二次函数周测卷',
          gradeLabel: '初中',
          subjectLabel: '数学',
          textbookLabel: '浙教版',
          trendLabel: '近期进步',
          habitTag: '订正及时',
          habitInsight: 'detail',
          followUpLevel: '常规关注',
          summary: 'summary',
          scoreLabel: '92 / 100',
          historyTrendLabel: '86 → 89 → 92',
          wrongCountLabel: '6 道',
          wrongCount: 6,
          scoreRecords: [],
          feedbackRecords: [],
          wrongQuestionRecords: [],
          highlights: [],
          nextStep: 'next',
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      },
    });

    const ctrl = new StudentsController(prisma);
    const result = await ctrl.detail(
      { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
      'student-1',
    );

    expect(result.student.id).toBe('student-1');
  });
});
