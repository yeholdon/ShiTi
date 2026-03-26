import { LessonsController } from "./lessons.controller";

function makePrisma(overrides: Partial<any> = {}) {
  const tenantMember = overrides.tenantMember ?? {
    findFirst: jest
      .fn()
      .mockResolvedValue({ role: "member", status: "active" }),
  };
  const studentProfile = overrides.studentProfile ?? {
    updateMany: jest.fn(),
  };
  const lessonSession = overrides.lessonSession ?? {
    create: jest.fn(),
    findMany: jest.fn(),
    findUnique: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };

  return {
    lessonSession,
    studentProfile,
    tenantMember,
    withTenant: jest.fn(async (_tenantId: string, fn: any) =>
      fn({
        lessonSession,
        studentProfile,
        tenantMember,
      }),
    ),
    ...overrides,
  } as any;
}

describe("LessonsController", () => {
  it("creates lesson profile under current tenant", async () => {
    const create = jest.fn().mockResolvedValue({
      tenantId: "t1",
      id: "lesson-4",
      title: "新课堂",
      classId: null,
      className: "九年级尖子班",
      focusStudentId: null,
      focusStudentName: null,
      teacherLabel: "主讲：李老师",
      scheduleLabel: "周五 19:00",
      scheduleTag: "待安排",
      classScopeLabel: "九年级尖子班",
      documentFocus: "未绑定资料",
      documentId: null,
      feedbackStatus: "待回收",
      followUpLabel: "待安排",
      feedbackInsight: "insight",
      feedbackRecords: [],
      assetRecords: [],
      taskRecords: [],
      summary: "summary",
      highlights: [],
      nextStep: "next",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    const prisma = makePrisma({
      lessonSession: {
        create,
        findMany: jest.fn(),
        findUnique: jest.fn(),
      },
    });

    const ctrl = new LessonsController(prisma);
    const result = await ctrl.create(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      {
        title: "新课堂",
        teacherLabel: "主讲：李老师",
        scheduleLabel: "周五 19:00",
        classScopeLabel: "九年级尖子班",
      },
    );

    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          tenantId: "t1",
          title: "新课堂",
          teacherLabel: "主讲：李老师",
          scheduleLabel: "周五 19:00",
          classScopeLabel: "九年级尖子班",
        }),
      }),
    );
    expect(result.lesson.title).toBe("新课堂");
  });

  it("lists lessons under current tenant", async () => {
    const prisma = makePrisma({
      lessonSession: {
        create: jest.fn(),
        findMany: jest.fn().mockResolvedValue([
          {
            tenantId: "t1",
            id: "lesson-1",
            title: "二次函数专题复盘课",
            classId: "class-1",
            className: "九年级尖子班",
            focusStudentId: "student-1",
            focusStudentName: "林之涵",
            teacherLabel: "主讲：陈老师",
            scheduleLabel: "周三 19:00",
            scheduleTag: "本周进行",
            classScopeLabel: "九年级尖子班",
            documentFocus: "二次函数周测卷",
            documentId: "doc-2",
            feedbackStatus: "待回收",
            followUpLabel: "补讲义",
            feedbackInsight: "insight",
            feedbackRecords: [],
            assetRecords: [],
            taskRecords: [],
            summary: "summary",
            highlights: [],
            nextStep: "next",
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        ]),
      },
    });

    const ctrl = new LessonsController(prisma);
    const result = await ctrl.list(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      undefined,
    );

    expect(result.lessons).toHaveLength(1);
    expect(result.lessons[0].id).toBe("lesson-1");
  });

  it("passes studentId and classId filters into lesson listing", async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = makePrisma({
      lessonSession: {
        create: jest.fn(),
        findMany,
        findUnique: jest.fn(),
      },
    });

    const ctrl = new LessonsController(prisma);
    await ctrl.list(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      "复盘",
      "student-1",
      "class-2",
    );

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "t1",
          archivedAt: null,
          focusStudentId: "student-1",
          classId: "class-2",
          OR: expect.any(Array),
        }),
      }),
    );
  });

  it("updates lesson profile under current tenant", async () => {
    const updateMany = jest.fn().mockResolvedValue({ count: 0 });
    const update = jest.fn().mockResolvedValue({
      tenantId: "t1",
      id: "lesson-1",
      title: "二次函数专题讲评课",
      classId: "class-1",
      className: "九年级提高班",
      focusStudentId: "student-1",
      focusStudentName: "林之涵",
      teacherLabel: "主讲：赵老师",
      scheduleLabel: "周六 14:00",
      scheduleTag: "本周进行",
      classScopeLabel: "九年级提高班",
      documentFocus: "二次函数周测卷",
      documentId: "doc-2",
      feedbackStatus: "待回收",
      followUpLabel: "补讲义",
      feedbackInsight: "insight",
      feedbackRecords: [],
      assetRecords: [],
      taskRecords: [],
      summary: "summary",
      highlights: [],
      nextStep: "next",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    const prisma = makePrisma({
      studentProfile: {
        updateMany,
      },
      lessonSession: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({
          tenantId: "t1",
          id: "lesson-1",
          title: "二次函数专题复盘课",
          classId: "class-1",
          className: "九年级尖子班",
          focusStudentId: "student-1",
          focusStudentName: "林之涵",
          teacherLabel: "主讲：陈老师",
          scheduleLabel: "周三 19:00",
          scheduleTag: "本周进行",
          classScopeLabel: "九年级尖子班",
          documentFocus: "二次函数周测卷",
          documentId: "doc-2",
          feedbackStatus: "待回收",
          followUpLabel: "补讲义",
          feedbackInsight: "insight",
          feedbackRecords: [],
          assetRecords: [],
          taskRecords: [],
          summary: "summary",
          highlights: [],
          nextStep: "next",
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
        update,
      },
    });

    const ctrl = new LessonsController(prisma);
    const result = await ctrl.update(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      "lesson-1",
      {
        title: "二次函数专题讲评课",
        teacherLabel: "主讲：赵老师",
        scheduleLabel: "周六 14:00",
        classScopeLabel: "九年级提高班",
        focusStudentId: "student-2",
        focusStudentName: "徐若楠",
        classId: "class-2",
        documentId: "doc-1",
        documentFocus: "相似三角形讲义",
        feedbackStudentIds: ["student-2", "student-3"],
      },
    );

    expect(updateMany).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "t1",
          lessonId: "lesson-1",
          id: { notIn: ["student-2", "student-3"] },
        }),
        data: {
          lessonId: null,
        },
      }),
    );
    expect(updateMany).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        where: expect.objectContaining({
          tenantId: "t1",
          id: { in: ["student-2", "student-3"] },
        }),
        data: {
          lessonId: "lesson-1",
        },
      }),
    );
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          title: "二次函数专题讲评课",
          teacherLabel: "主讲：赵老师",
          scheduleLabel: "周六 14:00",
          classScopeLabel: "九年级提高班",
          className: "九年级提高班",
          focusStudentId: "student-2",
          focusStudentName: "徐若楠",
          classId: "class-2",
          documentId: "doc-1",
          documentFocus: "相似三角形讲义",
          feedbackStatus: "2 人已承接",
        }),
      }),
    );
    expect(result.lesson.title).toBe("二次函数专题讲评课");
  });

  it("archives lesson profile under current tenant", async () => {
    const update = jest.fn().mockResolvedValue({
      tenantId: "t1",
      id: "lesson-1",
      title: "二次函数专题复盘课",
      archivedAt: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    const prisma = makePrisma({
      lessonSession: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({
          tenantId: "t1",
          id: "lesson-1",
          title: "二次函数专题复盘课",
          archivedAt: null,
          teacherLabel: "主讲：陈老师",
          scheduleLabel: "周三 19:00",
          scheduleTag: "本周进行",
          classScopeLabel: "九年级尖子班",
          documentFocus: "二次函数周测卷",
          feedbackStatus: "待回收",
          followUpLabel: "补讲义",
          feedbackInsight: "",
          feedbackRecords: [],
          assetRecords: [],
          taskRecords: [],
          summary: "",
          highlights: [],
          nextStep: "",
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
        update,
      },
      studentProfile: {
        updateMany: jest.fn(),
      },
    });

    const ctrl = new LessonsController(prisma);
    await ctrl.update(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      "lesson-1",
      { archived: true },
    );

    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          archivedAt: expect.any(Date),
        }),
      }),
    );
  });

  it("removes lesson profile under current tenant", async () => {
    const remove = jest.fn().mockResolvedValue({});
    const prisma = makePrisma({
      lessonSession: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({
          tenantId: "t1",
          id: "lesson-1",
          title: "二次函数专题复盘课",
        }),
        update: jest.fn(),
        delete: remove,
      },
    });

    const ctrl = new LessonsController(prisma);
    const result = await ctrl.remove(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      "lesson-1",
    );

    expect(remove).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          tenantId_id: {
            tenantId: "t1",
            id: "lesson-1",
          },
        },
      }),
    );
    expect(result.removedId).toBe("lesson-1");
  });

  it("returns lesson detail by composite id", async () => {
    const prisma = makePrisma({
      lessonSession: {
        create: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({
          tenantId: "t1",
          id: "lesson-1",
          title: "二次函数专题复盘课",
          classId: "class-1",
          className: "九年级尖子班",
          focusStudentId: "student-1",
          focusStudentName: "林之涵",
          teacherLabel: "主讲：陈老师",
          scheduleLabel: "周三 19:00",
          scheduleTag: "本周进行",
          classScopeLabel: "九年级尖子班",
          documentFocus: "二次函数周测卷",
          documentId: "doc-2",
          feedbackStatus: "待回收",
          followUpLabel: "补讲义",
          feedbackInsight: "insight",
          feedbackRecords: [],
          assetRecords: [],
          taskRecords: [],
          summary: "summary",
          highlights: [],
          nextStep: "next",
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      },
    });

    const ctrl = new LessonsController(prisma);
    const result = await ctrl.detail(
      { tenant: { tenantId: "t1" }, auth: { userId: "u1" } } as any,
      "lesson-1",
    );

    expect(result.lesson.id).toBe("lesson-1");
  });
});
