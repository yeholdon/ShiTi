import 'package:flutter/material.dart';

import '../../core/models/class_detail_args.dart';
import '../../core/models/classes_page_args.dart';
import '../../core/models/documents_page_args.dart';
import '../../core/models/library_page_args.dart';
import '../../core/models/lessons_page_args.dart';
import '../../core/models/students_page_args.dart';
import '../../core/config/app_config.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../core/network/http_json_client.dart';
import '../shared/workspace_flow_panel.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/primary_page_view_state_memory.dart';
import '../shared/workspace_shell.dart';
import '../../router/app_router.dart';
import 'create_class_dialog.dart';
import 'class_workspace_data.dart';

enum _ClassFilter {
  all('全部班级'),
  active('近期活跃'),
  exam('测评班级'),
  handout('讲义班级');

  const _ClassFilter(this.label);
  final String label;
}

class ClassesPage extends StatefulWidget {
  const ClassesPage({this.args, super.key});

  final ClassesPageArgs? args;

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  late _ClassFilter _filter;
  late String _selectedClassId;
  late final TextEditingController _queryController;
  late List<ClassWorkspaceRecord> _records;
  bool _isLoading = !AppConfig.useMockData;
  String? _loadError;

  bool get _hasContextualEntry => widget.args?.focusClassId != null;

  @override
  void initState() {
    super.initState();
    final storedState = PrimaryPageViewStateMemory.classes;
    _queryController = TextEditingController(
      text: !_hasContextualEntry && storedState != null ? storedState.query : '',
    );
    _filter = !_hasContextualEntry && storedState != null
        ? _classFilterFromLabel(storedState.filter)
        : _ClassFilter.all;
    _records = sampleClassRecords;
    _selectedClassId = widget.args?.focusClassId ??
        (!_hasContextualEntry && storedState != null
            ? storedState.selectedClassId
            : sampleClassRecords.first.id);
    if (!AppConfig.useMockData) {
      _loadClasses();
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _rememberViewState() {
    PrimaryPageViewStateMemory.classes = PrimaryClassesViewState(
      query: _queryController.text.trim(),
      filter: _filter.label,
      selectedClassId: _selectedClassId,
    );
  }

  List<ClassWorkspaceRecord> _recordsForFilter(_ClassFilter filter) {
    final query = _queryController.text.trim().toLowerCase();
    return _records
        .where((item) => switch (filter) {
              _ClassFilter.all => true,
              _ClassFilter.active => item.activityLabel == '本周活跃',
              _ClassFilter.exam => item.focusLabel == '试卷跟进',
              _ClassFilter.handout => item.focusLabel == '讲义整理',
            })
        .where(
          (item) =>
              query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.textbookLabel.toLowerCase().contains(query) ||
              item.lessonFocusLabel.toLowerCase().contains(query) ||
              item.focusLabel.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  Future<void> _loadClasses({String? focusClassId}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final records = await AppServices.instance.classRepository.listClasses();
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        _isLoading = false;
        _loadError = null;
        final preferredClassId = focusClassId ?? _selectedClassId;
        if (_records.isNotEmpty &&
            _records.any((item) => item.id == preferredClassId)) {
          _selectedClassId = preferredClassId;
        } else if (_records.isNotEmpty &&
            !_records.any((item) => item.id == _selectedClassId)) {
          _selectedClassId = _records.first.id;
        }
        _rememberViewState();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  void _openStudents(ClassWorkspaceRecord classroom) {
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
  }

  void _openLesson(ClassWorkspaceRecord classroom) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.lessons,
      (route) => false,
      arguments: LessonsPageArgs(
        focusLessonId: classroom.lessonId,
        flashMessage: '已定位到 ${classroom.lessonFocusLabel}，可继续安排课堂资料与反馈。',
        highlightTitle: '当前班级关联课堂',
        highlightDetail:
            '${classroom.lessonFocusLabel} 正承接 ${classroom.name} 的课堂安排，可继续回看资料与反馈节奏。',
        feedbackBadgeLabel: '班级回看',
      ),
    );
  }

  void _openDocument(ClassWorkspaceRecord classroom) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.documents,
      (route) => false,
      arguments: DocumentsPageArgs(
        focusDocumentId: classroom.documentId,
        flashMessage: '已定位到 ${classroom.latestDocLabel}，可继续整理班级资料。',
        highlightTitle: '当前班级资料',
        highlightDetail:
            '${classroom.latestDocLabel} 正承接 ${classroom.name} 的资料安排，可继续补讲义、试卷和课堂节奏。',
        feedbackBadgeLabel: '班级资料',
        sourceModule: 'classes',
        sourceRecordId: classroom.id,
        sourceLabel: classroom.name,
      ),
    );
  }

  void _openLibrary(ClassWorkspaceRecord classroom) {
    final stageLabel = classroom.stageLabel.split('·').first.trim();
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.library,
      (route) => false,
      arguments: LibraryPageArgs(
        initialStageLabel: stageLabel,
        initialTextbookLabel: classroom.textbookLabel.trim(),
        flashMessage: '已定位到 ${classroom.name} 的题库上下文，可继续按当前班级筛题。',
        highlightTitle: '当前班级题库上下文',
        highlightDetail:
            '${classroom.name} 的学段、教材和关联学科条件已带入题库，可继续筛题、入篮或送入文档。',
        feedbackBadgeLabel: '班级筛题',
        sourceModule: 'classes',
        sourceRecordId: classroom.id,
        sourceLabel: classroom.name,
      ),
    );
  }

