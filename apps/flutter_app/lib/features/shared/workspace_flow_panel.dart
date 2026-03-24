import 'package:flutter/material.dart';

import '../../core/theme/telegram_palette.dart';
import 'workspace_module_paths.dart';
import 'workspace_module_shell.dart';
import 'workspace_shell.dart';

class WorkspaceFlowAction {
  const WorkspaceFlowAction({
    required this.module,
    required this.icon,
    required this.label,
    required this.description,
  });

  final WorkspaceModule module;
  final IconData icon;
  final String label;
  final String description;
}

class WorkspaceFlowPanel extends StatelessWidget {
  const WorkspaceFlowPanel({
    required this.currentModule,
    required this.title,
    required this.subtitle,
    required this.actions,
    super.key,
  });

  final WorkspaceModule currentModule;
  final String title;
  final String subtitle;
  final List<WorkspaceFlowAction> actions;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
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
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final useGrid = constraints.maxWidth >= 900;
              final cards = actions
                  .map(
                    (action) => _WorkspaceFlowActionCard(
                      action: action,
                      selected: action.module == currentModule,
                    ),
                  )
                  .toList();
              if (!useGrid) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i != cards.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WorkspaceFlowActionCard extends StatelessWidget {
  const _WorkspaceFlowActionCard({
    required this.action,
    required this.selected,
  });

  final WorkspaceFlowAction action;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? TelegramPalette.accentDark : TelegramPalette.textStrong;
    final background = selected
        ? TelegramPalette.surfaceAccent
        : TelegramPalette.surfaceSoft;
    final border =
        selected ? TelegramPalette.borderAccent : TelegramPalette.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: selected
            ? null
            : () => navigateToWorkspaceModule(context, action.module),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(action.icon, color: foreground, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action.description,
                      style: const TextStyle(
                        height: 1.45,
                        color: TelegramPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: TelegramPalette.accentDark,
                  size: 18,
                )
              else
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: TelegramPalette.textSoft,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
