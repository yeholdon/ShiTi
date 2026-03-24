import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/classes_page_args.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/lesson_detail_args.dart';
import '../../core/models/lessons_page_args.dart';
import '../../core/models/students_page_args.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';
import 'lesson_workspace_data.dart';

class LessonDetailPage extends StatelessWidget {
  const LessonDetailPage({
    required this.lessonId,
    this.flashMessage,
    super.key,
  });

  final String lessonId;
  final String? flashMessage;

  static LessonDetailPage fromArgs(LessonDetailArgs args) {
    return LessonDetailPage(
      lessonId: args.lessonId,
      flashMessage: args.flashMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = findLessonWorkspaceRecord(lessonId);
    final activeTenant = AppServices.instance.activeTenant;
    final tenantScope = activeTenant == null
        ? '未选择机构'
        : activeTenant.isPersonal
            ? '个人工作区'
            : '机构工作区';

    if (lesson == null) {
      return Scaffold(
        body: WorkspaceModuleShell(
          currentModule: WorkspaceModule.lessons,
          onSelectModule: (module) => navigateToWorkspaceModule(context, module),
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
                  message: '这节课堂暂时不在当前样例数据里，请返回课堂管理页重新选择。',
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
          label: const Text('返回课堂页'),
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
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      AppRouter.classes,
                                      (route) => false,
                                      arguments: ClassesPageArgs(
                                        focusClassId: lesson.classId,
                                        flashMessage:
                                            '已定位到 ${lesson.classScopeLabel}，可继续回看 ${lesson.title} 对应的班级安排。',
                                        highlightTitle: '当前课堂关联班级',
                                        highlightDetail:
                                            '${lesson.classScopeLabel} 正承接 ${lesson.title} 的课堂安排，可继续查看班级结构、资料和后续节奏。',
                                        feedbackBadgeLabel: '课堂回看',
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.groups_outlined, size: 18),
                                  label: Text('查看${lesson.classScopeLabel}'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      AppRouter.students,
                                      (route) => false,
                                      arguments: StudentsPageArgs(
                                        focusStudentId: lesson.focusStudentId,
                                        flashMessage:
                                            '已定位到 ${lesson.focusStudentName}，可继续回看 ${lesson.title} 的课堂反馈。',
                                        highlightTitle: '当前课堂反馈学生',
                                        highlightDetail:
                                            '${lesson.focusStudentName} 正承接 ${lesson.title} 的课堂反馈，可继续回看画像、错题与习惯跟进。',
                                        feedbackBadgeLabel: '课堂回看',
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.school_outlined, size: 18),
                                  label: Text('回看${lesson.focusStudentName}'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.documentDetail,
                                      arguments: DocumentDetailArgs(
                                        documentId: lesson.documentId,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.description_outlined, size: 18),
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
