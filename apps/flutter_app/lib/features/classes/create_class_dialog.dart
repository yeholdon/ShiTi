import 'package:flutter/material.dart';

import '../../core/models/document_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../lessons/lesson_workspace_data.dart';
import '../shared/workspace_shell.dart';
import '../students/student_workspace_data.dart';
import 'class_workspace_data.dart';

Future<ClassWorkspaceRecord?> showCreateClassDialog(BuildContext context) {
  return showDialog<ClassWorkspaceRecord>(
    context: context,
    builder: (_) => const _CreateClassDialog(),
  );
}

class _CreateClassDialog extends StatefulWidget {
  const _CreateClassDialog();

  @override
  State<_CreateClassDialog> createState() => _CreateClassDialogState();
}

class _CreateClassDialogState extends State<_CreateClassDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _teacherController =
      TextEditingController(text: '主讲：待补充');
  String _stageLabel = '初中 · 九年级';
  String _textbookLabel = '浙教版';
  String _focusLabel = '讲义整理';
  String _focusStudentId = '';
  String _lessonId = '';
  String _documentId = '';
  List<String> _memberStudentIds = const [];
  List<StudentWorkspaceRecord> _students = const [];
  List<LessonWorkspaceRecord> _lessons = const [];
  List<DocumentSummary> _documents = const [];
  bool _loadingStudents = true;
  bool _loadingLessons = true;
  bool _loadingDocuments = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadLessons();
    _loadDocuments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    super.dispose();
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
      final selectedFocusStudent =
          _students.cast<StudentWorkspaceRecord?>().firstWhere(
                (student) => student?.id == _focusStudentId,
                orElse: () => null,
              );
      final selectedLesson = _lessons.cast<LessonWorkspaceRecord?>().firstWhere(
            (lesson) => lesson?.id == _lessonId,
            orElse: () => null,
          );
      final selectedDocument = _documents.cast<DocumentSummary?>().firstWhere(
            (document) => document?.id == _documentId,
            orElse: () => null,
          );
      final created = await AppServices.instance.classRepository.createClass(
        name: _nameController.text.trim(),
        stageLabel: _stageLabel,
        teacherLabel: _teacherController.text.trim(),
        textbookLabel: _textbookLabel,
        focusLabel: _focusLabel,
        focusStudentId: _focusStudentId.isEmpty ? null : _focusStudentId,
        focusStudentName:
            _focusStudentId.isEmpty ? null : (selectedFocusStudent?.name ?? ''),
        lessonId: _lessonId.isEmpty ? null : _lessonId,
        lessonFocusLabel:
            _lessonId.isEmpty ? null : (selectedLesson?.title ?? '待安排课堂'),
        documentId: _documentId.isEmpty ? null : _documentId,
        latestDocLabel:
            _documentId.isEmpty ? null : (selectedDocument?.name ?? '暂无资料'),
        memberStudentIds: _memberStudentIds,
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
        _errorMessage = '创建班级失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '创建班级失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusCandidates = _memberStudentIds.isEmpty
        ? _students
        : _students
            .where((student) => _memberStudentIds.contains(student.id))
            .toList(growable: false);
    final focusStudentValue =
        _students.any((student) => student.id == _focusStudentId) &&
                (_memberStudentIds.isEmpty ||
                    _memberStudentIds.contains(_focusStudentId))
            ? _focusStudentId
            : '';
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
                  '新建班级',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '创建时就补齐成员、课堂和资料承接，后续再继续完善时间线与分层结构。',
                  style: TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  WorkspaceMessageBanner.error(
                    title: '还不能创建班级',
                    message: _errorMessage!,
                    padding: const EdgeInsets.all(12),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '班级名称',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? '请先输入班级名称' : null,
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
                DropdownButtonFormField<String>(
                  initialValue: _stageLabel,
                  decoration: const InputDecoration(
                    labelText: '学段',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '小学 · 五年级', child: Text('小学 · 五年级')),
                    DropdownMenuItem(value: '初中 · 八年级', child: Text('初中 · 八年级')),
                    DropdownMenuItem(value: '初中 · 九年级', child: Text('初中 · 九年级')),
                    DropdownMenuItem(value: '高中 · 高一', child: Text('高中 · 高一')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _stageLabel = value);
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _focusLabel,
                  decoration: const InputDecoration(
                    labelText: '当前工作重点',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '讲义整理', child: Text('讲义整理')),
                    DropdownMenuItem(value: '试卷跟进', child: Text('试卷跟进')),
                    DropdownMenuItem(value: '课堂复盘', child: Text('课堂复盘')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _focusLabel = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: focusStudentValue,
                  decoration: const InputDecoration(
                    labelText: '重点学生',
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
                    labelText: '班级成员',
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
                                        _memberStudentIds.contains(student.id);
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
                                            _memberStudentIds = [
                                              ..._memberStudentIds,
                                              student.id,
                                            ];
                                          } else {
                                            _memberStudentIds =
                                                _memberStudentIds
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
                  initialValue: lessonValue,
                  decoration: const InputDecoration(
                    labelText: '关联课堂',
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
                        child: Text(_submitting ? '创建中...' : '创建班级'),
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
