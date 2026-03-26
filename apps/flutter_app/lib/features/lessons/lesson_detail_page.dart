import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/class_detail_args.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/documents_page_args.dart';
import '../../core/models/library_page_args.dart';
import '../../core/models/lesson_detail_args.dart';
import '../../core/models/lessons_page_args.dart';
import '../../core/models/student_detail_args.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';
import '../classes/class_workspace_data.dart';
import 'edit_lesson_dialog.dart';
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
        sourceModule: 'lesson_detail',
        sourceRecordId: lesson.id,
        sourceLabel: lesson.title,
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

  Future<void> _editLesson(
    BuildContext context,
    LessonWorkspaceRecord lesson,
  ) async {
    final updated = await showEditLessonDialog(context, lesson: lesson);
    if (!context.mounted || updated == null) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      AppRouter.lessonDetail,
      arguments: LessonDetailArgs(
        lessonId: updated.id,
        flashMessage: '已更新 ${updated.title} 的课堂档案。',
        sourceModule: sourceModule,
        sourceRecordId: sourceRecordId,
        sourceLabel: sourceLabel,
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(
    BuildContext context,
    LessonWorkspaceRecord lesson,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: WorkspacePanel(
            borderRadius: 28,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '删除课堂档案',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '确认后会从当前机构里移除 ${lesson.title} 的课堂档案。资料清单、反馈明细和课后任务也会一起失去这条入口。',
                  style: const TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                const WorkspaceMessageBanner.warning(
                  title: '此操作不可恢复',
                  message: '如果只是暂时不继续维护，建议先保留课堂档案，避免丢失历史反馈和资料记录。',
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: TelegramPalette.errorText,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('确认删除'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteLesson(
    BuildContext context,
    LessonWorkspaceRecord lesson,
  ) async {
    final confirmed = await _showDeleteConfirmDialog(context, lesson);
    if (!context.mounted || confirmed != true) {
      return;
    }

    try {
      await AppServices.instance.lessonRepository.deleteLesson(lesson.id);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.lessons,
        (route) => false,
        arguments: const LessonsPageArgs(
          flashMessage: '已删除课堂档案，可继续回看其他课堂节奏。',
        ),
      );
    } on HttpJsonException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除课堂失败：${error.message}（HTTP ${error.statusCode}）')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除课堂失败：$error')),
      );
    }
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
        if (lesson == null) {
          return (null, const <StudentWorkspaceRecord>[], null, null);
        }
        final relatedStudents = sampleStudentRecords
            .where((student) => student.lessonId == lessonId)
            .toList(growable: false);
        return (
          lesson,
          relatedStudents,
          findClassWorkspaceRecord(lesson.classId),
          null,
        );
      }

      final lesson = await AppServices.instance.lessonRepository.getLesson(lessonId);
      if (lesson == null) {
        return (null, const <StudentWorkspaceRecord>[], null, null);
      }
      final results = await Future.wait([
        AppServices.instance.studentRepository.listStudents(lessonId: lessonId),
        AppServices.instance.classRepository.listClasses(lessonId: lessonId),
        lesson.documentId.trim().isEmpty
            ? Future<DocumentSummary?>.value(null)
            : AppServices.instance.documentRepository.getDocument(lesson.documentId),
      ]);
      final relatedStudents = results[0] as List<StudentWorkspaceRecord>;
      final relatedClasses = results[1] as List<ClassWorkspaceRecord>;
      return (
        lesson,
        relatedStudents,
        relatedClasses.isEmpty ? null : relatedClasses.first,
        results[2] as DocumentSummary?,
      );
    }();

    return FutureBuilder<
      (
        LessonWorkspaceRecord?,
        List<StudentWorkspaceRecord>,
        ClassWorkspaceRecord?,
        DocumentSummary?,
      )
    >(
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
        final relatedClass = snapshot.data?.$3;
        final relatedDocument = snapshot.data?.$4;

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

        final currentClassId = relatedClass?.id ?? lesson.classId;
        final currentClassLabel = relatedClass?.name ?? lesson.classScopeLabel;
        final currentDocumentId = relatedDocument?.id ?? lesson.documentId;
        final currentDocumentLabel =
            relatedDocument?.name ?? lesson.documentFocus;

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
            trailing: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _editLesson(context, lesson),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑档案'),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: TelegramPalette.errorText,
                  ),
                  onPressed: () => _deleteLesson(context, lesson),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除档案'),
                ),
                FilledButton.icon(
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
              ],
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
                          '$currentClassLabel · ${lesson.scheduleLabel} · ${lesson.teacherLabel}',
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
                          value: currentDocumentLabel,
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
                                        classId: currentClassId,
                                        flashMessage:
                                            '已从 ${lesson.title} 的课堂档案进入 $currentClassLabel，可继续回看班级安排。',
                                        sourceModule: 'lessons',
                                        sourceRecordId: lesson.id,
                                        sourceLabel: lesson.title,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.groups_outlined,
                                      size: 18),
                                  label: Text('查看$currentClassLabel详情'),
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
                                    _openDocumentsWorkspace(
                                      context,
                                      lesson,
                                      documentId: currentDocumentId,
                                      documentLabel: currentDocumentLabel,
                                    );
                                  },
                                  icon: const Icon(Icons.description_outlined,
                                      size: 18),
                                  label: Text('打开$currentDocumentLabel'),
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
                              value: currentClassLabel,
                            ),
                            WorkspaceInfoPill(
                              label: '主资料',
                              value: currentDocumentLabel,
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
                                    classId: currentClassId,
                                    flashMessage:
                                        '已从 ${lesson.title} 的课堂档案进入 $currentClassLabel，可继续回看班级安排。',
                                    sourceModule: 'lessons',
                                    sourceRecordId: lesson.id,
                                    sourceLabel: lesson.title,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.groups_outlined, size: 18),
                              label: Text(currentClassLabel),
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
                                _openDocumentsWorkspace(
                                  context,
                                  lesson,
                                  documentId: currentDocumentId,
                                  documentLabel: currentDocumentLabel,
                                );
                              },
                              icon: const Icon(Icons.description_outlined,
                                  size: 18),
                              label: Text(currentDocumentLabel),
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
