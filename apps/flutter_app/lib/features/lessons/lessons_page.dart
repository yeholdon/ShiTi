import 'package:flutter/material.dart';

import '../../core/models/classes_page_args.dart';
import '../../core/models/documents_page_args.dart';
import '../../core/models/lesson_detail_args.dart';
import '../../core/models/lessons_page_args.dart';
import '../../core/models/students_page_args.dart';
import '../../core/config/app_config.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_flow_panel.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/primary_page_view_state_memory.dart';
import '../shared/workspace_shell.dart';
import '../../router/app_router.dart';
import 'lesson_workspace_data.dart';

enum _LessonFilter {
  all('全部课堂'),
  thisWeek('本周进行'),
  feedback('待收反馈'),
  docs('资料联动');

  const _LessonFilter(this.label);
  final String label;
}

class LessonsPage extends StatefulWidget {
  const LessonsPage({this.args, super.key});

  final LessonsPageArgs? args;

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  late _LessonFilter _filter;
  late String _selectedLessonId;
  late final TextEditingController _queryController;

  bool get _hasContextualEntry => widget.args?.focusLessonId != null;

  @override
  void initState() {
    super.initState();
    final storedState = PrimaryPageViewStateMemory.lessons;
    _queryController = TextEditingController(
      text: !_hasContextualEntry && storedState != null ? storedState.query : '',
    );
    _filter = !_hasContextualEntry && storedState != null
        ? _lessonFilterFromLabel(storedState.filter)
        : _LessonFilter.all;
    _selectedLessonId = widget.args?.focusLessonId ??
        (!_hasContextualEntry && storedState != null
            ? storedState.selectedLessonId
            : sampleLessonRecords.first.id);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _rememberViewState() {
    PrimaryPageViewStateMemory.lessons = PrimaryLessonsViewState(
      query: _queryController.text.trim(),
      filter: _filter.label,
      selectedLessonId: _selectedLessonId,
    );
  }

  List<LessonWorkspaceRecord> _recordsForFilter(_LessonFilter filter) {
    final query = _queryController.text.trim().toLowerCase();
    return sampleLessonRecords
        .where((lesson) => switch (filter) {
              _LessonFilter.all => true,
              _LessonFilter.thisWeek => lesson.scheduleTag == '本周进行',
              _LessonFilter.feedback => lesson.feedbackStatus == '待回收',
              _LessonFilter.docs => lesson.documentFocus.isNotEmpty,
            })
        .where(
          (lesson) =>
              query.isEmpty ||
              lesson.title.toLowerCase().contains(query) ||
              lesson.className.toLowerCase().contains(query) ||
              lesson.documentFocus.toLowerCase().contains(query) ||
              lesson.followUpLabel.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _openDetail(LessonWorkspaceRecord lesson) {
    Navigator.of(context).pushNamed(
      AppRouter.lessonDetail,
      arguments: LessonDetailArgs(
        lessonId: lesson.id,
        flashMessage: '已从课堂工作页进入 ${lesson.title} 的详情档案。',
      ),
    );
  }

  void _openClass(LessonWorkspaceRecord lesson) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.classes,
      (route) => false,
      arguments: ClassesPageArgs(
        focusClassId: lesson.classId,
        flashMessage: '已定位到 ${lesson.classScopeLabel}，可继续编排班级与课堂资料。',
        highlightTitle: '当前课堂关联班级',
        highlightDetail:
            '${lesson.classScopeLabel} 正承接 ${lesson.title} 的教学安排，可继续回看班级资料、学生分层和课堂节奏。',
        feedbackBadgeLabel: '课堂回看',
      ),
    );
  }

  void _openStudents(LessonWorkspaceRecord lesson) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.students,
      (route) => false,
      arguments: StudentsPageArgs(
        focusStudentId: lesson.focusStudentId,
        flashMessage:
            '已定位到 ${lesson.focusStudentName}，可继续把 ${lesson.title} 的课堂反馈回写到学生画像。',
        highlightTitle: '当前课堂反馈学生',
        highlightDetail:
            '${lesson.focusStudentName} 正承接 ${lesson.title} 的课堂反馈，可继续回看错题、习惯与课后任务跟进。',
        feedbackBadgeLabel: '课堂回看',
      ),
    );
  }

  void _openDocument(LessonWorkspaceRecord lesson) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.documents,
      (route) => false,
      arguments: DocumentsPageArgs(
        focusDocumentId: lesson.documentId,
        flashMessage: '已定位到 ${lesson.documentFocus}，可继续整理这节课使用的资料。',
        highlightTitle: '当前课堂资料',
        highlightDetail:
            '${lesson.documentFocus} 正承接 ${lesson.title} 的主资料，可继续调整课堂资料与反馈回收。',
        feedbackBadgeLabel: '课堂资料',
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
    final filteredLessons = _recordsForFilter(_filter);
    final selectedLesson = filteredLessons.firstWhere(
      (lesson) => lesson.id == _selectedLessonId,
      orElse: () => filteredLessons.isNotEmpty
          ? filteredLessons.first
          : sampleLessonRecords.first,
    );
    final highlightTitle = widget.args?.highlightTitle;
    final highlightDetail = widget.args?.highlightDetail;
    final feedbackBadgeLabel = widget.args?.feedbackBadgeLabel;

    return Scaffold(
      body: WorkspaceModuleShell(
        currentModule: WorkspaceModule.lessons,
        onSelectModule: (module) => navigateToWorkspaceModule(context, module),
        title: '课堂管理',
        subtitle: '围绕每一堂课的时间、班级、文档资料和课后反馈，组织真正可回看的课堂工作台。',
        searchHint: '搜索课堂主题、班级、讲义、试卷、课堂反馈或课后任务',
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
          onPressed: () {},
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('新建课堂'),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final showAside = constraints.maxWidth >= 1180;
            return workspaceConstrainedContent(
              context,
              child: ListView(
                padding: workspacePagePadding(context),
                children: [
                  _LessonHeroSection(
                    lessonCount: sampleLessonRecords.length,
                    feedbackCount: sampleLessonRecords
                        .where((lesson) => lesson.feedbackStatus == '待回收')
                        .length,
                    linkedDocsCount: sampleLessonRecords
                        .map((lesson) => lesson.documentFocus)
                        .where((focus) => focus.isNotEmpty)
                        .toSet()
                        .length,
                    linkedClassCount: sampleLessonRecords
                        .map((lesson) => lesson.className)
                        .toSet()
                        .length,
                  ),
                  const SizedBox(height: 18),
                  WorkspacePanel(
                    padding: workspacePanelPadding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '课堂视图',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TelegramPalette.textStrong,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _queryController,
                          decoration: const InputDecoration(
                            hintText: '搜索课堂主题、班级、资料或课后任务',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onChanged: (_) {
                            final nextRecords = _recordsForFilter(_filter);
                            setState(() {
                              if (!nextRecords.any(
                                (lesson) => lesson.id == _selectedLessonId,
                              )) {
                                _selectedLessonId = nextRecords.isNotEmpty
                                    ? nextRecords.first.id
                                    : sampleLessonRecords.first.id;
                              }
                              _rememberViewState();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _LessonFilter.values
                              .map(
                                (filter) => WorkspaceFilterPill(
                                  label: filter.label,
                                  selected: _filter == filter,
                                  onTap: () {
                                    final nextRecords = _recordsForFilter(filter);
                                    setState(() {
                                      _filter = filter;
                                      if (!nextRecords.any(
                                        (lesson) =>
                                            lesson.id == _selectedLessonId,
                                      )) {
                                        _selectedLessonId = nextRecords.isNotEmpty
                                            ? nextRecords.first.id
                                            : sampleLessonRecords.first.id;
                                      }
                                      _rememberViewState();
                                    });
                                  },
                                  showSelectedCheckmark: true,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  if ((widget.args?.flashMessage ?? '').isNotEmpty) ...[
                    const SizedBox(height: 18),
                    WorkspaceMessageBanner.info(
                      title: '当前上下文',
                      message: widget.args!.flashMessage!,
                    ),
                  ],
                  if ((highlightTitle?.trim().isNotEmpty ?? false) ||
                      (highlightDetail?.trim().isNotEmpty ?? false) ||
                      (feedbackBadgeLabel?.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 18),
                    WorkspacePanel(
                      padding: workspacePanelPadding(context),
                      backgroundColor: TelegramPalette.surfaceAccent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (feedbackBadgeLabel != null &&
                                  feedbackBadgeLabel.trim().isNotEmpty)
                                WorkspaceInfoPill(
                                  label: '当前来源',
                                  value: feedbackBadgeLabel,
                                  highlight: true,
                                ),
                              WorkspaceInfoPill(
                                label: '当前课堂',
                                value: selectedLesson.title,
                              ),
                              WorkspaceInfoPill(
                                label: '当前班级',
                                value: selectedLesson.className,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            highlightTitle ?? '当前课堂上下文',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: TelegramPalette.text,
                            ),
                          ),
                          if (highlightDetail != null &&
                              highlightDetail.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              highlightDetail,
                              style: const TextStyle(
                                height: 1.5,
                                color: TelegramPalette.textStrong,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const WorkspaceFlowPanel(
                    currentModule: WorkspaceModule.lessons,
                    title: '联动工作流',
                    subtitle: '课堂是班级、学生反馈和文档资料真正汇合的地方，通常要在这三块之间循环推进。',
                    actions: [
                      WorkspaceFlowAction(
                        module: WorkspaceModule.classes,
                        icon: Icons.groups_outlined,
                        label: '回到班级编排',
                        description: '先确认这节课面向哪个班级、当前规模和最近资料节奏。',
                      ),
                      WorkspaceFlowAction(
                        module: WorkspaceModule.students,
                        icon: Icons.school_outlined,
                        label: '回写学生反馈',
                        description: '把课堂表现、错题和习惯反馈沉淀进学生画像。',
                      ),
                      WorkspaceFlowAction(
                        module: WorkspaceModule.documents,
                        icon: Icons.description_outlined,
                        label: '继续整理资料',
                        description: '回到文档页继续补讲义、试卷和排版资料，再回看课堂使用效果。',
                      ),
                      WorkspaceFlowAction(
                        module: WorkspaceModule.lessons,
                        icon: Icons.timeline_outlined,
                        label: '当前仍在课堂页',
                        description: '先把课堂资料、反馈和后续任务串起来，再决定回到哪条链路。',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (showAside)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _LessonListPanel(
                            lessons: filteredLessons,
                            selectedLessonId: selectedLesson.id,
                            onOpenDetail: _openDetail,
                            onSelect: (lessonId) {
                              setState(() {
                                _selectedLessonId = lessonId;
                                _rememberViewState();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _LessonDetailRail(
                            lesson: selectedLesson,
                            onOpenDetail: () => _openDetail(selectedLesson),
                            onOpenClass: () => _openClass(selectedLesson),
                            onOpenStudents: () => _openStudents(selectedLesson),
                            onOpenDocument: () => _openDocument(selectedLesson),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _LessonDetailRail(
                      lesson: selectedLesson,
                      onOpenDetail: () => _openDetail(selectedLesson),
                      onOpenClass: () => _openClass(selectedLesson),
                      onOpenStudents: () => _openStudents(selectedLesson),
                      onOpenDocument: () => _openDocument(selectedLesson),
                    ),
                    const SizedBox(height: 16),
                    _LessonListPanel(
                      lessons: filteredLessons,
                      selectedLessonId: selectedLesson.id,
                      onOpenDetail: _openDetail,
                      onSelect: (lessonId) {
                        setState(() {
                          _selectedLessonId = lessonId;
                          _rememberViewState();
                        });
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

_LessonFilter _lessonFilterFromLabel(String label) {
  return _LessonFilter.values.firstWhere(
    (filter) => filter.label == label,
    orElse: () => _LessonFilter.all,
  );
}

class _LessonHeroSection extends StatelessWidget {
  const _LessonHeroSection({
    required this.lessonCount,
    required this.feedbackCount,
    required this.linkedDocsCount,
    required this.linkedClassCount,
  });

  final int lessonCount;
  final int feedbackCount;
  final int linkedDocsCount;
  final int linkedClassCount;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspaceHeroPanelPadding(context),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: '课堂工作台',
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(height: 14),
          const Text(
            '把每一堂课的备课、讲义、试卷与课后反馈整理成可回看的课堂时间线。',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '首版先用真实工作页承接课堂主题、班级节奏、资料联动和反馈回收，后续再把新版课堂模型与学生反馈真正接进来。',
            style: TextStyle(
              height: 1.55,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              WorkspaceMetricPill(label: '课堂数', value: '$lessonCount'),
              WorkspaceMetricPill(
                label: '待回收反馈',
                value: '$feedbackCount',
                highlight: feedbackCount > 0,
              ),
              WorkspaceMetricPill(label: '联动资料', value: '$linkedDocsCount'),
              WorkspaceMetricPill(label: '关联班级', value: '$linkedClassCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonListPanel extends StatelessWidget {
  const _LessonListPanel({
    required this.lessons,
    required this.selectedLessonId,
    required this.onOpenDetail,
    required this.onSelect,
  });

  final List<LessonWorkspaceRecord> lessons;
  final String selectedLessonId;
  final ValueChanged<LessonWorkspaceRecord> onOpenDetail;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '课堂列表',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当前结果 ${lessons.length} 节课堂，按班级、资料联动与反馈回收状态快速切换。',
            style: const TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          ...lessons.map(
            (lesson) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LessonCard(
                lesson: lesson,
                selected: lesson.id == selectedLessonId,
                onOpenDetail: () => onOpenDetail(lesson),
                onTap: () => onSelect(lesson.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.selected,
    required this.onOpenDetail,
    required this.onTap,
  });

  final LessonWorkspaceRecord lesson;
  final bool selected;
  final VoidCallback onOpenDetail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? TelegramPalette.surfaceAccent
                : TelegramPalette.surfaceRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? TelegramPalette.borderAccent
                  : TelegramPalette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: TelegramPalette.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${lesson.className} · ${lesson.scheduleLabel} · ${lesson.teacherLabel}',
                          style: const TextStyle(
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  WorkspaceInfoPill(
                    value: lesson.feedbackStatus,
                    highlight: lesson.feedbackStatus == '待回收',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '查看课堂详情',
                    onPressed: onOpenDetail,
                    icon: const Icon(Icons.open_in_new_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  WorkspaceInfoPill(label: '课堂状态', value: lesson.scheduleTag),
                  WorkspaceInfoPill(label: '关联班级', value: lesson.classScopeLabel),
                  WorkspaceInfoPill(label: '主资料', value: lesson.documentFocus),
                  WorkspaceInfoPill(label: '任务', value: lesson.followUpLabel),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                lesson.summary,
                style: const TextStyle(
                  height: 1.5,
                  color: TelegramPalette.textStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonDetailRail extends StatelessWidget {
  const _LessonDetailRail({
    required this.lesson,
    required this.onOpenDetail,
    required this.onOpenClass,
    required this.onOpenStudents,
    required this.onOpenDocument,
  });

  final LessonWorkspaceRecord lesson;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenClass;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenDocument;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      backgroundColor: TelegramPalette.surfaceAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前课堂摘要',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lesson.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${lesson.className} · ${lesson.scheduleLabel}',
            style: const TextStyle(color: TelegramPalette.textMuted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              WorkspaceMetricPill(label: '主资料', value: lesson.documentFocus),
              WorkspaceMetricPill(label: '反馈', value: lesson.feedbackStatus),
              WorkspaceMetricPill(label: '关联班级', value: lesson.classScopeLabel),
              WorkspaceMetricPill(label: '课后任务', value: lesson.followUpLabel),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onOpenDetail,
            icon: const Icon(Icons.open_in_new_outlined, size: 18),
            label: const Text('查看课堂详情'),
          ),
          const SizedBox(height: 16),
          WorkspaceMessageBanner.warning(
            title: '课后反馈',
            message: lesson.feedbackInsight,
          ),
          const SizedBox(height: 16),
          const Text(
            '本节重点',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: TelegramPalette.textStrong,
            ),
          ),
          const SizedBox(height: 10),
          ...lesson.highlights.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WorkspaceBulletPoint(text: point),
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceMessageBanner.info(
            title: '下一步动作',
            message: lesson.nextStep,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenClass,
                icon: const Icon(Icons.groups_outlined, size: 18),
                label: Text('查看${lesson.classScopeLabel}'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenStudents,
                icon: const Icon(Icons.school_outlined, size: 18),
                label: Text('回看${lesson.focusStudentName}'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenDocument,
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text('打开${lesson.documentFocus}'),
              ),
              const WorkspaceFilterPill(
                label: '当前课堂页',
                icon: Icons.schedule_outlined,
                selected: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
