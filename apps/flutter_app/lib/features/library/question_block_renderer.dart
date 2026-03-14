import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../core/theme/telegram_palette.dart';

class QuestionBlockRenderer extends StatelessWidget {
  const QuestionBlockRenderer({
    required this.blocks,
    required this.fallbackText,
    super.key,
  });

  final List<Map<String, dynamic>> blocks;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return Text(
        fallbackText.trim().isEmpty ? '暂无内容。' : fallbackText,
        style: const TextStyle(height: 1.6),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks
          .map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuestionBlockTile(block: block),
            ),
          )
          .toList(),
    );
  }
}

class _QuestionBlockTile extends StatelessWidget {
  const _QuestionBlockTile({required this.block});

  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    final type = (block['type'] ?? 'text').toString();
    final nestedBlocks = _nestedBlocks(block);
    switch (type) {
      case 'image':
        return _PlaceholderCard(
          icon: Icons.image_outlined,
          label: '图片块',
          detail: (block['assetId'] ?? '未绑定资源').toString(),
        );
      case 'table':
        return _PlaceholderCard(
          icon: Icons.table_chart_outlined,
          label: '表格块',
          detail: (block['label'] ?? '表格内容待渲染').toString(),
        );
      case 'latex':
      case 'math':
        final latex = _extractText(block);
        if (latex.isEmpty) {
          return const SizedBox.shrink();
        }
        return _LatexCard(
          text: latex,
          nestedBlocks: nestedBlocks,
        );
      default:
        final text = _extractText(block);
        if (text.isEmpty && nestedBlocks.isEmpty) {
          return const SizedBox.shrink();
        }
        return _TextBlock(
          text: text,
          nestedBlocks: nestedBlocks,
        );
    }
  }

  List<Map<String, dynamic>> _nestedBlocks(Map<String, dynamic> value) {
    final results = <Map<String, dynamic>>[];

    void collect(dynamic candidate) {
      if (candidate is List) {
        for (final item in candidate) {
          if (item is Map<String, dynamic>) {
            results.add(item);
          } else {
            collect(item);
          }
        }
      }
    }

    collect(value['children']);
    collect(value['blocks']);
    collect(value['items']);
    return results;
  }

  String _extractText(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    if (value is List) {
      return value
          .where((item) => item is! Map<String, dynamic>)
          .map(_extractText)
          .where((item) => item.isNotEmpty)
          .join(' ')
          .trim();
    }
    if (value is Map<String, dynamic>) {
      final directText = value['text'];
      if (directText is String && directText.trim().isNotEmpty) {
        return directText.trim();
      }
      return value.entries
          .where(
            (entry) =>
                entry.key != 'children' &&
                entry.key != 'blocks' &&
                entry.key != 'items',
          )
          .map((entry) => _extractText(entry.value))
          .where((item) => item.isNotEmpty)
          .join(' ')
          .trim();
    }
    return '';
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.text,
    required this.nestedBlocks,
  });

  final String text;
  final List<Map<String, dynamic>> nestedBlocks;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (text.isNotEmpty) {
      children.add(_InlineMathText(text: text));
    }
    if (nestedBlocks.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 10));
      }
      children.add(_NestedBlockList(blocks: nestedBlocks));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _InlineMathText extends StatelessWidget {
  const _InlineMathText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final segments = _splitInlineMath(text);
    if (segments.length == 1 && !segments.first.isMath) {
      return SelectableText(
        text,
        style: const TextStyle(height: 1.6),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: segments.map((segment) {
        if (segment.isMath) {
          return Math.tex(
            segment.value,
            mathStyle: MathStyle.text,
            textStyle: const TextStyle(
              fontSize: 16,
              color: TelegramPalette.textStrong,
            ),
            onErrorFallback: (error) => Text(
              segment.value,
              style: const TextStyle(
                fontFamily: 'monospace',
                height: 1.6,
                color: TelegramPalette.textStrong,
              ),
            ),
          );
        }

        return Text(
          segment.value,
          style: const TextStyle(
            height: 1.6,
            color: Colors.black87,
          ),
        );
      }).toList(),
    );
  }

  List<_InlineSegment> _splitInlineMath(String source) {
    final matches = RegExp(r'\$(.+?)\$').allMatches(source);
    if (matches.isEmpty) {
      return <_InlineSegment>[_InlineSegment.text(source)];
    }

    final segments = <_InlineSegment>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        segments.add(
          _InlineSegment.text(source.substring(cursor, match.start)),
        );
      }

      final latex = match.group(1)?.trim() ?? '';
      if (latex.isNotEmpty) {
        segments.add(_InlineSegment.math(latex));
      }
      cursor = match.end;
    }

    if (cursor < source.length) {
      segments.add(_InlineSegment.text(source.substring(cursor)));
    }

    return segments.where((segment) => segment.value.trim().isNotEmpty).toList();
  }
}

class _InlineSegment {
  const _InlineSegment._({
    required this.value,
    required this.isMath,
  });

  factory _InlineSegment.text(String value) =>
      _InlineSegment._(value: value, isMath: false);

  factory _InlineSegment.math(String value) =>
      _InlineSegment._(value: value, isMath: true);

  final String value;
  final bool isMath;
}

class _LatexCard extends StatelessWidget {
  const _LatexCard({
    required this.text,
    required this.nestedBlocks,
  });

  final String text;
  final List<Map<String, dynamic>> nestedBlocks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TelegramPalette.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TelegramPalette.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LaTeX / 公式块',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: TelegramPalette.warningText,
            ),
          ),
          const SizedBox(height: 8),
          Math.tex(
            text,
            mathStyle: MathStyle.display,
            textStyle: const TextStyle(
              fontSize: 18,
              color: TelegramPalette.textStrong,
            ),
            onErrorFallback: (error) => SelectableText(
              text,
              style: const TextStyle(
                fontFamily: 'monospace',
                height: 1.6,
                color: TelegramPalette.textStrong,
              ),
            ),
          ),
          if (nestedBlocks.isNotEmpty) ...[
            const SizedBox(height: 10),
            _NestedBlockList(blocks: nestedBlocks),
          ],
        ],
      ),
    );
  }
}

class _NestedBlockList extends StatelessWidget {
  const _NestedBlockList({required this.blocks});

  final List<Map<String, dynamic>> blocks;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: TelegramPalette.border,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks
            .map(
              (nestedBlock) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuestionBlockTile(block: nestedBlock),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TelegramPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: TelegramPalette.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TelegramPalette.textStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    height: 1.4,
                    color: TelegramPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
