import 'package:flutter/material.dart';

import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_shell.dart';

Future<String?> showRenameDocumentDialog(
  BuildContext context, {
  required String initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDocumentDialog(initialName: initialName),
  );
}

class _RenameDocumentDialog extends StatefulWidget {
  const _RenameDocumentDialog({
    required this.initialName,
  });

  final String initialName;

  @override
  State<_RenameDocumentDialog> createState() => _RenameDocumentDialogState();
}

class _RenameDocumentDialogState extends State<_RenameDocumentDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = '请先输入文档名称';
      });
      return;
    }
    Navigator.of(context).pop(name);
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
                '重命名文档',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                '更新文档名称后，题库、文档和导出记录中的显示会同步刷新。',
                style: TextStyle(
                  height: 1.5,
                  color: TelegramPalette.textMuted,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                WorkspaceMessageBanner.error(
                  message: _errorMessage!,
                  title: '还不能更新名称',
                  padding: const EdgeInsets.all(12),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '文档名称',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: _submit,
                      child: const Text('保存'),
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
