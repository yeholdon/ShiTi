import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';

enum _ClassFilter {
  all('全部班级'),
  active('近期活跃'),
  exam('测评班级'),
  handout('讲义班级');

  const _ClassFilter(this.label);
  final String label;
}

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  _ClassFilter _filter = _ClassFilter.all;
  String _selectedClassId = _classRecords.first.id;

  @override
  Widget build(BuildContext context) {
    final activeTenant = AppServices.instance.activeTenant;
    final tenantScope = activeTenant == null
        ? '未选择机构'
        : activeTenant.isPersonal
            ? '个人工作区'
            : '机构工作区';
    final filteredClasses = _classRecords
        .where((item) => switch (_filter) {
              _ClassFilter.all => true,
              _ClassFilter.active => item.activityLabel == '本周活跃',
              _ClassFilter.exam => item.focusLabel == '试卷跟进',
              _ClassFilter.handout => item.focusLabel == '讲义整理',
            })
        .toList(growable: false);
    final selectedClass = filteredClasses.firstWhere(
      (item) => item.id == _selectedClassId,
      orElse: () => filteredClasses.isNotEmpty
          ? filteredClasses.first
          : _classRecords.first,
    );

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
          onPressed: () {},
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
                    classCount: _classRecords.length,
                    studentCount: _classRecords.fold<int>(
                      0,
                      (sum, item) => sum + item.studentCount,
                    ),
                    activeLessonCount: _classRecords.fold<int>(
                      0,
                      (sum, item) => sum + item.weeklyLessonCount,
                    ),
                    linkedDocCount: _classRecords
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _ClassFilter.values
                              .map(
                                (filter) => WorkspaceFilterPill(
                                  label: filter.label,
                                  selected: _filter == filter,
                                  onTap: () {
                                    setState(() {
                                      _filter = filter;
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
                  const SizedBox(height: 18),
                  if (showAside)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _ClassListPanel(
                            classes: filteredClasses,
                            selectedClassId: selectedClass.id,
                            onSelect: (classId) {
                              setState(() {
                                _selectedClassId = classId;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _ClassDetailRail(classroom: selectedClass),
                        ),
                      ],
                    )
                  else ...[
                    _ClassDetailRail(classroom: selectedClass),
                    const SizedBox(height: 16),
                    _ClassListPanel(
                      classes: filteredClasses,
                      selectedClassId: selectedClass.id,
                      onSelect: (classId) {
                        setState(() {
                          _selectedClassId = classId;
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
    required this.onSelect,
  });

  final List<_ClassRecord> classes;
  final String selectedClassId;
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
  });

  final _ClassRecord classroom;
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
  });

  final _ClassRecord classroom;

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
        ],
      ),
    );
  }
}

class _ClassRecord {
  const _ClassRecord({
    required this.id,
    required this.name,
    required this.stageLabel,
    required this.teacherLabel,
    required this.textbookLabel,
    required this.focusLabel,
    required this.activityLabel,
    required this.classSizeLabel,
    required this.lessonFocusLabel,
    required this.structureInsight,
    required this.studentCount,
    required this.weeklyLessonCount,
    required this.latestDocLabel,
    required this.summary,
    required this.highlights,
    required this.nextStep,
  });

  final String id;
  final String name;
  final String stageLabel;
  final String teacherLabel;
  final String textbookLabel;
  final String focusLabel;
  final String activityLabel;
  final String classSizeLabel;
  final String lessonFocusLabel;
  final String structureInsight;
  final int studentCount;
  final int weeklyLessonCount;
  final String latestDocLabel;
  final String summary;
  final List<String> highlights;
  final String nextStep;
}

const List<_ClassRecord> _classRecords = [
  _ClassRecord(
    id: 'class-1',
    name: '九年级尖子班',
    stageLabel: '初中 · 冲刺组',
    teacherLabel: '主讲：陈老师',
    textbookLabel: '浙教版',
    focusLabel: '试卷跟进',
    activityLabel: '本周活跃',
    classSizeLabel: '26 人 · 小班精练',
    lessonFocusLabel: '复盘课',
    structureInsight: '班级规模适合精细追踪压轴题表达，可把课堂反馈直接回收进学生画像。',
    studentCount: 26,
    weeklyLessonCount: 3,
    latestDocLabel: '二次函数周测卷',
    summary: '当前重点是周测卷复盘和压轴题讲解，班级对讲义中的板书提示响应较好。',
    highlights: [
      '本周安排 3 节课堂，2 份试卷回看，1 份讲义补充。',
      '需要关注中段学生在函数压轴题上的分层差异。',
      '最近导出资料以试卷为主，讲义需要补一次课堂版。',
    ],
    nextStep: '先补一份“压轴题拆解讲义”，再串到周四的专题复盘课里。',
  ),
  _ClassRecord(
    id: 'class-2',
    name: '九年级提高班',
    stageLabel: '初中 · 提高组',
    teacherLabel: '主讲：沈老师',
    textbookLabel: '浙教版',
    focusLabel: '讲义整理',
    activityLabel: '本周活跃',
    classSizeLabel: '34 人 · 常规班型',
    lessonFocusLabel: '讲义推进',
    structureInsight: '班级人数偏多，讲义与课堂追问需要更强的分层结构，短测更适合作为课后回收。',
    studentCount: 34,
    weeklyLessonCount: 2,
    latestDocLabel: '相似三角形讲义',
    summary: '班级目前更适合讲义驱动，课堂中对例题拆解和追问框的反馈较好。',
    highlights: [
      '最近一周以讲义整理和板书节奏优化为主。',
      '需要补一次随堂小测，把讲义反馈收回到题库复盘。',
      '班级人数较多，课堂任务要进一步分层。',
    ],
    nextStep: '下节课前补一份短测卷，并按讲义段落安排分层互动。',
  ),
  _ClassRecord(
    id: 'class-3',
    name: '高一物理培优班',
    stageLabel: '高中 · 培优组',
    teacherLabel: '主讲：周老师',
    textbookLabel: '人教版',
    focusLabel: '课堂联动',
    activityLabel: '待排课',
    classSizeLabel: '18 人 · 培优小组',
    lessonFocusLabel: '模型拆解',
    structureInsight: '小规模培优班适合把课堂、讲义和学生反馈绑得更紧，先跑通课堂闭环样例。',
    studentCount: 18,
    weeklyLessonCount: 1,
    latestDocLabel: '力学建模讲义',
    summary: '当前在验证课堂、学生画像和讲义之间的联动路径，班级规模适合做更细的反馈跟进。',
    highlights: [
      '班级规模较小，适合先跑课堂反馈样例。',
      '本周只有 1 节课，适合作为课堂管理首批联动样例。',
      '讲义和课后任务可以更紧密地串联。',
    ],
    nextStep: '先用一节课堂跑通“讲义 -> 反馈 -> 学生画像”的闭环。',
  ),
];