  void _openDetail(ClassWorkspaceRecord classroom) {
    Navigator.of(context).pushNamed(
      AppRouter.classDetail,
      arguments: ClassDetailArgs(
        classId: classroom.id,
        flashMessage: '已从班级工作页进入 ${classroom.name} 的详情档案。',
      ),
    );
  }

  Future<void> _createClass() async {
    final created = await showCreateClassDialog(context);
    if (!mounted || created == null) {
      return;
    }

    try {
      await _loadClasses(focusClassId: created.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已创建班级：${created.name}')),
      );
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('班级列表刷新失败：${error.message}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('班级列表刷新失败：$error')),
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
    final filteredClasses = _recordsForFilter(_filter);
    final selectedClass = filteredClasses.isNotEmpty
        ? filteredClasses.firstWhere(
            (item) => item.id == _selectedClassId,
            orElse: () => filteredClasses.first,
          )
        : (_records.isNotEmpty ? _records.first : null);
    final highlightTitle = widget.args?.highlightTitle;
    final highlightDetail = widget.args?.highlightDetail;
    final feedbackBadgeLabel = widget.args?.feedbackBadgeLabel;

    return Scaffold(
      body: WorkspaceModuleShell(
        currentModule: WorkspaceModule.classes,
        onSelectModule: (module) => navigateToWorkspaceModule(context, module),
        title: '班级管理',
        subtitle: '围绕班级规模、成员动态、资料联动与阶段目标，组织统一的班级工作台。',
        searchHint: '搜索班级名称、人数规模、教材版本、阶段目标或最近课堂',
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
          onPressed: _createClass,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('新建班级'),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final showAside = constraints.maxWidth >= 1180;
            return workspaceConstrainedContent(
              context,
              child: ListView(
                padding: workspacePagePadding(context),
                children: [
                  _ClassHeroSection(
                    classCount: _records.length,
                    studentCount: _records.fold<int>(
                      0,
                      (sum, item) => sum + item.studentCount,
                    ),
                    activeLessonCount: _records.fold<int>(
                      0,
                      (sum, item) => sum + item.weeklyLessonCount,
                    ),
                    linkedDocCount: _records
                        .map((item) => item.latestDocLabel)
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
                          '班级视图',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TelegramPalette.textStrong,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _queryController,
                          decoration: const InputDecoration(
                            hintText: '搜索班级名称、教材、课堂或跟进重点',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onChanged: (_) {
                            final nextRecords = _recordsForFilter(_filter);
                            setState(() {
                              if (!nextRecords.any(
                                (item) => item.id == _selectedClassId,
                              )) {
                                _selectedClassId = nextRecords.isNotEmpty
                                    ? nextRecords.first.id
                                    : (_records.isNotEmpty
                                        ? _records.first.id
                                        : _selectedClassId);
                              }
                              _rememberViewState();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _ClassFilter.values
                              .map(
                                (filter) => WorkspaceFilterPill(
                                  label: filter.label,
                                  selected: _filter == filter,
                                  onTap: () {
                                    final nextRecords = _recordsForFilter(filter);
                                    setState(() {
                                      _filter = filter;
                                      if (!nextRecords.any(
                                        (item) => item.id == _selectedClassId,
                                      )) {
                                        _selectedClassId = nextRecords.isNotEmpty
                                            ? nextRecords.first.id
                                            : (_records.isNotEmpty
                                                ? _records.first.id
                                                : _selectedClassId);
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
                  if (_isLoading) ...[
                    const SizedBox(height: 18),
                    const WorkspaceMessageBanner.info(
                      title: '正在加载班级数据',
                      message: '正在从当前机构读取班级结构、课堂安排和资料联动。',
                    ),
                  ] else if (_loadError != null) ...[
                    const SizedBox(height: 18),
                    WorkspacePanel(
                      padding: workspacePanelPadding(context),
                      child: Row(
                        children: [
                          const Expanded(
                            child: WorkspaceMessageBanner.warning(
                              title: '班级数据加载失败',
                              message: '当前无法读取班级列表，请稍后重试。',
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _loadClasses,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if ((widget.args?.flashMessage ?? '').isNotEmpty) ...[
                    const SizedBox(height: 18),
                    WorkspaceMessageBanner.info(
                      title: '当前上下文',
                      message: widget.args!.flashMessage!,
                    ),
                  ],
                  if (selectedClass != null &&
                      ((highlightTitle?.trim().isNotEmpty ?? false) ||
                      (highlightDetail?.trim().isNotEmpty ?? false) ||
                      (feedbackBadgeLabel?.trim().isNotEmpty ?? false))) ...[
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
                                label: '当前班级',
                                value: selectedClass.name,
                              ),
                              WorkspaceInfoPill(
                                label: '当前课堂',
                                value: selectedClass.lessonFocusLabel,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            highlightTitle ?? '当前班级上下文',
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
                    currentModule: WorkspaceModule.classes,
                    title: '联动工作流',
                    subtitle: '班级是学生、课堂和资料之间的组织层，通常要在这三块之间来回切换。',
                    actions: [
                      WorkspaceFlowAction(
                        module: WorkspaceModule.students,
                        icon: Icons.school_outlined,
                        label: '回看学生画像',
                        description: '根据班级分层结果，继续查看重点学生的成绩、错题和习惯。',
                      ),
                      WorkspaceFlowAction(
                        module: WorkspaceModule.lessons,
                        icon: Icons.schedule_outlined,
                        label: '安排课堂节奏',
                        description: '把班级当前资料和教学目标，继续推进到课堂时间线里。',
                      ),
                      WorkspaceFlowAction(
                        module: WorkspaceModule.documents,
                        icon: Icons.description_outlined,
                        label: '整理讲义试卷',
                        description: '回到文档页继续整理这批班级当前使用的讲义与试卷。',
                      ),
                      WorkspaceFlowAction(
                        module: WorkspaceModule.classes,
                        icon: Icons.view_list_outlined,
                        label: '当前仍在班级页',
                        description: '先整理班级规模、教材与课堂焦点，再继续切到其他模块。',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (showAside)
                    selectedClass == null
                        ? WorkspaceMessageBanner.warning(
                            title: '当前没有班级数据',
                            message: _isLoading
                                ? '班级数据仍在加载中。'
                                : '当前机构下还没有班级档案，请先新增班级或切换到有数据的机构。',
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: _ClassListPanel(
                                  classes: filteredClasses,
                                  selectedClassId: selectedClass.id,
                                  onOpenDetail: _openDetail,
                                  onSelect: (classId) {
                                    setState(() {
                                      _selectedClassId = classId;
                                      _rememberViewState();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: _ClassDetailRail(
                                  classroom: selectedClass,
                                  onOpenDetail: () => _openDetail(selectedClass),
                                  onOpenStudents: () => _openStudents(selectedClass),
                                  onOpenLesson: () => _openLesson(selectedClass),
                                  onOpenDocument: () => _openDocument(selectedClass),
                                  onOpenLibrary: () => _openLibrary(selectedClass),
                                ),
                              ),
                            ],
                          )
                  else ...[
                    if (selectedClass == null)
                      WorkspaceMessageBanner.warning(
                        title: '当前没有班级数据',
                        message: _isLoading
                            ? '班级数据仍在加载中。'
                            : '当前机构下还没有班级档案，请先新增班级或切换到有数据的机构。',
                      )
                    else ...[
                      _ClassDetailRail(
                        classroom: selectedClass,
                        onOpenDetail: () => _openDetail(selectedClass),
                        onOpenStudents: () => _openStudents(selectedClass),
                        onOpenLesson: () => _openLesson(selectedClass),
                        onOpenDocument: () => _openDocument(selectedClass),
                        onOpenLibrary: () => _openLibrary(selectedClass),
                      ),
                      const SizedBox(height: 16),
                      _ClassListPanel(
                        classes: filteredClasses,
                        selectedClassId: selectedClass.id,
                        onOpenDetail: _openDetail,
                        onSelect: (classId) {
                          setState(() {
                            _selectedClassId = classId;
                            _rememberViewState();
                          });
                        },
                      ),
                    ],
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

_ClassFilter _classFilterFromLabel(String label) {
  return _ClassFilter.values.firstWhere(
    (filter) => filter.label == label,
    orElse: () => _ClassFilter.all,
  );
}

class _ClassHeroSection extends StatelessWidget {
  const _ClassHeroSection({
    required this.classCount,
    required this.studentCount,
    required this.activeLessonCount,
    required this.linkedDocCount,
  });

  final int classCount;
  final int studentCount;
  final int activeLessonCount;
  final int linkedDocCount;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspaceHeroPanelPadding(context),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: '班级工作台',
            icon: Icons.groups_outlined,
          ),
          const SizedBox(height: 14),
          const Text(
            '把班级成员、教材版本与课堂资料关联到同一条教研链路里。',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '首版先用结构化工作页承接班级名册、资料联动和课堂节奏，后续再把真实班级模型和成员调整流接进来。',
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
              WorkspaceMetricPill(label: '班级数', value: '$classCount'),
              WorkspaceMetricPill(label: '学生总数', value: '$studentCount'),
              WorkspaceMetricPill(
                label: '本周课堂',
                value: '$activeLessonCount',
                highlight: activeLessonCount > 0,
              ),
              WorkspaceMetricPill(label: '联动资料', value: '$linkedDocCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassListPanel extends StatelessWidget {
  const _ClassListPanel({
    required this.classes,
    required this.selectedClassId,
    required this.onOpenDetail,
    required this.onSelect,
  });

  final List<ClassWorkspaceRecord> classes;
  final String selectedClassId;
  final ValueChanged<ClassWorkspaceRecord> onOpenDetail;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '班级列表',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当前结果 ${classes.length} 个班级，按班级规模、资料侧重点和课堂活跃度快速切换。',
            style: const TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          ...classes.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ClassCard(
                classroom: item,
                selected: item.id == selectedClassId,
                onTap: () => onSelect(item.id),
                onOpenDetail: () => onOpenDetail(item),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classroom,
    required this.selected,
    required this.onTap,
    required this.onOpenDetail,
  });

  final ClassWorkspaceRecord classroom;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpenDetail;

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
                          classroom.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: TelegramPalette.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${classroom.stageLabel} · ${classroom.teacherLabel}',
                          style: const TextStyle(
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  WorkspaceInfoPill(value: classroom.activityLabel),
                  IconButton(
                    onPressed: onOpenDetail,
                    tooltip: '查看班级详情',
                    icon: const Icon(Icons.open_in_new_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  WorkspaceInfoPill(label: '规模', value: classroom.classSizeLabel),
                  WorkspaceInfoPill(
                      label: '教材', value: classroom.textbookLabel),
                  WorkspaceInfoPill(
                      label: '当前课堂', value: classroom.lessonFocusLabel),
                  WorkspaceInfoPill(label: '资料', value: classroom.latestDocLabel),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                classroom.summary,
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

class _ClassDetailRail extends StatelessWidget {
  const _ClassDetailRail({
    required this.classroom,
    required this.onOpenDetail,
    required this.onOpenStudents,
    required this.onOpenLesson,
    required this.onOpenDocument,
    required this.onOpenLibrary,
  });

  final ClassWorkspaceRecord classroom;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenLesson;
  final VoidCallback onOpenDocument;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      backgroundColor: TelegramPalette.surfaceAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前班级摘要',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            classroom.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${classroom.studentCount} 人 · ${classroom.weeklyLessonCount} 节本周课堂',
            style: const TextStyle(color: TelegramPalette.textMuted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              WorkspaceMetricPill(
                  label: '教材版本', value: classroom.textbookLabel),
              WorkspaceMetricPill(
                  label: '最近资料', value: classroom.latestDocLabel),
              WorkspaceMetricPill(
                  label: '当前课堂', value: classroom.lessonFocusLabel),
              WorkspaceMetricPill(label: '规模', value: classroom.classSizeLabel),
            ],
          ),
          const SizedBox(height: 16),
          WorkspaceMessageBanner.info(
            title: '班级结构',
            message: classroom.structureInsight,
          ),
          const SizedBox(height: 16),
          const Text(
            '本周重点',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: TelegramPalette.textStrong,
            ),
          ),
          const SizedBox(height: 10),
          ...classroom.highlights.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WorkspaceBulletPoint(text: point),
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceMessageBanner.info(
            title: '下一步动作',
            message: classroom.nextStep,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenDetail,
                icon: const Icon(Icons.groups_outlined, size: 18),
                label: const Text('查看班级详情'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenStudents,
                icon: const Icon(Icons.school_outlined, size: 18),
                label: Text('查看${classroom.focusStudentName}'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenLesson,
                icon: const Icon(Icons.schedule_outlined, size: 18),
                label: Text('查看${classroom.lessonFocusLabel}'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenDocument,
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text('打开${classroom.latestDocLabel}'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenLibrary,
                icon: const Icon(Icons.search_outlined, size: 18),
                label: const Text('关联题库'),
              ),
              const WorkspaceFilterPill(
                label: '当前班级页',
                icon: Icons.groups_outlined,
                selected: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
