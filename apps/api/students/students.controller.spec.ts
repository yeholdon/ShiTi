import { StudentsController } from "./students.controller";

function makePrisma(overrides: Partial<any> = {}) {
  const tenantMember = overrides.tenantMember ?? {
    findFirst: jest
      .fn()
      .mockResolvedValue({ role: "member", status: "active" }),
  };
  const studentProfile = overrides.studentProfile ?? {
    create: jest.fn(),
    findMany: jest.fn(),
    findUnique: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
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

describe("StudentsController", () => {
  it("creates student profile under current tenant", async () => {
    const create = jest.fn().mockResolvedValue({
      tenantId: "t1",
      id: "student-4",
      name: "新同学",
      classId: "class-2",
      className: "九年级提高班",
      lessonId: "lesson-2",
      documentId: "doc-1",
      documentName: "九上相似专题讲义",
      gradeLabel: "初中 · 九年级下",
      subjectLabel: "数学",
      textbookLabel: "浙教版",
      trendLabel: "新建档案",
      habitTag: "待观察",
      habitInsight: "detail",
      followUpLevel: "常规关注",
      summary: "summary",
      scoreLabel: "暂无成绩",
      historyTrendLabel: "待记录",
      wrongCountLabel: "0 道",
      wrongCount: 0,
      scoreRecords: [],
      feedbackRecords: [],
      wrongQuestionRecords: [],
      highlights: [],
      nextStep: "next",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    const prisma = makePrisma({
      studentProfile: {
        create,
        findMany: jest.fn(),
        findUnique: jest.fn(),
      },
    });

    const ctrl = new StudentsController(prisma);
    const result = await ctrl.create(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      {
        name: "新同学",
        classId: "class-2",
        className: "九年级提高班",
        lessonId: "lesson-2",
        documentId: "doc-1",
        documentName: "九上相似专题讲义",
        gradeLabel: "初中 · 九年级下",
        subjectLabel: "数学",
        textbookLabel: "浙教版",
      },
    );

    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          tenantId: "t1",
          name: "新同学",
          classId: "class-2",
          className: "九年级提高班",
          lessonId: "lesson-2",
          documentId: "doc-1",
          documentName: "九上相似专题讲义",
          gradeLabel: "初中 · 九年级下",
          subjectLabel: "数学",
          textbookLabel: "浙教版",
        }),
      }),
    );
    expect(result.student.name).toBe("新同学");
  });

  it("lists students under current tenant", async () => {
    const prisma = makePrisma({
      studentProfile: {
        create: jest.fn(),
        findMany: jest.fn().mockResolvedValue([
          {
            tenantId: "t1",
            id: "student-1",
            name: "林之涵",
            classId: "class-1",
            className: "九年级尖子班",
            lessonId: "lesson-1",
            documentId: "doc-2",
            documentName: "二次函数周测卷",
            gradeLabel: "初中",
            subjectLabel: "数学",
            textbookLabel: "浙教版",
            trendLabel: "近期进步",
            habitTag: "订正及时",
            habitInsight: "detail",
            followUpLevel: "常规关注",
            summary: "summary",
            scoreLabel: "92 / 100",
            historyTrendLabel: "86 → 89 → 92",
            wrongCountLabel: "6 道",
            wrongCount: 6,
            scoreRecords: [],
            feedbackRecords: [],
            wrongQuestionRecords: [],
            highlights: [],
            nextStep: "next",
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        ]),
      },
    });

    const ctrl = new StudentsController(prisma);
    const result = await ctrl.list(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      undefined,
    );

    expect(result.students).toHaveLength(1);
    expect(result.students[0].id).toBe("student-1");
  });

  it("passes classId and lessonId filters to student list query", async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = makePrisma({
      studentProfile: {
        create: jest.fn(),
        findMany,
        findUnique: jest.fn(),
      },
    });

    const ctrl = new StudentsController(prisma);
    await ctrl.list(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      "林",
      "class-3",
      "lesson-3",
    );

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "t1",
          classId: "class-3",
          lessonId: "lesson-3",
        }),
      }),
    );
  });

  it("returns student detail by composite id", async () => {
    const prisma = makePrisma({
      studentProfile: {
        create: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({
          tenantId: "t1",
          id: "student-1",
          name: "林之涵",
          classId: "class-1",
          className: "九年级尖子班",
          lessonId: "lesson-1",
          documentId: "doc-2",
          documentName: "二次函数周测卷",
          gradeLabel: "初中",
          subjectLabel: "数学",
          textbookLabel: "浙教版",
          trendLabel: "近期进步",
          habitTag: "订正及时",
          habitInsight: "detail",
          followUpLevel: "常规关注",
          summary: "summary",
          scoreLabel: "92 / 100",
          historyTrendLabel: "86 → 89 → 92",
          wrongCountLabel: "6 道",
          wrongCount: 6,
          scoreRecords: [],
          feedbackRecords: [],
          wrongQuestionRecords: [],
          highlights: [],
          nextStep: "next",
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      },
    });

    const ctrl = new StudentsController(prisma);
    const result = await ctrl.detail(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      "student-1",
    );

    expect(result.student.id).toBe("student-1");
  });

  it("updates student profile under current tenant", async () => {
    const findUnique = jest.fn().mockResolvedValue({
      tenantId: "t1",
      id: "student-1",
      name: "林之涵",
      classId: null,
      className: "九年级尖子班",
      lessonId: null,
      documentId: null,
      documentName: null,
      gradeLabel: "初中 · 九年级下",
      subjectLabel: "数学",
      textbookLabel: "浙教版",
      trendLabel: "近期进步",
      habitTag: "订正及时",
      habitInsight: "detail",
      followUpLevel: "常规关注",
      summary: "summary",
      scoreLabel: "92 / 100",
      historyTrendLabel: "86 → 89 → 92",
      wrongCountLabel: "6 道",
      wrongCount: 6,
      scoreRecords: [],
      feedbackRecords: [],
      wrongQuestionRecords: [],
      highlights: [],
      nextStep: "next",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    const update = jest.fn().mockResolvedValue({
      tenantId: "t1",
      id: "student-1",
      name: "林之涵（更新）",
      classId: "class-2",
      className: "九年级提高班",
      lessonId: "lesson-2",
      documentId: "doc-1",
      documentName: "九上相似专题讲义",
      gradeLabel: "初中 · 九年级下",
      subjectLabel: "数学",
      textbookLabel: "人教版",
      trendLabel: "近期进步",
      habitTag: "订正及时",
      habitInsight: "detail",
      followUpLevel: "常规关注",
      summary: "summary",
      scoreLabel: "92 / 100",
      historyTrendLabel: "86 → 89 → 92",
      wrongCountLabel: "6 道",
      wrongCount: 6,
      scoreRecords: [],
      feedbackRecords: [],
      wrongQuestionRecords: [],
      highlights: [],
      nextStep: "next",
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const prisma = makePrisma({
      studentProfile: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique,
        update,
      },
    });

    const ctrl = new StudentsController(prisma);
    const result = await ctrl.update(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      "student-1",
      {
        name: "林之涵（更新）",
        classId: "class-2",
        className: "九年级提高班",
        lessonId: "lesson-2",
        documentId: "doc-1",
        documentName: "九上相似专题讲义",
        textbookLabel: "人教版",
      },
    );

    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          tenantId_id: {
            tenantId: "t1",
            id: "student-1",
          },
        },
        data: expect.objectContaining({
          name: "林之涵（更新）",
          classId: "class-2",
          className: "九年级提高班",
          lessonId: "lesson-2",
          documentId: "doc-1",
          documentName: "九上相似专题讲义",
          textbookLabel: "人教版",
        }),
      }),
    );
    expect(result.student.name).toBe("林之涵（更新）");
  });

  it("removes student profile under current tenant", async () => {
    const findUnique = jest.fn().mockResolvedValue({
      tenantId: "t1",
      id: "student-1",
      name: "林之涵",
    });
    const remove = jest.fn().mockResolvedValue({});

    const prisma = makePrisma({
      studentProfile: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique,
        update: jest.fn(),
        delete: remove,
      },
    });

    const ctrl = new StudentsController(prisma);
    const result = await ctrl.remove(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      "student-1",
    );

    expect(remove).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          tenantId_id: {
            tenantId: "t1",
            id: "student-1",
          },
        },
      }),
    );
    expect(result.removedId).toBe("student-1");
  });
});
