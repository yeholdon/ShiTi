import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_services.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_overview_page.dart';
import '../shared/workspace_shell.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final activeTenant = AppServices.instance.activeTenant;
    final tenantScope = activeTenant == null
        ? '未选择机构'
        : activeTenant.isPersonal
            ? '个人工作区'
            : '机构工作区';

    return WorkspaceOverviewPage(
      currentModule: WorkspaceModule.settings,
      onSelectModule: (module) => navigateToWorkspaceModule(context, module),
      topTitle: '设置',
      topSubtitle: '围绕账号、机构、本地题库、云端同步与导出偏好，整理跨平台教研平台的设置入口。',
      searchHint: '搜索账号安全、机构权限、本地题库、云端同步或导出设置',
      heroEyebrow: 'Settings Console',
      heroTitle: '把账号、机构、本地题库与云端同步设置整理进一套清晰的控制台里。',
      heroDescription: '设置模块会承接账号安全、机构权限、本地题库与云端题库模式、导出偏好和跨平台同步规则。',
      heroMetrics: const [
        WorkspaceOverviewMetric(
            label: '账号安全', value: '密码 / 会话', highlight: true),
        WorkspaceOverviewMetric(label: '题库存储', value: '本地 / 云端'),
        WorkspaceOverviewMetric(label: '同步策略', value: '跨平台可控'),
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
          eyebrow: '存储',
          title: '题库存储与同步',
          subtitle: '围绕新版数据模型里的本地题库与云端题库，建立可解释的设置入口。',
          points: [
            '桌面端后续会支持本地题库模式，并明确本地数据库安装与访问边界。',
            '云端题库会支持跨桌面与移动端访问，以及题库级 read / write 授权。',
            '设置页会承接默认题库、同步策略和导出偏好的统一配置。',
          ],
        ),
        WorkspaceOverviewSection(
          eyebrow: '权限',
          title: '账号与机构设置',
          subtitle: '把账号安全、机构切换、成员权限与题库授权整理在一处管理。',
          points: [
            '支持查看当前账号、个人工作区和机构工作区上下文。',
            '机构负责人和管理员后续会在这里管理题库授权和成员范围。',
            '个人工作区与机构工作区会保持清晰边界，不再混在同一入口里。',
          ],
        ),
      ],
      asideTitle: '设置模块方向',
      asideSubtitle: '这一版先把设置模块接进新版工作台结构，后续重点是承接本地题库与云端题库配置。',
      asidePoints: const [
        '设置会是个人工作区、机构工作区和题库存储模式的总入口。',
        '本地题库只在桌面端可用，云端题库可跨桌面与移动端共享。',
        '后续会补真实设置项，而不是停留在说明页。',
      ],
    );
  }
}
