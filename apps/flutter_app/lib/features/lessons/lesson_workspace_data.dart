class LessonWorkspaceRecord {
  const LessonWorkspaceRecord({
    required this.id,
    required this.title,
    required this.classId,
    required this.className,
    required this.focusStudentId,
    required this.focusStudentName,
    required this.teacherLabel,
    required this.scheduleLabel,
    required this.scheduleTag,
    required this.classScopeLabel,
    required this.documentFocus,
    required this.documentId,
    required this.feedbackStatus,
    required this.followUpLabel,
    required this.feedbackInsight,
    required this.summary,
    required this.highlights,
    required this.nextStep,
  });

  final String id;
  final String title;
  final String classId;
  final String className;
  final String focusStudentId;
  final String focusStudentName;
  final String teacherLabel;
  final String scheduleLabel;
  final String scheduleTag;
  final String classScopeLabel;
  final String documentFocus;
  final String documentId;
  final String feedbackStatus;
  final String followUpLabel;
  final String feedbackInsight;
  final String summary;
  final List<String> highlights;
  final String nextStep;
}

const List<LessonWorkspaceRecord> sampleLessonRecords = [
  LessonWorkspaceRecord(
    id: 'lesson-1',
    title: '二次函数专题复盘课',
    classId: 'class-1',
    className: '九年级尖子班',
    focusStudentId: 'student-1',
    focusStudentName: '林之涵',
    teacherLabel: '主讲：陈老师',
    scheduleLabel: '周三 19:00 - 20:30',
    scheduleTag: '本周进行',
    classScopeLabel: '九年级尖子班',
    documentFocus: '二次函数周测卷',
    documentId: 'doc-2',
    feedbackStatus: '待回收',
    followUpLabel: '补讲义',
    feedbackInsight: '本节课后要重点回收压轴题口头讲解、错题订正和课堂参与反馈，方便回写学生画像。',
    summary: '这节课会先复盘周测卷，再补一页压轴题拆解讲义，课后需要回收错题与口头讲解反馈。',
    highlights: [
      '主资料是试卷 + 补充讲义，课堂结构更像复盘课。',
      '课后要记录 5 名重点学生的压轴题表达问题。',
      '下节课前需把课堂反馈回写到学生画像和题库复盘。',
    ],
    nextStep: '课后先收一轮错题反馈，再把讲义补充页挂到下节专题课。',
  ),
  LessonWorkspaceRecord(
    id: 'lesson-2',
    title: '相似三角形讲义推进课',
    classId: 'class-2',
    className: '九年级提高班',
    focusStudentId: 'student-2',
    focusStudentName: '徐若楠',
    teacherLabel: '主讲：沈老师',
    scheduleLabel: '周四 18:30 - 20:00',
    scheduleTag: '本周进行',
    classScopeLabel: '九年级提高班',
    documentFocus: '相似三角形讲义',
    documentId: 'doc-1',
    feedbackStatus: '已回收',
    followUpLabel: '短测跟进',
    feedbackInsight: '讲义反馈已收齐，下一轮重点是把课堂追问和课后短测结果重新沉淀到班级分层任务里。',
    summary: '本节以讲义推进为主，重点看例题拆解、课堂追问和课后短测之间的衔接。',
    highlights: [
      '讲义版式已经稳定，重点优化课堂追问节奏。',
      '反馈回收完成，可以开始沉淀短测题单。',
      '后续要把讲义反馈回流到班级分层任务里。',
    ],
    nextStep: '补一份短测卷，并在周末班级复盘里对齐讲义重点段落。',
  ),
  LessonWorkspaceRecord(
    id: 'lesson-3',
    title: '高一力学模型拆解课',
    classId: 'class-3',
    className: '高一物理培优班',
    focusStudentId: 'student-3',
    focusStudentName: '陈嘉言',
    teacherLabel: '主讲：周老师',
    scheduleLabel: '下周一 19:30 - 21:00',
    scheduleTag: '待准备',
    classScopeLabel: '高一物理培优班',
    documentFocus: '力学模型讲义',
    documentId: 'doc-1',
    feedbackStatus: '待回收',
    followUpLabel: '资料待排版',
    feedbackInsight: '这节课的反馈重点是图像信息提取、模型识别和讲义图示是否足够清晰，适合先跑课堂样例。',
    summary: '课堂重点是把模型图像和文字描述拆开讲，当前最需要把讲义中的示意图和板书节奏补完整。',
    highlights: [
      '当前资料还在排版阶段，课堂前需完成最终导出。',
      '课后要收图像题理解反馈，验证讲义版式是否足够清晰。',
      '个人工作区里的物理样例可以先承接这条课堂时间线。',
    ],
    nextStep: '先完成力学讲义排版，再为课堂补一份图像辨析短练。',
  ),
];

LessonWorkspaceRecord? findLessonWorkspaceRecord(String id) {
  for (final lesson in sampleLessonRecords) {
    if (lesson.id == id) {
      return lesson;
    }
  }
  return null;
}
