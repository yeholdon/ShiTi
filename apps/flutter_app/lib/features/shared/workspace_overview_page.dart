import 'package:flutter/material.dart';

import '../../core/theme/telegram_palette.dart';
import 'workspace_module_shell.dart';
import 'workspace_shell.dart';

class WorkspaceOverviewMetric {
  const WorkspaceOverviewMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;
}

class WorkspaceOverviewSection {
  const WorkspaceOverviewSection({
    required this.title,
    required this.subtitle,
    required this.points,
    this.eyebrow,
  });

  final String title;
  final String subtitle;
  final List<String> points;
  final String? eyebrow;
}

class WorkspaceOverviewPage extends StatelessWidget {
  const WorkspaceOverviewPage({
    required this.currentModule,
    required this.onSelectModule,
    required this.topTitle,
    required this.topSubtitle,
    required this.searchHint,
    required this.heroEyebrow,
    required this.heroTitle,
    required this.heroDescription,
    required this.heroMetrics,
    required this.sections,
    required this.asideTitle,
    required this.asideSubtitle,
    required this.asidePoints,
    required this.statusWidgets,
    super.key,
  });

  final WorkspaceModule currentModule;
  final ValueChanged<WorkspaceModule> onSelectModule;
  final String topTitle;
  final String topSubtitle;
  final String searchHint;
  final String heroEyebrow;
  final String heroTitle;
  final String heroDescription;
  final List<WorkspaceOverviewMetric> heroMetrics;
  final List<WorkspaceOverviewSection> sections;
  final String asideTitle;
  final String asideSubtitle;
  final List<String> asidePoints;
  final List<Widget> statusWidgets;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WorkspaceModuleShell(
        currentModule: currentModule,
        onSelectModule: onSelectModule,
        title: topTitle,
        subtitle: topSubtitle,
        searchHint: searchHint,
        statusWidgets: statusWidgets,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final showAside = constraints.maxWidth >= 1120;
            return workspaceConstrainedContent(
              context,
              child: ListView(
                padding: workspacePagePadding(context),
                children: [
                  WorkspacePanel(
                    padding: workspaceHeroPanelPadding(context),
                    borderRadius: 28,
                    backgroundColor: TelegramPalette.surfaceRaised,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WorkspaceEyebrow(
                          label: heroEyebrow,
                          icon: Icons.auto_awesome_outlined,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          heroTitle,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: TelegramPalette.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          heroDescription,
                          style: const TextStyle(
                            height: 1.55,
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: heroMetrics
                              .map(
                                (metric) => WorkspaceMetricPill(
                                  label: metric.label,
                                  value: metric.value,
                                  highlight: metric.highlight,
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
                          child: Column(
                            children: sections
                                .map(
                                  (section) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child:
                                        _OverviewSectionCard(section: section),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _OverviewAside(
                            title: asideTitle,
                            subtitle: asideSubtitle,
                            points: asidePoints,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    ...sections.map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _OverviewSectionCard(section: section),
                      ),
                    ),
                    _OverviewAside(
                      title: asideTitle,
                      subtitle: asideSubtitle,
                      points: asidePoints,
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

class _OverviewSectionCard extends StatelessWidget {
  const _OverviewSectionCard({
    required this.section,
  });

  final WorkspaceOverviewSection section;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((section.eyebrow ?? '').isNotEmpty) ...[
            WorkspaceEyebrow(label: section.eyebrow!),
            const SizedBox(height: 14),
          ],
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.subtitle,
            style: const TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          ...section.points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WorkspaceBulletPoint(text: point),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewAside extends StatelessWidget {
  const _OverviewAside({
    required this.title,
    required this.subtitle,
    required this.points,
  });

  final String title;
  final String subtitle;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      backgroundColor: TelegramPalette.surfaceAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: TelegramPalette.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WorkspaceBulletPoint(
                text: point,
                icon: Icons.arrow_forward_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
