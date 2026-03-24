class StudentWorkspaceRecord {
  const StudentWorkspaceRecord({
    required this.id,
    required this.name,
    required this.classId,
    required this.className,
    required this.lessonId,
    required this.documentId,
    required this.documentName,
    required this.gradeLabel,
    required this.subjectLabel,
    required this.textbookLabel,
    required this.trendLabel,
    required this.habitTag,
    required this.habitInsight,
    required this.followUpLevel,
    required this.summary,
    required this.scoreLabel,
    required this.historyTrendLabel,
    required this.wrongCountLabel,
    required this.wrongCount,
    required this.highlights,
    required this.nextStep,
  });

  final String id;
  final String name;
  final String classId;
  final String className;
  final String lessonId;
  final String documentId;
  final String documentName;
  final String gradeLabel;
  final String subjectLabel;
  final String textbookLabel;
  final String trendLabel;
  final String habitTag;
  final String habitInsight;
  final String followUpLevel;
  final String summary;
  final String scoreLabel;
  final String historyTrendLabel;
  final String wrongCountLabel;
  final int wrongCount;
  final List<String> highlights;
  final String nextStep;
}

const List<StudentWorkspaceRecord> sampleStudentRecords = [
  StudentWorkspaceRecord(
    id: 'student-1',
    name: '林之涵',
    classId: 'class-1',
    className: '九年级尖子班',
    lessonId: 'lesson-1',
    documentId: 'doc-2',
    documentName: '二次函数周测卷',
    gradeLabel: '初中 · 九年级下',
    subjectLabel: '数学',
    textbookLabel: '浙教版',
    trendLabel: '近期进步',
    habitTag: '订正及时',
    habitInsight: '课后会主动回看讲义边注，订正完成度高，适合逐步增加开放题表达训练。',
    followUpLevel: '常规关注',
    summary: '最近两次函数专题测试稳步提升，几何综合题仍然需要在证明链条上加强拆解。',
    scoreLabel: '92 / 100',
    historyTrendLabel: '86 → 89 → 92',
    wrongCountLabel: '6 道',
    wrongCount: 6,
    highlights: [
      '相似三角形与二次函数综合题开始具备完整表达。',
      '课堂互动积极，课后讲义订正完成度高。',
      '可以逐步提高压轴题和开放题比重。',
    ],
    nextStep: '下一轮讲义里增加 2 道几何压轴题，并安排一次口头讲解复盘。',
  ),
  StudentWorkspaceRecord(
    id: 'student-2',
    name: '徐若楠',
    classId: 'class-2',
    className: '九年级提高班',
    lessonId: 'lesson-2',
    documentId: 'doc-1',
    documentName: '九上相似专题讲义',
    gradeLabel: '初中 · 九年级下',
    subjectLabel: '数学',
    textbookLabel: '浙教版',
    trendLabel: '波动明显',
    habitTag: '审题偏快',
    habitInsight: '课堂中容易直接下笔，跳过已知条件整理，适合在讲义里加入审题停顿框。',
    followUpLevel: '重点跟进',
    summary: '函数图像题失分较多，课堂作答时容易跳步骤，需要把题干拆解与审题节奏纳入跟进。',
    scoreLabel: '71 / 100',
    historyTrendLabel: '78 → 69 → 71',
    wrongCountLabel: '14 道',
    wrongCount: 14,
    highlights: [
      '函数图像题和表格信息题错误集中。',
      '错题订正完成，但口头复述仍不稳定。',
      '需要通过讲义中的“已知/求证”拆解框减缓审题节奏。',
    ],
    nextStep: '下节课前单独推送函数图像复盘讲义，并在课堂里安排一次分步板演。',
  ),
  StudentWorkspaceRecord(
    id: 'student-3',
    name: '陈嘉言',
    classId: 'class-3',
    className: '个人工作区样例',
    lessonId: 'lesson-3',
    documentId: 'doc-1',
    documentName: '九上相似专题讲义',
    gradeLabel: '高中 · 高一',
    subjectLabel: '物理',
    textbookLabel: '人教版',
    trendLabel: '稳定',
    habitTag: '错题回看',
    habitInsight: '习惯在课后回看错题与讲义边注，适合用个人工作区持续沉淀单人学习轨迹。',
    followUpLevel: '常规关注',
    summary: '力学计算题完成度稳定，个人工作区里重点跟踪的是错题回看的频次与课堂反馈衔接。',
    scoreLabel: '84 / 100',
    historyTrendLabel: '81 → 83 → 84',
    wrongCountLabel: '9 道',
    wrongCount: 9,
    highlights: [
      '习惯在课后回看错题与讲义边注。',
      '需要强化图像信息提取和物理量转化。',
      '适合作为个人工作区样例，后续验证课堂反馈回流。',
    ],
    nextStep: '将下一次课堂反馈与错题标签联动，验证个人工作区闭环。',
  ),
];

StudentWorkspaceRecord? findStudentWorkspaceRecord(String id) {
  for (final student in sampleStudentRecords) {
    if (student.id == id) {
      return student;
    }
  }
  return null;
}
