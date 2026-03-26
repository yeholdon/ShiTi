import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_item_summary.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/classes_page_args.dart';
import '../../core/models/library_filter_state.dart';
import '../../core/models/library_page_args.dart';
import '../../core/models/class_detail_args.dart';
import '../../core/models/lesson_detail_args.dart';
import '../../core/models/lessons_page_args.dart';
import '../../core/models/question_detail_args.dart';
import '../../core/models/question_summary.dart';
import '../../core/models/student_detail_args.dart';
import '../../core/models/students_page_args.dart';
import '../../core/models/taxonomy_option.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../documents/create_document_dialog.dart';
import '../documents/select_document_dialog.dart';
import '../shared/question_workspace_context_card.dart';
import '../shared/primary_navigation_bar.dart';
import '../shared/primary_page_scroll_memory.dart';
import '../shared/primary_page_view_state_memory.dart';
import '../shared/workspace_module_paths.dart';
import '../shared/workspace_module_shell.dart';
import '../shared/workspace_shell.dart';
import 'question_editor_dialog.dart';
import 'question_summary_preview.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    this.args,
  });

  final LibraryPageArgs? args;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  static const _pageKey = 'library';
  static const TaxonomyOption _allSubjects =
      TaxonomyOption(id: '', label: '全部学科');
  static const TaxonomyOption _allStages =
      TaxonomyOption(id: '', label: '全部学段');
  static const TaxonomyOption _allTextbooks =
      TaxonomyOption(id: '', label: '全部教材');

  final _searchController = TextEditingController();
  late final bool _forceInitialTopReset =
      PrimaryPageScrollMemory.consumePendingTopReset(_pageKey);
  late final ScrollController _scrollController = ScrollController(
    initialScrollOffset: _hasContextualEntry || _forceInitialTopReset
        ? 0
        : PrimaryPageScrollMemory.offsetFor(_pageKey),
  );

  LibraryFilterState _filters = const LibraryFilterState();
  List<QuestionSummary> _questions = const <QuestionSummary>[];
  Set<String> _basketQuestionIds = <String>{};
  Set<String> _selectedQuestionIds = <String>{};
  List<TaxonomyOption> _subjectOptions = const <TaxonomyOption>[_allSubjects];
  List<TaxonomyOption> _stageOptions = const <TaxonomyOption>[_allStages];
  List<TaxonomyOption> _textbookOptions = const <TaxonomyOption>[_allTextbooks];
  Object? _loadError;
  bool _loading = true;
  bool _addingSelectedToBasket = false;
  bool _removingSelectedFromBasket = false;
  bool _addingSelectedToDocument = false;
  bool _creatingDocumentAndAddingSelected = false;
  bool _showOnlySelectedQuestions = false;
  String _basketFilter = 'all';
  String _gradeFilter = 'all';
  String _chapterFilter = 'all';
  String _sortBy = 'results';
  bool _didApplyContextualFilters = false;
  bool _creatingQuestion = false;

  DocumentSummary? get _preferredTargetDocument =>
      widget.args?.preferredDocumentSnapshot;
  String? get _insertAfterItemId => widget.args?.insertAfterItemId;
  String? get _insertAfterItemTitle => widget.args?.insertAfterItemTitle;
  String? get _flashMessage => widget.args?.flashMessage;
  String? get _highlightTitle => widget.args?.highlightTitle;
  String? get _highlightDetail => widget.args?.highlightDetail;
  String? get _feedbackBadgeLabel => widget.args?.feedbackBadgeLabel;
  String? get _sourceModule => widget.args?.sourceModule;
  String? get _sourceRecordId => widget.args?.sourceRecordId;
  String? get _sourceLabel => widget.args?.sourceLabel;
  bool get _hasContextualEntry =>
      widget.args?.preferredDocumentSnapshot != null ||
      ((widget.args?.initialQuery ?? '').trim().isNotEmpty) ||
      ((widget.args?.initialSubjectLabel ?? '').trim().isNotEmpty) ||
      ((widget.args?.initialStageLabel ?? '').trim().isNotEmpty) ||
      ((widget.args?.initialTextbookLabel ?? '').trim().isNotEmpty) ||
      ((_flashMessage ?? '').trim().isNotEmpty) ||
      ((_highlightTitle ?? '').trim().isNotEmpty) ||
      ((_highlightDetail ?? '').trim().isNotEmpty) ||
      ((_feedbackBadgeLabel ?? '').trim().isNotEmpty) ||
      ((_sourceModule ?? '').trim().isNotEmpty) ||
      ((_sourceRecordId ?? '').trim().isNotEmpty) ||
      ((_sourceLabel ?? '').trim().isNotEmpty) ||
      ((widget.args?.insertAfterItemId ?? '').trim().isNotEmpty) ||
      ((widget.args?.insertAfterItemTitle ?? '').trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_rememberScrollOffset);
    if (_forceInitialTopReset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }
        _scrollController.jumpTo(0);
      });
    }
    final savedViewState = PrimaryPageViewStateMemory.library;
    if (!_hasContextualEntry && savedViewState != null) {
      _filters = savedViewState.filters;
      _showOnlySelectedQuestions = savedViewState.showOnlySelectedQuestions;
      _basketFilter = savedViewState.basketFilter;
      _gradeFilter = savedViewState.gradeFilter;
      _chapterFilter = savedViewState.chapterFilter;
      _sortBy = savedViewState.sortBy;
      _searchController.text = savedViewState.filters.query;
    } else {
      final contextualQuery = widget.args?.initialQuery?.trim();
      if (contextualQuery != null && contextualQuery.isNotEmpty) {
        _filters = _filters.copyWith(query: contextualQuery);
        _searchController.text = contextualQuery;
      }
    }
    _loadTaxonomyOptions();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _rememberScrollOffset() {
    PrimaryPageScrollMemory.update(_pageKey, _scrollController.offset);
  }

  void _rememberViewState() {
    PrimaryPageViewStateMemory.library = PrimaryLibraryViewState(
      filters: _filters,
      showOnlySelectedQuestions: _showOnlySelectedQuestions,
      basketFilter: _basketFilter,
      gradeFilter: _gradeFilter,
      chapterFilter: _chapterFilter,
      sortBy: _sortBy,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final repository = AppServices.instance.questionRepository;
    try {
      final questions = await repository.listQuestions(filters: _filters);
      final basketIds = await repository.listBasketQuestionIds();
      if (!mounted) {
        return;
      }
      setState(() {
        _questions = questions;
        _basketQuestionIds = basketIds;
        _selectedQuestionIds = _selectedQuestionIds
            .where((id) => questions.any((question) => question.id == id))
            .toSet();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadTaxonomyOptions() async {
    final repository = AppServices.instance.taxonomyRepository;
    try {
      final subjects = await repository.listSubjects();
      final stages = await repository.listStages();
      final textbooks = await repository.listTextbooks();
      if (!mounted) {
        return;
      }
      setState(() {
        _subjectOptions = <TaxonomyOption>[_allSubjects, ...subjects];
        _stageOptions = <TaxonomyOption>[_allStages, ...stages];
        _textbookOptions = <TaxonomyOption>[_allTextbooks, ...textbooks];
        _applyContextualFiltersIfNeeded();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _subjectOptions = const <TaxonomyOption>[_allSubjects];
        _stageOptions = const <TaxonomyOption>[_allStages];
        _textbookOptions = const <TaxonomyOption>[_allTextbooks];
        _applyContextualFiltersIfNeeded();
      });
    }
  }

  void _applyContextualFiltersIfNeeded() {
    if (_didApplyContextualFilters || !_hasContextualEntry) {
      return;
    }
    final subjectLabel = widget.args?.initialSubjectLabel?.trim();
    final stageLabel = widget.args?.initialStageLabel?.trim();
    final textbookLabel = widget.args?.initialTextbookLabel?.trim();
    final query = widget.args?.initialQuery?.trim();
    final subjectOption = _subjectOptions.cast<TaxonomyOption?>().firstWhere(
          (option) => option?.label == subjectLabel,
          orElse: () => null,
        );
    final stageOption = _stageOptions.cast<TaxonomyOption?>().firstWhere(
          (option) => option?.label == stageLabel,
          orElse: () => null,
        );
    final textbookOption = _textbookOptions.cast<TaxonomyOption?>().firstWhere(
          (option) => option?.label == textbookLabel,
          orElse: () => null,
        );
    _filters = _filters.copyWith(
      query: (query?.isNotEmpty ?? false) ? query : _filters.query,
      subject: subjectOption?.label ?? _filters.subject,
      subjectId: subjectOption?.id ?? _filters.subjectId,
      stage: stageOption?.label ?? _filters.stage,
      stageId: stageOption?.id ?? _filters.stageId,
      textbook: textbookOption?.label ?? _filters.textbook,
      textbookId: textbookOption?.id ?? _filters.textbookId,
    );
    if ((query?.isNotEmpty ?? false)) {
      _searchController.text = query!;
    }
    _didApplyContextualFilters = true;
  }

  void _updateFilters(LibraryFilterState next) {
    setState(() {
      _filters = next;
      if (_searchController.text != next.query) {
        _searchController.text = next.query;
      }
    });
    _rememberViewState();
    _reload();
  }

  Future<void> _reloadWithGuard() async {
    await _reload();
  }

  Future<void> _openQuestionDetail(String questionId) async {
    final result = await Navigator.of(context).pushNamed(
      AppRouter.questionDetail,
      arguments: _buildQuestionDetailArgs(questionId),
    );
    if (!mounted) {
      return;
    }
    if (result == true) {
      await _reload();
    }
  }

  Future<void> _createQuestion() async {
    if (_creatingQuestion) {
      return;
    }
    setState(() {
      _creatingQuestion = true;
    });
    try {
      final created = await showCreateQuestionDialog(context);
      if (!mounted || created == null) {
        return;
      }
      await _reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已创建题目：${created.title}')),
      );
      await _openQuestionDetail(created.id);
    } finally {
      if (mounted) {
        setState(() {
          _creatingQuestion = false;
        });
      }
    }
  }

  QuestionDetailArgs _buildQuestionDetailArgs(String questionId) {
    final query = _searchController.text.trim();
    return QuestionDetailArgs(
      questionId: questionId,
      preferredDocumentSnapshot: _preferredTargetDocument,
      insertAfterItemId: _insertAfterItemId,
      insertAfterItemTitle: _insertAfterItemTitle,
      libraryContextArgs: LibraryPageArgs(
        preferredDocumentSnapshot: _preferredTargetDocument,
        insertAfterItemId: _insertAfterItemId,
        insertAfterItemTitle: _insertAfterItemTitle,
        initialQuery: query.isEmpty ? null : query,
        initialSubjectLabel:
            (_filters.subjectId ?? '').isEmpty ? null : _filters.subject,
        initialStageLabel:
            (_filters.stageId ?? '').isEmpty ? null : _filters.stage,
        initialTextbookLabel:
            (_filters.textbookId ?? '').isEmpty ? null : _filters.textbook,
        flashMessage: _flashMessage,
        highlightTitle: _highlightTitle,
        highlightDetail: _highlightDetail,
        feedbackBadgeLabel: _feedbackBadgeLabel,
        sourceModule: _sourceModule,
        sourceRecordId: _sourceRecordId,
        sourceLabel: _sourceLabel,
      ),
    );
  }

  String get _returnActionLabel {
    switch (_sourceModule) {
      case 'students':
        return '返回学生页';
      case 'student_detail':
        return '返回学生详情';
      case 'classes':
        return '返回班级页';
      case 'class_detail':
        return '返回班级详情';
      case 'lessons':
        return '返回课堂页';
      case 'lesson_detail':
        return '返回课堂详情';
      default:
        return '返回工作台';
    }
  }

  void _openWorkspace() {
    switch (_sourceModule) {
      case 'students':
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.students,
          (route) => false,
          arguments: StudentsPageArgs(
            focusStudentId: _sourceRecordId,
            flashMessage: '已从题库返回 ${_sourceLabel ?? '学生页'}，可继续按当前学生回看筛题结果。',
            highlightTitle: '当前学生题库上下文',
            highlightDetail:
                '${_sourceLabel ?? '当前学生'} 的学科、学段和教材条件仍可继续用于挑题与回看。',
            feedbackBadgeLabel: '题库回看',
          ),
        );
        return;
      case 'student_detail':
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.studentDetail,
          (route) => false,
          arguments: StudentDetailArgs(
            studentId: _sourceRecordId!,
            flashMessage: '已从题库返回 ${_sourceLabel ?? '学生详情'}，可继续按当前学生回看筛题结果。',
          ),
        );
        return;
      case 'classes':
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.classes,
          (route) => false,
          arguments: ClassesPageArgs(
            focusClassId: _sourceRecordId,
            flashMessage: '已从题库返回 ${_sourceLabel ?? '班级页'}，可继续按当前班级回看筛题结果。',
            highlightTitle: '当前班级题库上下文',
            highlightDetail:
                '${_sourceLabel ?? '当前班级'} 的学段、教材和关联学科条件仍可继续用于挑题与回看。',
            feedbackBadgeLabel: '题库回看',
          ),
        );
        return;
      case 'class_detail':
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.classDetail,
          (route) => false,
          arguments: ClassDetailArgs(
            classId: _sourceRecordId!,
            flashMessage: '已从题库返回 ${_sourceLabel ?? '班级详情'}，可继续按当前班级回看筛题结果。',
          ),
        );
        return;
      case 'lessons':
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.lessons,
          (route) => false,
          arguments: LessonsPageArgs(
            focusLessonId: _sourceRecordId,
            flashMessage: '已从题库返回 ${_sourceLabel ?? '课堂页'}，可继续按当前课堂回看筛题结果。',
            highlightTitle: '当前课堂题库上下文',
            highlightDetail:
                '${_sourceLabel ?? '当前课堂'} 的主题、学段和教材条件仍可继续用于挑题与回看。',
            feedbackBadgeLabel: '题库回看',
          ),
        );
        return;
      case 'lesson_detail':
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.lessonDetail,
          (route) => false,
          arguments: LessonDetailArgs(
            lessonId: _sourceRecordId!,
            flashMessage: '已从题库返回 ${_sourceLabel ?? '课堂详情'}，可继续按当前课堂回看筛题结果。',
          ),
        );
        return;
      default:
        PrimaryNavigationBar.navigateToSection(context, PrimaryAppSection.home);
        return;
    }
  }

  bool get _hasActiveFilters {
    return (_filters.query).trim().isNotEmpty ||
        (_filters.subjectId?.isNotEmpty ?? false) ||
        (_filters.stageId?.isNotEmpty ?? false) ||
        (_filters.textbookId?.isNotEmpty ?? false) ||
        _gradeFilter != 'all' ||
        _chapterFilter != 'all' ||
        _basketFilter != 'all';
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _showOnlySelectedQuestions = false;
      _basketFilter = 'all';
      _gradeFilter = 'all';
      _chapterFilter = 'all';
      _sortBy = 'results';
    });
    _rememberViewState();
    _updateFilters(const LibraryFilterState());
  }

  void _setBasketMembership(String questionId, bool isInBasket) {
    setState(() {
      if (isInBasket) {
        _basketQuestionIds.add(questionId);
      } else {
        _basketQuestionIds.remove(questionId);
      }
    });
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

  void _selectAllVisibleQuestions() {
    setState(() {
      _selectedQuestionIds =
          _visibleQuestions.map((question) => question.id).toSet();
    });
  }

  void _selectQuestionsByBasketMembership(bool isInBasket) {
    setState(() {
      _selectedQuestionIds = _visibleQuestions
          .where(
            (question) =>
                _basketQuestionIds.contains(question.id) == isInBasket,
          )
          .map((question) => question.id)
          .toSet();
    });
  }

  void _invertVisibleQuestionsSelection() {
    setState(() {
      final nextSelection = <String>{..._selectedQuestionIds};
      for (final question in _visibleQuestions) {
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

  Future<void> _addSelectedQuestionsToBasket() async {
    if (_addingSelectedToBasket || _selectedQuestionIds.isEmpty) {
      return;
    }
    final repository = AppServices.instance.questionRepository;
    final selectedQuestions = _questions
        .where((question) => _selectedQuestionIds.contains(question.id))
        .toList();
    final questionsToAdd = selectedQuestions
        .where((question) => !_basketQuestionIds.contains(question.id))
        .toList();
    if (questionsToAdd.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选中的题目已经都在选题篮里了')),
      );
      return;
    }

    setState(() {
      _addingSelectedToBasket = true;
    });
    try {
      for (final question in questionsToAdd) {
        await repository.addQuestionToBasket(question);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _basketQuestionIds
            .addAll(questionsToAdd.map((question) => question.id));
        _selectedQuestionIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已批量加入选题篮：${questionsToAdd.length} 道题'),
          action: SnackBarAction(
            label: '查看',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.basket);
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量加入选题篮失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingSelectedToBasket = false;
        });
      }
    }
  }

  Future<void> _removeSelectedQuestionsFromBasket() async {
    if (_removingSelectedFromBasket || _selectedQuestionIds.isEmpty) {
      return;
    }
    final selectedQuestions = _questions
        .where((question) => _selectedQuestionIds.contains(question.id))
        .toList(growable: false);
    final questionsToRemove = selectedQuestions
        .where((question) => _basketQuestionIds.contains(question.id))
        .toList(growable: false);
    if (questionsToRemove.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选中的题目当前都不在选题篮里')),
      );
      return;
    }

    setState(() {
      _removingSelectedFromBasket = true;
    });
    try {
      for (final question in questionsToRemove) {
        await AppServices.instance.questionRepository
            .removeQuestionFromBasket(question.id);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _basketQuestionIds
            .removeAll(questionsToRemove.map((question) => question.id));
        _selectedQuestionIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已从选题篮移除 ${questionsToRemove.length} 道题')),
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
          _removingSelectedFromBasket = false;
        });
      }
    }
  }

  Future<void> _addSelectedQuestionsToDocument() async {
    if (_addingSelectedToDocument || _selectedQuestionIds.isEmpty) {
      return;
    }
    final targetDocument =
        _preferredTargetDocument ?? await pickTargetDocument(context);
    if (targetDocument == null || !mounted) {
      return;
    }
    await _completeSelectedAddToDocument(
      targetDocument: targetDocument,
      markSubmitting: () {
        _addingSelectedToDocument = true;
      },
      clearSubmitting: () {
        _addingSelectedToDocument = false;
      },
      successMessageBuilder: (document, count) =>
          '已将 $count 道题加入文档：${document.name}',
    );
  }

  Future<void> _createDocumentAndAddSelectedQuestions() async {
    if (_creatingDocumentAndAddingSelected || _selectedQuestionIds.isEmpty) {
      return;
    }
    final selectedQuestions = _questions
        .where((question) => _selectedQuestionIds.contains(question.id))
        .toList();
    if (selectedQuestions.isEmpty) {
      return;
    }
    final targetDocument = await showCreateDocumentDialog(
      context,
      initialName: '${selectedQuestions.length}题讲义',
      initialKind: 'handout',
      title: '新建文档并批量加入',
    );
    if (targetDocument == null || !mounted) {
      return;
    }
    await _completeSelectedAddToDocument(
      targetDocument: targetDocument,
      markSubmitting: () {
        _creatingDocumentAndAddingSelected = true;
      },
      clearSubmitting: () {
        _creatingDocumentAndAddingSelected = false;
      },
      successMessageBuilder: (document, count) =>
          '已新建文档并加入 $count 道题：${document.name}',
    );
  }

  Future<void> _completeSelectedAddToDocument({
    required DocumentSummary targetDocument,
    required VoidCallback markSubmitting,
    required VoidCallback clearSubmitting,
    required String Function(DocumentSummary targetDocument, int count)
        successMessageBuilder,
  }) async {
    final selectedQuestions = _questions
        .where((question) => _selectedQuestionIds.contains(question.id))
        .toList();
    if (selectedQuestions.isEmpty) {
      return;
    }

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
        questions: selectedQuestions,
      );
      await _repositionCreatedItems(
        documentId: targetDocument.id,
        previousItems: previousItems,
        createdItems: createdItems,
      );
      if (!mounted) {
        return;
      }
      final focusItem = createdItems.isNotEmpty ? createdItems.last : null;
      setState(() {
        _selectedQuestionIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            previousItems != null
                ? '${successMessageBuilder(targetDocument, selectedQuestions.length)}，并已插到${_insertAfterItemTitle ?? '当前选中项'}后'
                : successMessageBuilder(
                    targetDocument, selectedQuestions.length),
          ),
        ),
      );
      Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: targetDocument.id,
          focusItemId: focusItem?.id,
          focusItemTitle: focusItem?.title ?? selectedQuestions.last.title,
          recentlyAddedQuestionCount: selectedQuestions.length,
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

  bool get _allVisibleQuestionsSelected {
    final visibleQuestions = _visibleQuestions;
    return visibleQuestions.isNotEmpty &&
        visibleQuestions
            .every((question) => _selectedQuestionIds.contains(question.id));
  }

  List<QuestionSummary> get _visibleQuestions {
    final visible = _questions.where((question) {
      if (_showOnlySelectedQuestions &&
          !_selectedQuestionIds.contains(question.id)) {
        return false;
      }
      final isInBasket = _basketQuestionIds.contains(question.id);
      if (_basketFilter == 'in_basket' && !isInBasket) {
        return false;
      }
      if (_basketFilter == 'not_in_basket' && isInBasket) {
        return false;
      }
      if (_gradeFilter != 'all' && question.grade != _gradeFilter) {
        return false;
      }
      if (_chapterFilter != 'all' && question.chapter != _chapterFilter) {
        return false;
      }
      return true;
    }).toList(growable: false);
    return _applySort(visible);
  }

  List<String> get _chapterOptions {
    final values = _questions
        .map((question) => question.chapter.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<String> get _gradeOptions {
    final values = _questions
        .map((question) => question.grade.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
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
      case 'basket':
        sorted.sort((left, right) {
          final leftRank = _basketQuestionIds.contains(left.id) ? 0 : 1;
          final rightRank = _basketQuestionIds.contains(right.id) ? 0 : 1;
          final compare = leftRank.compareTo(rightRank);
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
      case 'results':
      default:
        break;
    }
    return sorted;
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

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final wideDesktop = MediaQuery.sizeOf(context).width >= 1280;
    final visibleQuestions = _visibleQuestions;
    final inBasketVisibleCount = visibleQuestions
        .where((question) => _basketQuestionIds.contains(question.id))
        .length;
    final outOfBasketVisibleCount =
        visibleQuestions.length - inBasketVisibleCount;
    final showPrimaryNavigation = _preferredTargetDocument == null &&
        _insertAfterItemId == null &&
        (_insertAfterItemTitle ?? '').isEmpty;
    final pageBody = workspaceConstrainedContent(
      context,
      child: ListView(
        controller: _scrollController,
        padding: workspacePagePadding(context),
        children: [
          if (wideDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _LibraryHeroSection(
                    totalCount: _questions.length,
                    visibleCount: visibleQuestions.length,
                    selectedCount: _selectedQuestionIds.length,
                    inBasketCount: _basketQuestionIds.length,
                    inDocumentContext: _preferredTargetDocument != null,
                    onOpenWorkspace: _openWorkspace,
                    returnLabel: _returnActionLabel,
                    hasSourceContext: (_sourceModule ?? '').trim().isNotEmpty,
                  ),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: 320,
                  child: _LibraryStatusCard(
                    modeLabel: AppConfig.dataModeLabel,
                    sessionLabel:
                        AppServices.instance.session?.username ?? '未登录',
                    tenantLabel:
                        AppServices.instance.activeTenant?.code ?? '未选择机构',
                  ),
                ),
              ],
            )
          else ...[
            _LibraryHeroSection(
              totalCount: _questions.length,
              visibleCount: visibleQuestions.length,
              selectedCount: _selectedQuestionIds.length,
              inBasketCount: _basketQuestionIds.length,
              inDocumentContext: _preferredTargetDocument != null,
              onOpenWorkspace: _openWorkspace,
              returnLabel: _returnActionLabel,
              hasSourceContext: (_sourceModule ?? '').trim().isNotEmpty,
            ),
            const SizedBox(height: 16),
            _LibraryStatusCard(
              modeLabel: AppConfig.dataModeLabel,
              sessionLabel: AppServices.instance.session?.username ?? '未登录',
              tenantLabel: AppServices.instance.activeTenant?.code ?? '未选择机构',
            ),
          ],
          if ((_flashMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            WorkspaceMessageBanner.info(
              title: '当前上下文',
              message: _flashMessage!,
            ),
          ],
          if (((_highlightTitle ?? '').trim().isNotEmpty) ||
              ((_highlightDetail ?? '').trim().isNotEmpty) ||
              ((_feedbackBadgeLabel ?? '').trim().isNotEmpty) ||
              ((_sourceLabel ?? '').trim().isNotEmpty)) ...[
            const SizedBox(height: 16),
            WorkspacePanel(
              padding: workspacePanelPadding(context),
              backgroundColor: TelegramPalette.surfaceAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if ((_feedbackBadgeLabel ?? '').trim().isNotEmpty)
                        WorkspaceInfoPill(
                          label: '当前来源',
                          value: _feedbackBadgeLabel!,
                          highlight: true,
                        ),
                      if ((_sourceLabel ?? '').trim().isNotEmpty)
                        WorkspaceInfoPill(
                          label: '当前对象',
                          value: _sourceLabel!,
                        ),
                      WorkspaceInfoPill(
                        label: '当前模式',
                        value:
                            _preferredTargetDocument != null ? '为文档找题' : '独立筛题',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    (_highlightTitle ?? '').trim().isNotEmpty
                        ? _highlightTitle!
                        : '当前题库上下文',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: TelegramPalette.text,
                    ),
                  ),
                  if ((_highlightDetail ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _highlightDetail!,
                      style: const TextStyle(
                        height: 1.5,
                        color: TelegramPalette.textStrong,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _FilterCard(
            filters: _filters,
            basketFilter: _basketFilter,
            gradeFilter: _gradeFilter,
            chapterFilter: _chapterFilter,
            sortBy: _sortBy,
            visibleQuestions: visibleQuestions,
            visibleInBasketCount: visibleQuestions
                .where((question) => _basketQuestionIds.contains(question.id))
                .length,
            visibleOutOfBasketCount: visibleQuestions
                .where((question) => !_basketQuestionIds.contains(question.id))
                .length,
            searchController: _searchController,
            subjectOptions: _subjectOptions,
            stageOptions: _stageOptions,
            textbookOptions: _textbookOptions,
            chapterOptions: _chapterOptions,
            onChanged: _updateFilters,
            onBasketFilterChanged: (value) {
              setState(() {
                _basketFilter = value;
              });
              _rememberViewState();
            },
            onGradeFilterChanged: (value) {
              setState(() {
                _gradeFilter = value;
              });
              _rememberViewState();
            },
            onChapterFilterChanged: (value) {
              setState(() {
                _chapterFilter = value;
              });
              _rememberViewState();
            },
            gradeOptions: _gradeOptions,
            onSortChanged: (value) {
              setState(() {
                _sortBy = value;
              });
              _rememberViewState();
            },
            onClearFilters: _clearFilters,
          ),
          if (_preferredTargetDocument != null) ...[
            const SizedBox(height: 16),
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
          ],
          const SizedBox(height: 16),
          if (_questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _LibrarySelectionBar(
                selectedCount: _selectedQuestionIds.length,
                selectedInBasketCount: _questions
                    .where(
                      (question) =>
                          _selectedQuestionIds.contains(question.id) &&
                          _basketQuestionIds.contains(question.id),
                    )
                    .length,
                selectedOutOfBasketCount: _questions
                    .where(
                      (question) =>
                          _selectedQuestionIds.contains(question.id) &&
                          !_basketQuestionIds.contains(question.id),
                    )
                    .length,
                selectedSubjectCount: _questions
                    .where((question) =>
                        _selectedQuestionIds.contains(question.id))
                    .map((question) => question.subject.trim())
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .length,
                selectedTextbookCount: _questions
                    .where((question) =>
                        _selectedQuestionIds.contains(question.id))
                    .map((question) => question.textbook.trim())
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .length,
                selectedChapterCount: _questions
                    .where((question) =>
                        _selectedQuestionIds.contains(question.id))
                    .map((question) => question.chapter.trim())
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .length,
                selectedStageCount: _questions
                    .where((question) =>
                        _selectedQuestionIds.contains(question.id))
                    .map((question) => question.stage.trim())
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .length,
                selectedGradeCount: _questions
                    .where((question) =>
                        _selectedQuestionIds.contains(question.id))
                    .map((question) => question.grade.trim())
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .length,
                totalCount: visibleQuestions.length,
                selectedVisibleCount: visibleQuestions
                    .where(
                      (question) => _selectedQuestionIds.contains(question.id),
                    )
                    .length,
                allSelected: _allVisibleQuestionsSelected,
                showOnlySelected: _showOnlySelectedQuestions,
                inBasketVisibleCount: inBasketVisibleCount,
                outOfBasketVisibleCount: outOfBasketVisibleCount,
                addingToBasket: _addingSelectedToBasket,
                removingFromBasket: _removingSelectedFromBasket,
                addingToDocument: _addingSelectedToDocument,
                creatingDocumentAndAdding: _creatingDocumentAndAddingSelected,
                preferredTargetDocumentName: _preferredTargetDocument?.name,
                onSelectAll: _selectAllVisibleQuestions,
                onSelectInBasket: () =>
                    _selectQuestionsByBasketMembership(true),
                onSelectOutOfBasket: () =>
                    _selectQuestionsByBasketMembership(false),
                onInvertSelection: _invertVisibleQuestionsSelection,
                onToggleShowOnlySelected: (value) {
                  setState(() {
                    _showOnlySelectedQuestions = value;
                  });
                  _rememberViewState();
                },
                onClearSelection: _clearSelection,
                onAddToBasket: _addSelectedQuestionsToBasket,
                onRemoveFromBasket: _removeSelectedQuestionsFromBasket,
                onAddToDocument: _addSelectedQuestionsToDocument,
                onCreateDocumentAndAdd: _createDocumentAndAddSelectedQuestions,
              ),
            ),
          if (_loadError != null)
            _LibraryErrorCard(
              message: _loadError is HttpJsonException
                  ? '题库加载失败：${(_loadError as HttpJsonException).message}（HTTP ${(_loadError as HttpJsonException).statusCode}）'
                  : '题库加载失败：$_loadError',
              onRetry: _reloadWithGuard,
            )
          else if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_questions.isEmpty || visibleQuestions.isEmpty)
            WorkspacePanel(
              padding: EdgeInsets.all(compact ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _showOnlySelectedQuestions
                        ? '当前没有已选中的题目可展示。'
                        : _hasActiveFilters
                            ? '当前筛选条件下没有匹配的题目。'
                            : '当前没有可展示的题目。',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: TelegramPalette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showOnlySelectedQuestions
                        ? '可以先退出“只看已选”，或重新选择一批题目后再批量处理。'
                        : _hasActiveFilters
                            ? '可以调整关键词、学科、学段、年级、教材或章节筛选，或者直接清空筛选后重新查看题库。'
                            : AppConfig.useMockData
                                ? '当前使用样例数据，可以直接从本地演示题目开始挑题。'
                                : '当前还没有可展示的题目。先登录并选择机构，再回来查看真实题库。',
                    style: TextStyle(
                      height: 1.5,
                      color: TelegramPalette.textMuted,
                    ),
                  ),
                  if (_showOnlySelectedQuestions || _hasActiveFilters) ...[
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: _showOnlySelectedQuestions
                          ? () {
                              setState(() {
                                _showOnlySelectedQuestions = false;
                              });
                              _rememberViewState();
                            }
                          : _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: Text(
                        _showOnlySelectedQuestions
                            ? '退出只看已选'
                            : (compact ? '清空' : '清空筛选'),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Column(
              children: visibleQuestions
                  .map(
                    (question) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _QuestionPreviewCard(
                        question: question,
                        isInBasket: _basketQuestionIds.contains(question.id),
                        isSelected: _selectedQuestionIds.contains(question.id),
                        preferredTargetDocument: _preferredTargetDocument,
                        insertAfterItemId: _insertAfterItemId,
                        insertAfterItemTitle: _insertAfterItemTitle,
                        onOpenQuestionDetail: _openQuestionDetail,
                        onBasketChanged: (isInBasket) {
                          _setBasketMembership(question.id, isInBasket);
                        },
                        onSelectionChanged: (selected) {
                          _setSelection(question.id, selected);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
    if (!showPrimaryNavigation) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: const Text('题库检索'),
          actions: [
            TextButton.icon(
              onPressed: _creatingQuestion ? null : _createQuestion,
              icon: _creatingQuestion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle_outline),
              label: Text(_creatingQuestion ? '创建中…' : '新建题目'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.login);
              },
              icon: const Icon(Icons.login),
              label: const Text('登录'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: WorkspaceBackdrop(
          child: SafeArea(
            child: pageBody,
          ),
        ),
      );
    }
    final activeTenant = AppServices.instance.activeTenant;
    return Scaffold(
      body: WorkspaceModuleShell(
        currentModule: WorkspaceModule.library,
        onSelectModule: (module) => navigateToWorkspaceModule(context, module),
        title: '题库',
        subtitle: '围绕题目内容、答案解析、标签、题库授权与文档投递，组织统一的检索与选题工作台。',
        searchHint: '搜索题目内容、章节、题型、教材、出处或题库实例',
        statusWidgets: [
          WorkspaceInfoPill(
            label: '数据模式',
            value: AppConfig.dataModeLabel,
          ),
          WorkspaceInfoPill(
            label: '当前场景',
            value: activeTenant == null
                ? '待选择机构'
                : activeTenant.isPersonal
                    ? '个人工作区'
                    : '机构工作区',
            highlight: activeTenant == null,
          ),
          WorkspaceInfoPill(
            label: '当前机构',
            value: activeTenant?.name ?? '未选择机构',
            highlight: activeTenant == null,
          ),
        ],
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonalIcon(
              onPressed: _creatingQuestion ? null : _createQuestion,
              icon: _creatingQuestion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle_outline),
              label: Text(_creatingQuestion ? '创建中…' : '新建题目'),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: _openWorkspace,
              tooltip: _returnActionLabel,
              icon: const Icon(Icons.home_outlined),
            ),
          ],
        ),
        body: pageBody,
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 900
          ? const PrimaryNavigationBar(
              currentSection: PrimaryAppSection.library,
            )
          : null,
    );
  }
}

class _LibraryHeroSection extends StatelessWidget {
  const _LibraryHeroSection({
    required this.totalCount,
    required this.visibleCount,
    required this.selectedCount,
    required this.inBasketCount,
    required this.inDocumentContext,
    required this.onOpenWorkspace,
    required this.returnLabel,
    required this.hasSourceContext,
  });

  final int totalCount;
  final int visibleCount;
  final int selectedCount;
  final int inBasketCount;
  final bool inDocumentContext;
  final VoidCallback onOpenWorkspace;
  final String returnLabel;
  final bool hasSourceContext;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final detail = inDocumentContext
        ? '当前在为既有文档补题，这一页负责检索、筛选、批量选择和跨页面投递。'
        : hasSourceContext
            ? '当前按既有对象上下文进入题库，这一页负责延续筛选条件，并把题目送入选题篮或文档。'
            : '当前在独立整理题池，这一页负责检索、筛选、批量选择和送入选题篮或文档。';
    return WorkspacePanel(
      padding: workspaceHeroPanelPadding(context),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: '题库检索',
            icon: Icons.travel_explore_outlined,
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: const Text(
              '先定位题目，再决定是放进选题篮还是直接落到当前文档。',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              detail,
              style: TextStyle(
                height: 1.55,
                color: TelegramPalette.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenWorkspace,
                icon: const Icon(Icons.home_outlined),
                label: Text(
                    compact ? returnLabel.replaceFirst('返回', '') : returnLabel),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              WorkspaceMetricPill(label: '题库总量', value: '$totalCount'),
              WorkspaceMetricPill(label: '当前结果', value: '$visibleCount'),
              WorkspaceMetricPill(
                label: '已选题目',
                value: '$selectedCount',
                highlight: selectedCount > 0,
              ),
              WorkspaceMetricPill(
                label: '选题篮',
                value: '$inBasketCount',
                highlight: inBasketCount > 0,
              ),
              WorkspaceMetricPill(
                label: '当前模式',
                value: inDocumentContext ? '为文档找题' : '独立浏览',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LibraryStatusCard extends StatelessWidget {
  const _LibraryStatusCard({
    required this.modeLabel,
    required this.sessionLabel,
    required this.tenantLabel,
  });

  final String modeLabel;
  final String sessionLabel;
  final String tenantLabel;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding:
          workspacePanelPadding(context, mobile: 14, tablet: 16, desktop: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusRow(label: '模式', value: modeLabel),
          const SizedBox(height: 8),
          _StatusRow(label: '会话', value: sessionLabel),
          const SizedBox(height: 8),
          _StatusRow(label: '机构', value: tenantLabel),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: TelegramPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: Row(
        children: [
          Text(
            '$label：',
            style: const TextStyle(
              color: TelegramPalette.textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TelegramPalette.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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

class _LibraryErrorCard extends StatelessWidget {
  const _LibraryErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final needsSession =
        !AppConfig.useMockData && AppServices.instance.session == null;
    final needsTenant =
        !AppConfig.useMockData && AppServices.instance.activeTenant == null;
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '题库暂时不可用',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重新加载'),
          ),
          if (needsSession || needsTenant) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (needsSession)
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRouter.login),
                    icon: const Icon(Icons.login),
                    label: const Text('先登录'),
                  ),
                if (needsTenant)
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRouter.tenantSwitch),
                    icon: const Icon(Icons.apartment_outlined),
                    label: const Text('选择机构'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.filters,
    required this.basketFilter,
    required this.gradeFilter,
    required this.chapterFilter,
    required this.sortBy,
    required this.visibleQuestions,
    required this.visibleInBasketCount,
    required this.visibleOutOfBasketCount,
    required this.searchController,
    required this.subjectOptions,
    required this.stageOptions,
    required this.textbookOptions,
    required this.gradeOptions,
    required this.chapterOptions,
    required this.onChanged,
    required this.onBasketFilterChanged,
    required this.onGradeFilterChanged,
    required this.onChapterFilterChanged,
    required this.onSortChanged,
    required this.onClearFilters,
  });

  final LibraryFilterState filters;
  final String basketFilter;
  final String gradeFilter;
  final String chapterFilter;
  final String sortBy;
  final List<QuestionSummary> visibleQuestions;
  final int visibleInBasketCount;
  final int visibleOutOfBasketCount;
  final TextEditingController searchController;
  final List<TaxonomyOption> subjectOptions;
  final List<TaxonomyOption> stageOptions;
  final List<TaxonomyOption> textbookOptions;
  final List<String> gradeOptions;
  final List<String> chapterOptions;
  final ValueChanged<LibraryFilterState> onChanged;
  final ValueChanged<String> onBasketFilterChanged;
  final ValueChanged<String> onGradeFilterChanged;
  final ValueChanged<String> onChapterFilterChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final desktopWide = MediaQuery.sizeOf(context).width >= 1180;
    final summaryChips = <Widget>[
      WorkspaceMetricPill(
        label: '当前结果',
        value: '${visibleQuestions.length}',
      ),
      WorkspaceMetricPill(
        label: '学科',
        value:
            '${_distinctQuestionValues(visibleQuestions.map((q) => q.subject)).length}',
      ),
      WorkspaceMetricPill(
        label: '学段',
        value:
            '${_distinctQuestionValues(visibleQuestions.map((q) => q.stage)).length}',
      ),
      WorkspaceMetricPill(
        label: '年级',
        value:
            '${_distinctQuestionValues(visibleQuestions.map((q) => q.grade)).length}',
      ),
      WorkspaceMetricPill(
        label: '教材',
        value:
            '${_distinctQuestionValues(visibleQuestions.map((q) => q.textbook)).length}',
      ),
      WorkspaceMetricPill(
        label: '章节',
        value:
            '${_distinctQuestionValues(visibleQuestions.map((q) => q.chapter)).length}',
      ),
      WorkspaceMetricPill(
        label: '已在篮',
        value: '$visibleInBasketCount',
      ),
      WorkspaceMetricPill(
        label: '未入篮',
        value: '$visibleOutOfBasketCount',
      ),
    ];
    final activeFilterChips = _activeFilterEntries
        .map(
          (entry) => WorkspaceMetricPill(
            label: entry.$1,
            value: entry.$2,
            highlight: true,
          ),
        )
        .toList(growable: false);
    return WorkspacePanel(
      padding:
          workspacePanelPadding(context, mobile: 14, tablet: 16, desktop: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: '筛选与投递',
            icon: Icons.tune_outlined,
          ),
          const SizedBox(height: 12),
          const Text(
            '筛选条件',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: '按标题、章节或标签搜索',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              onChanged(filters.copyWith(query: value));
            },
          ),
          const SizedBox(height: 16),
          if (desktopWide && activeFilterChips.isEmpty)
            const Text(
              '结果摘要',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: TelegramPalette.textMuted,
              ),
            ),
          if (desktopWide && activeFilterChips.isEmpty)
            const SizedBox(height: 8),
          if (!desktopWide)
            Wrap(
              spacing: compact ? 8 : 10,
              runSpacing: compact ? 8 : 10,
              children: summaryChips,
            )
          else if (activeFilterChips.isEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: summaryChips,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DesktopInlineMetricsRow(
                    label: '结果摘要',
                    children: summaryChips,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _DesktopInlineMetricsRow(
                    label: '已启用条件',
                    children: activeFilterChips,
                  ),
                ),
              ],
            ),
          if (_activeFilterEntries.isNotEmpty && !desktopWide) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: compact ? 8 : 10,
              runSpacing: compact ? 8 : 10,
              children: activeFilterChips,
            ),
          ],
          const SizedBox(height: 16),
          if (desktopWide)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                '继续筛选',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: TelegramPalette.textMuted,
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 560;
              final compactGrid = constraints.maxWidth < 920;
              final wideDesktop = constraints.maxWidth >= 1180;
              final filterWidth = stacked
                  ? constraints.maxWidth
                  : compactGrid
                      ? (constraints.maxWidth - 12) / 2
                      : wideDesktop
                          ? 240.0
                          : 220.0;
              return Wrap(
                spacing: compact ? 8 : 12,
                runSpacing: compact ? 8 : 12,
                children: [
                  _FilterDropdown(
                    width: filterWidth,
                    label: '学科',
                    selectedId: filters.subjectId ?? '',
                    options: subjectOptions,
                    onChanged: (value) => onChanged(
                      filters.copyWith(
                        subject: value.label,
                        subjectId: value.id.isEmpty ? null : value.id,
                      ),
                    ),
                  ),
                  _FilterDropdown(
                    width: filterWidth,
                    label: '学段',
                    selectedId: filters.stageId ?? '',
                    options: stageOptions,
                    onChanged: (value) => onChanged(
                      filters.copyWith(
                        stage: value.label,
                        stageId: value.id.isEmpty ? null : value.id,
                      ),
                    ),
                  ),
                  _FilterDropdown(
                    width: filterWidth,
                    label: '教材',
                    selectedId: filters.textbookId ?? '',
                    options: textbookOptions,
                    onChanged: (value) => onChanged(
                      filters.copyWith(
                        textbook: value.label,
                        textbookId: value.id.isEmpty ? null : value.id,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: DropdownButtonFormField<String>(
                      initialValue: gradeFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '年级',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('全部年级'),
                        ),
                        ...gradeOptions.map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onGradeFilterChanged(value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: DropdownButtonFormField<String>(
                      initialValue: basketFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '选题篮状态',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('全部状态')),
                        DropdownMenuItem(
                          value: 'in_basket',
                          child: Text('已在选题篮'),
                        ),
                        DropdownMenuItem(
                          value: 'not_in_basket',
                          child: Text('未在选题篮'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onBasketFilterChanged(value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: DropdownButtonFormField<String>(
                      initialValue: chapterFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '章节',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('全部章节'),
                        ),
                        ...chapterOptions.map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onChapterFilterChanged(value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: DropdownButtonFormField<String>(
                      initialValue: sortBy,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '排序',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'results',
                          child: Text('结果顺序'),
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
                          value: 'basket',
                          child: Text('选题篮优先'),
                        ),
                        DropdownMenuItem(
                          value: 'chapter',
                          child: Text('按章节'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onSortChanged(value);
                        }
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: Text(compact ? '清空' : '清空筛选'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<String> _distinctQuestionValues(Iterable<String> values) {
    final normalized = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return normalized;
  }

  List<(String, String)> get _activeFilterEntries {
    final entries = <(String, String)>[];
    final query = filters.query.trim();
    if (query.isNotEmpty) {
      entries.add(('关键词', query));
    }
    if (filters.subject.trim().isNotEmpty) {
      entries.add(('学科', filters.subject.trim()));
    }
    if (filters.stage.trim().isNotEmpty) {
      entries.add(('学段', filters.stage.trim()));
    }
    if (filters.textbook.trim().isNotEmpty) {
      entries.add(('教材', filters.textbook.trim()));
    }
    if (gradeFilter != 'all') {
      entries.add(('年级', gradeFilter));
    }
    if (chapterFilter != 'all') {
      entries.add(('章节', chapterFilter));
    }
    if (basketFilter == 'in_basket') {
      entries.add(('选题篮', '已在选题篮'));
    } else if (basketFilter == 'not_in_basket') {
      entries.add(('选题篮', '未在选题篮'));
    }
    if (sortBy != 'results') {
      entries.add(('排序', _sortLabel(sortBy)));
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
      case 'basket':
        return '选题篮优先';
      case 'chapter':
        return '按章节';
      case 'results':
      default:
        return '结果顺序';
    }
  }
}

class _DesktopInlineMetricsRow extends StatelessWidget {
  const _DesktopInlineMetricsRow({
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TelegramPalette.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.width,
    required this.label,
    required this.selectedId,
    required this.options,
    required this.onChanged,
  });

  final double width;
  final String label;
  final String selectedId;
  final List<TaxonomyOption> options;
  final ValueChanged<TaxonomyOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: selectedId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((option) => DropdownMenuItem<String>(
                  value: option.id,
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: (next) {
          if (next != null) {
            final option = options.firstWhere(
              (item) => item.id == next,
              orElse: () => options.first,
            );
            onChanged(option);
          }
        },
      ),
    );
  }
}

class _LibrarySelectionBar extends StatelessWidget {
  const _LibrarySelectionBar({
    required this.selectedCount,
    required this.selectedInBasketCount,
    required this.selectedOutOfBasketCount,
    required this.selectedSubjectCount,
    required this.selectedTextbookCount,
    required this.selectedChapterCount,
    required this.selectedStageCount,
    required this.selectedGradeCount,
    required this.totalCount,
    required this.selectedVisibleCount,
    required this.allSelected,
    required this.showOnlySelected,
    required this.inBasketVisibleCount,
    required this.outOfBasketVisibleCount,
    required this.addingToBasket,
    required this.removingFromBasket,
    required this.addingToDocument,
    required this.creatingDocumentAndAdding,
    this.preferredTargetDocumentName,
    required this.onSelectAll,
    required this.onSelectInBasket,
    required this.onSelectOutOfBasket,
    required this.onInvertSelection,
    required this.onToggleShowOnlySelected,
    required this.onClearSelection,
    required this.onAddToBasket,
    required this.onRemoveFromBasket,
    required this.onAddToDocument,
    required this.onCreateDocumentAndAdd,
  });

  final int selectedCount;
  final int selectedInBasketCount;
  final int selectedOutOfBasketCount;
  final int selectedSubjectCount;
  final int selectedTextbookCount;
  final int selectedChapterCount;
  final int selectedStageCount;
  final int selectedGradeCount;
  final int totalCount;
  final int selectedVisibleCount;
  final bool allSelected;
  final bool showOnlySelected;
  final int inBasketVisibleCount;
  final int outOfBasketVisibleCount;
  final bool addingToBasket;
  final bool removingFromBasket;
  final bool addingToDocument;
  final bool creatingDocumentAndAdding;
  final String? preferredTargetDocumentName;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectInBasket;
  final VoidCallback onSelectOutOfBasket;
  final VoidCallback onInvertSelection;
  final ValueChanged<bool> onToggleShowOnlySelected;
  final VoidCallback onClearSelection;
  final Future<void> Function() onAddToBasket;
  final Future<void> Function() onRemoveFromBasket;
  final Future<void> Function() onAddToDocument;
  final Future<void> Function() onCreateDocumentAndAdd;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return WorkspacePanel(
      backgroundColor: selectedCount > 0
          ? TelegramPalette.surface
          : TelegramPalette.surfaceRaised,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Wrap(
        spacing: compact ? 8 : 12,
        runSpacing: compact ? 8 : 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            selectedCount > 0
                ? '已选择 $selectedCount / $totalCount 道题'
                : (compact ? '选题后批量处理' : '可批量选择题目后加入选题篮'),
            style: const TextStyle(
              color: TelegramPalette.textStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (selectedCount > 0)
            _StatusChip(label: '已选在篮', value: '$selectedInBasketCount'),
          if (selectedCount > 0)
            _StatusChip(label: '已选未入篮', value: '$selectedOutOfBasketCount'),
          if (selectedCount > 0)
            _StatusChip(label: '涉及学科', value: '$selectedSubjectCount'),
          if (selectedCount > 0)
            _StatusChip(label: '涉及教材', value: '$selectedTextbookCount'),
          if (selectedCount > 0)
            _StatusChip(label: '涉及章节', value: '$selectedChapterCount'),
          if (selectedCount > 0)
            _StatusChip(label: '涉及学段', value: '$selectedStageCount'),
          if (selectedCount > 0)
            _StatusChip(label: '涉及年级', value: '$selectedGradeCount'),
          OutlinedButton.icon(
            onPressed: allSelected ? null : onSelectAll,
            icon: const Icon(Icons.select_all),
            label: Text(allSelected ? '已全选' : (compact ? '全选结果' : '全选当前结果')),
          ),
          OutlinedButton.icon(
            onPressed: inBasketVisibleCount == 0 ? null : onSelectInBasket,
            icon: const Icon(Icons.bookmark_outlined),
            label: Text(compact ? '选已在篮' : '选中已在篮中'),
          ),
          OutlinedButton.icon(
            onPressed:
                outOfBasketVisibleCount == 0 ? null : onSelectOutOfBasket,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(compact ? '选未入篮' : '选中未入篮'),
          ),
          OutlinedButton.icon(
            onPressed: totalCount == 0 ? null : onInvertSelection,
            icon: const Icon(Icons.flip_to_back_outlined),
            label: Text(compact ? '反选结果' : '反选当前结果'),
          ),
          WorkspaceFilterPill(
            label: showOnlySelected ? (compact ? '已选中' : '只看已选中') : '只看已选',
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
          FilledButton.icon(
            onPressed: selectedCount == 0 ||
                    addingToBasket ||
                    removingFromBasket ||
                    addingToDocument ||
                    creatingDocumentAndAdding
                ? null
                : () => onAddToBasket(),
            icon: addingToBasket
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.collections_bookmark_outlined),
            label:
                Text(addingToBasket ? '加入中…' : (compact ? '加入选题篮' : '批量加入选题篮')),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingToBasket ||
                    removingFromBasket ||
                    addingToDocument ||
                    creatingDocumentAndAdding
                ? null
                : () => onRemoveFromBasket(),
            icon: removingFromBasket
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bookmark_remove_outlined),
            label: Text(
                removingFromBasket ? '移出中…' : (compact ? '移出选题篮' : '批量移出选题篮')),
          ),
          FilledButton.tonalIcon(
            onPressed: selectedCount == 0 ||
                    addingToBasket ||
                    removingFromBasket ||
                    addingToDocument ||
                    creatingDocumentAndAdding
                ? null
                : () => onAddToDocument(),
            icon: addingToDocument
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.note_add_outlined),
            label: Text(
              addingToDocument
                  ? '加入中…'
                  : (preferredTargetDocumentName == null
                      ? (compact ? '加入文档' : '批量加入文档')
                      : (compact ? '加入当前文档' : '批量加入当前文档')),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: selectedCount == 0 ||
                    addingToBasket ||
                    removingFromBasket ||
                    addingToDocument ||
                    creatingDocumentAndAdding
                ? null
                : () => onCreateDocumentAndAdd(),
            icon: creatingDocumentAndAdding
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
            label: Text(
              creatingDocumentAndAdding
                  ? '创建并加入中…'
                  : (compact ? '新建后加入' : '新建文档并加入'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionPreviewCard extends StatefulWidget {
  const _QuestionPreviewCard({
    required this.question,
    required this.isInBasket,
    required this.isSelected,
    required this.onOpenQuestionDetail,
    this.preferredTargetDocument,
    this.insertAfterItemId,
    this.insertAfterItemTitle,
    required this.onBasketChanged,
    required this.onSelectionChanged,
  });

  final QuestionSummary question;
  final bool isInBasket;
  final bool isSelected;
  final Future<void> Function(String questionId) onOpenQuestionDetail;
  final DocumentSummary? preferredTargetDocument;
  final String? insertAfterItemId;
  final String? insertAfterItemTitle;
  final ValueChanged<bool> onBasketChanged;
  final ValueChanged<bool> onSelectionChanged;

  @override
  State<_QuestionPreviewCard> createState() => _QuestionPreviewCardState();
}

class _QuestionPreviewCardState extends State<_QuestionPreviewCard> {
  bool _addingToDocument = false;
  bool _creatingAndAdding = false;
  bool _updatingBasket = false;

  Future<void> _repositionCreatedItem({
    required String documentId,
    required List<DocumentItemSummary>? previousItems,
    required DocumentItemSummary createdItem,
  }) async {
    if (previousItems == null || widget.insertAfterItemId == null) {
      return;
    }
    final insertAfterIndex =
        previousItems.indexWhere((item) => item.id == widget.insertAfterItemId);
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

  Future<void> _toggleBasket(BuildContext context) async {
    if (_updatingBasket) {
      return;
    }
    setState(() {
      _updatingBasket = true;
    });
    final repository = AppServices.instance.questionRepository;
    try {
      if (widget.isInBasket) {
        await repository.removeQuestionFromBasket(widget.question.id);
      } else {
        await repository.addQuestionToBasket(widget.question);
      }
      widget.onBasketChanged(!widget.isInBasket);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isInBasket
                ? '已从选题篮移除：${widget.question.title}'
                : '已加入选题篮：${widget.question.title}',
          ),
          action: widget.isInBasket
              ? null
              : SnackBarAction(
                  label: '查看',
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRouter.basket);
                  },
                ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新选题篮失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingBasket = false;
        });
      }
    }
  }

  Future<void> _addToDocument(BuildContext context) async {
    final targetDocument =
        widget.preferredTargetDocument ?? await pickTargetDocument(context);
    if (targetDocument == null || !mounted) {
      return;
    }

    setState(() {
      _addingToDocument = true;
    });
    try {
      final previousItems = widget.insertAfterItemId == null ||
              targetDocument.id != widget.preferredTargetDocument?.id
          ? null
          : await AppServices.instance.documentRepository.listDocumentItems(
              targetDocument.id,
            );
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
            previousItems != null
                ? '已加入文档并插到${widget.insertAfterItemTitle ?? '当前选中项'}后：${targetDocument.name}'
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
    } finally {
      if (mounted) {
        setState(() {
          _addingToDocument = false;
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
    if (targetDocument == null || !mounted) {
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
    final compact = MediaQuery.sizeOf(context).width < 640;
    return WorkspacePanel(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          widget.onOpenQuestionDetail(widget.question.id);
        },
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              QuestionSummaryPreview(question: widget.question),
              const SizedBox(height: 14),
              Wrap(
                spacing: compact ? 8 : 10,
                runSpacing: compact ? 8 : 10,
                children: [
                  FilledButton.icon(
                    onPressed: (_addingToDocument || _creatingAndAdding)
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
                  FilledButton.tonalIcon(
                    onPressed: (_addingToDocument || _creatingAndAdding)
                        ? null
                        : () => _createDocumentAndAdd(context),
                    icon: _creatingAndAdding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle_outline),
                    label: Text(
                      _creatingAndAdding
                          ? '创建并加入中…'
                          : (compact ? '新建后加入' : '新建文档并加入'),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: (_updatingBasket ||
                            _addingToDocument ||
                            _creatingAndAdding)
                        ? null
                        : () => _toggleBasket(context),
                    icon: _updatingBasket
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            widget.isInBasket
                                ? Icons.bookmark_remove_outlined
                                : Icons.collections_bookmark_outlined,
                          ),
                    label: Text(
                      _updatingBasket
                          ? '处理中…'
                          : (widget.isInBasket
                              ? (compact ? '移出题篮' : '移出选题篮')
                              : (compact ? '加入题篮' : '加入选题篮')),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.onOpenQuestionDetail(widget.question.id);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: Text(compact ? '详情' : '查看详情'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
