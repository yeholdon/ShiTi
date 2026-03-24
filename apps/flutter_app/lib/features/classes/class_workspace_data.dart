class ClassTierRecord {
  const ClassTierRecord({
    required this.label,
    required this.studentCount,
    required this.focus,
  });

  final String label;
  final int studentCount;
  final String focus;
}

class ClassLessonTimelineRecord {
  const ClassLessonTimelineRecord({
    required this.label,
    required this.scheduleLabel,
    required this.statusLabel,
    required this.focus,
    required this.lessonId,
    required this.actionLabel,
  });

  final String label;
  final String scheduleLabel;
  final String statusLabel;
  final String focus;
  final String lessonId;
  final String actionLabel;
}

class ClassWorkspaceRecord {
  const ClassWorkspaceRecord({
    required this.id,
    required this.name,
    required this.lessonId,
    required this.documentId,
    required this.focusStudentId,
    required this.focusStudentName,
    required this.stageLabel,
    required this.teacherLabel,
    required this.textbookLabel,
    required this.focusLabel,
    required this.activityLabel,
    required this.classSizeLabel,
    required this.lessonFocusLabel,
    required this.structureInsight,
    required this.studentCount,
    required this.weeklyLessonCount,
    required this.latestDocLabel,
    required this.memberTiers,
    required this.lessonTimeline,
    required this.summary,
    required this.highlights,
    required this.nextStep,
  });

  final String id;
  final String name;
  final String lessonId;
  final String documentId;
  final String focusStudentId;
  final String focusStudentName;
  final String stageLabel;
  final String teacherLabel;
  final String textbookLabel;
  final String focusLabel;
  final String activityLabel;
  final String classSizeLabel;
  final String lessonFocusLabel;
  final String structureInsight;
  final int studentCount;
  final int weeklyLessonCount;
  final String latestDocLabel;
  final List<ClassTierRecord> memberTiers;
  final List<ClassLessonTimelineRecord> lessonTimeline;
  final String summary;
  final List<String> highlights;
  final String nextStep;
}

