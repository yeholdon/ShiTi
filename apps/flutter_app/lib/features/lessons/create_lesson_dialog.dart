import 'package:flutter/material.dart';

import '../../core/models/document_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../classes/class_workspace_data.dart';
import '../shared/workspace_shell.dart';
import '../students/student_workspace_data.dart';
import 'lesson_workspace_data.dart';

Future<LessonWorkspaceRecord?> showCreateLessonDialog(BuildContext context) {
  return showDialog<LessonWorkspaceRecord>(
    context: context,
    builder: (_) => const _CreateLessonDialog(),
  );
}

class _CreateLessonDialog extends StatefulWidget {
  const _CreateLessonDialog();

  @override
  State<_CreateLessonDialog> createState() => _CreateLessonDialogState();
}

class _CreateLessonDialogState extends State<_CreateLessonDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController = TextEditingController();
  late final TextEditingController _teacherController =
      TextEditingController(text: '主讲：待补充');
  late final TextEditingController _scheduleController =
      TextEditingController(text: '待安排时间');
  String _classId = '';
  String _focusStudentId = '';
  String _documentId = '';
  List<String> _feedbackStudentIds = const [];
  List<ClassWorkspaceRecord> _classes = const [];
  List<StudentWorkspaceRecord> _students = const [];
  List<DocumentSummary> _documents = const [];
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
        _loadingStudents = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _students = const [];
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
      final created = await AppServices.instance.lessonRepository.createLesson(
        title: _titleController.text.trim(),
        teacherLabel: _teacherController.text.trim(),
        scheduleLabel: _scheduleController.text.trim(),
        classScopeLabel:
            _classId.isEmpty ? '未绑定班级' : (selectedClass?.name ?? '未绑定班级'),
        focusStudentId: _focusStudentId.isEmpty ? null : _focusStudentId,
        focusStudentName:
            _focusStudentId.isEmpty ? null : (selectedFocusStudent?.name ?? ''),
        classId: _classId.isEmpty ? null : _classId,
        documentId: _documentId.isEmpty ? null : _documentId,
        documentFocus:
            _documentId.isEmpty ? null : (selectedDocument?.name ?? '未绑定资料'),
        feedbackStudentIds: _feedbackStudentIds,
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
        _errorMessage = '创建课堂失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '创建课堂失败：$error';
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
                  '新建课堂',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '创建时就补齐班级、资料和承接学生，后续再继续完善反馈与任务明细。',
                  style: TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  WorkspaceMessageBanner.error(
                    title: '还不能创建课堂',
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
                                  '当前没有可关联的学生，稍后也可以回到学生页继续补充。',
                                  style: TextStyle(
                                    color: TelegramPalette.textMuted,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _students.map((student) {
                                    final selected =
                                        _feedbackStudentIds.contains(student.id);
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
                        child: Text(_submitting ? '创建中...' : '创建课堂'),
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
