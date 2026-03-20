import 'package:flutter/material.dart';

import '../../core/models/document_detail_args.dart';
import '../../core/models/document_item_summary.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/question_basket_page_args.dart';
import '../../core/models/question_detail_args.dart';
import '../../core/models/question_summary.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../documents/create_document_dialog.dart';
import '../documents/select_document_dialog.dart';
import '../library/question_summary_preview.dart';
import '../shared/question_workspace_context_card.dart';
import '../shared/primary_navigation_bar.dart';
import '../shared/workspace_shell.dart';

class QuestionBasketPage extends StatefulWidget {
  const QuestionBasketPage({
    super.key,
    this.args,
  });

  final QuestionBasketPageArgs? args;

  @override
  State<QuestionBasketPage> createState() => _QuestionBasketPageState();
}

class _QuestionBasketPageState extends State<QuestionBasketPage> {
  final TextEditingController _queryController = TextEditingController();
  List<QuestionSummary>? _questions;
  Set<String> _selectedQuestionIds = <String>{};
  bool _addingAll = false;
  bool _creatingAndAddingAll = false;
  bool _addingSelected = false;
  bool _creatingAndAddingSelected = false;
  bool _removingSelected = false;
  bool _clearingBasket = false;
  String _query = '';
  bool _showOnlySelectedQuestions = false;
  String _subjectFilter = 'all';
  String _stageFilter = 'all';
  String _gradeFilter = 'all';
  String _textbookFilter = 'all';
  String _chapterFilter = 'all';
  String _sortBy = 'basket';

