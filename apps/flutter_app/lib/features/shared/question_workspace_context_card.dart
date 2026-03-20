import 'package:flutter/material.dart';

import '../../core/theme/telegram_palette.dart';
import 'workspace_shell.dart';

class QuestionWorkspaceContextCard extends StatelessWidget {
  const QuestionWorkspaceContextCard({
    required this.documentName,
    required this.onOpenDocument,
    this.insertAfterItemTitle,
    super.key,
  });

  final String documentName;
  final String? insertAfterItemTitle;
  final VoidCallback onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final detail =
        insertAfterItemTitle == null || insertAfterItemTitle!.trim().isEmpty
            ? '当前在为这份文档整理题目，接下来加入的题会默认落回这份文档。'
            : '当前在为这份文档整理题目，接下来加入的题会默认插到“$insertAfterItemTitle”后面。';
    return WorkspacePanel(
      padding: const EdgeInsets.all(18),
      backgroundColor: TelegramPalette.surfaceAccent,
      borderColor: TelegramPalette.borderAccent,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          const Icon(
            Icons.drive_file_move_outlined,
            color: TelegramPalette.accent,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WorkspaceEyebrow(
                  label: '当前加题上下文',
                  icon: Icons.alt_route_outlined,
                ),
                const SizedBox(height: 10),
                Text(
                  '当前目标文档：$documentName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TelegramPalette.textStrong,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: const TextStyle(
                    height: 1.45,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onOpenDocument,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开当前文档'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
