import 'package:flutter/material.dart';

import '../../core/models/document_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
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
                style: const TextStyle(height: 1.5, color: Color(0xFF9F1239)),
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
                    style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
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
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: const Color(0xFFF5FAF8),
                  title: Text(document.name),
                  subtitle: Text(
                    '${document.kind == 'paper' ? '试卷' : '讲义'} · 题目 ${document.questionCount} · 排版 ${document.layoutCount}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pop(document),
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
