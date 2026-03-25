import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/class_detail_args.dart';
import '../../core/models/documents_page_args.dart';
import '../../core/models/library_page_args.dart';
import '../../core/models/lesson_detail_args.dart';
import '../../core/models/student_detail_args.dart';
import '../../core/models/classes_page_args.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';
import '../students/student_workspace_data.dart';
import 'class_workspace_data.dart';

class ClassDetailPage extends StatelessWidget {
  const ClassDetailPage({
    required this.classId,
    this.flashMessage,
    this.sourceModule,
    this.sourceRecordId,
    this.sourceLabel,
    super.key,
  });

  final String classId;
  final String? flashMessage;
  final String? sourceModule;
  final String? sourceRecordId;
  final String? sourceLabel;

  static ClassDetailPage fromArgs(ClassDetailArgs args) {
    return ClassDetailPage(
      classId: args.classId,
      flashMessage: args.flashMessage,
      sourceModule: args.sourceModule,
      sourceRecordId: args.sourceRecordId,
      sourceLabel: args.sourceLabel,
    );
  }

  void _openDocumentsWorkspace(
    BuildContext context,
    ClassWorkspaceRecord classroom, {
    String? documentId,
    String? documentLabel,
  }) {
    final targetDocumentId = documentId ?? classroom.documentId;
    final targetDocumentLabel = documentLabel ?? classroom.latestDocLabel;
    Navigator.of(context).pushNamed(
      AppRouter.documents,
      arguments: DocumentsPageArgs(
        focusDocumentId: targetDocumentId,
        flashMessage: '已定位到 $targetDocumentLabel，可继续整理班级资料。',
        highlightTitle: '当前班级资料',
        highlightDetail:
            '$targetDocumentLabel 正承接 ${classroom.name} 的资料安排，可继续补讲义、试卷和课堂节奏。',
        feedbackBadgeLabel: '班级资料',
      ),
    );
  }

