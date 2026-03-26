import 'package:flutter/material.dart';

import '../../core/models/document_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../classes/class_workspace_data.dart';
import '../lessons/lesson_workspace_data.dart';
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
  final _formKey = GlobalKey<FormState>();
  String _gradeLabel = '初中 · 九年级下';
  String _subjectLabel = '数学';
  String _textbookLabel = '浙教版';
  String _classId = '';
  String _lessonId = '';
  String _documentId = '';
  List<ClassWorkspaceRecord> _classes = const [];
  List<LessonWorkspaceRecord> _lessons = const [];
  List<DocumentSummary> _documents = const [];
  bool _loadingClasses = true;
  bool _loadingLessons = true;
  bool _loadingDocuments = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadLessons();
    _loadDocuments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await AppServices.instance.classRepository.listClasses();
      if (!mounted) {
        return;
      }
      setState(() {
        _classes = classes;
        _loadingClasses = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _classes = const [];
        _loadingClasses = false;
      });
    }
  }

  Future<void> _loadLessons() async {
    try {
      final lessons = await AppServices.instance.lessonRepository.listLessons();
      if (!mounted) {
        return;
      }
      setState(() {
        _lessons = lessons;
        _loadingLessons = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lessons = const [];
        _loadingLessons = false;
      });
    }
  }

  Future<void> _loadDocuments() async {
    try {
      final documents =
          await AppServices.instance.documentRepository.listDocuments();
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = documents;
        _loadingDocuments = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = const [];
        _loadingDocuments = false;
      });
    }
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
      final selectedClass = _classes.cast<ClassWorkspaceRecord?>().firstWhere(
            (classroom) => classroom?.id == _classId,
            orElse: () => null,
          );
      final selectedDocument = _documents.cast<DocumentSummary?>().firstWhere(
            (document) => document?.id == _documentId,
            orElse: () => null,
          );
      final created =
          await AppServices.instance.studentRepository.createStudent(
        name: _nameController.text.trim(),
        gradeLabel: _gradeLabel,
        subjectLabel: _subjectLabel,
        textbookLabel: _textbookLabel,
        classId: _classId,
        className: _classId.isEmpty ? null : (selectedClass?.name ?? ''),
        lessonId: _lessonId,
        documentId: _documentId,
        documentName:
            _documentId.isEmpty ? null : (selectedDocument?.name ?? ''),
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
    final classValue =
        _classes.any((classroom) => classroom.id == _classId) ? _classId : '';
    final lessonValue =
        _lessons.any((lesson) => lesson.id == _lessonId) ? _lessonId : '';
    final documentValue =
        _documents.any((document) => document.id == _documentId)
            ? _documentId
            : '';
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
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? '请先输入学生姓名'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: classValue,
                  decoration: const InputDecoration(
                    labelText: '所属班级（可选）',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('暂不关联')),
                    ..._classes.map(
                      (classroom) => DropdownMenuItem(
                        value: classroom.id,
                        child: Text(classroom.name),
                      ),
                    ),
                  ],
                  onChanged: _loadingClasses
                      ? null
                      : (value) {
                          setState(() => _classId = value ?? '');
                        },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: lessonValue,
                  decoration: const InputDecoration(
                    labelText: '关联课堂（可选）',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('暂不关联')),
                    ..._lessons.map(
                      (lesson) => DropdownMenuItem(
                        value: lesson.id,
                        child: Text(lesson.title),
                      ),
                    ),
                  ],
                  onChanged: _loadingLessons
                      ? null
                      : (value) {
                          setState(() => _lessonId = value ?? '');
                        },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: documentValue,
                  decoration: const InputDecoration(
                    labelText: '关联资料（可选）',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('暂不关联')),
                    ..._documents.map(
                      (document) => DropdownMenuItem(
                        value: document.id,
                        child: Text(document.name),
                      ),
                    ),
                  ],
                  onChanged: _loadingDocuments
                      ? null
                      : (value) {
                          setState(() => _documentId = value ?? '');
                        },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _gradeLabel,
                  decoration: const InputDecoration(
                    labelText: '学段年级',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: '小学 · 五年级下', child: Text('小学 · 五年级下')),
                    DropdownMenuItem(
                        value: '初中 · 八年级下', child: Text('初中 · 八年级下')),
                    DropdownMenuItem(
                        value: '初中 · 九年级下', child: Text('初中 · 九年级下')),
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
