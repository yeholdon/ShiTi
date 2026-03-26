class LessonFeedbackRecord {
  const LessonFeedbackRecord({
    required this.label,
    required this.status,
    required this.detail,
  });

  final String label;
  final String status;
  final String detail;

  factory LessonFeedbackRecord.fromJson(Map<String, dynamic> json) {
    return LessonFeedbackRecord(
      label: json['label']?.toString() ?? '未命名反馈项',
      status: json['status']?.toString() ?? '待处理',
      detail: json['detail']?.toString() ?? '',
    );
  }
}

class LessonAssetRecord {
  const LessonAssetRecord({
    required this.label,
    required this.kindLabel,
    required this.statusLabel,
    required this.detail,
    required this.documentId,
    required this.actionLabel,
  });

  final String label;
  final String kindLabel;
  final String statusLabel;
  final String detail;
  final String documentId;
  final String actionLabel;

  factory LessonAssetRecord.fromJson(Map<String, dynamic> json) {
    return LessonAssetRecord(
      label: json['label']?.toString() ?? '未命名资料',
      kindLabel: json['kindLabel']?.toString() ?? '资料',
      statusLabel: json['statusLabel']?.toString() ?? '待处理',
      detail: json['detail']?.toString() ?? '',
      documentId: json['documentId']?.toString() ?? '',
      actionLabel: json['actionLabel']?.toString() ?? '查看资料详情',
    );
  }
}

class LessonTaskRecord {
  const LessonTaskRecord({
    required this.label,
    required this.ownerLabel,
    required this.statusLabel,
    required this.detail,
    required this.targetModule,
    required this.targetRecordId,
    required this.targetLabel,
    required this.actionLabel,
  });

  final String label;
  final String ownerLabel;
  final String statusLabel;
  final String detail;
  final String targetModule;
  final String targetRecordId;
  final String targetLabel;
  final String actionLabel;

  factory LessonTaskRecord.fromJson(Map<String, dynamic> json) {
    return LessonTaskRecord(
      label: json['label']?.toString() ?? '未命名任务',
      ownerLabel: json['ownerLabel']?.toString() ?? '待分配',
      statusLabel: json['statusLabel']?.toString() ?? '待处理',
      detail: json['detail']?.toString() ?? '',
      targetModule: json['targetModule']?.toString() ?? '',
      targetRecordId: json['targetRecordId']?.toString() ?? '',
      targetLabel: json['targetLabel']?.toString() ?? '',
      actionLabel: json['actionLabel']?.toString() ?? '查看详情',
    );
  }
}

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
    required this.feedbackRecords,
    required this.assetRecords,
    required this.taskRecords,
    required this.summary,
    required this.highlights,
    required this.nextStep,
    this.archivedAt,
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
  final List<LessonFeedbackRecord> feedbackRecords;
  final List<LessonAssetRecord> assetRecords;
  final List<LessonTaskRecord> taskRecords;
  final String summary;
  final List<String> highlights;
  final String nextStep;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  factory LessonWorkspaceRecord.fromJson(Map<String, dynamic> json) {
    return LessonWorkspaceRecord(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '未命名课堂',
      classId: json['classId']?.toString() ?? '',
      className: json['className']?.toString() ?? '未绑定班级',
      focusStudentId: json['focusStudentId']?.toString() ?? '',
      focusStudentName: json['focusStudentName']?.toString() ?? '未指定学生',
      teacherLabel: json['teacherLabel']?.toString() ?? '主讲待定',
      scheduleLabel: json['scheduleLabel']?.toString() ?? '未排时间',
      scheduleTag: json['scheduleTag']?.toString() ?? '待安排',
      classScopeLabel: json['classScopeLabel']?.toString() ?? '未绑定班级',
      documentFocus: json['documentFocus']?.toString() ?? '未绑定资料',
      documentId: json['documentId']?.toString() ?? '',
      feedbackStatus: json['feedbackStatus']?.toString() ?? '待回收',
      followUpLabel: json['followUpLabel']?.toString() ?? '待处理',
      feedbackInsight: json['feedbackInsight']?.toString() ?? '',
      feedbackRecords: _decodeLessonList<LessonFeedbackRecord>(
        json['feedbackRecords'],
        (item) => LessonFeedbackRecord.fromJson(item),
      ),
      assetRecords: _decodeLessonList<LessonAssetRecord>(
        json['assetRecords'],
        (item) => LessonAssetRecord.fromJson(item),
      ),
      taskRecords: _decodeLessonList<LessonTaskRecord>(
        json['taskRecords'],
        (item) => LessonTaskRecord.fromJson(item),
      ),
      summary: json['summary']?.toString() ?? '',
      highlights: _decodeLessonStringList(json['highlights']),
      nextStep: json['nextStep']?.toString() ?? '',
      archivedAt: _decodeLessonDateTime(json['archivedAt']),
    );
  }
}

