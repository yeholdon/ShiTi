import { ClassesController } from './classes.controller';

function makePrisma(overrides: Partial<any> = {}) {
  const tenantMember = overrides.tenantMember ?? {
    findFirst: jest.fn().mockResolvedValue({ role: 'member', status: 'active' }),
  };
  const teachingClass = overrides.teachingClass ?? {
    findMany: jest.fn(),
    findUnique: jest.fn(),
  };

  return {
    teachingClass,
    tenantMember,
    withTenant: jest.fn(async (_tenantId: string, fn: any) =>
      fn({
        teachingClass,
        tenantMember,
      }),
    ),
    ...overrides,
  } as any;
}

describe('ClassesController', () => {
  it('lists classes under current tenant', async () => {
    const prisma = makePrisma({
      teachingClass: {
        findMany: jest.fn().mockResolvedValue([
          {
            tenantId: 't1',
            id: 'class-1',
            name: '九年级尖子班',
            lessonId: 'lesson-1',
            documentId: 'doc-2',
            focusStudentId: 'student-1',
            focusStudentName: '林之涵',
            stageLabel: '初中',
            teacherLabel: '主讲：陈老师',
            textbookLabel: '浙教版',
            focusLabel: '试卷跟进',
            activityLabel: '本周活跃',
            classSizeLabel: '26 人',
            lessonFocusLabel: '复盘课',
            structureInsight: 'insight',
            studentCount: 26,
            weeklyLessonCount: 3,
            latestDocLabel: '二次函数周测卷',
            assetLinks: [],
            memberTiers: [],
            lessonTimeline: [],
            summary: 'summary',
            highlights: [],
            nextStep: 'next',
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        ]),
      },
    });

    const ctrl = new ClassesController(prisma);
    const result = await ctrl.list(
      { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
      undefined,
    );

    expect(result.classes).toHaveLength(1);
    expect(result.classes[0].id).toBe('class-1');
  });

  it('passes studentId and lessonId filters into class listing', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = makePrisma({
      teachingClass: {
        findMany,
        findUnique: jest.fn(),
      },
    });

    const ctrl = new ClassesController(prisma);
    await ctrl.list(
      { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
      '培优',
      'student-1',
      'lesson-2',
    );

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: 't1',
          focusStudentId: 'student-1',
          lessonId: 'lesson-2',
          OR: expect.any(Array),
        }),
      }),
    );
  });

  it('returns class detail by composite id', async () => {
    const prisma = makePrisma({
      teachingClass: {
        findUnique: jest.fn().mockResolvedValue({
          tenantId: 't1',
          id: 'class-1',
          name: '九年级尖子班',
          lessonId: 'lesson-1',
          documentId: 'doc-2',
          focusStudentId: 'student-1',
          focusStudentName: '林之涵',
          stageLabel: '初中',
          teacherLabel: '主讲：陈老师',
          textbookLabel: '浙教版',
          focusLabel: '试卷跟进',
          activityLabel: '本周活跃',
          classSizeLabel: '26 人',
          lessonFocusLabel: '复盘课',
          structureInsight: 'insight',
          studentCount: 26,
          weeklyLessonCount: 3,
          latestDocLabel: '二次函数周测卷',
          assetLinks: [],
          memberTiers: [],
          lessonTimeline: [],
          summary: 'summary',
          highlights: [],
          nextStep: 'next',
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      },
    });

    const ctrl = new ClassesController(prisma);
    const result = await ctrl.detail(
      { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
      'class-1',
    );

    expect(result.class.id).toBe('class-1');
  });
});