const List<ClassWorkspaceRecord> sampleClassRecords = [
  ClassWorkspaceRecord(
    id: 'class-1',
    name: '九年级尖子班',
    lessonId: 'lesson-1',
    documentId: 'doc-2',
    focusStudentId: 'student-1',
    focusStudentName: '林之涵',
    stageLabel: '初中 · 冲刺组',
    teacherLabel: '主讲：陈老师',
    textbookLabel: '浙教版',
    focusLabel: '试卷跟进',
    activityLabel: '本周活跃',
    classSizeLabel: '26 人 · 小班精练',
    lessonFocusLabel: '复盘课',
    structureInsight: '班级规模适合精细追踪压轴题表达，可把课堂反馈直接回收进学生画像。',
    studentCount: 26,
    weeklyLessonCount: 3,
    latestDocLabel: '二次函数周测卷',
    memberTiers: [
      ClassTierRecord(
        label: '冲刺层',
        studentCount: 8,
        focus: '压轴题表达与证明链条稳定推进。',
      ),
      ClassTierRecord(
        label: '稳固层',
        studentCount: 12,
        focus: '二次函数综合题保持正确率，继续补讲义拆解。',
      ),
      ClassTierRecord(
        label: '跟进层',
        studentCount: 6,
        focus: '课堂复盘后重点跟进函数压轴题与错题订正。',
      ),
    ],
    lessonTimeline: [
      ClassLessonTimelineRecord(
        label: '周二 · 二次函数周测复盘',
        scheduleLabel: '已完成',
        statusLabel: '反馈已回收',
        focus: '重点回看压轴题的表达链条，并把复盘结果沉淀进学生画像。',
        lessonId: 'lesson-1',
        actionLabel: '查看复盘课详情',
      ),
      ClassLessonTimelineRecord(
        label: '周四 · 压轴题拆解讲义',
        scheduleLabel: '进行中',
        statusLabel: '资料待补',
        focus: '围绕讲义拆分压轴题模型，课堂里继续区分冲刺层和稳固层。',
        lessonId: 'lesson-1',
        actionLabel: '查看当前课堂详情',
      ),
      ClassLessonTimelineRecord(
        label: '周六 · 专题复盘课',
        scheduleLabel: '待开始',
        statusLabel: '课堂待排',
        focus: '把本周周测卷和讲义回看串到同一节专题课里，验证提分节奏。',
        lessonId: 'lesson-1',
        actionLabel: '查看待排课堂',
      ),
    ],
    summary: '当前重点是周测卷复盘和压轴题讲解，班级对讲义中的板书提示响应较好。',
    highlights: [
      '本周安排 3 节课堂，2 份试卷回看，1 份讲义补充。',
      '需要关注中段学生在函数压轴题上的分层差异。',
      '最近导出资料以试卷为主，讲义需要补一次课堂版。',
    ],
    nextStep: '先补一份“压轴题拆解讲义”，再串到周四的专题复盘课里。',
  ),
  ClassWorkspaceRecord(
    id: 'class-2',
    name: '九年级提高班',
    lessonId: 'lesson-2',
    documentId: 'doc-1',
    focusStudentId: 'student-2',
    focusStudentName: '徐若楠',
    stageLabel: '初中 · 提高组',
    teacherLabel: '主讲：沈老师',
    textbookLabel: '浙教版',
    focusLabel: '讲义整理',
    activityLabel: '本周活跃',
    classSizeLabel: '34 人 · 常规班型',
    lessonFocusLabel: '讲义推进',
    structureInsight: '班级人数偏多，讲义与课堂追问需要更强的分层结构，短测更适合作为课后回收。',
    studentCount: 34,
    weeklyLessonCount: 2,
    latestDocLabel: '相似三角形讲义',
    memberTiers: [
      ClassTierRecord(
        label: '提优层',
        studentCount: 9,
        focus: '保持讲义推进节奏，补短测承接开放题表达。',
      ),
      ClassTierRecord(
        label: '主力层',
        studentCount: 17,
        focus: '围绕讲义例题和课堂追问建立稳定答题结构。',
      ),
      ClassTierRecord(
        label: '跟进层',
        studentCount: 8,
        focus: '重点放慢审题节奏，先稳住图像和表格信息题。',
      ),
    ],
    lessonTimeline: [
      ClassLessonTimelineRecord(
        label: '周三 · 相似三角形讲义推进',
        scheduleLabel: '已完成',
        statusLabel: '讲义已同步',
        focus: '课堂例题和追问框反应较好，下一步需要补一轮短测回收。',
        lessonId: 'lesson-2',
        actionLabel: '查看讲义推进课',
      ),
      ClassLessonTimelineRecord(
        label: '周五 · 随堂短测',
        scheduleLabel: '待开始',
        statusLabel: '试卷待补',
        focus: '把讲义中的重点例题转成短测，区分主力层和跟进层的回收效果。',
        lessonId: 'lesson-2',
        actionLabel: '查看短测课堂',
      ),
    ],
    summary: '班级目前更适合讲义驱动，课堂中对例题拆解和追问框的反馈较好。',
    highlights: [
      '最近一周以讲义整理和板书节奏优化为主。',
      '需要补一次随堂小测，把讲义反馈收回到题库复盘。',
      '班级人数较多，课堂任务要进一步分层。',
    ],
    nextStep: '下节课前补一份短测卷，并按讲义段落安排分层互动。',
  ),
  ClassWorkspaceRecord(
    id: 'class-3',
    name: '高一物理培优班',
    lessonId: 'lesson-3',
    documentId: 'doc-1',
    focusStudentId: 'student-3',
    focusStudentName: '陈嘉言',
    stageLabel: '高中 · 培优组',
    teacherLabel: '主讲：周老师',
    textbookLabel: '人教版',
    focusLabel: '课堂联动',
    activityLabel: '待排课',
    classSizeLabel: '18 人 · 培优小组',
    lessonFocusLabel: '模型拆解',
    structureInsight: '小规模培优班适合把课堂、讲义和学生反馈绑得更紧，先跑通课堂闭环样例。',
    studentCount: 18,
    weeklyLessonCount: 1,
    latestDocLabel: '力学建模讲义',
    memberTiers: [
      ClassTierRecord(
        label: '培优层',
        studentCount: 6,
        focus: '主抓模型辨析和图像信息转化的高阶表达。',
      ),
      ClassTierRecord(
        label: '稳定层',
        studentCount: 7,
        focus: '保证讲义例题和课堂反馈之间的闭环。',
      ),
      ClassTierRecord(
        label: '跟进层',
        studentCount: 5,
        focus: '先跑通课堂反馈样例，再补错题和课后任务衔接。',
      ),
    ],
    lessonTimeline: [
      ClassLessonTimelineRecord(
        label: '周四 · 力学建模导入',
        scheduleLabel: '待开始',
        statusLabel: '资料已准备',
        focus: '先用一节导入课跑通模型辨析、讲义提示和反馈采样。',
        lessonId: 'lesson-3',
        actionLabel: '查看导入课堂',
      ),
      ClassLessonTimelineRecord(
        label: '周末 · 课堂反馈整理',
        scheduleLabel: '待开始',
        statusLabel: '任务待创建',
        focus: '把课堂里采到的反馈整理成后续任务，回写到学生画像和班级跟进。',
        lessonId: 'lesson-3',
        actionLabel: '查看反馈整理课',
      ),
    ],
    summary: '当前在验证课堂、学生画像和讲义之间的联动路径，班级规模适合做更细的反馈跟进。',
    highlights: [
      '班级规模较小，适合先跑课堂反馈样例。',
      '本周只有 1 节课，适合作为课堂管理首批联动样例。',
      '讲义和课后任务可以更紧密地串联。',
    ],
    nextStep: '先用一节课堂跑通“讲义 -> 反馈 -> 学生画像”的闭环。',
  ),
];

ClassWorkspaceRecord? findClassWorkspaceRecord(String id) {
  for (final classroom in sampleClassRecords) {
    if (classroom.id == id) {
      return classroom;
    }
  }
  return null;
}
