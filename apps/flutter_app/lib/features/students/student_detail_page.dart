import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/classes_page_args.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/lessons_page_args.dart';
import '../../core/models/student_detail_args.dart';
import '../../core/models/students_page_args.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';
import 'student_workspace_data.dart';

class StudentDetailPage extends StatelessWidget {
  const StudentDetailPage({
    required this.studentId,
    this.flashMessage,
    super.key,
  });

  final String studentId;
  final String? flashMessage;

  static StudentDetailPage fromArgs(StudentDetailArgs args) {
    return StudentDetailPage(
      studentId: args.studentId,
      flashMessage: args.flashMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = findStudentWorkspaceRecord(studentId);
    final activeTenant = AppServices.instance.activeTenant;
    final tenantScope = activeTenant == null
        ? '未选择机构'
        : activeTenant.isPersonal
            ? '个人工作区'
            : '机构工作区';

    if (student == null) {
      return Scaffold(
        body: WorkspaceModuleShell(
          currentModule: WorkspaceModule.students,
          onSelectModule: (module) => navigateToWorkspaceModule(context, module),
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
                  message: '这位学生暂时不在当前样例数据里，请返回学生管理页重新选择。',
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
          label: const Text('返回学生页'),
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
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      AppRouter.classes,
                                      (route) => false,
                                      arguments: ClassesPageArgs(
                                        focusClassId: student.classId,
                                        flashMessage: '已定位到 ${student.className}，可继续安排班级与课堂节奏。',
                                        highlightTitle: '当前学生所在班级',
                                        highlightDetail:
                                            '${student.className} 正承接 ${student.name} 的学习跟进，可继续回看班级资料、课堂安排和分层任务。',
                                        feedbackBadgeLabel: '学生回看',
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.groups_outlined, size: 18),
                                  label: Text('查看${student.className}'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      AppRouter.lessons,
                                      (route) => false,
                                      arguments: LessonsPageArgs(
                                        focusLessonId: student.lessonId,
                                        flashMessage: '已定位到与 ${student.name} 相关的课堂，可继续回看反馈。',
                                        highlightTitle: '当前学生关联课堂',
                                        highlightDetail:
                                            '${student.name} 当前关联 ${student.className} 的课堂安排，可继续回看资料使用和课后反馈。',
                                        feedbackBadgeLabel: '学生回看',
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.schedule_outlined, size: 18),
                                  label: const Text('回看关联课堂'),
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
                                  icon: const Icon(Icons.description_outlined, size: 18),
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
                              value: student.className,
                            ),
                            WorkspaceInfoPill(
                              label: '课堂',
                              value: student.lessonId == 'lesson-1'
                                  ? '二次函数专题复盘课'
                                  : student.lessonId == 'lesson-2'
                                      ? '相似三角形讲义推进课'
                                      : '高一力学模型拆解课',
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
  }
}
