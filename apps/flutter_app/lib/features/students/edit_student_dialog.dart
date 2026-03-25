import 'package:flutter/material.dart';

import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_shell.dart';
import 'student_workspace_data.dart';

Future<StudentWorkspaceRecord?> showEditStudentDialog(
  BuildContext context, {
  required StudentWorkspaceRecord student,
}) {
  return showDialog<StudentWorkspaceRecord>(
    context: context,
    builder: (_) => _EditStudentDialog(student: student),
  );
}

class _EditStudentDialog extends StatefulWidget {
  const _EditStudentDialog({required this.student});

  final StudentWorkspaceRecord student;

  @override
  State<_EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<_EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.student.name);
  late final TextEditingController _classNameController =
      TextEditingController(text: widget.student.className);
  late String _gradeLabel = widget.student.gradeLabel;
  late String _subjectLabel = widget.student.subjectLabel;
  late String _textbookLabel = widget.student.textbookLabel;
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
      final updated = await AppServices.instance.studentRepository.updateStudent(
        studentId: widget.student.id,
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
      Navigator.of(context).pop(updated);
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '更新学生失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '更新学生失败：$error';
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
                  '编辑学生档案',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '更新学生的基础档案信息，成绩、错题和课堂反馈会继续沿用现有记录。',
                  style: TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  WorkspaceMessageBanner.error(
                    title: '还不能更新学生',
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
