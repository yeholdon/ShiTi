import 'package:flutter/material.dart';

import '../../core/models/document_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';

Future<DocumentSummary?> showCreateDocumentDialog(BuildContext context) {
  return showDialog<DocumentSummary>(
    context: context,
    builder: (_) => const _CreateDocumentDialog(),
  );
}

class _CreateDocumentDialog extends StatefulWidget {
  const _CreateDocumentDialog();

  @override
  State<_CreateDocumentDialog> createState() => _CreateDocumentDialogState();
}

class _CreateDocumentDialogState extends State<_CreateDocumentDialog> {
  final _nameController = TextEditingController();
  String _kind = 'handout';
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = '请先输入文档名称';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final document = await AppServices.instance.documentRepository.createDocument(
        name: name,
        kind: _kind,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(document);
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '创建文档失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '创建文档失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建文档'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFF9F1239), height: 1.4),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '文档名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(
                labelText: '文档类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'handout', child: Text('讲义')),
                DropdownMenuItem(value: 'paper', child: Text('试卷')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _kind = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '创建中...' : '创建'),
        ),
      ],
    );
  }
}
