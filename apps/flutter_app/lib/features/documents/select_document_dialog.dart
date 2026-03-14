import 'package:flutter/material.dart';

import '../../core/models/document_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../library/question_block_renderer.dart';
import 'create_document_dialog.dart';

Future<DocumentSummary?> pickTargetDocument(BuildContext context) {
  return showDialog<DocumentSummary>(
    context: context,
    builder: (_) => const _SelectDocumentDialog(),
  );
}

class _SelectDocumentDialog extends StatefulWidget {
  const _SelectDocumentDialog();

  @override
  State<_SelectDocumentDialog> createState() => _SelectDocumentDialogState();
}

class _SelectDocumentDialogState extends State<_SelectDocumentDialog> {
  late Future<List<DocumentSummary>> _documentsFuture =
      AppServices.instance.documentRepository.listDocuments();

  void _reload() {
    setState(() {
      _documentsFuture = AppServices.instance.documentRepository.listDocuments();
    });
  }

  Future<void> _createDocument() async {
    final created = await showCreateDocumentDialog(context);
    if (created == null || !mounted) {
      return;
    }
    _reload();
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择目标文档'),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<List<DocumentSummary>>(
          future: _documentsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final error = snapshot.error;
              final message = error is HttpJsonException
                  ? '文档加载失败：${error.message}（HTTP ${error.statusCode}）'
                  : '文档加载失败：$error';
              return Text(
                message,
                style: const TextStyle(
                  height: 1.5,
                  color: TelegramPalette.errorText,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final documents = snapshot.data!;
            if (documents.isEmpty) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前没有可加入的文档。你可以直接在这里新建讲义或试卷，然后继续加入题目。',
                    style: TextStyle(
                      height: 1.5,
                      color: TelegramPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _createDocument,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('新建文档并继续'),
                  ),
                ],
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              itemCount: documents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final document = documents[index];
                return Card(
                  color: TelegramPalette.surfaceSoft,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(document),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: document.kind == 'paper'
                                  ? TelegramPalette.warningSurface
                                  : TelegramPalette.surfaceAccent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              document.kind == 'paper'
                                  ? Icons.description_outlined
                                  : Icons.menu_book_outlined,
                              color: TelegramPalette.textStrong,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  document.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _MetaChip(
                                      label: document.kind == 'paper' ? '试卷' : '讲义',
                                    ),
                                    _MetaChip(label: '题目 ${document.questionCount}'),
                                    _MetaChip(label: '排版 ${document.layoutCount}'),
                                    _MetaChip(
                                      label: '导出 ${_formatExportStatus(document.latestExportStatus)}',
                                    ),
                                  ],
                                ),
                                if (document.previewBlocks.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: TelegramPalette.surfaceAccent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: TelegramPalette.border),
                                    ),
                                    child: QuestionBlockRenderer(
                                      blocks: document.previewBlocks,
                                      fallbackText: '暂无文档预览。',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _createDocument,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('新建文档'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: TelegramPalette.textMuted,
        ),
      ),
    );
  }
}

String _formatExportStatus(String status) {
  switch (status) {
    case 'succeeded':
      return '成功';
    case 'pending':
      return '排队中';
    case 'failed':
      return '失败';
    case 'running':
      return '处理中';
    default:
      return '未开始';
  }
}
