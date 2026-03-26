import 'package:flutter/material.dart';

import '../../core/network/http_json_client.dart';
import '../../core/models/document_summary.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../classes/class_workspace_data.dart';
import '../shared/workspace_shell.dart';
import 'lesson_workspace_data.dart';
import '../students/student_workspace_data.dart';

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
  late String _classId = widget.lesson.classId;
  late String _focusStudentId = widget.lesson.focusStudentId;
  late String _documentId = widget.lesson.documentId;
  List<String> _feedbackStudentIds = const [];
  List<ClassWorkspaceRecord> _classes = const [];
  List<StudentWorkspaceRecord> _students = const [];
  List<DocumentSummary> _documents = const [];
  bool _feedbackSelectionInitialized = false;
  bool _loadingClasses = true;
  bool _loadingStudents = true;
  bool _loadingDocuments = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadStudents();
    _loadDocuments();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _teacherController.dispose();
    _scheduleController.dispose();
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

  Future<void> _loadStudents() async {
    try {
      final students =
          await AppServices.instance.studentRepository.listStudents();
      if (!mounted) {
        return;
      }
      setState(() {
        _students = students;
        if (!_feedbackSelectionInitialized) {
          _feedbackStudentIds = students
              .where((student) => student.lessonId == widget.lesson.id)
              .map((student) => student.id)
              .toList(growable: false);
          _feedbackSelectionInitialized = true;
        }
        _loadingStudents = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _students = const [];
        if (!_feedbackSelectionInitialized) {
          _feedbackStudentIds = const [];
          _feedbackSelectionInitialized = true;
        }
        _loadingStudents = false;
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
      final selectedFocusStudent =
          _students.cast<StudentWorkspaceRecord?>().firstWhere(
                (student) => student?.id == _focusStudentId,
                orElse: () => null,
              );
      final selectedClass = _classes.cast<ClassWorkspaceRecord?>().firstWhere(
            (classroom) => classroom?.id == _classId,
            orElse: () => null,
          );
      final selectedDocument = _documents.cast<DocumentSummary?>().firstWhere(
            (document) => document?.id == _documentId,
            orElse: () => null,
          );
      final updated = await AppServices.instance.lessonRepository.updateLesson(
        lessonId: widget.lesson.id,
        title: _titleController.text.trim(),
        teacherLabel: _teacherController.text.trim(),
        scheduleLabel: _scheduleController.text.trim(),
        classScopeLabel: _classId.isEmpty
            ? '未绑定班级'
            : (selectedClass?.name ?? widget.lesson.classScopeLabel),
        focusStudentId: _focusStudentId.isEmpty ? '' : _focusStudentId,
        focusStudentName:
            _focusStudentId.isEmpty ? '' : (selectedFocusStudent?.name ?? ''),
        classId: _classId.isEmpty ? '' : _classId,
        documentId: _documentId.isEmpty ? '' : _documentId,
        documentFocus: _documentId.isEmpty
            ? '未绑定资料'
            : (selectedDocument?.name ?? widget.lesson.documentFocus),
        feedbackStudentIds: _feedbackStudentIds,
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
    final focusCandidates = _feedbackStudentIds.isEmpty
        ? _students
        : _students
            .where((student) => _feedbackStudentIds.contains(student.id))
            .toList(growable: false);
    final focusStudentValue =
        _students.any((student) => student.id == _focusStudentId) &&
                (_feedbackStudentIds.isEmpty ||
                    _feedbackStudentIds.contains(_focusStudentId))
            ? _focusStudentId
            : '';
    final classValue =
        _classes.any((classroom) => classroom.id == _classId) ? _classId : '';
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
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? '请先输入课堂主题'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _teacherController,
                  decoration: const InputDecoration(
                    labelText: '任课说明',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? '请先输入任课说明'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _scheduleController,
                  decoration: const InputDecoration(
                    labelText: '时间安排',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? '请先输入时间安排'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: classValue,
                  decoration: const InputDecoration(
                    labelText: '关联班级',
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
                  initialValue: focusStudentValue,
                  decoration: const InputDecoration(
                    labelText: '反馈学生',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('暂不设置')),
                    ...focusCandidates.map(
                      (student) => DropdownMenuItem(
                        value: student.id,
                        child: Text(student.name),
                      ),
                    ),
                  ],
                  onChanged: _loadingStudents
                      ? null
                      : (value) {
                          setState(() => _focusStudentId = value ?? '');
                        },
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '课堂承接学生',
                    border: OutlineInputBorder(),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: _loadingStudents
                        ? const SizedBox(
                            height: 48,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _students.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  '当前没有可关联的学生，稍后可在学生页先创建档案。',
                                  style: TextStyle(
                                    color: TelegramPalette.textMuted,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _students.map((student) {
                                    final selected = _feedbackStudentIds
                                        .contains(student.id);
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      value: selected,
                                      title: Text(student.name),
                                      subtitle: Text(
                                        '${student.gradeLabel} · ${student.textbookLabel}',
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _feedbackStudentIds = [
                                              ..._feedbackStudentIds,
                                              student.id,
                                            ];
                                          } else {
                                            _feedbackStudentIds =
                                                _feedbackStudentIds
                                                    .where((id) =>
                                                        id != student.id)
                                                    .toList(growable: false);
                                            if (_focusStudentId == student.id) {
                                              _focusStudentId = '';
                                            }
                                          }
                                        });
                                      },
                                    );
                                  }).toList(growable: false),
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: documentValue,
                  decoration: const InputDecoration(
                    labelText: '关联资料',
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
