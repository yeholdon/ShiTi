import { ClassesController } from './classes.controller';

function makePrisma(overrides: Partial<any> = {}) {
  const tenantMember = overrides.tenantMember ?? {
    findFirst: jest.fn().mockResolvedValue({ role: 'member', status: 'active' }),
  };
  const teachingClass = overrides.teachingClass ?? {
    create: jest.fn(),
    findMany: jest.fn(),
    findUnique: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
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
  it('creates class profile under current tenant', async () => {
    const create = jest.fn().mockResolvedValue({
      tenantId: 't1',
      id: 'class-4',
      name: '九年级新班',
      lessonId: null,
      documentId: null,
      focusStudentId: null,
      focusStudentName: null,
      stageLabel: '初中 · 九年级',
      teacherLabel: '主讲：王老师',
      textbookLabel: '浙教版',
      focusLabel: '讲义整理',
      activityLabel: '新建档案',
      classSizeLabel: '0 人 · 待补充',
      lessonFocusLabel: '待安排课堂',
      structureInsight: 'insight',
      studentCount: 0,
      weeklyLessonCount: 0,
      latestDocLabel: '暂无资料',
      assetLinks: [],
      memberTiers: [],
      lessonTimeline: [],
      summary: 'summary',
      highlights: [],
      nextStep: 'next',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    const prisma = makePrisma({
      teachingClass: {
        create,
        findMany: jest.fn(),
        findUnique: jest.fn(),
      },
    });

    const ctrl = new ClassesController(prisma);
    const result = await ctrl.create(
      { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
      {
        name: '九年级新班',
        stageLabel: '初中 · 九年级',
        teacherLabel: '主讲：王老师',
        textbookLabel: '浙教版',
        focusLabel: '讲义整理',
      },
    );

    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          tenantId: 't1',
          name: '九年级新班',
          stageLabel: '初中 · 九年级',
          teacherLabel: '主讲：王老师',
          textbookLabel: '浙教版',
          focusLabel: '讲义整理',
        }),
      }),
    );
    expect(result.class.name).toBe('九年级新班');
  });

  it('lists classes under current tenant', async () => {
    const prisma = makePrisma({
      teachingClass: {
        create: jest.fn(),
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
        create: jest.fn(),
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

  it('updates class profile under current tenant', async () => {
    const update = jest.fn().mockResolvedValue({
      tenantId: 't1',
      id: 'class-1',
      name: '九年级培优班',
      lessonId: 'lesson-1',
      documentId: 'doc-2',
      focusStudentId: 'student-1',
      focusStudentName: '林之涵',
      stageLabel: '初中 · 九年级',
      teacherLabel: '主讲：赵老师',
      textbookLabel: '人教版',
      focusLabel: '课堂复盘',
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
    });
    const prisma = makePrisma({
      teachingClass: {
        create: jest.fn(),
        findMany: jest.fn(),
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
        update,
      },
    });

    const ctrl = new ClassesController(prisma);
    const result = await ctrl.update(
      { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
      'class-1',
      {
        name: '九年级培优班',
        stageLabel: '初中 · 九年级',
        teacherLabel: '主讲：赵老师',
        textbookLabel: '人教版',
        focusLabel: '课堂复盘',
        focusStudentId: 'student-2',
        focusStudentName: '徐若楠',
      },
    );

    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          name: '九年级培优班',
          stageLabel: '初中 · 九年级',
          teacherLabel: '主讲：赵老师',
          textbookLabel: '人教版',
          focusLabel: '课堂复盘',
          focusStudentId: 'student-2',
          focusStudentName: '徐若楠',
        }),
      }),
    );
    expect(result.class.name).toBe('九年级培优班');
  });

  it('removes class profile under current tenant', async () => {
    const remove = jest.fn().mockResolvedValue({});
    const prisma = makePrisma({
      teachingClass: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({
          tenantId: 't1',
          id: 'class-1',
          name: '九年级尖子班',
        }),
        update: jest.fn(),
        delete: remove,
      },
    });

    const ctrl = new ClassesController(prisma);
    const result = await ctrl.remove(
      { tenant: { tenantId: 't1' }, auth: { userId: 'u1' } } as any,
      'class-1',
    );

    expect(remove).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          tenantId_id: {
            tenantId: 't1',
            id: 'class-1',
          },
        },
      }),
    );
    expect(result.removedId).toBe('class-1');
  });

  it('returns class detail by composite id', async () => {
    const prisma = makePrisma({
      teachingClass: {
        create: jest.fn(),
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
