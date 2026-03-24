import 'package:flutter/material.dart';

import '../../core/models/classes_page_args.dart';
import '../../core/models/documents_page_args.dart';
import '../../core/models/lessons_page_args.dart';
import '../../core/models/students_page_args.dart';
import '../../core/config/app_config.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_flow_panel.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';
import '../../router/app_router.dart';

enum _StudentFilter {
  all('全部学生'),
  risk('待跟进'),
  improving('近期进步'),
  habits('习惯观察');

  const _StudentFilter(this.label);
  final String label;
}

class StudentsPage extends StatefulWidget {
  const StudentsPage({this.args, super.key});

  final StudentsPageArgs? args;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  _StudentFilter _filter = _StudentFilter.all;
  late String _selectedStudentId =
      widget.args?.focusStudentId ?? _studentRecords.first.id;

  void _openClass(_StudentRecord student) {
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
  }

  void _openLesson(_StudentRecord student) {
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
  }

  void _openDocument(_StudentRecord student) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.documents,
      (route) => false,
      arguments: DocumentsPageArgs(
        focusDocumentId: student.documentId,
        flashMessage: '已定位到 ${student.documentName}，可继续整理学生跟进资料。',
        highlightTitle: '当前学生跟进资料',
        highlightDetail:
            '${student.documentName} 正承接 ${student.name} 的跟进任务，可继续补讲义、试卷与课堂反馈。',
        feedbackBadgeLabel: '学生跟进',
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
    final filteredRecords = _studentRecords
        .where((student) => switch (_filter) {
              _StudentFilter.all => true,
              _StudentFilter.risk => student.followUpLevel == '重点跟进',
              _StudentFilter.improving => student.trendLabel == '近期进步',
              _StudentFilter.habits => student.habitTag.isNotEmpty,
            })
        .toList(growable: false);
    final selectedRecord = filteredRecords.firstWhere(
      (student) => student.id == _selectedStudentId,
      orElse: () => filteredRecords.isNotEmpty
          ? filteredRecords.first
          : _studentRecords.first,
    );
    final highlightTitle = widget.args?.highlightTitle;
    final highlightDetail = widget.args?.highlightDetail;
    final feedbackBadgeLabel = widget.args?.feedbackBadgeLabel;

    return Scaffold(
      body: WorkspaceModuleShell(
        currentModule: WorkspaceModule.students,
        onSelectModule: (module) => navigateToWorkspaceModule(context, module),
        title: '学生管理',
        subtitle: '围绕学生画像、历史成绩、错题跟进与学习习惯，组织统一的学生工作台。',
        searchHint: '搜索学生姓名、班级、教材版本、学习习惯或错题轨迹',
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
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('添加学生'),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final showAside = constraints.maxWidth >= 1180;
            return workspaceConstrainedContent(
              context,
              child: ListView(
                padding: workspacePagePadding(context),
                children: [
                  _StudentHeroSection(
                    totalCount: _studentRecords.length,
                    riskCount: _studentRecords
                        .where((student) => student.followUpLevel == '重点跟进')
                        .length,
                    linkedClassCount: _studentRecords
                        .map((student) => student.className)
                        .toSet()
                        .length,
                    trackedWrongCount: _studentRecords.fold<int>(
                      0,
                      (sum, student) => sum + student.wrongCount,
                    ),
                  ),
                  const SizedBox(height: 18),
                  WorkspacePanel(
                    padding: workspacePanelPadding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '当前筛选',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TelegramPalette.textStrong,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _StudentFilter.values
                              .map(
                                (filter) => WorkspaceFilterPill(
                                  label: filter.label,
                                  selected: _filter == filter,
                                  onTap: () {
                                    setState(() {
                                      _filter = filter;
                                      if (!filteredRecords.any(
                                        (student) =>
                                            student.id == _selectedStudentId,
                                      )) {
                                        _selectedStudentId =
                                            _studentRecords.first.id;
                                      }
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
                                label: '当前学生',
                                value: selectedRecord.name,
                              ),
                              WorkspaceInfoPill(
                                label: '当前班级',
                                value: selectedRecord.className,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            highlightTitle ?? '当前学生上下文',
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
                    currentModule: WorkspaceModule.students,
                    title: '联动工作流',
                    subtitle: '学生画像不是孤立名册，下一步通常要回到班级、课堂和文档资料里继续推进。',
                    actions: [
                      WorkspaceFlowAction(
                        module: WorkspaceModule.classes,
                        icon: Icons.groups_outlined,
                        label: '查看关联班级',
                        description: '回到班级管理，确认班级规模、教材版本和当前课堂节奏。',
                      ),
                      WorkspaceFlowAction(
                        module: WorkspaceModule.lessons,
                        icon: Icons.schedule_outlined,
                        label: '回看课堂反馈',
                        description: '把本次课堂表现和课后反馈重新挂回学生画像。',
                      ),
                      WorkspaceFlowAction(
                        module: WorkspaceModule.documents,
                        icon: Icons.description_outlined,
                        label: '整理文档资料',
                        description: '继续调整讲义或试卷，让学生跟进任务真正落到资料里。',
                      ),
                      WorkspaceFlowAction(
                        module: WorkspaceModule.students,
                        icon: Icons.person_search_outlined,
                        label: '当前仍在学生页',
                        description: '先筛出重点跟进学生，再决定回流到班级、课堂或文档。',
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
                          child: _StudentRosterPanel(
                            records: filteredRecords,
                            selectedStudentId: selectedRecord.id,
                            onSelect: (studentId) {
                              setState(() {
                                _selectedStudentId = studentId;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _StudentDetailRail(
                            student: selectedRecord,
                            onOpenClass: () => _openClass(selectedRecord),
                            onOpenLesson: () => _openLesson(selectedRecord),
                            onOpenDocument: () => _openDocument(selectedRecord),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _StudentDetailRail(
                      student: selectedRecord,
                      onOpenClass: () => _openClass(selectedRecord),
                      onOpenLesson: () => _openLesson(selectedRecord),
                      onOpenDocument: () => _openDocument(selectedRecord),
                    ),
                    const SizedBox(height: 16),
                    _StudentRosterPanel(
                      records: filteredRecords,
                      selectedStudentId: selectedRecord.id,
                      onSelect: (studentId) {
                        setState(() {
                          _selectedStudentId = studentId;
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

class _StudentHeroSection extends StatelessWidget {
  const _StudentHeroSection({
    required this.totalCount,
    required this.riskCount,
    required this.linkedClassCount,
    required this.trackedWrongCount,
  });

  final int totalCount;
  final int riskCount;
  final int linkedClassCount;
  final int trackedWrongCount;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspaceHeroPanelPadding(context),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: '学生工作台',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 14),
          const Text(
            '把学生画像、成绩变化和错题跟进放在同一条教研视图里。',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '首版先用真实工作页结构承接学生档案、错题轨迹与学习习惯，后续再把新版学生数据模型逐步接入。',
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
              WorkspaceMetricPill(label: '学生总数', value: '$totalCount'),
              WorkspaceMetricPill(
                label: '重点跟进',
                value: '$riskCount',
                highlight: riskCount > 0,
              ),
              WorkspaceMetricPill(label: '关联班级', value: '$linkedClassCount'),
              WorkspaceMetricPill(label: '在追错题', value: '$trackedWrongCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentRosterPanel extends StatelessWidget {
  const _StudentRosterPanel({
    required this.records,
    required this.selectedStudentId,
    required this.onSelect,
  });

  final List<_StudentRecord> records;
  final String selectedStudentId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '学生名册',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当前结果 ${records.length} 人，按成绩趋势、错题风险和学习习惯快速定位需要跟进的学生。',
            style: const TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          ...records.map(
            (student) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StudentCard(
                student: student,
                selected: student.id == selectedStudentId,
                onTap: () => onSelect(student.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.selected,
    required this.onTap,
  });

  final _StudentRecord student;
  final bool selected;
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
                          student.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: TelegramPalette.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${student.className} · ${student.gradeLabel} · ${student.subjectLabel}',
                          style: const TextStyle(
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  WorkspaceInfoPill(
                    value: student.followUpLevel,
                    highlight: student.followUpLevel == '重点跟进',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  WorkspaceInfoPill(label: '教材', value: student.textbookLabel),
                  WorkspaceInfoPill(label: '成绩', value: student.scoreLabel),
                  WorkspaceInfoPill(
                      label: '错题', value: student.wrongCountLabel),
                  WorkspaceInfoPill(label: '习惯', value: student.habitTag),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                student.summary,
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

class _StudentDetailRail extends StatelessWidget {
  const _StudentDetailRail({
    required this.student,
    required this.onOpenClass,
    required this.onOpenLesson,
    required this.onOpenDocument,
  });

  final _StudentRecord student;
  final VoidCallback onOpenClass;
  final VoidCallback onOpenLesson;
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
            '当前学生画像',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            student.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${student.className} · ${student.gradeLabel}',
            style: const TextStyle(color: TelegramPalette.textMuted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              WorkspaceMetricPill(label: '最近测评', value: student.scoreLabel),
              WorkspaceMetricPill(
                  label: '历史成绩', value: student.historyTrendLabel),
              WorkspaceMetricPill(
                  label: '错题数', value: student.wrongCountLabel),
              WorkspaceMetricPill(label: '教材版本', value: student.textbookLabel),
            ],
          ),
          const SizedBox(height: 16),
          WorkspaceMessageBanner.warning(
            title: '学习习惯',
            message: student.habitInsight,
          ),
          const SizedBox(height: 16),
          const Text(
            '跟进重点',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: TelegramPalette.textStrong,
            ),
          ),
          const SizedBox(height: 10),
          ...student.highlights.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WorkspaceBulletPoint(text: point),
            ),
          ),
          const SizedBox(height: 16),
          WorkspaceMessageBanner.info(
            title: '下一步动作',
            message: student.nextStep,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenClass,
                icon: const Icon(Icons.groups_outlined, size: 18),
                label: Text('查看${student.className}'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenLesson,
                icon: const Icon(Icons.schedule_outlined, size: 18),
                label: const Text('回看关联课堂'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenDocument,
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text('打开${student.documentName}'),
              ),
              const WorkspaceFilterPill(
                label: '当前学生页',
                icon: Icons.school_outlined,
                selected: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentRecord {
  const _StudentRecord({
    required this.id,
    required this.name,
    required this.classId,
    required this.className,
    required this.lessonId,
    required this.documentId,
    required this.documentName,
    required this.gradeLabel,
    required this.subjectLabel,
    required this.textbookLabel,
    required this.trendLabel,
    required this.habitTag,
    required this.habitInsight,
    required this.followUpLevel,
    required this.summary,
    required this.scoreLabel,
    required this.historyTrendLabel,
    required this.wrongCountLabel,
    required this.wrongCount,
    required this.highlights,
    required this.nextStep,
  });

  final String id;
  final String name;
  final String classId;
  final String className;
  final String lessonId;
  final String documentId;
  final String documentName;
  final String gradeLabel;
  final String subjectLabel;
  final String textbookLabel;
  final String trendLabel;
  final String habitTag;
  final String habitInsight;
  final String followUpLevel;
  final String summary;
  final String scoreLabel;
  final String historyTrendLabel;
  final String wrongCountLabel;
  final int wrongCount;
  final List<String> highlights;
  final String nextStep;
}

const List<_StudentRecord> _studentRecords = [
  _StudentRecord(
    id: 'student-1',
    name: '林之涵',
    classId: 'class-1',
    className: '九年级尖子班',
    lessonId: 'lesson-1',
    documentId: 'doc-2',
    documentName: '二次函数周测卷',
    gradeLabel: '初中 · 九年级下',
    subjectLabel: '数学',
    textbookLabel: '浙教版',
    trendLabel: '近期进步',
    habitTag: '订正及时',
    habitInsight: '课后会主动回看讲义边注，订正完成度高，适合逐步增加开放题表达训练。',
    followUpLevel: '常规关注',
    summary: '最近两次函数专题测试稳步提升，几何综合题仍然需要在证明链条上加强拆解。',
    scoreLabel: '92 / 100',
    historyTrendLabel: '86 → 89 → 92',
    wrongCountLabel: '6 道',
    wrongCount: 6,
    highlights: [
      '相似三角形与二次函数综合题开始具备完整表达。',
      '课堂互动积极，课后讲义订正完成度高。',
      '可以逐步提高压轴题和开放题比重。',
    ],
    nextStep: '下一轮讲义里增加 2 道几何压轴题，并安排一次口头讲解复盘。',
  ),
  _StudentRecord(
    id: 'student-2',
    name: '徐若楠',
    classId: 'class-2',
    className: '九年级提高班',
    lessonId: 'lesson-2',
    documentId: 'doc-1',
    documentName: '九上相似专题讲义',
    gradeLabel: '初中 · 九年级下',
    subjectLabel: '数学',
    textbookLabel: '浙教版',
    trendLabel: '波动明显',
    habitTag: '审题偏快',
    habitInsight: '课堂中容易直接下笔，跳过已知条件整理，适合在讲义里加入审题停顿框。',
    followUpLevel: '重点跟进',
    summary: '函数图像题失分较多，课堂作答时容易跳步骤，需要把题干拆解与审题节奏纳入跟进。',
    scoreLabel: '71 / 100',
    historyTrendLabel: '78 → 69 → 71',
    wrongCountLabel: '14 道',
    wrongCount: 14,
    highlights: [
      '函数图像题和表格信息题错误集中。',
      '错题订正完成，但口头复述仍不稳定。',
      '需要通过讲义中的“已知/求证”拆解框减缓审题节奏。',
    ],
    nextStep: '下节课前单独推送函数图像复盘讲义，并在课堂里安排一次分步板演。',
  ),
  _StudentRecord(
    id: 'student-3',
    name: '陈嘉言',
    classId: 'class-3',
    className: '个人工作区样例',
    lessonId: 'lesson-3',
    documentId: 'doc-1',
    documentName: '九上相似专题讲义',
    gradeLabel: '高中 · 高一',
    subjectLabel: '物理',
    textbookLabel: '人教版',
    trendLabel: '稳定',
    habitTag: '错题回看',
    habitInsight: '习惯在课后回看错题与讲义边注，适合用个人工作区持续沉淀单人学习轨迹。',
    followUpLevel: '常规关注',
    summary: '力学计算题完成度稳定，个人工作区里重点跟踪的是错题回看的频次与课堂反馈衔接。',
    scoreLabel: '84 / 100',
    historyTrendLabel: '81 → 83 → 84',
    wrongCountLabel: '9 道',
    wrongCount: 9,
    highlights: [
      '习惯在课后回看错题与讲义边注。',
      '需要强化图像信息提取和物理量转化。',
      '适合作为个人工作区样例，后续验证课堂反馈回流。',
    ],
    nextStep: '将下一次课堂反馈与错题标签联动，验证个人工作区闭环。',
  ),
];
