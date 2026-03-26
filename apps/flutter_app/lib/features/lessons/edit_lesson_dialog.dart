import 'package:flutter/material.dart';

import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_shell.dart';
import 'lesson_workspace_data.dart';

Future<LessonWorkspaceRecord?> showEditLessonDialog(
  BuildContext context, {
  required LessonWorkspaceRecord lesson,
}) {
  return showDialog<LessonWorkspaceRecord>(
    context: context,
    builder: (_) => _EditLessonDialog(lesson: lesson),
  );
}

class _EditLessonDialog extends StatefulWidget {
  const _EditLessonDialog({required this.lesson});

  final LessonWorkspaceRecord lesson;

  @override
  State<_EditLessonDialog> createState() => _EditLessonDialogState();
}

class _EditLessonDialogState extends State<_EditLessonDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController =
      TextEditingController(text: widget.lesson.title);
  late final TextEditingController _teacherController =
      TextEditingController(text: widget.lesson.teacherLabel);
  late final TextEditingController _scheduleController =
      TextEditingController(text: widget.lesson.scheduleLabel);
  late String _classScopeLabel = widget.lesson.classScopeLabel;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _teacherController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final updated = await AppServices.instance.lessonRepository.updateLesson(
        lessonId: widget.lesson.id,
        title: _titleController.text.trim(),
        teacherLabel: _teacherController.text.trim(),
        scheduleLabel: _scheduleController.text.trim(),
        classScopeLabel: _classScopeLabel,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updated);
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '更新课堂失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '更新课堂失败：$error';
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: WorkspacePanel(
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '编辑课堂档案',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '更新课堂的基础安排信息，资料清单、反馈明细和课后任务会继续沿用现有记录。',
                  style: TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  WorkspaceMessageBanner.error(
                    title: '还不能更新课堂',
                    message: _errorMessage!,
                    padding: const EdgeInsets.all(12),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '课堂主题',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? '请先输入课堂主题' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _teacherController,
                  decoration: const InputDecoration(
                    labelText: '任课说明',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? '请先输入任课说明' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _scheduleController,
                  decoration: const InputDecoration(
                    labelText: '时间安排',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? '请先输入时间安排' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _classScopeLabel,
                  decoration: const InputDecoration(
                    labelText: '班级范围',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '未绑定班级', child: Text('未绑定班级')),
                    DropdownMenuItem(value: '九年级尖子班', child: Text('九年级尖子班')),
                    DropdownMenuItem(value: '九年级提高班', child: Text('九年级提高班')),
                    DropdownMenuItem(value: '高一函数培优班', child: Text('高一函数培优班')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _classScopeLabel = value);
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
                        child: Text(_submitting ? '保存中...' : '保存修改'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
