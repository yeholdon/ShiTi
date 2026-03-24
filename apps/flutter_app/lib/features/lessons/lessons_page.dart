import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_flow_panel.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';

enum _LessonFilter {
  all('全部课堂'),
  thisWeek('本周进行'),
  feedback('待收反馈'),
  docs('资料联动');

  const _LessonFilter(this.label);
  final String label;
}

class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  _LessonFilter _filter = _LessonFilter.all;
  String _selectedLessonId = _lessonRecords.first.id;

  @override
  Widget build(BuildContext context) {
    final activeTenant = AppServices.instance.activeTenant;
    final tenantScope = activeTenant == null
        ? '未选择机构'
        : activeTenant.isPersonal
            ? '个人工作区'
            : '机构工作区';
    final filteredLessons = _lessonRecords
        .where((lesson) => switch (_filter) {
              _LessonFilter.all => true,
              _LessonFilter.thisWeek => lesson.scheduleTag == '本周进行',
              _LessonFilter.feedback => lesson.feedbackStatus == '待回收',
              _LessonFilter.docs => lesson.documentFocus.isNotEmpty,
            })
        .toList(growable: false);
    final selectedLesson = filteredLessons.firstWhere(
      (lesson) => lesson.id == _selectedLessonId,
      orElse: () => filteredLessons.isNotEmpty
          ? filteredLessons.first
          : _lessonRecords.first,
    );

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
                    lessonCount: _lessonRecords.length,
                    feedbackCount: _lessonRecords
                        .where((lesson) => lesson.feedbackStatus == '待回收')
                        .length,
                    linkedDocsCount: _lessonRecords
                        .map((lesson) => lesson.documentFocus)
                        .where((focus) => focus.isNotEmpty)
                        .toSet()
                        .length,
                    linkedClassCount: _lessonRecords
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _LessonFilter.values
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
                            onSelect: (lessonId) {
                              setState(() {
                                _selectedLessonId = lessonId;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _LessonDetailRail(lesson: selectedLesson),
                        ),
                      ],
                    )
                  else ...[
                    _LessonDetailRail(lesson: selectedLesson),
                    const SizedBox(height: 16),
                    _LessonListPanel(
                      lessons: filteredLessons,
                      selectedLessonId: selectedLesson.id,
                      onSelect: (lessonId) {
                        setState(() {
                          _selectedLessonId = lessonId;
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
    required this.onSelect,
  });

  final List<_LessonRecord> lessons;
  final String selectedLessonId;
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
    required this.onTap,
  });

  final _LessonRecord lesson;
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
  });

  final _LessonRecord lesson;

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
          const WorkspaceModuleQuickActions(
            currentModule: WorkspaceModule.lessons,
            actions: [
              WorkspaceFlowAction(
                module: WorkspaceModule.classes,
                icon: Icons.groups_outlined,
                label: '打开班级',
                description: '',
              ),
              WorkspaceFlowAction(
                module: WorkspaceModule.students,
                icon: Icons.school_outlined,
                label: '打开学生',
                description: '',
              ),
              WorkspaceFlowAction(
                module: WorkspaceModule.documents,
                icon: Icons.description_outlined,
                label: '打开文档',
                description: '',
              ),
              WorkspaceFlowAction(
                module: WorkspaceModule.lessons,
                icon: Icons.schedule_outlined,
                label: '当前课堂页',
                description: '',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonRecord {
  const _LessonRecord({
    required this.id,
    required this.title,
    required this.className,
    required this.teacherLabel,
    required this.scheduleLabel,
    required this.scheduleTag,
    required this.classScopeLabel,
    required this.documentFocus,
    required this.feedbackStatus,
    required this.followUpLabel,
    required this.feedbackInsight,
    required this.summary,
    required this.highlights,
    required this.nextStep,
  });

  final String id;
  final String title;
  final String className;
  final String teacherLabel;
  final String scheduleLabel;
  final String scheduleTag;
  final String classScopeLabel;
  final String documentFocus;
  final String feedbackStatus;
  final String followUpLabel;
  final String feedbackInsight;
  final String summary;
  final List<String> highlights;
  final String nextStep;
}

const List<_LessonRecord> _lessonRecords = [
  _LessonRecord(
    id: 'lesson-1',
    title: '二次函数专题复盘课',
    className: '九年级尖子班',
    teacherLabel: '主讲：陈老师',
    scheduleLabel: '周三 19:00 - 20:30',
    scheduleTag: '本周进行',
    classScopeLabel: '九年级尖子班',
    documentFocus: '二次函数周测卷',
    feedbackStatus: '待回收',
    followUpLabel: '补讲义',
    feedbackInsight: '本节课后要重点回收压轴题口头讲解、错题订正和课堂参与反馈，方便回写学生画像。',
    summary: '这节课会先复盘周测卷，再补一页压轴题拆解讲义，课后需要回收错题与口头讲解反馈。',
    highlights: [
      '主资料是试卷 + 补充讲义，课堂结构更像复盘课。',
      '课后要记录 5 名重点学生的压轴题表达问题。',
      '下节课前需把课堂反馈回写到学生画像和题库复盘。',
    ],
    nextStep: '课后先收一轮错题反馈，再把讲义补充页挂到下节专题课。',
  ),
  _LessonRecord(
    id: 'lesson-2',
    title: '相似三角形讲义推进课',
    className: '九年级提高班',
    teacherLabel: '主讲：沈老师',
    scheduleLabel: '周四 18:30 - 20:00',
    scheduleTag: '本周进行',
    classScopeLabel: '九年级提高班',
    documentFocus: '相似三角形讲义',
    feedbackStatus: '已回收',
    followUpLabel: '短测跟进',
    feedbackInsight: '讲义反馈已收齐，下一轮重点是把课堂追问和课后短测结果重新沉淀到班级分层任务里。',
    summary: '本节以讲义推进为主，重点看例题拆解、课堂追问和课后短测之间的衔接。',
    highlights: [
      '讲义版式已经稳定，重点优化课堂追问节奏。',
      '反馈回收完成，可以开始沉淀短测题单。',
      '后续要把讲义反馈回流到班级分层任务里。',
    ],
    nextStep: '补一份短测卷，并在周末班级复盘里对齐讲义重点段落。',
  ),
  _LessonRecord(
    id: 'lesson-3',
    title: '高一力学模型拆解课',
    className: '高一物理培优班',
    teacherLabel: '主讲：周老师',
    scheduleLabel: '下周一 19:30 - 21:00',
    scheduleTag: '待准备',
    classScopeLabel: '高一物理培优班',
    documentFocus: '力学模型讲义',
    feedbackStatus: '待回收',
    followUpLabel: '资料待排版',
    feedbackInsight: '这节课的反馈重点是图像信息提取、模型识别和讲义图示是否足够清晰，适合先跑课堂样例。',
    summary: '课堂重点是把模型图像和文字描述拆开讲，当前最需要把讲义中的示意图和板书节奏补完整。',
    highlights: [
      '当前资料还在排版阶段，课堂前需完成最终导出。',
      '课后要收图像题理解反馈，验证讲义版式是否足够清晰。',
      '个人工作区里的物理样例可以先承接这条课堂时间线。',
    ],
    nextStep: '先完成力学讲义排版，再为课堂补一份图像辨析短练。',
  ),
];
