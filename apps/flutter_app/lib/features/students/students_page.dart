import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_services.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_overview_page.dart';
import '../shared/workspace_shell.dart';

class StudentsPage extends StatelessWidget {
  const StudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final activeTenant = AppServices.instance.activeTenant;
    final tenantScope = activeTenant == null
        ? '未选择机构'
        : activeTenant.isPersonal
            ? '个人工作区'
            : '机构工作区';

    return WorkspaceOverviewPage(
      currentModule: WorkspaceModule.students,
      onSelectModule: (module) => navigateToWorkspaceModule(context, module),
      topTitle: '学生管理',
      topSubtitle: '围绕学生画像、历史成绩、学习习惯与错题跟进，建立可持续更新的学生档案。',
      searchHint: '搜索学生姓名、教材版本、学习习惯或错题记录',
      heroEyebrow: 'Student Studio',
      heroTitle: '把学生画像、历史成绩与错题跟进放进同一套教研视图。',
      heroDescription: '学生模块会承接个人工作区和机构工作区下的学生名册，支持年级、教材版本、错题归因与学习习惯标签的统一整理。',
      heroMetrics: const [
        WorkspaceOverviewMetric(label: '学生档案', value: '待接入', highlight: true),
        WorkspaceOverviewMetric(label: '历史成绩', value: '多次测评'),
        WorkspaceOverviewMetric(label: '错题跟进', value: '持续更新'),
      ],
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
      sections: const [
        WorkspaceOverviewSection(
          eyebrow: '画像',
          title: '学生档案',
          subtitle: '围绕学生的基础信息、教材版本、阶段成绩和学习习惯建立长期档案。',
          points: [
            '支持按学段、年级、教材版本与机构来源管理学生名册。',
            '补齐历史成绩、能力标签、薄弱知识点和常见错因。',
            '为后续课堂反馈、讲义分发和错题追踪提供统一入口。',
          ],
        ),
        WorkspaceOverviewSection(
          eyebrow: '跟进',
          title: '错题与学习习惯',
          subtitle: '把学生在题库、讲义、试卷和课堂中的反馈沉淀成持续可用的教研资料。',
          points: [
            '记录学生错题、错因、订正情况和阶段变化。',
            '标记学习习惯、答题节奏、课堂参与度等辅助信息。',
            '支持按学生回看其题目轨迹和文档使用记录。',
          ],
        ),
      ],
      asideTitle: '模块首版范围',
      asideSubtitle: '这一版先把学生管理接进新版工作台信息架构，后续再承接真实学生模型与课堂反馈。',
      asidePoints: const [
        '学生档案结构会对齐新版数据模型里的年级、教材版本、历史成绩与错题字段。',
        '个人工作区和机构工作区都可以承接学生档案，但数据边界会跟随当前上下文切换。',
        '后续会和班级、课堂、题库反馈做联动，而不是只做孤立名册。',
      ],
    );
  }
}