  DocumentSummary? get _preferredTargetDocument =>
      widget.args?.preferredDocumentSnapshot;
  String? get _insertAfterItemId => widget.args?.insertAfterItemId;
  String? get _insertAfterItemTitle => widget.args?.insertAfterItemTitle;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadBasket();
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    String cancelLabel = '取消',
    String confirmLabel = '确定',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
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
                  title,
                  style: Theme.of(dialogContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(cancelLabel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(confirmLabel),
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

  Future<void> _loadBasket() async {
    final questions =
        await AppServices.instance.questionRepository.listBasketQuestions();
    if (!mounted) {
      return;
    }
    setState(() {
      _questions = questions;
      _selectedQuestionIds = _selectedQuestionIds
          .where((id) => questions.any((question) => question.id == id))
          .toSet();
    });
  }

  Future<void> _addAllToDocument() async {
    final questions = _questions ?? const <QuestionSummary>[];
    if (questions.isEmpty) {
      return;
    }

    final targetDocument =
        _preferredTargetDocument ?? await pickTargetDocument(context);
    if (targetDocument == null) {
      return;
    }

    final clearAfterAdd = await _pickBulkAddFollowUp(questions.length);
    if (clearAfterAdd == null) {
      return;
    }

    await _completeBulkAdd(
      targetDocument: targetDocument,
      questions: questions,
      clearAfterAdd: clearAfterAdd,
      markSubmitting: () {
        _addingAll = true;
      },
      clearSubmitting: () {
        _addingAll = false;
      },
    );
  }

  Future<void> _addSelectedToDocument() async {
    final questions = _selectedQuestions;
    if (questions.isEmpty || _addingSelected) {
      return;
    }

    final targetDocument =
        _preferredTargetDocument ?? await pickTargetDocument(context);
    if (targetDocument == null) {
      return;
    }

    final removeAfterAdd = await _pickSelectionAddFollowUp(questions.length);
    if (removeAfterAdd == null) {
      return;
    }

    await _completeSelectionAdd(
      targetDocument: targetDocument,
      questions: questions,
      removeAfterAdd: removeAfterAdd,
      markSubmitting: () {
        _addingSelected = true;
      },
      clearSubmitting: () {
        _addingSelected = false;
      },
      successMessage: '已将 ${questions.length} 道已选题加入文档：${targetDocument.name}',
    );
  }

  Future<void> _createDocumentAndAddSelected() async {
    final questions = _selectedQuestions;
    if (questions.isEmpty || _creatingAndAddingSelected) {
      return;
    }

    final targetDocument = await showCreateDocumentDialog(
      context,
      initialName: '${questions.length}题讲义',
      initialKind: 'handout',
      title: '新建文档并加入',
    );
    if (targetDocument == null) {
      return;
    }

    final removeAfterAdd = await _pickSelectionAddFollowUp(questions.length);
    if (removeAfterAdd == null) {
      return;
    }

    await _completeSelectionAdd(
      targetDocument: targetDocument,
      questions: questions,
      removeAfterAdd: removeAfterAdd,
      markSubmitting: () {
        _creatingAndAddingSelected = true;
      },
      clearSubmitting: () {
        _creatingAndAddingSelected = false;
      },
      successMessage:
          '已新建文档并加入 ${questions.length} 道已选题：${targetDocument.name}',
    );
  }

  Future<void> _createDocumentAndAddAll() async {
    final questions = _questions ?? const <QuestionSummary>[];
    if (questions.isEmpty) {
      return;
    }

    final targetDocument = await showCreateDocumentDialog(
      context,
      initialName: '${questions.length}题讲义',
      initialKind: 'handout',
      title: '新建文档并加入',
    );
    if (targetDocument == null) {
      return;
    }

    final clearAfterAdd = await _pickBulkAddFollowUp(questions.length);
    if (clearAfterAdd == null) {
      return;
    }

    await _completeBulkAdd(
      targetDocument: targetDocument,
      questions: questions,
      clearAfterAdd: clearAfterAdd,
      markSubmitting: () {
        _creatingAndAddingAll = true;
      },
      clearSubmitting: () {
        _creatingAndAddingAll = false;
      },
    );
  }

  Future<void> _completeBulkAdd({
    required dynamic targetDocument,
    required List<QuestionSummary> questions,
    required bool clearAfterAdd,
    required VoidCallback markSubmitting,
    required VoidCallback clearSubmitting,
  }) async {
    setState(markSubmitting);
    try {
      final previousItems = _insertAfterItemId == null ||
              targetDocument.id != _preferredTargetDocument?.id
          ? null
          : await AppServices.instance.documentRepository.listDocumentItems(
              targetDocument.id,
            );
      final createdItems =
          await AppServices.instance.documentRepository.addQuestionsToDocument(
        documentId: targetDocument.id,
        questions: questions,
      );
      await _repositionCreatedItems(
        documentId: targetDocument.id,
        previousItems: previousItems,
        createdItems: createdItems,
      );
      if (!mounted) {
        return;
      }

      if (clearAfterAdd) {
        await AppServices.instance.questionRepository.clearBasket();
        if (!mounted) {
          return;
        }
        setState(() {
          _questions = <QuestionSummary>[];
        });
      }

      final focusItem = createdItems.isNotEmpty ? createdItems.last : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clearAfterAdd
                ? previousItems != null
                    ? '已将 ${questions.length} 道题加入文档并清空选题篮，并插到${_insertAfterItemTitle ?? '当前选中项'}后：${targetDocument.name}'
                    : '已将 ${questions.length} 道题加入文档并清空选题篮：${targetDocument.name}'
                : previousItems != null
                    ? '已将 ${questions.length} 道题加入文档，并插到${_insertAfterItemTitle ?? '当前选中项'}后：${targetDocument.name}'
                    : '已将 ${questions.length} 道题加入文档：${targetDocument.name}',
          ),
        ),
      );
      Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: targetDocument.id,
          focusItemId: focusItem?.id,
          focusItemTitle: focusItem?.title ?? questions.last.title,
          recentlyAddedQuestionCount: questions.length,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量加入文档失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          clearSubmitting();
        });
      }
    }
  }

  Future<void> _completeSelectionAdd({
    required dynamic targetDocument,
    required List<QuestionSummary> questions,
    required bool removeAfterAdd,
    required VoidCallback markSubmitting,
    required VoidCallback clearSubmitting,
    required String successMessage,
  }) async {
    setState(markSubmitting);
    try {
      final previousItems = _insertAfterItemId == null ||
              targetDocument.id != _preferredTargetDocument?.id
          ? null
          : await AppServices.instance.documentRepository.listDocumentItems(
              targetDocument.id,
            );
      final createdItems =
          await AppServices.instance.documentRepository.addQuestionsToDocument(
        documentId: targetDocument.id,
        questions: questions,
      );
      await _repositionCreatedItems(
        documentId: targetDocument.id,
        previousItems: previousItems,
        createdItems: createdItems,
      );
      if (!mounted) {
        return;
      }

      if (removeAfterAdd) {
        final removedIds = questions.map((question) => question.id).toSet();
        for (final question in questions) {
          await AppServices.instance.questionRepository
              .removeQuestionFromBasket(question.id);
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _questions = (_questions ?? const <QuestionSummary>[])
              .where((question) => !removedIds.contains(question.id))
              .toList(growable: false);
        });
      }

      final focusItem = createdItems.isNotEmpty ? createdItems.last : null;
      setState(() {
        _selectedQuestionIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(previousItems != null
              ? removeAfterAdd
                  ? '$successMessage，并已移出这批题，且插到${_insertAfterItemTitle ?? '当前选中项'}后'
                  : '$successMessage，并已插到${_insertAfterItemTitle ?? '当前选中项'}后'
              : removeAfterAdd
                  ? '$successMessage，并已移出这批题'
                  : successMessage),
        ),
      );
      Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: targetDocument.id,
          focusItemId: focusItem?.id,
          focusItemTitle: focusItem?.title ?? questions.last.title,
          recentlyAddedQuestionCount: questions.length,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量加入文档失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          clearSubmitting();
        });
      }
    }
  }

  Future<void> _repositionCreatedItems({
    required String documentId,
    required List<DocumentItemSummary>? previousItems,
    required List<DocumentItemSummary> createdItems,
  }) async {
    if (previousItems == null ||
        createdItems.isEmpty ||
        _insertAfterItemId == null) {
      return;
    }
    final insertAfterIndex =
        previousItems.indexWhere((item) => item.id == _insertAfterItemId);
    if (insertAfterIndex < 0) {
      return;
    }
    final targetIndex = insertAfterIndex + 1;
    final moveSteps = previousItems.length - targetIndex;
    if (moveSteps <= 0) {
      return;
    }
    for (final createdItem in createdItems) {
      for (var i = 0; i < moveSteps; i += 1) {
        await AppServices.instance.documentRepository.moveDocumentItem(
          documentId: documentId,
          itemId: createdItem.id,
          offset: -1,
        );
      }
    }
  }

  Future<bool?> _pickBulkAddFollowUp(int questionCount) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: WorkspacePanel(
            borderRadius: 28,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '批量加入文档',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  '即将把 $questionCount 道题加入目标文档。加入后是否同时清空当前选题篮？',
                  style: const TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('取消'),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('加入但保留'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('加入并清空'),
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

  Future<bool?> _pickSelectionAddFollowUp(int questionCount) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: WorkspacePanel(
            borderRadius: 28,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '批量加入已选题',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  '即将把当前选中的 $questionCount 道题加入目标文档。加入后是否同时把这批题从选题篮移出？',
                  style: const TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('取消'),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('加入但保留'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('加入并移出'),
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

  Future<void> _removeQuestion(QuestionSummary question) async {
    await AppServices.instance.questionRepository
        .removeQuestionFromBasket(question.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _questions = (_questions ?? <QuestionSummary>[])
          .where((item) => item.id != question.id)
          .toList();
      _selectedQuestionIds.remove(question.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已从选题篮移除：${question.title}')),
    );
  }

  Future<void> _clearBasket() async {
    final questions = _questions ?? const <QuestionSummary>[];
    if (questions.isEmpty || _clearingBasket) {
      return;
    }
    final confirmed = await _showConfirmDialog(
      title: '清空选题篮',
      message: '确定清空当前选题篮中的 ${questions.length} 道题吗？',
      confirmLabel: '清空',
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _clearingBasket = true;
    });
    try {
      await AppServices.instance.questionRepository.clearBasket();
      if (!mounted) {
        return;
      }
      setState(() {
        _questions = <QuestionSummary>[];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选题篮已清空')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清空选题篮失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _clearingBasket = false;
        });
      }
    }
  }

  Future<void> _removeSelectedQuestions() async {
    final questions = _selectedQuestions;
    if (questions.isEmpty || _removingSelected) {
      return;
    }
    final confirmed = await _showConfirmDialog(
      title: '移出已选题',
      message: '确定把当前已选择的 ${questions.length} 道题从选题篮移除吗？',
      confirmLabel: '移出',
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _removingSelected = true;
    });
    try {
      for (final question in questions) {
        await AppServices.instance.questionRepository
            .removeQuestionFromBasket(question.id);
      }
      if (!mounted) {
        return;
      }
      final removedIds = questions.map((question) => question.id).toSet();
      setState(() {
        _questions = (_questions ?? <QuestionSummary>[])
            .where((question) => !removedIds.contains(question.id))
            .toList();
        _selectedQuestionIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移出 ${questions.length} 道已选题')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量移出选题篮失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _removingSelected = false;
        });
      }
    }
  }

  List<QuestionSummary> _applyFilter(List<QuestionSummary> questions) {
    final normalizedQuery = _query.trim().toLowerCase();
    return questions.where((question) {
      if (_subjectFilter != 'all' && question.subject != _subjectFilter) {
        return false;
      }
      if (_stageFilter != 'all' && question.stage != _stageFilter) {
        return false;
      }
      if (_gradeFilter != 'all' && question.grade != _gradeFilter) {
        return false;
      }
      if (_textbookFilter != 'all' && question.textbook != _textbookFilter) {
        return false;
      }
      if (_chapterFilter != 'all' && question.chapter != _chapterFilter) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return <String>[
        question.title,
        question.subject,
        question.stage,
        question.grade,
        question.textbook,
        question.chapter,
        question.stemPreview,
        ...question.tags,
      ].any((value) => value.toLowerCase().contains(normalizedQuery));
    }).toList(growable: false);
  }

  void _clearFilter() {
    _queryController.clear();
    setState(() {
      _query = '';
      _showOnlySelectedQuestions = false;
      _subjectFilter = 'all';
      _stageFilter = 'all';
      _gradeFilter = 'all';
      _textbookFilter = 'all';
      _chapterFilter = 'all';
      _sortBy = 'basket';
    });
  }

  List<QuestionSummary> get _filteredQuestions {
    final filtered = _applyFilter(_questions ?? const <QuestionSummary>[]);
    final visible = !_showOnlySelectedQuestions
        ? filtered
        : filtered
            .where((question) => _selectedQuestionIds.contains(question.id))
            .toList(growable: false);
    return _applySort(visible);
  }

  List<QuestionSummary> _applySort(List<QuestionSummary> questions) {
    final sorted = questions.toList(growable: true);
    switch (_sortBy) {
      case 'title':
        sorted.sort(
          (left, right) => left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              ),
        );
        break;
      case 'subject':
        sorted.sort((left, right) {
          final compare = left.subject.toLowerCase().compareTo(
                right.subject.toLowerCase(),
              );
          if (compare != 0) {
            return compare;
          }
          return left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              );
        });
        break;
      case 'stage':
        sorted.sort((left, right) {
          final compare = left.stage.toLowerCase().compareTo(
                right.stage.toLowerCase(),
              );
          if (compare != 0) {
            return compare;
          }
          return left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              );
        });
        break;
      case 'grade':
        sorted.sort((left, right) {
          final compare = left.grade.toLowerCase().compareTo(
                right.grade.toLowerCase(),
              );
          if (compare != 0) {
            return compare;
          }
          return left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              );
        });
        break;
      case 'textbook':
        sorted.sort((left, right) {
          final compare = left.textbook.toLowerCase().compareTo(
                right.textbook.toLowerCase(),
              );
          if (compare != 0) {
            return compare;
          }
          return left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              );
        });
        break;
      case 'chapter':
        sorted.sort((left, right) {
          final compare = left.chapter.toLowerCase().compareTo(
                right.chapter.toLowerCase(),
              );
          if (compare != 0) {
            return compare;
          }
          return left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              );
        });
        break;
      case 'basket':
      default:
        break;
    }
    return sorted;
  }

  List<QuestionSummary> get _selectedQuestions {
    return (_questions ?? const <QuestionSummary>[])
        .where((question) => _selectedQuestionIds.contains(question.id))
        .toList(growable: false);
  }

  void _setSelection(String questionId, bool selected) {
    setState(() {
      if (selected) {
        _selectedQuestionIds.add(questionId);
      } else {
        _selectedQuestionIds.remove(questionId);
      }
    });
  }

  void _selectAllFiltered() {
    setState(() {
      _selectedQuestionIds =
          _filteredQuestions.map((question) => question.id).toSet();
    });
  }

  void _invertFilteredSelection() {
    setState(() {
      final nextSelection = <String>{..._selectedQuestionIds};
      for (final question in _filteredQuestions) {
        if (nextSelection.contains(question.id)) {
          nextSelection.remove(question.id);
        } else {
          nextSelection.add(question.id);
        }
      }
      _selectedQuestionIds = nextSelection;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedQuestionIds.clear();
    });
  }

  bool get _allFilteredSelected {
    final filtered = _filteredQuestions;
    return filtered.isNotEmpty &&
        filtered
            .every((question) => _selectedQuestionIds.contains(question.id));
  }

  List<String> _distinctSubjects(List<QuestionSummary> questions) {
    final values = questions
        .map((question) => question.subject.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<String> _distinctTextbooks(List<QuestionSummary> questions) {
    final values = questions
        .map((question) => question.textbook.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<String> _distinctGrades(List<QuestionSummary> questions) {
    final values = questions
        .map((question) => question.grade.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<String> _distinctStages(List<QuestionSummary> questions) {
    final values = questions
        .map((question) => question.stage.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<String> _distinctChapters(List<QuestionSummary> questions) {
    final values = questions
        .map((question) => question.chapter.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<(String, String)> get _activeFilterEntries {
    final entries = <(String, String)>[];
    final query = _query.trim();
    if (query.isNotEmpty) {
      entries.add(('关键词', query));
    }
    if (_subjectFilter != 'all') {
      entries.add(('学科', _subjectFilter));
    }
    if (_stageFilter != 'all') {
      entries.add(('学段', _stageFilter));
    }
    if (_gradeFilter != 'all') {
      entries.add(('年级', _gradeFilter));
    }
    if (_textbookFilter != 'all') {
      entries.add(('教材', _textbookFilter));
    }
    if (_chapterFilter != 'all') {
      entries.add(('章节', _chapterFilter));
    }
    if (_sortBy != 'basket') {
      entries.add(('排序', _sortLabel(_sortBy)));
    }
    if (_showOnlySelectedQuestions) {
      entries.add(('范围', '只看已选'));
    }
    return entries;
  }

  String _sortLabel(String value) {
    switch (value) {
      case 'title':
        return '按标题';
      case 'subject':
        return '按学科';
      case 'stage':
        return '按学段';
      case 'grade':
        return '按年级';
      case 'textbook':
        return '按教材';
      case 'chapter':
        return '按章节';
      case 'basket':
      default:
        return '选题篮顺序';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPrimaryNavigation = _preferredTargetDocument == null &&
        _insertAfterItemId == null &&
        (_insertAfterItemTitle ?? '').isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('选题篮')),
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: workspaceConstrainedContent(
            context,
            child: ListView(
              padding: workspacePagePadding(context),
              children: [
                _BasketHeroSection(
                  totalCount: (_questions ?? const <QuestionSummary>[]).length,
                  visibleCount: _filteredQuestions.length,
                  selectedCount: _selectedQuestionIds.length,
                  preferredTargetDocumentName: _preferredTargetDocument?.name,
                  insertAfterItemTitle: _insertAfterItemTitle,
                ),
                const SizedBox(height: 18),
                WorkspacePanel(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WorkspaceEyebrow(
                        label: 'Basket Control',
                        icon: Icons.checklist_rtl_outlined,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '筛选、确认上下文，然后把一篮题目送进文档工作区。',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '这里用来整理候选题和批量加题，适合先收拢一批题，再把它们放进讲义或试卷。',
                        style: TextStyle(
                          height: 1.5,
                          color: TelegramPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _queryController,
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: '搜索选题篮',
                          hintText: '题目 / 学科 / 章节 / 标签',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.trim().isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _clearFilter,
                                  icon: const Icon(Icons.close),
                                  tooltip: '清空搜索',
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final filterWidth = constraints.maxWidth < 520
                              ? constraints.maxWidth
                              : 220.0;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: filterWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _subjectFilter,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '学科',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('全部学科'),
                                    ),
                                    ..._distinctSubjects(
                                      _questions ?? const <QuestionSummary>[],
                                    ).map(
                                      (subject) => DropdownMenuItem(
                                        value: subject,
                                        child: Text(subject),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _subjectFilter = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                              SizedBox(
                                width: filterWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _chapterFilter,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '章节',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('全部章节'),
                                    ),
                                    ..._distinctChapters(
                                      _questions ?? const <QuestionSummary>[],
                                    ).map(
                                      (chapter) => DropdownMenuItem(
                                        value: chapter,
                                        child: Text(
                                          chapter,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _chapterFilter = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                              SizedBox(
                                width: filterWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _textbookFilter,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '教材',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('全部教材'),
                                    ),
                                    ..._distinctTextbooks(
                                      _questions ?? const <QuestionSummary>[],
                                    ).map(
                                      (textbook) => DropdownMenuItem(
                                        value: textbook,
                                        child: Text(textbook),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _textbookFilter = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                              SizedBox(
                                width: filterWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _stageFilter,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '学段',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('全部学段'),
                                    ),
                                    ..._distinctStages(
                                      _questions ?? const <QuestionSummary>[],
                                    ).map(
                                      (stage) => DropdownMenuItem(
                                        value: stage,
                                        child: Text(stage),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _stageFilter = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                              SizedBox(
                                width: filterWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _gradeFilter,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '年级',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('全部年级'),
                                    ),
                                    ..._distinctGrades(
                                      _questions ?? const <QuestionSummary>[],
                                    ).map(
                                      (grade) => DropdownMenuItem(
                                        value: grade,
                                        child: Text(grade),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _gradeFilter = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                              SizedBox(
                                width: filterWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _sortBy,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '排序',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'basket',
                                      child: Text('选题篮顺序'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'title',
                                      child: Text('按标题'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'subject',
                                      child: Text('按学科'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'stage',
                                      child: Text('按学段'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'grade',
                                      child: Text('按年级'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'textbook',
                                      child: Text('按教材'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'chapter',
                                      child: Text('按章节'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _sortBy = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          WorkspaceMetricPill(
                            label: '当前结果',
                            value: '${_filteredQuestions.length}',
                          ),
                          WorkspaceMetricPill(
                            label: '学科',
                            value:
                                '${_distinctSubjects(_filteredQuestions).length}',
                          ),
                          WorkspaceMetricPill(
                            label: '学段',
                            value:
                                '${_distinctStages(_filteredQuestions).length}',
                          ),
                          WorkspaceMetricPill(
                            label: '年级',
                            value:
                                '${_distinctGrades(_filteredQuestions).length}',
                          ),
                          WorkspaceMetricPill(
                            label: '教材',
                            value:
                                '${_distinctTextbooks(_filteredQuestions).length}',
                          ),
                          WorkspaceMetricPill(
                            label: '章节',
                            value:
                                '${_distinctChapters(_filteredQuestions).length}',
                          ),
                        ],
                      ),
                      if (_activeFilterEntries.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _activeFilterEntries
                              .map(
                                (entry) => _BasketSummaryChip(
                                  label: entry.$1,
                                  value: entry.$2,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 12,
                        spacing: 12,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              PrimaryNavigationBar.navigateToSection(
                                context,
                                PrimaryAppSection.documents,
                              );
                            },
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('进入文档工作区'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              PrimaryNavigationBar.navigateToSection(
                                context,
                                PrimaryAppSection.library,
                              );
                            },
                            icon: const Icon(Icons.search),
                            label: const Text('继续挑题'),
                          ),
                          OutlinedButton.icon(
                            onPressed: (_questions == null ||
                                    _questions!.isEmpty ||
                                    _addingAll ||
                                    _creatingAndAddingAll ||
                                    _clearingBasket)
                                ? null
                                : _clearBasket,
                            icon: _clearingBasket
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.clear_all),
                            label: Text(_clearingBasket ? '清空中…' : '清空选题篮'),
                          ),
                          FilledButton.icon(
                            onPressed: (_questions == null ||
                                    _questions!.isEmpty ||
                                    _addingAll ||
                                    _creatingAndAddingAll ||
                                    _clearingBasket)
                                ? null
                                : _addAllToDocument,
                            icon: const Icon(
                              Icons.playlist_add_check_circle_outlined,
                            ),
                            label: Text(_addingAll ? '加入中...' : '全部加入文档'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: (_questions == null ||
                                    _questions!.isEmpty ||
                                    _addingAll ||
                                    _creatingAndAddingAll ||
                                    _clearingBasket)
                                ? null
                                : _createDocumentAndAddAll,
                            icon: const Icon(Icons.add_circle_outline),
                            label: Text(
                              _creatingAndAddingAll ? '创建并加入中...' : '新建文档并加入',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_preferredTargetDocument != null) ...[
                  QuestionWorkspaceContextCard(
                    documentName: _preferredTargetDocument!.name,
                    insertAfterItemTitle: _insertAfterItemTitle,
                    onOpenDocument: () {
                      Navigator.of(context).pushNamed(
                        AppRouter.documentDetail,
                        arguments: DocumentDetailArgs(
                          documentId: _preferredTargetDocument!.id,
                          documentSnapshot: _preferredTargetDocument,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                ],
                if (_questions == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_questions!.isEmpty)
                  WorkspacePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '当前选题篮为空。你可以先从题库挑题，再回到这里继续编排文档。',
                          style: TextStyle(
                            height: 1.5,
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            PrimaryNavigationBar.navigateToSection(
                              context,
                              PrimaryAppSection.library,
                            );
                          },
                          icon: const Icon(Icons.travel_explore_outlined),
                          label: const Text('去题库挑题'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (_filteredQuestions.isEmpty)
                    WorkspacePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _showOnlySelectedQuestions
                                ? '当前没有已选中的题目可展示。'
                                : '当前筛选条件下没有匹配的题目。',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: TelegramPalette.textStrong,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _showOnlySelectedQuestions
                                ? '可以先退出“只看已选”，或重新选择一批题目后再批量处理。'
                                : '可以调整关键词、学科、学段、年级、教材或章节筛选，或清空筛选后继续处理当前选题篮。',
                            style: const TextStyle(
                              height: 1.5,
                              color: TelegramPalette.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: _showOnlySelectedQuestions
                                ? () {
                                    setState(() {
                                      _showOnlySelectedQuestions = false;
                                    });
                                  }
                                : _clearFilter,
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: Text(
                              _showOnlySelectedQuestions ? '退出只看已选' : '清空筛选',
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        _BasketSelectionBar(
                          selectedCount: _selectedQuestionIds.length,
                          filteredCount: _filteredQuestions.length,
                          selectedFilteredCount: _filteredQuestions
                              .where(
                                (question) =>
                                    _selectedQuestionIds.contains(question.id),
                              )
                              .length,
                          selectedSubjectCount:
                              _distinctSubjects(_selectedQuestions).length,
                          selectedTextbookCount:
                              _distinctTextbooks(_selectedQuestions).length,
                          selectedChapterCount:
                              _distinctChapters(_selectedQuestions).length,
                          selectedStageCount:
                              _distinctStages(_selectedQuestions).length,
                          selectedGradeCount:
                              _distinctGrades(_selectedQuestions).length,
                          allFilteredSelected: _allFilteredSelected,
                          showOnlySelected: _showOnlySelectedQuestions,
                          addingSelected: _addingSelected,
                          creatingAndAddingSelected: _creatingAndAddingSelected,
                          removingSelected: _removingSelected,
                          preferredTargetDocumentName:
                              _preferredTargetDocument?.name,
                          onSelectAll: _selectAllFiltered,
                          onInvertSelection: _invertFilteredSelection,
                          onToggleShowOnlySelected: (value) {
                            setState(() {
                              _showOnlySelectedQuestions = value;
                            });
                          },
                          onClearSelection: _clearSelection,
                          onAddToDocument: _addSelectedToDocument,
                          onCreateDocumentAndAdd: _createDocumentAndAddSelected,
                          onRemoveSelected: _removeSelectedQuestions,
                        ),
                        const SizedBox(height: 12),
                        ..._filteredQuestions.map(
                          (question) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BasketQuestionCard(
                              question: question,
                              isSelected: _selectedQuestionIds.contains(
                                question.id,
                              ),
                              preferredTargetDocument: _preferredTargetDocument,
                              insertAfterItemId: _insertAfterItemId,
                              insertAfterItemTitle: _insertAfterItemTitle,
                              onSelectionChanged: (selected) {
                                _setSelection(question.id, selected);
                              },
                              onRemove: () => _removeQuestion(question),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          MediaQuery.of(context).size.width < 900 && showPrimaryNavigation
              ? const PrimaryNavigationBar(
                  currentSection: PrimaryAppSection.library,
                )
              : null,
    );
  }
}

class _BasketHeroSection extends StatelessWidget {
  const _BasketHeroSection({
    required this.totalCount,
    required this.visibleCount,
    required this.selectedCount,
    this.preferredTargetDocumentName,
    this.insertAfterItemTitle,
  });

  final int totalCount;
  final int visibleCount;
  final int selectedCount;
  final String? preferredTargetDocumentName;
  final String? insertAfterItemTitle;

  @override
  Widget build(BuildContext context) {
    final contextLabel = preferredTargetDocumentName == null
        ? '当前在单独整理候选题，适合先收拢一批题，再统一决定放进哪份文档。'
        : insertAfterItemTitle == null || insertAfterItemTitle!.trim().isEmpty
            ? '当前在为“$preferredTargetDocumentName”补题，这一篮题接下来会优先加入这份文档。'
            : '当前在为“$preferredTargetDocumentName”补题，这一篮题接下来会优先放到“$insertAfterItemTitle”后面。';
    return WorkspacePanel(
      padding: const EdgeInsets.all(24),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: 'Question Basket',
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 14),
          const Text(
            '先确认这一篮题的范围，再决定哪些题要落到当前文档。',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          WorkspaceMessageBanner.info(
            title: preferredTargetDocumentName == null
                ? '当前模式：独立整理'
                : '当前模式：为文档补题',
            message: contextLabel,
            child: null,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              WorkspaceMetricPill(
                label: '篮中题目',
                value: '$totalCount',
                highlight: true,
              ),
              WorkspaceMetricPill(label: '当前结果', value: '$visibleCount'),
              WorkspaceMetricPill(label: '已选子集', value: '$selectedCount'),
              WorkspaceMetricPill(
                label: '当前模式',
                value: preferredTargetDocumentName == null ? '独立整理' : '为文档补题',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BasketSelectionBar extends StatelessWidget {
  const _BasketSelectionBar({
    required this.selectedCount,
    required this.filteredCount,
    required this.selectedFilteredCount,
    required this.selectedSubjectCount,
    required this.selectedTextbookCount,
    required this.selectedChapterCount,
    required this.selectedStageCount,
    required this.selectedGradeCount,
    required this.allFilteredSelected,
    required this.showOnlySelected,
    required this.addingSelected,
    required this.creatingAndAddingSelected,
    required this.removingSelected,
    this.preferredTargetDocumentName,
    required this.onSelectAll,
    required this.onInvertSelection,
    required this.onToggleShowOnlySelected,
    required this.onClearSelection,
    required this.onAddToDocument,
    required this.onCreateDocumentAndAdd,
    required this.onRemoveSelected,
  });

  final int selectedCount;
  final int filteredCount;
  final int selectedFilteredCount;
  final int selectedSubjectCount;
  final int selectedTextbookCount;
  final int selectedChapterCount;
  final int selectedStageCount;
  final int selectedGradeCount;
  final bool allFilteredSelected;
  final bool showOnlySelected;
  final bool addingSelected;
  final bool creatingAndAddingSelected;
  final bool removingSelected;
  final String? preferredTargetDocumentName;
  final VoidCallback onSelectAll;
  final VoidCallback onInvertSelection;
  final ValueChanged<bool> onToggleShowOnlySelected;
  final VoidCallback onClearSelection;
  final Future<void> Function() onAddToDocument;
  final Future<void> Function() onCreateDocumentAndAdd;
  final Future<void> Function() onRemoveSelected;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      backgroundColor: selectedCount > 0
          ? TelegramPalette.surface
          : TelegramPalette.surfaceRaised,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            selectedCount > 0
                ? '已选择 $selectedCount / $filteredCount 道题'
                : '可选择当前结果中的部分题目再批量处理',
            style: const TextStyle(
              color: TelegramPalette.textStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (selectedCount > 0) ...[
            Chip(
              avatar: const Icon(Icons.auto_stories_outlined, size: 18),
              label: Text('涉及 $selectedSubjectCount 个学科'),
            ),
            Chip(
              avatar: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text('涉及 $selectedTextbookCount 套教材'),
            ),
            Chip(
              avatar: const Icon(Icons.account_tree_outlined, size: 18),
              label: Text('涉及 $selectedChapterCount 个章节'),
            ),
            Chip(
              avatar: const Icon(Icons.layers_outlined, size: 18),
              label: Text('涉及 $selectedStageCount 个学段'),
            ),
            Chip(
              avatar: const Icon(Icons.looks_outlined, size: 18),
              label: Text('涉及 $selectedGradeCount 个年级'),
            ),
          ],
          OutlinedButton.icon(
            onPressed: allFilteredSelected ? null : onSelectAll,
            icon: const Icon(Icons.select_all),
            label: Text(allFilteredSelected ? '已全选' : '全选当前结果'),
          ),
          OutlinedButton.icon(
            onPressed: filteredCount == 0 ? null : onInvertSelection,
            icon: const Icon(Icons.flip_to_back_outlined),
            label: Text(
              selectedFilteredCount == 0 ? '反选当前结果' : '反选当前结果',
            ),
          ),
          WorkspaceFilterPill(
            label: showOnlySelected ? '只看已选中' : '只看已选',
            selected: showOnlySelected,
            onTap: selectedCount == 0
                ? null
                : () => onToggleShowOnlySelected(!showOnlySelected),
            icon: Icons.checklist_rtl_outlined,
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ? null : onClearSelection,
            icon: const Icon(Icons.clear_all),
            label: const Text('清空选择'),
          ),
          FilledButton.tonalIcon(
            onPressed: selectedCount == 0 ||
                    addingSelected ||
                    creatingAndAddingSelected ||
                    removingSelected
                ? null
                : () => onAddToDocument(),
            icon: addingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.note_add_outlined),
            label: Text(
              addingSelected
                  ? '加入中…'
                  : (preferredTargetDocumentName == null ? '加入文档' : '加入当前文档'),
            ),
          ),
          FilledButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelected ||
                    creatingAndAddingSelected ||
                    removingSelected
                ? null
                : () => onCreateDocumentAndAdd(),
            icon: creatingAndAddingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
            label: Text(
              creatingAndAddingSelected ? '创建并加入中…' : '新建文档并加入',
            ),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelected ||
                    creatingAndAddingSelected ||
                    removingSelected
                ? null
                : () => onRemoveSelected(),
            icon: removingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.remove_circle_outline),
            label: Text(removingSelected ? '移出中…' : '移出已选题'),
          ),
        ],
      ),
    );
  }
}

class _BasketQuestionCard extends StatefulWidget {
  const _BasketQuestionCard({
    required this.question,
    required this.isSelected,
    this.preferredTargetDocument,
    this.insertAfterItemId,
    this.insertAfterItemTitle,
    required this.onSelectionChanged,
    required this.onRemove,
  });

  final QuestionSummary question;
  final bool isSelected;
  final DocumentSummary? preferredTargetDocument;
  final String? insertAfterItemId;
  final String? insertAfterItemTitle;
  final ValueChanged<bool> onSelectionChanged;
  final Future<void> Function() onRemove;

  @override
  State<_BasketQuestionCard> createState() => _BasketQuestionCardState();
}

class _BasketSummaryChip extends StatelessWidget {
  const _BasketSummaryChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TelegramPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: Text(
        '$label：$value',
        style: const TextStyle(
          color: TelegramPalette.textStrong,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BasketQuestionCardState extends State<_BasketQuestionCard> {
  bool _addingToDocument = false;
  bool _creatingAndAdding = false;
  bool _removing = false;

  Future<void> _repositionCreatedItem({
    required String documentId,
    required List<DocumentItemSummary>? previousItems,
    required DocumentItemSummary createdItem,
  }) async {
    if (previousItems == null || widget.insertAfterItemId == null) {
      return;
    }
    final insertAfterIndex = previousItems.indexWhere(
      (item) => item.id == widget.insertAfterItemId,
    );
    if (insertAfterIndex < 0) {
      return;
    }
    final targetIndex = insertAfterIndex + 1;
    final moveSteps = previousItems.length - targetIndex;
    if (moveSteps <= 0) {
      return;
    }
    for (var i = 0; i < moveSteps; i += 1) {
      await AppServices.instance.documentRepository.moveDocumentItem(
        documentId: documentId,
        itemId: createdItem.id,
        offset: -1,
      );
    }
  }

  Future<void> _addToDocument(BuildContext context) async {
    if (_addingToDocument) {
      return;
    }
    final targetDocument =
        widget.preferredTargetDocument ?? await pickTargetDocument(context);
    if (targetDocument == null) {
      return;
    }
    setState(() {
      _addingToDocument = true;
    });
    try {
      List<DocumentItemSummary>? previousItems;
      if (widget.insertAfterItemId != null &&
          widget.preferredTargetDocument?.id == targetDocument.id) {
        previousItems = await AppServices.instance.documentRepository
            .listDocumentItems(targetDocument.id);
      }
      final createdItem =
          await AppServices.instance.documentRepository.addQuestionToDocument(
        documentId: targetDocument.id,
        question: widget.question,
      );
      await _repositionCreatedItem(
        documentId: targetDocument.id,
        previousItems: previousItems,
        createdItem: createdItem,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.insertAfterItemTitle != null &&
                    widget.preferredTargetDocument?.id == targetDocument.id
                ? '已插入到“${widget.insertAfterItemTitle}”后：${targetDocument.name}'
                : '已加入文档：${targetDocument.name}',
          ),
        ),
      );
      Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: targetDocument.id,
          focusItemId: createdItem.id,
          focusItemTitle: widget.question.title,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入文档失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingToDocument = false;
        });
      }
    }
  }

  Future<void> _removeFromBasket(BuildContext context) async {
    if (_removing) {
      return;
    }
    setState(() {
      _removing = true;
    });
    try {
      await widget.onRemove();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移出选题篮失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _removing = false;
        });
      }
    }
  }

  Future<void> _createDocumentAndAdd(BuildContext context) async {
    if (_creatingAndAdding) {
      return;
    }
    final targetDocument = await showCreateDocumentDialog(
      context,
      initialName: '${widget.question.title} 讲义',
      initialKind: 'handout',
      title: '新建文档并加入',
    );
    if (targetDocument == null) {
      return;
    }
    setState(() {
      _creatingAndAdding = true;
    });
    try {
      final createdItem =
          await AppServices.instance.documentRepository.addQuestionToDocument(
        documentId: targetDocument.id,
        question: widget.question,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已新建文档并加入：${targetDocument.name}')),
      );
      Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: targetDocument.id,
          focusItemId: createdItem.id,
          focusItemTitle: widget.question.title,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新建文档并加入失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creatingAndAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Checkbox(
                value: widget.isSelected,
                onChanged: (selected) {
                  widget.onSelectionChanged(selected ?? false);
                },
              ),
              const SizedBox(width: 4),
              const Text(
                '批量选择',
                style: TextStyle(
                  color: TelegramPalette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          QuestionSummaryPreview(
            question: widget.question,
            showSubject: false,
            showTags: false,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed:
                    (_addingToDocument || _creatingAndAdding || _removing)
                        ? null
                        : () => _addToDocument(context),
                icon: _addingToDocument
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.note_add_outlined),
                label: Text(
                  _addingToDocument
                      ? '加入中…'
                      : (widget.preferredTargetDocument == null
                          ? '加入文档'
                          : '加入当前文档'),
                ),
              ),
              FilledButton.icon(
                onPressed:
                    (_addingToDocument || _creatingAndAdding || _removing)
                        ? null
                        : () => _createDocumentAndAdd(context),
                icon: _creatingAndAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(_creatingAndAdding ? '创建并加入中…' : '新建文档并加入'),
              ),
              OutlinedButton.icon(
                onPressed:
                    (_addingToDocument || _creatingAndAdding || _removing)
                        ? null
                        : () => _removeFromBasket(context),
                icon: _removing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(_removing ? '移除中…' : '移出选题篮'),
              ),
              OutlinedButton.icon(
                onPressed: (_addingToDocument ||
                        _creatingAndAdding ||
                        _removing)
                    ? null
                    : () {
                        Navigator.of(context).pushNamed(
                          AppRouter.questionDetail,
                          arguments: QuestionDetailArgs(
                            questionId: widget.question.id,
                            preferredDocumentSnapshot:
                                widget.preferredTargetDocument,
                            insertAfterItemId: widget.insertAfterItemId,
                            insertAfterItemTitle: widget.insertAfterItemTitle,
                          ),
                        );
                      },
                icon: const Icon(Icons.open_in_new),
                label: const Text('查看详情'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
