import 'package:flutter/material.dart';

import '../../core/theme/telegram_palette.dart';
import 'workspace_shell.dart';

enum WorkspaceModule {
  home,
  library,
  documents,
  students,
  classes,
  lessons,
  exports,
  account,
  settings,
}

class WorkspaceModuleShell extends StatelessWidget {
  const WorkspaceModuleShell({
    required this.currentModule,
    required this.onSelectModule,
    required this.title,
    required this.subtitle,
    required this.body,
    this.searchHint = '搜索题目、文档、学生、班级或课堂',
    this.statusWidgets = const <Widget>[],
    this.trailing,
    super.key,
  });

  final WorkspaceModule currentModule;
  final ValueChanged<WorkspaceModule> onSelectModule;
  final String title;
  final String subtitle;
  final Widget body;
  final String searchHint;
  final List<Widget> statusWidgets;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return WorkspaceBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showRail = constraints.maxWidth >= 1180;
            return Row(
              children: [
                if (showRail)
                  _WorkspaceDesktopRail(
                    currentModule: currentModule,
                    onSelectModule: onSelectModule,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          showRail ? 20 : 16,
                          16,
                          showRail ? 20 : 16,
                          0,
                        ),
                        child: workspaceConstrainedContent(
                          context,
                          child: _WorkspaceTopBar(
                            title: title,
                            subtitle: subtitle,
                            searchHint: searchHint,
                            statusWidgets: statusWidgets,
                            trailing: trailing,
                            compact: !showRail,
                          ),
                        ),
                      ),
                      if (!showRail)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: workspaceConstrainedContent(
                            context,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _primaryModules
                                    .map(
                                      (item) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 10),
                                        child: WorkspaceFilterPill(
                                          label: item.label,
                                          icon: item.icon,
                                          selected:
                                              item.module == currentModule,
                                          onTap: () =>
                                              onSelectModule(item.module),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.statusWidgets,
    required this.compact,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String searchHint;
  final List<Widget> statusWidgets;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return WorkspaceGlassPanel(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 20,
        compact ? 16 : 18,
        compact ? 16 : 20,
        compact ? 14 : 16,
      ),
      borderRadius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WorkspaceTopBarTitle(
                  title: title,
                  subtitle: subtitle,
                  trailing: trailing,
                ),
                const SizedBox(height: 14),
                _WorkspaceSearchField(hintText: searchHint),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _WorkspaceTopBarTitle(
                    title: title,
                    subtitle: subtitle,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _WorkspaceSearchField(hintText: searchHint),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 16),
                  trailing!,
                ],
              ],
            ),
          if (statusWidgets.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: statusWidgets,
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceTopBarTitle extends StatelessWidget {
  const _WorkspaceTopBarTitle({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: TelegramPalette.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  height: 1.45,
                  color: TelegramPalette.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class _WorkspaceSearchField extends StatelessWidget {
  const _WorkspaceSearchField({
    required this.hintText,
  });

  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: TelegramPalette.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hintText,
              style: const TextStyle(
                color: TelegramPalette.textSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(
            Icons.tune_rounded,
            size: 20,
            color: TelegramPalette.textSoft,
          ),
        ],
      ),
    );
  }
}

class _WorkspaceDesktopRail extends StatelessWidget {
  const _WorkspaceDesktopRail({
    required this.currentModule,
    required this.onSelectModule,
  });

  final WorkspaceModule currentModule;
  final ValueChanged<WorkspaceModule> onSelectModule;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 276),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
        decoration: BoxDecoration(
          color: TelegramPalette.shellDeep,
          border: Border(
            right: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ShiTi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '智能跨平台教研平台',
              style: TextStyle(
                color: Color(0xFF9FC7EA),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            const WorkspaceEyebrow(
              label: 'Academic Architect',
              icon: Icons.auto_awesome_outlined,
              foregroundColor: Colors.white,
              backgroundColor: Color(0x223390EC),
            ),
            const SizedBox(height: 24),
            ..._primaryModules.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RailModuleButton(
                  item: item,
                  active: item.module == currentModule,
                  onTap: () => onSelectModule(item.module),
                ),
              ),
            ),
            const Spacer(),
            WorkspacePanel(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              borderColor: Colors.white.withValues(alpha: 0.08),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '新版工作台',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '题库、文档、学生、班级与课堂共用一套中文教研工作台结构。',
                    style: TextStyle(
                      color: Color(0xD5DDEBFF),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailModuleButton extends StatelessWidget {
  const _RailModuleButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _WorkspaceRailItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : TelegramPalette.surfaceAccent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: active
                ? TelegramPalette.accent
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: active
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceRailItem {
  const _WorkspaceRailItem({
    required this.module,
    required this.icon,
    required this.label,
  });

  final WorkspaceModule module;
  final IconData icon;
  final String label;
}

const List<_WorkspaceRailItem> _primaryModules = <_WorkspaceRailItem>[
  _WorkspaceRailItem(
    module: WorkspaceModule.home,
    icon: Icons.dashboard_outlined,
    label: '工作台',
  ),
  _WorkspaceRailItem(
    module: WorkspaceModule.library,
    icon: Icons.search_outlined,
    label: '题库',
  ),
  _WorkspaceRailItem(
    module: WorkspaceModule.documents,
    icon: Icons.description_outlined,
    label: '文档管理',
  ),
  _WorkspaceRailItem(
    module: WorkspaceModule.students,
    icon: Icons.school_outlined,
    label: '学生管理',
  ),
  _WorkspaceRailItem(
    module: WorkspaceModule.classes,
    icon: Icons.groups_outlined,
    label: '班级管理',
  ),
  _WorkspaceRailItem(
    module: WorkspaceModule.lessons,
    icon: Icons.cast_for_education_outlined,
    label: '课堂管理',
  ),
  _WorkspaceRailItem(
    module: WorkspaceModule.exports,
    icon: Icons.cloud_upload_outlined,
    label: '导出',
  ),
  _WorkspaceRailItem(
    module: WorkspaceModule.account,
    icon: Icons.person_outline,
    label: '个人中心',
  ),
  _WorkspaceRailItem(
    module: WorkspaceModule.settings,
    icon: Icons.tune_rounded,
    label: '设置',
  ),
];
