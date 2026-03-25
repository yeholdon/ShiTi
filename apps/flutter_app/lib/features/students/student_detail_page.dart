import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/class_detail_args.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/lesson_detail_args.dart';
import '../../core/models/student_detail_args.dart';
import '../../core/models/students_page_args.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';
import '../classes/class_workspace_data.dart';
import '../lessons/lesson_workspace_data.dart';
import 'student_workspace_data.dart';

class StudentDetailPage extends StatelessWidget {
  const StudentDetailPage({
    required this.studentId,
    this.flashMessage,
    this.sourceModule,
    this.sourceRecordId,
    this.sourceLabel,
    super.key,
  });

  final String studentId;
  final String? flashMessage;
  final String? sourceModule;
  final String? sourceRecordId;
  final String? sourceLabel;

  static StudentDetailPage fromArgs(StudentDetailArgs args) {
    return StudentDetailPage(
      studentId: args.studentId,
      flashMessage: args.flashMessage,
      sourceModule: args.sourceModule,
      sourceRecordId: args.sourceRecordId,
      sourceLabel: args.sourceLabel,
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
      'classes' => '返回${sourceLabel ?? '班级详情'}',
      'lessons' => '返回${sourceLabel ?? '课堂详情'}',
      _ => '返回学生页',
    };
    final detailFuture = () async {
      if (AppConfig.useMockData) {
        final student = findStudentWorkspaceRecord(studentId);
        if (student == null) {
          return (null, null, null);
        }
        return (
          student,
          findClassWorkspaceRecord(student.classId),
          findLessonWorkspaceRecord(student.lessonId),
        );
      }

      final student = await AppServices.instance.studentRepository.getStudent(studentId);
      if (student == null) {
        return (null, null, null);
      }
      final results = await Future.wait([
        AppServices.instance.classRepository.getClass(student.classId),
        AppServices.instance.lessonRepository.getLesson(student.lessonId),
      ]);
      return (
        student,
        results[0] as ClassWorkspaceRecord?,
        results[1] as LessonWorkspaceRecord?,
      );
    }();

    return FutureBuilder<(
      StudentWorkspaceRecord?,
      ClassWorkspaceRecord?,
      LessonWorkspaceRecord?,
    )>(
      future: detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: WorkspaceModuleShell(
              currentModule: WorkspaceModule.students,
              onSelectModule: (module) =>
                  navigateToWorkspaceModule(context, module),
              title: '学生详情',
              subtitle: '正在读取学生成绩、错题、课堂反馈与资料承接。',
              searchHint: '搜索学生姓名、班级或历史表现',
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
                      title: '正在加载学生详情',
                      message: '正在读取当前学生的成绩记录、错题跟进和课堂反馈。',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final student = snapshot.data?.$1;
        final relatedClass = snapshot.data?.$2;
        final relatedLesson = snapshot.data?.$3;
        if (student == null) {
          return Scaffold(
            body: WorkspaceModuleShell(
              currentModule: WorkspaceModule.students,
              onSelectModule: (module) =>
                  navigateToWorkspaceModule(context, module),
              title: '学生详情',
              subtitle: '当前学生不存在或尚未同步到学生档案列表。',
              searchHint: '搜索学生姓名、班级或历史表现',
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
                      title: '未找到学生',
                      message: '这位学生暂时不在当前数据里，请返回学生管理页重新选择。',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: WorkspaceModuleShell(
            currentModule: WorkspaceModule.students,
            onSelectModule: (module) => navigateToWorkspaceModule(context, module),
            title: '学生详情',
            subtitle: '围绕单个学生查看成绩走势、错题跟进、课堂反馈与资料承接。',
            searchHint: '搜索其他学生姓名、班级、错题表现或教材版本',
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
                if (sourceModule == 'classes' && sourceRecordId != null) {
                  Navigator.of(context).pushNamed(
                    AppRouter.classDetail,
                    arguments: ClassDetailArgs(
                      classId: sourceRecordId!,
                      flashMessage:
                          '已从 ${student.name} 返回 ${sourceLabel ?? '班级详情'}。',
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
                          '已从 ${student.name} 返回 ${sourceLabel ?? '课堂详情'}。',
                    ),
                  );
                  return;
                }
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRouter.students,
                  (route) => false,
                  arguments: StudentsPageArgs(
                    focusStudentId: student.id,
                    flashMessage: '已返回 ${student.name} 所在学生页，可继续回看画像。',
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
                          label: '学生档案',
                          icon: Icons.person_search_outlined,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          student.name,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: TelegramPalette.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${student.className} · ${student.gradeLabel} · ${student.subjectLabel}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          student.summary,
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
                          label: '最近测评',
                          value: student.scoreLabel,
                        ),
                        WorkspaceMetricPill(
                          label: '历史成绩',
                          value: student.historyTrendLabel,
                        ),
                        WorkspaceMetricPill(
                          label: '错题数',
                          value: student.wrongCountLabel,
                          highlight: student.wrongCount >= 10,
                        ),
                        WorkspaceMetricPill(
                          label: '教材版本',
                          value: student.textbookLabel,
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
                              '成绩记录',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...student.scoreRecords.map(
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
                                              record.insight,
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
                                        label: '得分',
                                        value:
                                            '${record.score} / ${record.totalScore}',
                                        highlight: record.score >= 90,
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
                              '课堂反馈记录',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...student.feedbackRecords.map(
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
                                        label: '回收状态',
                                        value: record.status,
                                        highlight: record.status.contains('待') ||
                                            record.status.contains('跟进'),
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
                              '资料承接',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: TelegramPalette.surfaceRaised,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: TelegramPalette.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '当前承接链路',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: TelegramPalette.text,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${relatedClass?.name ?? student.className} -> ${relatedLesson?.title ?? '关联课堂'} -> ${student.documentName}',
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
                                        label: '班级',
                                        value: relatedClass?.name ?? student.className,
                                      ),
                                      WorkspaceInfoPill(
                                        label: '课堂',
                                        value: relatedLesson?.title ?? '关联课堂',
                                      ),
                                      WorkspaceInfoPill(
                                        label: '资料',
                                        value: student.documentName,
                                      ),
                                      WorkspaceInfoPill(
                                        label: '教材',
                                        value: student.textbookLabel,
                                      ),
                                    ],
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
                                              classId: student.classId,
                                              flashMessage:
                                                  '已从 ${student.name} 的资料承接区进入 ${relatedClass?.name ?? student.className}，可继续回看班级节奏与资料联动。',
                                              sourceModule: 'students',
                                              sourceRecordId: student.id,
                                              sourceLabel: student.name,
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.groups_outlined,
                                          size: 18,
                                        ),
                                        label: Text('查看${relatedClass?.name ?? student.className}'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).pushNamed(
                                            AppRouter.lessonDetail,
                                            arguments: LessonDetailArgs(
                                              lessonId: student.lessonId,
                                              flashMessage:
                                                  '已从 ${student.name} 的资料承接区进入 ${relatedLesson?.title ?? '关联课堂'}，可继续回看本节课的资料与反馈。',
                                              sourceModule: 'students',
                                              sourceRecordId: student.id,
                                              sourceLabel: student.name,
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.schedule_outlined,
                                          size: 18,
                                        ),
                                        label: Text('查看${relatedLesson?.title ?? '关联课堂'}'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).pushNamed(
                                            AppRouter.documentDetail,
                                            arguments: DocumentDetailArgs(
                                              documentId: student.documentId,
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.description_outlined,
                                          size: 18,
                                        ),
                                        label:
                                            Text('打开${student.documentName}'),
                                      ),
                                    ],
                                  ),
                                ],
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
                              '错题跟进',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...student.wrongQuestionRecords.map(
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
                                              record.followUp,
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
                              '学习习惯与跟进重点',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TelegramPalette.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            WorkspaceMessageBanner.warning(
                              title: student.habitTag,
                              message: student.habitInsight,
                            ),
                            const SizedBox(height: 16),
                            ...student.highlights.map(
                              (point) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: WorkspaceBulletPoint(text: point),
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
                              message: student.nextStep,
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
                                        classId: student.classId,
                                        flashMessage:
                                            '已从 ${student.name} 的学生档案进入 ${relatedClass?.name ?? student.className}，可继续回看班级节奏与资料联动。',
                                        sourceModule: 'students',
                                        sourceRecordId: student.id,
                                        sourceLabel: student.name,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.groups_outlined,
                                      size: 18),
                                  label: Text('查看${relatedClass?.name ?? student.className}详情'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.lessonDetail,
                                      arguments: LessonDetailArgs(
                                        lessonId: student.lessonId,
                                        flashMessage:
                                            '已从 ${student.name} 的学生档案进入 ${relatedLesson?.title ?? '关联课堂'}，可继续回看本节课的资料与反馈。',
                                        sourceModule: 'students',
                                        sourceRecordId: student.id,
                                        sourceLabel: student.name,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.schedule_outlined,
                                      size: 18),
                                  label: Text('查看${relatedLesson?.title ?? '关联课堂'}详情'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.documentDetail,
                                      arguments: DocumentDetailArgs(
                                        documentId: student.documentId,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.description_outlined,
                                      size: 18),
                                  label: Text('打开${student.documentName}'),
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
                              value: relatedClass?.name ?? student.className,
                            ),
                            WorkspaceInfoPill(
                              label: '课堂',
                              value: relatedLesson?.title ?? '关联课堂',
                            ),
                            WorkspaceInfoPill(
                              label: '资料',
                              value: student.documentName,
                            ),
                            WorkspaceInfoPill(
                              label: '跟进级别',
                              value: student.followUpLevel,
                              highlight: student.followUpLevel == '重点跟进',
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
                                        classId: student.classId,
                                        flashMessage:
                                        '已从 ${student.name} 的学生档案进入 ${relatedClass?.name ?? student.className}，可继续回看班级节奏与资料联动。',
                                    sourceModule: 'students',
                                    sourceRecordId: student.id,
                                    sourceLabel: student.name,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.groups_outlined, size: 18),
                              label: Text(relatedClass?.name ?? student.className),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRouter.lessonDetail,
                                  arguments: LessonDetailArgs(
                                        lessonId: student.lessonId,
                                        flashMessage:
                                        '已从 ${student.name} 的学生档案进入 ${relatedLesson?.title ?? '关联课堂'}，可继续回看本节课的资料与反馈。',
                                    sourceModule: 'students',
                                    sourceRecordId: student.id,
                                    sourceLabel: student.name,
                                  ),
                                );
                              },
                              icon:
                                  const Icon(Icons.schedule_outlined, size: 18),
                              label: Text(relatedLesson?.title ?? '当前课堂'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRouter.documentDetail,
                                  arguments: DocumentDetailArgs(
                                    documentId: student.documentId,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.description_outlined,
                                  size: 18),
                              label: Text(student.documentName),
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
