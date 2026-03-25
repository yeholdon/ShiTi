import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/class_detail_args.dart';
import '../../core/models/documents_page_args.dart';
import '../../core/models/library_page_args.dart';
import '../../core/models/lesson_detail_args.dart';
import '../../core/models/lessons_page_args.dart';
import '../../core/models/student_detail_args.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';
import '../students/student_workspace_data.dart';
import 'lesson_workspace_data.dart';

class LessonDetailPage extends StatelessWidget {
  const LessonDetailPage({
    required this.lessonId,
    this.flashMessage,
    this.sourceModule,
    this.sourceRecordId,
    this.sourceLabel,
    super.key,
  });

  final String lessonId;
  final String? flashMessage;
  final String? sourceModule;
  final String? sourceRecordId;
  final String? sourceLabel;

  static LessonDetailPage fromArgs(LessonDetailArgs args) {
    return LessonDetailPage(
      lessonId: args.lessonId,
      flashMessage: args.flashMessage,
      sourceModule: args.sourceModule,
      sourceRecordId: args.sourceRecordId,
      sourceLabel: args.sourceLabel,
    );
  }

  void _openTaskTarget(
    BuildContext context,
    LessonWorkspaceRecord lesson,
    LessonTaskRecord task,
  ) {
    switch (task.targetModule) {
      case 'students':
        Navigator.of(context).pushNamed(
          AppRouter.studentDetail,
          arguments: StudentDetailArgs(
            studentId: task.targetRecordId,
            flashMessage:
                '已从 ${lesson.title} 的任务清单进入 ${task.targetLabel}，可继续回看学生反馈。',
            sourceModule: 'lessons',
            sourceRecordId: lesson.id,
            sourceLabel: lesson.title,
          ),
        );
        return;
      case 'classes':
        Navigator.of(context).pushNamed(
          AppRouter.classDetail,
          arguments: ClassDetailArgs(
            classId: task.targetRecordId,
            flashMessage:
                '已从 ${lesson.title} 的任务清单进入 ${task.targetLabel}，可继续回看班级安排。',
            sourceModule: 'lessons',
            sourceRecordId: lesson.id,
            sourceLabel: lesson.title,
          ),
        );
        return;
      case 'documents':
        _openDocumentsWorkspace(
          context,
          lesson,
          documentId: task.targetRecordId,
          documentLabel: task.targetLabel,
        );
        return;
    }
  }

  void _openDocumentsWorkspace(
    BuildContext context,
    LessonWorkspaceRecord lesson, {
    String? documentId,
    String? documentLabel,
  }) {
    final targetDocumentId = documentId ?? lesson.documentId;
    final targetDocumentLabel = documentLabel ?? lesson.documentFocus;
    Navigator.of(context).pushNamed(
      AppRouter.documents,
      arguments: DocumentsPageArgs(
        focusDocumentId: targetDocumentId,
        flashMessage: '已定位到 $targetDocumentLabel，可继续整理这节课使用的资料。',
        highlightTitle: '当前课堂资料',
        highlightDetail:
            '$targetDocumentLabel 正承接 ${lesson.title} 的主资料，可继续调整课堂资料与反馈回收。',
        feedbackBadgeLabel: '课堂资料',
      ),
    );
  }