  void _openLibraryWorkspace(
    BuildContext context,
    ClassWorkspaceRecord classroom,
    List<StudentWorkspaceRecord> relatedStudents,
  ) {
    final stageLabel = classroom.stageLabel.split('·').first.trim();
    final subjectLabel = relatedStudents.isNotEmpty
        ? relatedStudents.first.subjectLabel.trim()
        : '';
    Navigator.of(context).pushNamed(
      AppRouter.library,
      arguments: LibraryPageArgs(
        initialSubjectLabel: subjectLabel.isEmpty ? null : subjectLabel,
        initialStageLabel: stageLabel,
        initialTextbookLabel: classroom.textbookLabel.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTenant = AppServices.instance.activeTenant;
    final tenantScope = activeTenant == null
        ? '未选择机构'
        : activeTenant.isPersonal
            ? '个人工作区'
            : '机构工作区';
    final backLabel = switch (sourceModule) {
      'students' => '返回${sourceLabel ?? '学生详情'}',
      'lessons' => '返回${sourceLabel ?? '课堂详情'}',
      _ => '返回班级页',
    };
    final detailFuture = () async {
      if (AppConfig.useMockData) {
        final classroom = findClassWorkspaceRecord(classId);
        final relatedStudents = sampleStudentRecords
            .where((student) => student.classId == classId)
            .toList(growable: false);
        return (classroom, relatedStudents);
      }

      final classroom = await AppServices.instance.classRepository.getClass(classId);
      final relatedStudents = await AppServices.instance.studentRepository.listStudents(
        classId: classId,
      );
      return (classroom, relatedStudents);
    }();

    return FutureBuilder<(ClassWorkspaceRecord?, List<StudentWorkspaceRecord>)>(
      future: detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: WorkspaceModuleShell(
              currentModule: WorkspaceModule.classes,
              onSelectModule: (module) =>
                  navigateToWorkspaceModule(context, module),
              title: '班级详情',
              subtitle: '正在读取班级结构、资料联动与关联学生。',
              searchHint: '搜索班级名称、教材版本或课堂节奏',
              statusWidgets: [
                WorkspaceInfoPill(
                  label: '数据模式',
                  value: AppConfig.useMockData ? '样例数据' : '真实数据',
                ),
                WorkspaceInfoPill(label: '当前场景', value: tenantScope),
              ],
              body: workspaceConstrainedContent(
                context,
                child: ListView(
                  padding: workspacePagePadding(context),
                  children: const [
                    WorkspaceMessageBanner.info(
                      title: '正在加载班级详情',
                      message: '正在读取当前班级的成员分层、课堂安排和资料联动。',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final classroom = snapshot.data?.$1;
        final relatedStudents = snapshot.data?.$2 ?? const <StudentWorkspaceRecord>[];

        if (classroom == null) {
          return Scaffold(
            body: WorkspaceModuleShell(
              currentModule: WorkspaceModule.classes,
              onSelectModule: (module) =>
                  navigateToWorkspaceModule(context, module),
              title: '班级详情',
              subtitle: '当前班级不存在或尚未同步到班级列表。',
              searchHint: '搜索班级名称、教材版本或课堂节奏',
              statusWidgets: [
                WorkspaceInfoPill(
                  label: '数据模式',
                  value: AppConfig.useMockData ? '样例数据' : '真实数据',
                ),
                WorkspaceInfoPill(label: '当前场景', value: tenantScope),
              ],
              body: workspaceConstrainedContent(
                context,
                child: ListView(
                  padding: workspacePagePadding(context),
                  children: const [
                    WorkspaceMessageBanner.warning(
                      title: '未找到班级',
                      message: '这条班级档案暂时不在当前数据里，请返回班级管理页重新选择。',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: WorkspaceModuleShell(
            currentModule: WorkspaceModule.classes,
            onSelectModule: (module) => navigateToWorkspaceModule(context, module),
            title: '班级详情',
            subtitle: '围绕单个班级查看班级规模、课堂安排、资料联动与重点学生。',
            searchHint: '搜索其他班级名称、阶段目标、教材版本或当前课堂',
            statusWidgets: [
              WorkspaceInfoPill(
                label: '数据模式',
                value: AppConfig.useMockData ? '样例数据' : '真实数据',
              ),
              WorkspaceInfoPill(label: '当前场景', value: tenantScope),
              WorkspaceInfoPill(
                label: '当前机构',
                value: activeTenant?.name ?? '未选择机构',
                highlight: activeTenant == null,
              ),
            ],
            trailing: FilledButton.icon(
              onPressed: () {
                if (sourceModule == 'students' && sourceRecordId != null) {
                  Navigator.of(context).pushNamed(
                    AppRouter.studentDetail,
                    arguments: StudentDetailArgs(
                      studentId: sourceRecordId!,
                      flashMessage:
                          '已从 ${classroom.name} 返回 ${sourceLabel ?? '学生详情'}。',
                    ),
                  );
                  return;
                }
                if (sourceModule == 'lessons' && sourceRecordId != null) {
                  Navigator.of(context).pushNamed(
                    AppRouter.lessonDetail,
                    arguments: LessonDetailArgs(
                      lessonId: sourceRecordId!,
                      flashMessage:
                          '已从 ${classroom.name} 返回 ${sourceLabel ?? '课堂详情'}。',
                    ),
                  );
                  return;
                }
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRouter.classes,
                  (route) => false,
                  arguments: ClassesPageArgs(
                    focusClassId: classroom.id,
                    flashMessage: '已返回 ${classroom.name} 所在班级页，可继续回看班级结构。',
                  ),
                );
              },
              icon: const Icon(Icons.arrow_back_outlined),
              label: Text(backLabel),
            ),
            body: workspaceConstrainedContent(
              context,
              child: ListView(
                padding: workspacePagePadding(context),
                children: [
              WorkspacePanel(
                padding: workspaceHeroPanelPadding(context),
                borderRadius: 28,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showAside = constraints.maxWidth >= 980;
                    final overview = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const WorkspaceEyebrow(
                          label: '班级档案',
                          icon: Icons.groups_outlined,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          classroom.name,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: TelegramPalette.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${classroom.stageLabel} · ${classroom.teacherLabel}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          classroom.summary,
                          style: const TextStyle(
                            height: 1.55,
                            color: TelegramPalette.textStrong,
                          ),
                        ),
                        if ((flashMessage ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          WorkspaceMessageBanner.info(
                            title: '当前上下文',
                            message: flashMessage!,
                          ),
                        ],
                      ],
                    );
                    final metrics = Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        WorkspaceMetricPill(
                          label: '班级规模',
                          value: classroom.classSizeLabel,
                        ),
                        WorkspaceMetricPill(
                          label: '本周课堂',
                          value: '${classroom.weeklyLessonCount} 节',
                        ),
                        WorkspaceMetricPill(
                          label: '当前课堂',
                          value: classroom.lessonFocusLabel,
                        ),
                        WorkspaceMetricPill(
                          label: '最近资料',
                          value: classroom.latestDocLabel,
                        ),
                      ],
                    );
                    if (!showAside) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          overview,
                          const SizedBox(height: 18),
                          metrics,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: overview),
                        const SizedBox(width: 18),
                        SizedBox(width: 320, child: metrics),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final showAside = constraints.maxWidth >= 1120;
                  final main = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WorkspacePanel(
                        padding: workspacePanelPadding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '班级结构与重点',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            WorkspaceMessageBanner.info(
                              title: '结构洞察',
                              message: classroom.structureInsight,
                            ),
                            const SizedBox(height: 16),
                            ...classroom.highlights.map(
                              (point) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: WorkspaceBulletPoint(text: point),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (relatedStudents.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        WorkspacePanel(
                          padding: workspacePanelPadding(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '重点学生',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: TelegramPalette.text,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...relatedStudents.map(
                                (student) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: TelegramPalette.surfaceRaised,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: TelegramPalette.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          TelegramPalette.text,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    student.summary,
                                                    style: const TextStyle(
                                                      height: 1.5,
                                                      color: TelegramPalette
                                                          .textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            WorkspaceMetricPill(
                                              label: '当前成绩',
                                              value: student.scoreLabel,
                                              highlight: student.followUpLevel
                                                  .contains(
                                                '重点',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            WorkspaceInfoPill(
                                              label: '趋势',
                                              value: student.historyTrendLabel,
                                            ),
                                            WorkspaceInfoPill(
                                              label: '错题',
                                              value: student.wrongCountLabel,
                                            ),
                                            WorkspaceInfoPill(
                                              label: '跟进级别',
                                              value: student.followUpLevel,
                                              highlight: student.followUpLevel
                                                  .contains(
                                                '重点',
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                Navigator.of(context).pushNamed(
                                                  AppRouter.studentDetail,
                                                  arguments: StudentDetailArgs(
                                                    studentId: student.id,
                                                    flashMessage:
                                                        '已从 ${classroom.name} 的重点学生区进入 ${student.name}，可继续回看学生画像。',
                                                    sourceModule: 'classes',
                                                    sourceRecordId:
                                                        classroom.id,
                                                    sourceLabel: classroom.name,
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.school_outlined,
                                                size: 18,
                                              ),
                                              label: Text(
                                                '查看${student.name}详情',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (classroom.assetLinks.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        WorkspacePanel(
                          padding: workspacePanelPadding(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '资料联动',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: TelegramPalette.text,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...classroom.assetLinks.map(
                                (asset) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: TelegramPalette.surfaceRaised,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: TelegramPalette.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    asset.documentLabel,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          TelegramPalette.text,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    asset.detail,
                                                    style: const TextStyle(
                                                      height: 1.5,
                                                      color: TelegramPalette
                                                          .textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            WorkspaceMetricPill(
                                              label: asset.label,
                                              value: asset.statusLabel,
                                              highlight: asset.statusLabel
                                                  .contains('待'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            WorkspaceInfoPill(
                                              label: '当前班级',
                                              value: classroom.name,
                                            ),
                                            WorkspaceInfoPill(
                                              label: '关联课堂',
                                              value: classroom.lessonFocusLabel,
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                _openDocumentsWorkspace(
                                                  context,
                                                  classroom,
                                                  documentId: asset.documentId,
                                                  documentLabel:
                                                      asset.documentLabel,
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.description_outlined,
                                                size: 18,
                                              ),
                                              label: Text(
                                                '打开${asset.documentLabel}',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      WorkspacePanel(
                        padding: workspacePanelPadding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '课堂时间线',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...classroom.lessonTimeline.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: TelegramPalette.surfaceRaised,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: TelegramPalette.border,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              entry.label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: TelegramPalette.text,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          WorkspaceMetricPill(
                                            label: '安排',
                                            value: entry.scheduleLabel,
                                            highlight: entry.scheduleLabel
                                                .contains('进行中'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        entry.focus,
                                        style: const TextStyle(
                                          height: 1.5,
                                          color: TelegramPalette.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          WorkspaceInfoPill(
                                            label: '状态',
                                            value: entry.statusLabel,
                                          ),
                                          WorkspaceInfoPill(
                                            label: '关联课堂',
                                            value: classroom.lessonFocusLabel,
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).pushNamed(
                                                AppRouter.lessonDetail,
                                                arguments: LessonDetailArgs(
                                                  lessonId: entry.lessonId,
                                                  flashMessage:
                                                      '已从 ${classroom.name} 的课堂时间线进入 ${entry.label}，可继续回看课堂资料与反馈。',
                                                  sourceModule: 'classes',
                                                  sourceRecordId: classroom.id,
                                                  sourceLabel: classroom.name,
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.open_in_new_outlined,
                                              size: 18,
                                            ),
                                            label: Text(entry.actionLabel),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      WorkspacePanel(
                        padding: workspacePanelPadding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '成员分层',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...classroom.memberTiers.map(
                              (tier) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: TelegramPalette.surfaceRaised,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: TelegramPalette.border,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tier.label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: TelegramPalette.text,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              tier.focus,
                                              style: const TextStyle(
                                                height: 1.5,
                                                color:
                                                    TelegramPalette.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      WorkspaceMetricPill(
                                        label: '人数',
                                        value: '${tier.studentCount} 人',
                                        highlight: tier.label.contains('跟进'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      WorkspacePanel(
                        padding: workspacePanelPadding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '后续动作',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            WorkspaceMessageBanner.info(
                              title: '下一步',
                              message: classroom.nextStep,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.studentDetail,
                                      arguments: StudentDetailArgs(
                                        studentId: classroom.focusStudentId,
                                        flashMessage:
                                            '已从 ${classroom.name} 的班级档案进入 ${classroom.focusStudentName}，可继续回看学生画像。',
                                        sourceModule: 'classes',
                                        sourceRecordId: classroom.id,
                                        sourceLabel: classroom.name,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.school_outlined,
                                      size: 18),
                                  label:
                                      Text('查看${classroom.focusStudentName}详情'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.lessonDetail,
                                      arguments: LessonDetailArgs(
                                        lessonId: classroom.lessonId,
                                        flashMessage:
                                            '已从 ${classroom.name} 的班级档案进入 ${classroom.lessonFocusLabel}，可继续回看课堂资料与反馈。',
                                        sourceModule: 'classes',
                                        sourceRecordId: classroom.id,
                                        sourceLabel: classroom.name,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.schedule_outlined,
                                      size: 18),
                                  label:
                                      Text('查看${classroom.lessonFocusLabel}详情'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _openDocumentsWorkspace(context, classroom);
                                  },
                                  icon: const Icon(Icons.description_outlined,
                                      size: 18),
                                  label: Text('打开${classroom.latestDocLabel}'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final aside = WorkspacePanel(
                    padding: workspacePanelPadding(context),
                    backgroundColor: TelegramPalette.surfaceAccent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '当前摘要',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: TelegramPalette.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            WorkspaceInfoPill(
                              label: '阶段',
                              value: classroom.stageLabel,
                            ),
                            WorkspaceInfoPill(
                              label: '重点学生',
                              value: classroom.focusStudentName,
                            ),
                            WorkspaceInfoPill(
                              label: '当前课堂',
                              value: classroom.lessonFocusLabel,
                            ),
                            WorkspaceInfoPill(
                              label: '资料',
                              value: classroom.latestDocLabel,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '关联对象',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TelegramPalette.textStrong,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRouter.studentDetail,
                                  arguments: StudentDetailArgs(
                                    studentId: classroom.focusStudentId,
                                    flashMessage:
                                        '已从 ${classroom.name} 的班级档案进入 ${classroom.focusStudentName}，可继续回看学生画像。',
                                    sourceModule: 'classes',
                                    sourceRecordId: classroom.id,
                                    sourceLabel: classroom.name,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.school_outlined, size: 18),
                              label: Text(classroom.focusStudentName),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRouter.lessonDetail,
                                  arguments: LessonDetailArgs(
                                    lessonId: classroom.lessonId,
                                    flashMessage:
                                        '已从 ${classroom.name} 的班级档案进入 ${classroom.lessonFocusLabel}，可继续回看课堂资料与反馈。',
                                    sourceModule: 'classes',
                                    sourceRecordId: classroom.id,
                                    sourceLabel: classroom.name,
                                  ),
                                );
                              },
                              icon:
                                  const Icon(Icons.schedule_outlined, size: 18),
                              label: Text(classroom.lessonFocusLabel),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                _openDocumentsWorkspace(context, classroom);
                              },
                              icon: const Icon(Icons.description_outlined,
                                  size: 18),
                              label: Text(classroom.latestDocLabel),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                _openLibraryWorkspace(
                                  context,
                                  classroom,
                                  relatedStudents,
                                );
                              },
                              icon: const Icon(Icons.search_outlined, size: 18),
                              label: const Text('关联题库'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                  if (!showAside) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        aside,
                        const SizedBox(height: 16),
                        main,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: main),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: aside),
                    ],
                  );
                },
              ),
            ],
          ),
            ),
          ),
        );
      },
    );
  }
}
