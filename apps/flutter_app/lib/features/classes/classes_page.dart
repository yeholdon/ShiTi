import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_services.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_overview_page.dart';
import '../shared/workspace_shell.dart';

class ClassesPage extends StatelessWidget {
  const ClassesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final activeTenant = AppServices.instance.activeTenant;
    final tenantScope = activeTenant == null
        ? '未选择机构'
        : activeTenant.isPersonal
            ? '个人工作区'
            : '机构工作区';

    return WorkspaceOverviewPage(
      currentModule: WorkspaceModule.classes,
      onSelectModule: (module) => navigateToWorkspaceModule(context, module),
      topTitle: '班级管理',
      topSubtitle: '围绕班级规模、成员调整、教材版本与阶段目标，建立可动态维护的班级工作台。',
      searchHint: '搜索班级名称、人数规模、教材版本或任课节奏',
      heroEyebrow: 'Classroom Groups',
      heroTitle: '把班级成员、教材与课堂资料关联到同一条教研链路里。',
      heroDescription: '班级模块会承接不同人数规模的班级，以及班级与学生、课堂、讲义和试卷之间的对应关系。',
      heroMetrics: const [
        WorkspaceOverviewMetric(label: '班级结构', value: '动态调整', highlight: true),
        WorkspaceOverviewMetric(label: '成员规模', value: '灵活扩缩'),
        WorkspaceOverviewMetric(label: '资料联动', value: '讲义 / 试卷 / 课堂'),
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
          eyebrow: '组织',
          title: '班级成员管理',
          subtitle: '支持创建不同规模的班级，并随教学周期动态调整成员、人数与教材版本。',
          points: [
            '支持班级增删、成员调整、人数扩缩与阶段迁移。',
            '每个班级可以承接不同教材版本、教学计划和讲义资料。',
            '后续会联动学生档案，把班级内成员变化沉淀到个人画像。',
          ],
        ),
        WorkspaceOverviewSection(
          eyebrow: '联动',
          title: '班级与课堂资料',
          subtitle: '班级不是孤立名单，而是课堂、讲义、试卷与反馈的组织层。',
          points: [
            '班级可以关联不同时间的课堂与对应文档。',
            '支持按班级查看最近讲义、试卷和课堂反馈轨迹。',
            '为后续课堂分析与分层资料投放提供结构化入口。',
          ],
        ),
      ],
      asideTitle: '班级模块方向',
      asideSubtitle: '这一版先把班级管理接进新版结构，下一步会把真实班级模型、成员调整和课堂联动真正接进来。',
      asidePoints: const [
        '班级会成为学生与课堂之间的中间组织层，而不是单独的名册页面。',
        '班级规模和教材版本会直接影响课堂资料推荐与课后反馈汇总。',
        '机构管理员和普通教师后续会在这里拥有不同的班级管理能力。',
      ],
    );
  }
}
