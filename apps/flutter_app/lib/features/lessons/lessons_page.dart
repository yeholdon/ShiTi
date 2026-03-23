import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_services.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_overview_page.dart';
import '../shared/workspace_shell.dart';

class LessonsPage extends StatelessWidget {
  const LessonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final activeTenant = AppServices.instance.activeTenant;
    final tenantScope = activeTenant == null
        ? '未选择机构'
        : activeTenant.isPersonal
            ? '个人工作区'
            : '机构工作区';

    return WorkspaceOverviewPage(
      currentModule: WorkspaceModule.lessons,
      onSelectModule: (module) => navigateToWorkspaceModule(context, module),
      topTitle: '课堂管理',
      topSubtitle: '围绕每一堂课的时间、班级、文档资料和课后反馈，建立真正可回看的课堂工作台。',
      searchHint: '搜索课堂主题、班级、讲义、试卷或课后反馈',
      heroEyebrow: 'Lesson Timeline',
      heroTitle: '把每一堂课的备课、讲义、试卷与反馈整理成可回看的课堂时间线。',
      heroDescription: '课堂模块会成为班级、文档、学生反馈和课后分析的汇聚入口，让每一堂课都能回看资料、表现和后续跟进。',
      heroMetrics: const [
        WorkspaceOverviewMetric(
            label: '课堂时间线', value: '按时间组织', highlight: true),
        WorkspaceOverviewMetric(label: '资料关联', value: '讲义 / 试卷'),
        WorkspaceOverviewMetric(label: '课后反馈', value: '按班级回看'),
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
          eyebrow: '时间线',
          title: '课堂编排',
          subtitle: '每个班级可以承接不同时间的课堂，每个课堂对应一堂真实课程。',
          points: [
            '按上课时间、班级和资料类型组织课堂记录。',
            '课堂可以关联讲义、试卷、排版资料和课后反馈。',
            '支持回看课堂使用过的文档与导出结果，而不只是静态记录。',
          ],
        ),
        WorkspaceOverviewSection(
          eyebrow: '反馈',
          title: '课后沉淀',
          subtitle: '把课堂反馈重新沉淀到学生档案、班级分析和题库复盘里。',
          points: [
            '支持按课堂记录学生反馈、疑难点和课后跟进任务。',
            '课堂反馈会成为学生画像和班级复盘的重要输入。',
            '后续会承接课堂后测、讲义使用情况和班级表现对比。',
          ],
        ),
      ],
      asideTitle: '课堂模块方向',
      asideSubtitle: '这一版先把课堂页接进工作台结构，后续重点是把班级、学生和文档资料真正串起来。',
      asidePoints: const [
        '课堂会成为班级与文档之间的桥，而不是单独的课时记录表。',
        '后续会重点支持按课堂回看讲义、试卷、学生反馈和课后任务。',
        '真实数据接入后，这里会是最重要的教学闭环入口之一。',
      ],
    );
  }
}
