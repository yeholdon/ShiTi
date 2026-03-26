import 'package:flutter/material.dart';

import '../../core/models/question_detail.dart';
import '../../core/models/taxonomy_option.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_shell.dart';

Future<QuestionDetail?> showCreateQuestionDialog(BuildContext context) {
  return showDialog<QuestionDetail>(
    context: context,
    builder: (_) => const _QuestionEditorDialog(),
  );
}

Future<QuestionDetail?> showEditQuestionDialog(
  BuildContext context, {
  required QuestionDetail question,
}) {
  return showDialog<QuestionDetail>(
    context: context,
    builder: (_) => _QuestionEditorDialog(question: question),
  );
}

class _QuestionEditorDialog extends StatefulWidget {
  const _QuestionEditorDialog({this.question});

  final QuestionDetail? question;

  bool get isEditing => question != null;

  @override
  State<_QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<_QuestionEditorDialog> {
  static const _questionTypes = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: 'single_choice', child: Text('选择题')),
    DropdownMenuItem(value: 'fill_blank', child: Text('填空题')),
    DropdownMenuItem(value: 'solution', child: Text('解答题')),
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stemController = TextEditingController(
    text: widget.question?.stemText ?? '',
  );
  late final TextEditingController _analysisController = TextEditingController(
    text: widget.question?.analysisText ?? '',
  );
  late final TextEditingController _solutionController = TextEditingController(
    text: widget.question?.solutionText ?? '',
  );
  late final TextEditingController _commentaryController =
      TextEditingController(
    text: widget.question?.commentaryText ?? '',
  );
  late final TextEditingController _scoreController = TextEditingController(
    text: widget.question?.defaultScore ?? '10.00',
  );
  late String _type = widget.question?.type ?? 'solution';
  late int _difficulty = widget.question?.difficulty ?? 3;
  String _subjectId = '';
  List<TaxonomyOption> _subjectOptions = const <TaxonomyOption>[];
  bool _loadingSubjects = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _stemController.dispose();
    _analysisController.dispose();
    _solutionController.dispose();
    _commentaryController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects =
          await AppServices.instance.taxonomyRepository.listSubjects();
      if (!mounted) {
        return;
      }
      final matched = subjects.cast<TaxonomyOption?>().firstWhere(
            (option) => option?.label == widget.question?.subject,
            orElse: () => null,
          );
      setState(() {
        _subjectOptions = subjects;
        _subjectId = matched?.id ?? '';
        _loadingSubjects = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _subjectOptions = const <TaxonomyOption>[];
        _loadingSubjects = false;
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
      final repository = AppServices.instance.questionRepository;
      final result = widget.isEditing
          ? await repository.updateQuestion(
              questionId: widget.question!.id,
              stemText: _stemController.text.trim(),
              analysisText: _analysisController.text.trim(),
              solutionText: _solutionController.text.trim(),
              commentaryText: _commentaryController.text.trim(),
              type: _type,
              difficulty: _difficulty,
              defaultScore: _scoreController.text.trim(),
              subjectId: _subjectId.isEmpty ? null : _subjectId,
            )
          : await repository.createQuestion(
              stemText: _stemController.text.trim(),
              analysisText: _analysisController.text.trim(),
              solutionText: _solutionController.text.trim(),
              commentaryText: _commentaryController.text.trim(),
              type: _type,
              difficulty: _difficulty,
              defaultScore: _scoreController.text.trim(),
              subjectId: _subjectId.isEmpty ? null : _subjectId,
            );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage =
            '${widget.isEditing ? '更新' : '创建'}题目失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '${widget.isEditing ? '更新' : '创建'}题目失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectValue =
        _subjectOptions.any((option) => option.id == _subjectId)
            ? _subjectId
            : '';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: WorkspacePanel(
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isEditing ? '编辑题目' : '新建题目',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isEditing
                        ? '更新题干、题解和基础元信息，保存后会直接刷新当前题目详情。'
                        : '先录入题干和题解主干，题目创建后即可继续加入题库、选题篮或文档。',
                    style: const TextStyle(
                      height: 1.5,
                      color: TelegramPalette.textMuted,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    WorkspaceMessageBanner.error(
                      title: '题目还不能保存',
                      message: _errorMessage!,
                      padding: const EdgeInsets.all(12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildMultilineField(
                    controller: _stemController,
                    label: '题干',
                    minLines: 4,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '请先输入题干' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildMultilineField(
                    controller: _analysisController,
                    label: '整体分析（可选）',
                    minLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildMultilineField(
                    controller: _solutionController,
                    label: '详细题解',
                    minLines: 5,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请先输入详细题解'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildMultilineField(
                    controller: _commentaryController,
                    label: '点评（可选）',
                    minLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: const InputDecoration(
                            labelText: '题型',
                            border: OutlineInputBorder(),
                          ),
                          items: _questionTypes,
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _type = value;
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<int>(
                          initialValue: _difficulty,
                          decoration: const InputDecoration(
                            labelText: '难度',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 · 极难')),
                            DropdownMenuItem(value: 2, child: Text('2 · 难')),
                            DropdownMenuItem(value: 3, child: Text('3 · 中难')),
                            DropdownMenuItem(value: 4, child: Text('4 · 中等')),
                            DropdownMenuItem(value: 5, child: Text('5 · 易')),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _difficulty = value;
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: TextFormField(
                          controller: _scoreController,
                          decoration: const InputDecoration(
                            labelText: '默认分值',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? '请先输入默认分值'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: subjectValue,
                    decoration: const InputDecoration(
                      labelText: '学科（可选）',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('沿用默认学科')),
                      ..._subjectOptions.map(
                        (subject) => DropdownMenuItem(
                          value: subject.id,
                          child: Text(subject.label),
                        ),
                      ),
                    ],
                    onChanged: _loadingSubjects
                        ? null
                        : (value) {
                            setState(() {
                              _subjectId = value ?? '';
                            });
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
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(widget.isEditing
                                  ? Icons.save_outlined
                                  : Icons.add_circle_outline),
                          label: Text(
                            _submitting
                                ? '保存中…'
                                : (widget.isEditing ? '保存修改' : '创建题目'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMultilineField({
    required TextEditingController controller,
    required String label,
    int minLines = 3,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines + 2,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}
