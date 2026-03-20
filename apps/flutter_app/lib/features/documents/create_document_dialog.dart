import 'package:flutter/material.dart';

import '../../core/models/document_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_shell.dart';

Future<DocumentSummary?> showCreateDocumentDialog(
  BuildContext context, {
  String? initialName,
  String initialKind = 'handout',
  String title = '新建文档',
}) {
  return showDialog<DocumentSummary>(
    context: context,
    builder: (_) => _CreateDocumentDialog(
      initialName: initialName,
      initialKind: initialKind,
      title: title,
    ),
  );
}

class _CreateDocumentDialog extends StatefulWidget {
  const _CreateDocumentDialog({
    this.initialName,
    this.initialKind = 'handout',
    this.title = '新建文档',
  });

  final String? initialName;
  final String initialKind;
  final String title;

  @override
  State<_CreateDocumentDialog> createState() => _CreateDocumentDialogState();
}

class _CreateDocumentDialogState extends State<_CreateDocumentDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName ?? '');
  late String _kind = widget.initialKind;
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
      final document =
          await AppServices.instance.documentRepository.createDocument(
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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: WorkspacePanel(
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                '设置文档名称和类型，创建后可以继续编排、补题或导出。',
                style: TextStyle(
                  height: 1.5,
                  color: TelegramPalette.textMuted,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                WorkspaceMessageBanner.error(
                  message: _errorMessage!,
                  title: '还不能创建文档',
                  padding: const EdgeInsets.all(12),
                ),
              ],
              const SizedBox(height: 16),
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
                isExpanded: true,
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
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(_submitting ? '创建中...' : '创建'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
