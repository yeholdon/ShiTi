import 'package:flutter/material.dart';

import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_shell.dart';
import 'student_workspace_data.dart';

Future<StudentWorkspaceRecord?> showCreateStudentDialog(BuildContext context) {
  return showDialog<StudentWorkspaceRecord>(
    context: context,
    builder: (_) => const _CreateStudentDialog(),
  );
}

class _CreateStudentDialog extends StatefulWidget {
  const _CreateStudentDialog();

  @override
  State<_CreateStudentDialog> createState() => _CreateStudentDialogState();
}

class _CreateStudentDialogState extends State<_CreateStudentDialog> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _classNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _gradeLabel = '初中 · 九年级下';
  String _subjectLabel = '数学';
  String _textbookLabel = '浙教版';
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _classNameController.dispose();
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
      final created = await AppServices.instance.studentRepository.createStudent(
        name: _nameController.text.trim(),
        gradeLabel: _gradeLabel,
        subjectLabel: _subjectLabel,
        textbookLabel: _textbookLabel,
        className: _classNameController.text.trim().isEmpty
            ? null
            : _classNameController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(created);
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '创建学生失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '创建学生失败：$error';
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
                  '添加学生',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '先补学生基础档案，成绩记录、错题跟进和课堂反馈可以稍后继续完善。',
                  style: TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  WorkspaceMessageBanner.error(
                    title: '还不能创建学生',
                    message: _errorMessage!,
                    padding: const EdgeInsets.all(12),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '学生姓名',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? '请先输入学生姓名' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _classNameController,
                  decoration: const InputDecoration(
                    labelText: '所属班级（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _gradeLabel,
                  decoration: const InputDecoration(
                    labelText: '学段年级',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '小学 · 五年级下', child: Text('小学 · 五年级下')),
                    DropdownMenuItem(value: '初中 · 八年级下', child: Text('初中 · 八年级下')),
                    DropdownMenuItem(value: '初中 · 九年级下', child: Text('初中 · 九年级下')),
                    DropdownMenuItem(value: '高中 · 高一', child: Text('高中 · 高一')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _gradeLabel = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _subjectLabel,
                  decoration: const InputDecoration(
                    labelText: '学科',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '数学', child: Text('数学')),
                    DropdownMenuItem(value: '物理', child: Text('物理')),
                    DropdownMenuItem(value: '化学', child: Text('化学')),
                    DropdownMenuItem(value: '英语', child: Text('英语')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _subjectLabel = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _textbookLabel,
                  decoration: const InputDecoration(
                    labelText: '教材版本',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '浙教版', child: Text('浙教版')),
                    DropdownMenuItem(value: '人教版', child: Text('人教版')),
                    DropdownMenuItem(value: '通用版', child: Text('通用版')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _textbookLabel = value);
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
                        child: Text(_submitting ? '创建中...' : '创建学生'),
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