DateTime? _decodeLessonDateTime(Object? raw) {
  if (raw is! String || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
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
    feedbackRecords: [
      LessonFeedbackRecord(
        label: '口头讲解回收',
        status: '待回收',
        detail: '需要回收 5 名重点学生的压轴题口头讲解录入。',
      ),
      LessonFeedbackRecord(
        label: '错题订正',
        status: '部分完成',
        detail: '当前已收回一半订正稿，仍需补齐函数压轴题订正。',
      ),
      LessonFeedbackRecord(
        label: '课堂参与',
        status: '待整理',
        detail: '课堂追问记录已在教师侧完成，待沉淀到学生画像。',
      ),
    ],
    assetRecords: [
      LessonAssetRecord(
        label: '二次函数周测卷',
        kindLabel: '试卷',
        statusLabel: '已上课',
        detail: '本节课堂先用周测卷复盘，定位压轴题表达链条。',
        documentId: 'doc-2',
        actionLabel: '查看试卷详情',
      ),
      LessonAssetRecord(
        label: '压轴题拆解讲义',
        kindLabel: '讲义',
        statusLabel: '待补充',
        detail: '需要补一页压轴题拆解讲义，承接课后复盘和下节专题课。',
        documentId: 'doc-2',
        actionLabel: '查看讲义详情',
      ),
    ],
    taskRecords: [
      LessonTaskRecord(
        label: '回收 5 名重点学生口头讲解',
        ownerLabel: '课堂记录',
        statusLabel: '待处理',
        detail: '先补齐重点学生口头讲解，再回写到学生画像。',
        targetModule: 'students',
        targetRecordId: 'student-1',
        targetLabel: '林之涵',
        actionLabel: '查看学生详情',
      ),
      LessonTaskRecord(
        label: '整理函数压轴题订正稿',
        ownerLabel: '课后任务',
        statusLabel: '进行中',
        detail: '已收回一半订正稿，剩余部分需要在晚自习后补齐。',
        targetModule: 'documents',
        targetRecordId: 'doc-2',
        targetLabel: '二次函数周测卷',
        actionLabel: '查看资料详情',
      ),
    ],
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
    feedbackRecords: [
      LessonFeedbackRecord(
        label: '讲义反馈',
        status: '已收齐',
        detail: '课堂追问和板书提示反馈已经整理完成。',
      ),
      LessonFeedbackRecord(
        label: '短测结果',
        status: '待沉淀',
        detail: '分层短测已完成，待回写到班级分层任务。',
      ),
      LessonFeedbackRecord(
        label: '课堂追问',
        status: '已整理',
        detail: '高频卡点已提炼，可直接回流到下轮讲义。',
      ),
    ],
    assetRecords: [
      LessonAssetRecord(
        label: '相似三角形讲义',
        kindLabel: '讲义',
        statusLabel: '已使用',
        detail: '讲义版式和例题顺序已稳定，可直接承接短测回看。',
        documentId: 'doc-1',
        actionLabel: '查看讲义详情',
      ),
      LessonAssetRecord(
        label: '相似三角形短测卷',
        kindLabel: '试卷',
        statusLabel: '待排版',
        detail: '短测卷还要补齐两道层级题，再进入周末班级复盘。',
        documentId: 'doc-1',
        actionLabel: '查看试卷详情',
      ),
    ],
    taskRecords: [
      LessonTaskRecord(
        label: '沉淀讲义反馈到班级分层',
        ownerLabel: '班级跟进',
        statusLabel: '待处理',
        detail: '需要把课堂追问中的高频卡点拆回提优层和跟进层。',
        targetModule: 'classes',
        targetRecordId: 'class-2',
        targetLabel: '九年级提高班',
        actionLabel: '查看班级详情',
      ),
      LessonTaskRecord(
        label: '补周末短测卷',
        ownerLabel: '资料准备',
        statusLabel: '待开始',
        detail: '按本节课讲义重点补一份短测卷，验证分层效果。',
        targetModule: 'documents',
        targetRecordId: 'doc-1',
        targetLabel: '相似三角形讲义',
        actionLabel: '查看资料详情',
      ),
    ],
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
    feedbackRecords: [
      LessonFeedbackRecord(
        label: '图像题反馈',
        status: '待回收',
        detail: '需要重点确认学生对图像辨析段落的理解情况。',
      ),
      LessonFeedbackRecord(
        label: '资料清晰度',
        status: '待确认',
        detail: '讲义图示还在排版，课堂后需确认图示是否足够清晰。',
      ),
      LessonFeedbackRecord(
        label: '模型识别',
        status: '样例跟进',
        detail: '本节先跑样例课堂，验证反馈能否回流到个人工作区。',
      ),
    ],
    assetRecords: [
      LessonAssetRecord(
        label: '力学模型讲义',
        kindLabel: '讲义',
        statusLabel: '排版中',
        detail: '图示和板书提示还在微调，课堂前需要完成最终导出。',
        documentId: 'doc-1',
        actionLabel: '查看讲义详情',
      ),
      LessonAssetRecord(
        label: '图像辨析短练',
        kindLabel: '练习',
        statusLabel: '待创建',
        detail: '计划在课堂后段使用，帮助收图像信息提取反馈。',
        documentId: 'doc-1',
        actionLabel: '查看资料详情',
      ),
    ],
    taskRecords: [
      LessonTaskRecord(
        label: '确认讲义图示清晰度',
        ownerLabel: '资料复核',
        statusLabel: '待确认',
        detail: '课堂后需要确认讲义图示是否足够清晰，决定是否追加重排版。',
        targetModule: 'documents',
        targetRecordId: 'doc-1',
        targetLabel: '力学模型讲义',
        actionLabel: '查看资料详情',
      ),
      LessonTaskRecord(
        label: '回写模型识别反馈',
        ownerLabel: '个人工作区',
        statusLabel: '样例跟进',
        detail: '把课堂里采到的模型识别反馈先回流到个人工作区样例链路。',
        targetModule: 'students',
        targetRecordId: 'student-3',
        targetLabel: '陈嘉言',
        actionLabel: '查看学生详情',
      ),
    ],
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

List<T> _decodeLessonList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) decoder,
) {
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map((item) => decoder(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<String> _decodeLessonStringList(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  return raw.map((item) => item.toString()).toList(growable: false);
}
