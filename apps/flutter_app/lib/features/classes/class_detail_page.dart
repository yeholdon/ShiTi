import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/class_detail_args.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/lessons_page_args.dart';
import '../../core/models/students_page_args.dart';
import '../../core/models/classes_page_args.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';
import 'class_workspace_data.dart';

class ClassDetailPage extends StatelessWidget {
  const ClassDetailPage({
    required this.classId,
    this.flashMessage,
    super.key,
  });

  final String classId;
  final String? flashMessage;

  static ClassDetailPage fromArgs(ClassDetailArgs args) {
    return ClassDetailPage(
      classId: args.classId,
      flashMessage: args.flashMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final classroom = findClassWorkspaceRecord(classId);
    final activeTenant = AppServices.instance.activeTenant;
    final tenantScope = activeTenant == null
        ? '未选择机构'
        : activeTenant.isPersonal
            ? '个人工作区'
            : '机构工作区';

    if (classroom == null) {
      return Scaffold(
        body: WorkspaceModuleShell(
          currentModule: WorkspaceModule.classes,
          onSelectModule: (module) => navigateToWorkspaceModule(context, module),
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
                  message: '这条班级档案暂时不在当前样例数据里，请返回班级管理页重新选择。',
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
          label: const Text('返回班级页'),
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
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      AppRouter.students,
                                      (route) => false,
                                      arguments: StudentsPageArgs(
                                        focusStudentId: classroom.focusStudentId,
                                        flashMessage:
                                            '已定位到 ${classroom.focusStudentName}，可继续结合 ${classroom.name} 的节奏跟进学生画像。',
                                        highlightTitle: '当前班级重点学生',
                                        highlightDetail:
                                            '${classroom.focusStudentName} 正处在 ${classroom.name} 的当前跟进节奏里，可继续结合班级资料与课堂安排回看画像。',
                                        feedbackBadgeLabel: '班级回看',
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.school_outlined, size: 18),
                                  label: Text('查看${classroom.focusStudentName}'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      AppRouter.lessons,
                                      (route) => false,
                                      arguments: LessonsPageArgs(
                                        focusLessonId: classroom.lessonId,
                                        flashMessage:
                                            '已定位到 ${classroom.lessonFocusLabel}，可继续安排课堂资料与反馈。',
                                        highlightTitle: '当前班级关联课堂',
                                        highlightDetail:
                                            '${classroom.lessonFocusLabel} 正承接 ${classroom.name} 的课堂安排，可继续回看资料与反馈节奏。',
                                        feedbackBadgeLabel: '班级回看',
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.schedule_outlined, size: 18),
                                  label: Text('查看${classroom.lessonFocusLabel}'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.documentDetail,
                                      arguments: DocumentDetailArgs(
                                        documentId: classroom.documentId,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.description_outlined, size: 18),
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
