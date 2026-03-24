class StudentScoreRecord {
  const StudentScoreRecord({
    required this.label,
    required this.score,
    required this.totalScore,
    required this.insight,
  });

  final String label;
  final int score;
  final int totalScore;
  final String insight;

  factory StudentScoreRecord.fromJson(Map<String, dynamic> json) {
    return StudentScoreRecord(
      label: json['label'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
      insight: json['insight'] as String? ?? '',
    );
  }
}

class StudentWrongQuestionRecord {
  const StudentWrongQuestionRecord({
    required this.label,
    required this.status,
    required this.followUp,
  });

  final String label;
  final String status;
  final String followUp;

  factory StudentWrongQuestionRecord.fromJson(Map<String, dynamic> json) {
    return StudentWrongQuestionRecord(
      label: json['label'] as String? ?? '',
      status: json['status'] as String? ?? '',
      followUp: json['followUp'] as String? ?? '',
    );
  }
}

class StudentFeedbackRecord {
  const StudentFeedbackRecord({
    required this.label,
    required this.status,
    required this.detail,
  });

  final String label;
  final String status;
  final String detail;

  factory StudentFeedbackRecord.fromJson(Map<String, dynamic> json) {
    return StudentFeedbackRecord(
      label: json['label'] as String? ?? '',
      status: json['status'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }
}

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
    required this.scoreRecords,
    required this.feedbackRecords,
    required this.wrongQuestionRecords,
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
  final List<StudentScoreRecord> scoreRecords;
  final List<StudentFeedbackRecord> feedbackRecords;
  final List<StudentWrongQuestionRecord> wrongQuestionRecords;
  final List<String> highlights;
  final String nextStep;

  factory StudentWorkspaceRecord.fromJson(Map<String, dynamic> json) {
    return StudentWorkspaceRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      classId: json['classId'] as String? ?? '',
      className: json['className'] as String? ?? '',
      lessonId: json['lessonId'] as String? ?? '',
      documentId: json['documentId'] as String? ?? '',
      documentName: json['documentName'] as String? ?? '',
      gradeLabel: json['gradeLabel'] as String? ?? '',
      subjectLabel: json['subjectLabel'] as String? ?? '',
      textbookLabel: json['textbookLabel'] as String? ?? '',
      trendLabel: json['trendLabel'] as String? ?? '',
      habitTag: json['habitTag'] as String? ?? '',
      habitInsight: json['habitInsight'] as String? ?? '',
      followUpLevel: json['followUpLevel'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      scoreLabel: json['scoreLabel'] as String? ?? '',
      historyTrendLabel: json['historyTrendLabel'] as String? ?? '',
      wrongCountLabel: json['wrongCountLabel'] as String? ?? '',
      wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
      scoreRecords: _decodeList(
        json['scoreRecords'],
        (item) => StudentScoreRecord.fromJson(item),
      ),
      feedbackRecords: _decodeList(
        json['feedbackRecords'],
        (item) => StudentFeedbackRecord.fromJson(item),
      ),
      wrongQuestionRecords: _decodeList(
        json['wrongQuestionRecords'],
        (item) => StudentWrongQuestionRecord.fromJson(item),
      ),
      highlights: _decodeStringList(json['highlights']),
      nextStep: json['nextStep'] as String? ?? '',
    );
  }
}

List<T> _decodeList<T>(
  Object? raw,
  T Function(Map<String, dynamic>) mapper,
) {
  if (raw is! List) {
    return List<T>.empty(growable: false);
  }
  return raw
      .whereType<Map>()
      .map((item) => mapper(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<String> _decodeStringList(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw.whereType<String>().toList(growable: false);
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
    scoreRecords: [
      StudentScoreRecord(
        label: '函数专题周测',
        score: 86,
        totalScore: 100,
        insight: '二次函数图像题失分较多，综合压轴题表达偏保守。',
      ),
      StudentScoreRecord(
        label: '相似综合复盘',
        score: 89,
        totalScore: 100,
        insight: '证明题结构更稳定，但开放题表达还可以再展开。',
      ),
      StudentScoreRecord(
        label: '二次函数压轴卷',
        score: 92,
        totalScore: 100,
        insight: '压轴题拆解明显进步，课堂讲解后复盘效果较好。',
      ),
    ],
    feedbackRecords: [
      StudentFeedbackRecord(
        label: '周测复盘课',
        status: '已回收',
        detail: '口头讲解完整度明显提升，下一轮可以加一点开放题追问。',
      ),
      StudentFeedbackRecord(
        label: '压轴题讲义回看',
        status: '跟进中',
        detail: '证明链条已稳定，但几何综合题仍需要单独拆一次已知/求证。',
      ),
    ],
    wrongQuestionRecords: [
      StudentWrongQuestionRecord(
        label: '二次函数压轴第 23 题',
        status: '已订正',
        followUp: '下轮口头讲解时复盘证明链条完整度。',
      ),
      StudentWrongQuestionRecord(
        label: '几何综合第 18 题',
        status: '待复盘',
        followUp: '需要补一次已知/求证拆解训练。',
      ),
    ],
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
    scoreRecords: [
      StudentScoreRecord(
        label: '函数图像小测',
        score: 78,
        totalScore: 100,
        insight: '基础代入题稳定，但表格与图像联动题停顿不足。',
      ),
      StudentScoreRecord(
        label: '讲义复盘测',
        score: 69,
        totalScore: 100,
        insight: '审题过快导致条件漏看，证明链条中断明显。',
      ),
      StudentScoreRecord(
        label: '课堂追问短测',
        score: 71,
        totalScore: 100,
        insight: '分步作答开始改善，但图像信息提取仍需专项跟进。',
      ),
    ],
    feedbackRecords: [
      StudentFeedbackRecord(
        label: '讲义推进课',
        status: '已回收',
        detail: '课堂追问能跟上，但审题停顿仍然不足，需要继续强化。',
      ),
      StudentFeedbackRecord(
        label: '短测回看',
        status: '待补录',
        detail: '等随堂短测完成后，把图像信息题的回收结果回写进学生画像。',
      ),
    ],
    wrongQuestionRecords: [
      StudentWrongQuestionRecord(
        label: '函数图像第 12 题',
        status: '待订正',
        followUp: '优先补图像与表格联动的已知条件整理。',
      ),
      StudentWrongQuestionRecord(
        label: '相似证明第 19 题',
        status: '已订正',
        followUp: '课堂中继续跟进口头复述是否稳定。',
      ),
      StudentWrongQuestionRecord(
        label: '开放探究第 24 题',
        status: '待讲解',
        followUp: '下节课安排一次分步板演和口头追问。',
      ),
    ],
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
    scoreRecords: [
      StudentScoreRecord(
        label: '力学模型起始测',
        score: 81,
        totalScore: 100,
        insight: '受力分析稳定，但图像信息转化速度偏慢。',
      ),
      StudentScoreRecord(
        label: '图像辨析短练',
        score: 83,
        totalScore: 100,
        insight: '图像题识别提升，讲义边注回看开始产生效果。',
      ),
      StudentScoreRecord(
        label: '课堂反馈复盘',
        score: 84,
        totalScore: 100,
        insight: '课堂反馈和错题回看已形成闭环，适合继续稳定推进。',
      ),
    ],
    feedbackRecords: [
      StudentFeedbackRecord(
        label: '模型导入课',
        status: '已回收',
        detail: '课堂互动稳定，图像辨析反馈已经能回写到个人工作区记录里。',
      ),
      StudentFeedbackRecord(
        label: '讲义边注复盘',
        status: '跟进中',
        detail: '下一轮重点确认边注回看是否能稳定转成课后任务。',
      ),
    ],
    wrongQuestionRecords: [
      StudentWrongQuestionRecord(
        label: '力学图像第 8 题',
        status: '待回看',
        followUp: '课后结合讲义边注再做一次图像辨析。',
      ),
      StudentWrongQuestionRecord(
        label: '模型转化第 15 题',
        status: '已复盘',
        followUp: '下次课堂继续观察物理量转化是否稳定。',
      ),
    ],
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