  void _openLibraryWorkspace(
    BuildContext context,
    LessonWorkspaceRecord lesson,
    List<StudentWorkspaceRecord> relatedStudents,
  ) {
    final referenceStudent =
        relatedStudents.isNotEmpty ? relatedStudents.first : null;
    final stageLabel = referenceStudent?.gradeLabel.split('·').first.trim();
    final subjectLabel = referenceStudent?.subjectLabel.trim();
    final textbookLabel = referenceStudent?.textbookLabel.trim();
    Navigator.of(context).pushNamed(
      AppRouter.library,
      arguments: LibraryPageArgs(
        initialSubjectLabel:
            (subjectLabel?.isNotEmpty ?? false) ? subjectLabel : null,
        initialStageLabel:
            (stageLabel?.isNotEmpty ?? false) ? stageLabel : null,
        initialTextbookLabel:
            (textbookLabel?.isNotEmpty ?? false) ? textbookLabel : null,
        initialQuery: lesson.title,
        flashMessage: '已定位到 ${lesson.title} 的题库上下文，可继续按当前课堂筛题。',
        highlightTitle: '当前课堂题库上下文',
        highlightDetail:
            '${lesson.title} 的课堂主题和关联学生条件已带入题库，可继续筛题、入篮或送入文档。',
        feedbackBadgeLabel: '课堂筛题',
        sourceModule: 'lesson_detail',
        sourceRecordId: lesson.id,
        sourceLabel: lesson.title,
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
      'classes' => '返回${sourceLabel ?? '班级详情'}',
      _ => '返回课堂页',
    };
    final detailFuture = () async {
      if (AppConfig.useMockData) {
        final lesson = findLessonWorkspaceRecord(lessonId);
        final relatedStudents = sampleStudentRecords
            .where((student) => student.lessonId == lessonId)
            .toList(growable: false);
        return (lesson, relatedStudents);
      }

      final lesson = await AppServices.instance.lessonRepository.getLesson(lessonId);
      final relatedStudents = await AppServices.instance.studentRepository.listStudents(
        lessonId: lessonId,
      );
      return (lesson, relatedStudents);
    }();

    return FutureBuilder<(LessonWorkspaceRecord?, List<StudentWorkspaceRecord>)>(
      future: detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: WorkspaceModuleShell(
              currentModule: WorkspaceModule.lessons,
              onSelectModule: (module) =>
                  navigateToWorkspaceModule(context, module),
              title: '课堂详情',
              subtitle: '正在读取课堂资料、反馈明细与后续任务。',
              searchHint: '搜索课堂主题、班级、资料或课后反馈',
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
                      title: '正在加载课堂详情',
                      message: '正在读取当前课堂的资料、反馈和任务数据。',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final lesson = snapshot.data?.$1;
        final relatedStudents =
            snapshot.data?.$2 ?? const <StudentWorkspaceRecord>[];

        if (lesson == null) {
          return Scaffold(
            body: WorkspaceModuleShell(
              currentModule: WorkspaceModule.lessons,
              onSelectModule: (module) =>
                  navigateToWorkspaceModule(context, module),
              title: '课堂详情',
              subtitle: '当前课堂不存在或尚未同步到课堂列表。',
              searchHint: '搜索课堂主题、班级、资料或课后反馈',
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
                      title: '未找到课堂',
                      message: '这节课堂暂时不在当前数据里，请返回课堂管理页重新选择。',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: WorkspaceModuleShell(
            currentModule: WorkspaceModule.lessons,
            onSelectModule: (module) => navigateToWorkspaceModule(context, module),
            title: '课堂详情',
            subtitle: '围绕单个课堂查看班级安排、主资料、课后反馈与后续任务。',
            searchHint: '搜索其他课堂主题、班级、资料或反馈节奏',
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
                          '已从 ${lesson.title} 返回 ${sourceLabel ?? '学生详情'}。',
                    ),
                  );
                  return;
                }
                if (sourceModule == 'classes' && sourceRecordId != null) {
                  Navigator.of(context).pushNamed(
                    AppRouter.classDetail,
                    arguments: ClassDetailArgs(
                      classId: sourceRecordId!,
                      flashMessage:
                          '已从 ${lesson.title} 返回 ${sourceLabel ?? '班级详情'}。',
                    ),
                  );
                  return;
                }
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRouter.lessons,
                  (route) => false,
                  arguments: LessonsPageArgs(
                    focusLessonId: lesson.id,
                    flashMessage: '已返回 ${lesson.title} 所在课堂页，可继续回看课堂节奏。',
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
                          label: '课堂档案',
                          icon: Icons.schedule_outlined,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          lesson.title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: TelegramPalette.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${lesson.className} · ${lesson.scheduleLabel} · ${lesson.teacherLabel}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lesson.summary,
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
                          label: '课堂状态',
                          value: lesson.scheduleTag,
                        ),
                        WorkspaceMetricPill(
                          label: '主资料',
                          value: lesson.documentFocus,
                        ),
                        WorkspaceMetricPill(
                          label: '反馈状态',
                          value: lesson.feedbackStatus,
                          highlight: lesson.feedbackStatus == '待回收',
                        ),
                        WorkspaceMetricPill(
                          label: '课后任务',
                          value: lesson.followUpLabel,
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
                              '课堂反馈与重点',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            WorkspaceMessageBanner.warning(
                              title: '反馈回收',
                              message: lesson.feedbackInsight,
                            ),
                            const SizedBox(height: 16),
                            ...lesson.highlights.map(
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
                                '反馈学生',
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
                                                        '已从 ${lesson.title} 的反馈学生区进入 ${student.name}，可继续回看学生反馈。',
                                                    sourceModule: 'lessons',
                                                    sourceRecordId: lesson.id,
                                                    sourceLabel: lesson.title,
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
                      const SizedBox(height: 16),
                      WorkspacePanel(
                        padding: workspacePanelPadding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '资料清单',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...lesson.assetRecords.map(
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
                                            child: Text(
                                              asset.label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: TelegramPalette.text,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          WorkspaceMetricPill(
                                            label: asset.kindLabel,
                                            value: asset.statusLabel,
                                            highlight:
                                                asset.statusLabel.contains('待'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        asset.detail,
                                        style: const TextStyle(
                                          height: 1.5,
                                          color: TelegramPalette.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          _openDocumentsWorkspace(
                                            context,
                                            lesson,
                                            documentId: asset.documentId,
                                            documentLabel: asset.label,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.description_outlined,
                                          size: 18,
                                        ),
                                        label: Text(asset.actionLabel),
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
                              '任务清单',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...lesson.taskRecords.map(
                              (task) => Padding(
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
                                              task.label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: TelegramPalette.text,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          WorkspaceMetricPill(
                                            label: '状态',
                                            value: task.statusLabel,
                                            highlight:
                                                task.statusLabel.contains('待'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        task.detail,
                                        style: const TextStyle(
                                          height: 1.5,
                                          color: TelegramPalette.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      WorkspaceInfoPill(
                                        label: '责任归属',
                                        value: task.ownerLabel,
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: () => _openTaskTarget(
                                            context, lesson, task),
                                        icon: const Icon(
                                          Icons.open_in_new_outlined,
                                          size: 18,
                                        ),
                                        label: Text(task.actionLabel),
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
                              '反馈明细',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...lesson.feedbackRecords.map(
                              (record) => Padding(
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
                                              record.label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: TelegramPalette.text,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              record.detail,
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
                                        label: '状态',
                                        value: record.status,
                                        highlight: record.status.contains('待'),
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
                              message: lesson.nextStep,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.classDetail,
                                      arguments: ClassDetailArgs(
                                        classId: lesson.classId,
                                        flashMessage:
                                            '已从 ${lesson.title} 的课堂档案进入 ${lesson.classScopeLabel}，可继续回看班级安排。',
                                        sourceModule: 'lessons',
                                        sourceRecordId: lesson.id,
                                        sourceLabel: lesson.title,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.groups_outlined,
                                      size: 18),
                                  label: Text('查看${lesson.classScopeLabel}详情'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.studentDetail,
                                      arguments: StudentDetailArgs(
                                        studentId: lesson.focusStudentId,
                                        flashMessage:
                                            '已从 ${lesson.title} 的课堂档案进入 ${lesson.focusStudentName}，可继续回看学生反馈。',
                                        sourceModule: 'lessons',
                                        sourceRecordId: lesson.id,
                                        sourceLabel: lesson.title,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.school_outlined,
                                      size: 18),
                                  label: Text('查看${lesson.focusStudentName}详情'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _openDocumentsWorkspace(context, lesson);
                                  },
                                  icon: const Icon(Icons.description_outlined,
                                      size: 18),
                                  label: Text('打开${lesson.documentFocus}'),
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
                              label: '班级',
                              value: lesson.classScopeLabel,
                            ),
                            WorkspaceInfoPill(
                              label: '主资料',
                              value: lesson.documentFocus,
                            ),
                            WorkspaceInfoPill(
                              label: '反馈学生',
                              value: lesson.focusStudentName,
                            ),
                            WorkspaceInfoPill(
                              label: '课后任务',
                              value: lesson.followUpLabel,
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
                                  AppRouter.classDetail,
                                  arguments: ClassDetailArgs(
                                    classId: lesson.classId,
                                    flashMessage:
                                        '已从 ${lesson.title} 的课堂档案进入 ${lesson.classScopeLabel}，可继续回看班级安排。',
                                    sourceModule: 'lessons',
                                    sourceRecordId: lesson.id,
                                    sourceLabel: lesson.title,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.groups_outlined, size: 18),
                              label: Text(lesson.classScopeLabel),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRouter.studentDetail,
                                  arguments: StudentDetailArgs(
                                    studentId: lesson.focusStudentId,
                                    flashMessage:
                                        '已从 ${lesson.title} 的课堂档案进入 ${lesson.focusStudentName}，可继续回看学生反馈。',
                                    sourceModule: 'lessons',
                                    sourceRecordId: lesson.id,
                                    sourceLabel: lesson.title,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.school_outlined, size: 18),
                              label: Text(lesson.focusStudentName),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                _openDocumentsWorkspace(context, lesson);
                              },
                              icon: const Icon(Icons.description_outlined,
                                  size: 18),
                              label: Text(lesson.documentFocus),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                _openLibraryWorkspace(
                                  context,
                                  lesson,
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
