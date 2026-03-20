import 'package:flutter/material.dart';

import '../../core/models/question_summary.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/content_section.dart';
import '../shared/workspace_shell.dart';

class QuestionSummaryPreview extends StatelessWidget {
  const QuestionSummaryPreview({
    required this.question,
    this.showSubject = true,
    this.showTags = true,
    super.key,
  });

  final QuestionSummary question;
  final bool showSubject;
  final bool showTags;

  @override
  Widget build(BuildContext context) {
    final metaParts = <String>[
      if (showSubject) question.subject,
      question.grade,
      question.textbook,
      question.chapter,
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            metaParts.join(' · '),
            style: const TextStyle(color: TelegramPalette.textSoft),
          ),
        ],
        const SizedBox(height: 10),
        ContentSection(
          title: '内容预览',
          blocks: question.previewBlocks,
          fallbackText: question.stemPreview,
          compact: true,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            WorkspaceInfoPill(
              label: '难度',
              value: '${question.difficulty}',
              highlight: true,
            ),
            if (showTags)
              ...question.tags.map(
                (tag) => WorkspaceInfoPill(label: '标签', value: tag),
              ),
          ],
        ),
      ],
    );
  }
}
