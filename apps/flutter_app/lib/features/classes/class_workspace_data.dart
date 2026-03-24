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
