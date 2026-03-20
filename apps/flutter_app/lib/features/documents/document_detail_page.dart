import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_item_summary.dart';
import '../../core/models/documents_page_args.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/export_detail_args.dart';
import '../../core/models/export_job_summary.dart';
import '../../core/models/exports_page_args.dart';
import '../../core/models/library_page_args.dart';
import '../../core/models/layout_element_summary.dart';
import '../../core/models/question_basket_page_args.dart';
import '../../core/models/question_detail_args.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/content_section.dart';
import '../shared/workspace_shell.dart';
import 'create_document_dialog.dart';
import 'rename_document_dialog.dart';
import 'select_document_dialog.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({
    required this.documentId,
    this.documentSnapshot,
    this.focusItemId,
    this.focusItemTitle,
    this.focusExportJobId,
    this.recentlyAddedQuestionCount,
    super.key,
  });

  final String documentId;
  final DocumentSummary? documentSnapshot;
  final String? focusItemId;
  final String? focusItemTitle;
  final String? focusExportJobId;
  final int? recentlyAddedQuestionCount;

  static DocumentDetailPage fromArgs(DocumentDetailArgs args) {
    return DocumentDetailPage(
      documentId: args.documentId,
      documentSnapshot: args.documentSnapshot,
      focusItemId: args.focusItemId,
      focusItemTitle: args.focusItemTitle,
      focusExportJobId: args.focusExportJobId,
      recentlyAddedQuestionCount: args.recentlyAddedQuestionCount,
    );
  }

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  late Future<DocumentSummary?> _documentFuture;
  late Future<List<DocumentItemSummary>> _itemsFuture;
  late Future<List<LayoutElementSummary>> _layoutElementsFuture;
  final TextEditingController _itemQueryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};
  final Set<String> _busyItemIds = <String>{};
  Set<String> _basketQuestionIds = <String>{};
  Set<String> _selectedItemIds = <String>{};
  late String? _focusedItemId = widget.focusItemId;
  late String? _focusedItemTitle = widget.focusItemTitle;
  late String? _focusedExportJobId = widget.focusExportJobId;
  int? _recentlyAddedQuestionCount;
  String? _lastScrolledItemId;
  int? _liveQuestionCount;
  int? _liveLayoutCount;
  bool _renamingDocument = false;
  bool _removingDocument = false;
  bool _duplicatingDocument = false;
  bool _movingSelectedItems = false;
  bool _removingSelectedItems = false;
  bool _duplicatingSelectedItems = false;
  bool _creatingDocumentFromSelectedItems = false;
  bool _addingSelectedItemsToDocument = false;
  bool _addingSelectedQuestionsToBasket = false;
  bool _removingSelectedQuestionsFromBasket = false;
  String _itemQuery = '';
  String _itemKindFilter = 'all';
  String _itemBasketFilter = 'all';
  String _itemSubjectFilter = 'all';
  String _itemStageFilter = 'all';
  String _itemGradeFilter = 'all';
  String _itemTextbookFilter = 'all';
  String _itemChapterFilter = 'all';
  String _itemSortBy = 'document_order';
  bool _showOnlySelectedItems = false;

  @override
  void initState() {
    super.initState();
    _documentFuture = widget.documentSnapshot != null
        ? Future<DocumentSummary?>.value(widget.documentSnapshot)
        : AppServices.instance.documentRepository
            .getDocument(widget.documentId);
    _itemsFuture = AppServices.instance.documentRepository
        .listDocumentItems(widget.documentId);
    _layoutElementsFuture =
        AppServices.instance.documentRepository.listLayoutElements();
    _reloadBasketQuestionIds();
    _recentlyAddedQuestionCount = widget.recentlyAddedQuestionCount;
    if (widget.documentSnapshot != null) {
      _refreshDocumentFromServer();
    }
  }

  @override
  void dispose() {
    _itemQueryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _reloadDocument() {
    setState(() {
      _documentFuture = AppServices.instance.documentRepository
          .getDocument(widget.documentId);
    });
  }

  void _reloadItems() {
    setState(() {
      _itemsFuture = AppServices.instance.documentRepository
          .listDocumentItems(widget.documentId);
    });
  }

  void _reloadAll() {
    _reloadDocument();
    _reloadItems();
  }

  Future<void> _patchItems(
    List<DocumentItemSummary> Function(List<DocumentItemSummary> items)
        transform,
  ) async {
    final currentItems = await _itemsFuture;
    if (!mounted) {
      return;
    }
    final nextItems = transform(List<DocumentItemSummary>.from(currentItems));
    setState(() {
      _itemsFuture = Future<List<DocumentItemSummary>>.value(nextItems);
      _selectedItemIds = _selectedItemIds
          .where((id) => nextItems.any((item) => item.id == id))
          .toSet();
    });
  }

  Future<void> _patchDocument(
    DocumentSummary Function(DocumentSummary document) transform,
  ) async {
    final currentDocument = await _documentFuture;
    if (!mounted || currentDocument == null) {
      return;
    }
    setState(() {
      _documentFuture =
          Future<DocumentSummary?>.value(transform(currentDocument));
    });
  }

  Future<void> _refreshDocumentFromServer() async {
    final refreshed = await AppServices.instance.documentRepository
        .getDocument(widget.documentId);
    if (!mounted || refreshed == null) {
      return;
    }
    setState(() {
      _documentFuture = Future<DocumentSummary?>.value(refreshed);
    });
  }

  Future<void> _reloadBasketQuestionIds() async {
    final basketQuestionIds =
        await AppServices.instance.questionRepository.listBasketQuestionIds();
    if (!mounted) {
      return;
    }
    setState(() {
      _basketQuestionIds = basketQuestionIds;
    });
  }

  Future<DocumentSummary?> _currentDocumentSnapshot() async {
    final currentDocument = await _documentFuture;
    if (currentDocument == null) {
      return null;
    }
    return currentDocument.copyWith(
      questionCount: _liveQuestionCount ?? currentDocument.questionCount,
      layoutCount: _liveLayoutCount ?? currentDocument.layoutCount,
    );
  }

  Future<DocumentItemSummary?> _currentInsertionAnchor() async {
    final items = await _itemsFuture;
    final anchorId = _lastSelectedItemIdInOrder(items);
    if (anchorId == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == anchorId) {
        return item;
      }
    }
    return null;
  }

  Future<void> _popWithCurrentDocument() async {
    final snapshot = await _currentDocumentSnapshot();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(snapshot);
  }

  void _syncDerivedCounts(List<DocumentItemSummary> items) {
    final questionCount = items.where((item) => item.kind == 'question').length;
    final layoutCount = items.length - questionCount;
    if (_liveQuestionCount == questionCount &&
        _liveLayoutCount == layoutCount) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveQuestionCount = questionCount;
        _liveLayoutCount = layoutCount;
      });
    });
  }

  GlobalKey _keyForItem(String itemId) {
    return _itemKeys.putIfAbsent(itemId, GlobalKey.new);
  }

  void _scheduleFocusedItemScroll(List<DocumentItemSummary> items) {
    DocumentItemSummary? focusedItem;
    if (_focusedItemId != null) {
      for (final item in items) {
        if (item.id == _focusedItemId) {
          focusedItem = item;
          break;
        }
      }
    }
    if (focusedItem == null && _focusedItemTitle != null) {
      for (final item in items) {
        if (item.title == _focusedItemTitle) {
          focusedItem = item;
          break;
        }
      }
    }
    if (focusedItem == null || _lastScrolledItemId == focusedItem.id) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetContext = _keyForItem(focusedItem!.id).currentContext;
      if (targetContext == null) {
        return;
      }
      _lastScrolledItemId = focusedItem.id;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.14,
      );
    });
  }

  List<DocumentItemSummary> _applyItemFilters(List<DocumentItemSummary> items) {
    final normalizedQuery = _itemQuery.trim().toLowerCase();
    final filtered = items.where((item) {
      if (_showOnlySelectedItems && !_selectedItemIds.contains(item.id)) {
        return false;
      }
      if (_itemKindFilter != 'all' && item.kind != _itemKindFilter) {
        return false;
      }
      if (_itemSubjectFilter != 'all' &&
          item.kind == 'question' &&
          item.subject != _itemSubjectFilter) {
        return false;
      }
      if (_itemStageFilter != 'all' &&
          item.kind == 'question' &&
          item.stage != _itemStageFilter) {
        return false;
      }
      if (_itemGradeFilter != 'all' &&
          item.kind == 'question' &&
          item.grade != _itemGradeFilter) {
        return false;
      }
      if (_itemTextbookFilter != 'all' &&
          item.kind == 'question' &&
          item.textbook != _itemTextbookFilter) {
        return false;
      }
      if (_itemChapterFilter != 'all' &&
          item.kind == 'question' &&
          item.chapter != _itemChapterFilter) {
        return false;
      }
      if (_itemBasketFilter != 'all') {
        if (item.kind != 'question' ||
            (item.sourceQuestionId?.isEmpty ?? true)) {
          return false;
        }
        final isInBasket = _basketQuestionIds.contains(item.sourceQuestionId);
        if (_itemBasketFilter == 'in_basket' && !isInBasket) {
          return false;
        }
        if (_itemBasketFilter == 'not_in_basket' && isInBasket) {
          return false;
        }
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return <String>[
        item.title,
        item.kind,
        item.detail,
      ].any((value) => value.toLowerCase().contains(normalizedQuery));
    }).toList(growable: false);
    return _applyItemSort(filtered);
  }

  List<DocumentItemSummary> _applyItemSort(List<DocumentItemSummary> items) {
    final sorted = items.toList(growable: true);
    switch (_itemSortBy) {
      case 'title':
        sorted.sort(
          (left, right) => left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              ),
        );
        break;
      case 'kind':
        sorted.sort((left, right) {
          final compare = left.kind.toLowerCase().compareTo(
                right.kind.toLowerCase(),
              );
          if (compare != 0) {
            return compare;
          }
          return left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              );
        });
        break;
      case 'subject':
        sorted.sort((left, right) {
          final compare = (left.subject ?? '').toLowerCase().compareTo(
                (right.subject ?? '').toLowerCase(),
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
          final compare = (left.stage ?? '').toLowerCase().compareTo(
                (right.stage ?? '').toLowerCase(),
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
          final compare = (left.grade ?? '').toLowerCase().compareTo(
                (right.grade ?? '').toLowerCase(),
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
          final compare = (left.textbook ?? '').toLowerCase().compareTo(
                (right.textbook ?? '').toLowerCase(),
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
          final compare = (left.chapter ?? '').toLowerCase().compareTo(
                (right.chapter ?? '').toLowerCase(),
              );
          if (compare != 0) {
            return compare;
          }
          return left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              );
        });
        break;
      case 'basket_first':
        sorted.sort((left, right) {
          final leftInBasket = left.kind == 'question' &&
              _basketQuestionIds.contains(left.sourceQuestionId);
          final rightInBasket = right.kind == 'question' &&
              _basketQuestionIds.contains(right.sourceQuestionId);
          final compare =
              (rightInBasket ? 1 : 0).compareTo(leftInBasket ? 1 : 0);
          if (compare != 0) {
            return compare;
          }
          return left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              );
        });
        break;
      case 'document_order':
      default:
        break;
    }
    return sorted;
  }

  void _clearItemFilters() {
    _itemQueryController.clear();
    setState(() {
      _itemQuery = '';
      _itemKindFilter = 'all';
      _itemBasketFilter = 'all';
      _itemSubjectFilter = 'all';
      _itemStageFilter = 'all';
      _itemGradeFilter = 'all';
      _itemTextbookFilter = 'all';
      _itemChapterFilter = 'all';
      _itemSortBy = 'document_order';
      _showOnlySelectedItems = false;
    });
  }

  void _setItemSelection(String itemId, bool selected) {
    setState(() {
      if (selected) {
        _selectedItemIds.add(itemId);
      } else {
        _selectedItemIds.remove(itemId);
      }
    });
  }

  void _selectAllFilteredItems(List<DocumentItemSummary> filteredItems) {
    setState(() {
      _selectedItemIds = filteredItems.map((item) => item.id).toSet();
    });
  }

  void _selectFilteredItemsByKind(
    List<DocumentItemSummary> filteredItems,
    String kind,
  ) {
    setState(() {
      _selectedItemIds = filteredItems
          .where(
            (item) => kind == 'question'
                ? item.kind == 'question'
                : item.kind != 'question',
          )
          .map((item) => item.id)
          .toSet();
    });
  }

  void _selectFilteredItemsInBasketQuestions(
      List<DocumentItemSummary> filteredItems) {
    setState(() {
      _selectedItemIds = filteredItems
          .where(
            (item) =>
                item.kind == 'question' &&
                (item.sourceQuestionId?.isNotEmpty ?? false) &&
                _basketQuestionIds.contains(item.sourceQuestionId),
          )
          .map((item) => item.id)
          .toSet();
    });
  }

  void _selectFilteredItemsNotInBasketQuestions(
    List<DocumentItemSummary> filteredItems,
  ) {
    setState(() {
      _selectedItemIds = filteredItems
          .where(
            (item) =>
                item.kind == 'question' &&
                (item.sourceQuestionId?.isNotEmpty ?? false) &&
                !_basketQuestionIds.contains(item.sourceQuestionId),
          )
          .map((item) => item.id)
          .toSet();
    });
  }

  void _invertFilteredItemsSelection(List<DocumentItemSummary> filteredItems) {
    setState(() {
      final nextSelection = <String>{..._selectedItemIds};
      for (final item in filteredItems) {
        if (nextSelection.contains(item.id)) {
          nextSelection.remove(item.id);
        } else {
          nextSelection.add(item.id);
        }
      }
      _selectedItemIds = nextSelection;
    });
  }

  void _clearItemSelection() {
    setState(() {
      _selectedItemIds.clear();
    });
  }

  void _setItemBusy(String itemId, bool busy) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (busy) {
        _busyItemIds.add(itemId);
      } else {
        _busyItemIds.remove(itemId);
      }
    });
  }

  Future<void> _runItemAction(
    DocumentItemSummary item,
    Future<void> Function() action,
  ) async {
    if (_busyItemIds.contains(item.id)) {
      return;
    }
    _setItemBusy(item.id, true);
    try {
      await action();
    } finally {
      _setItemBusy(item.id, false);
    }
  }

  String? _lastSelectedItemIdInOrder(List<DocumentItemSummary> items) {
    for (var index = items.length - 1; index >= 0; index -= 1) {
      final candidate = items[index];
      if (_selectedItemIds.contains(candidate.id)) {
        return candidate.id;
      }
    }
    return null;
  }

  Future<void> _repositionAppendedItem({
    required DocumentItemSummary createdItem,
    required List<DocumentItemSummary> previousItems,
    required int? insertAfterIndex,
  }) async {
    if (insertAfterIndex == null) {
      return;
    }
    final targetIndex = insertAfterIndex + 1;
    if (targetIndex < 0 || targetIndex >= previousItems.length) {
      return;
    }
    final moveSteps = previousItems.length - targetIndex;
    if (moveSteps <= 0) {
      return;
    }
    for (var i = 0; i < moveSteps; i += 1) {
      await AppServices.instance.documentRepository.moveDocumentItem(
        documentId: widget.documentId,
        itemId: createdItem.id,
        offset: -1,
      );
    }
    _lastScrolledItemId = null;
    await _patchItems((items) {
      final currentIndex =
          items.indexWhere((candidate) => candidate.id == createdItem.id);
      if (currentIndex < 0) {
        return items;
      }
      final reordered = List<DocumentItemSummary>.from(items);
      final moved = reordered.removeAt(currentIndex);
      final safeIndex = targetIndex.clamp(0, reordered.length);
      reordered.insert(safeIndex, moved);
      return reordered;
    });
  }

  Future<void> _moveItem(DocumentItemSummary item, int offset) async {
    await _runItemAction(item, () async {
      try {
        await AppServices.instance.documentRepository.moveDocumentItem(
          documentId: widget.documentId,
          itemId: item.id,
          offset: offset,
        );
        setState(() {
          _focusedItemId = item.id;
          _focusedItemTitle = item.title;
        });
        _lastScrolledItemId = null;
        await _patchItems((items) {
          final currentIndex =
              items.indexWhere((candidate) => candidate.id == item.id);
          if (currentIndex < 0) {
            return items;
          }
          final nextIndex = currentIndex + offset;
          if (nextIndex < 0 || nextIndex >= items.length) {
            return items;
          }
          final reordered = List<DocumentItemSummary>.from(items);
          final movedItem = reordered.removeAt(currentIndex);
          reordered.insert(nextIndex, movedItem);
          return reordered;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showActionError('调整顺序失败', error);
      }
    });
  }

  Future<void> _removeItem(DocumentItemSummary item) async {
    await _runItemAction(item, () async {
      try {
        await _removeDocumentItem(item);
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showActionError('移除文档项失败', error);
      }
    });
  }

  Future<void> _removeDocumentItem(
    DocumentItemSummary item, {
    bool showFeedback = true,
  }) async {
    await AppServices.instance.documentRepository.removeDocumentItem(
      documentId: widget.documentId,
      itemId: item.id,
    );
    if (_focusedItemId == item.id) {
      _focusedItemId = null;
    }
    if (_focusedItemTitle == item.title) {
      _focusedItemTitle = null;
    }
    _lastScrolledItemId = null;
    await _patchItems(
      (items) => items.where((candidate) => candidate.id != item.id).toList(),
    );
    await _patchDocument(
      (document) => document.copyWith(
        questionCount: item.kind == 'question'
            ? (document.questionCount > 0 ? document.questionCount - 1 : 0)
            : document.questionCount,
        layoutCount: item.kind == 'layout_element'
            ? (document.layoutCount > 0 ? document.layoutCount - 1 : 0)
            : document.layoutCount,
      ),
    );
    if (!mounted || !showFeedback) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已移除文档项：${item.title}')),
    );
  }

  Future<void> _removeSelectedItems(
      List<DocumentItemSummary> filteredItems) async {
    final selectedItems = filteredItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
    if (selectedItems.isEmpty || _removingSelectedItems) {
      return;
    }
    final confirmed = await _showConfirmDialog(
      title: '批量移除文档项',
      message: '确定移除当前选中的 ${selectedItems.length} 个文档项吗？',
      confirmLabel: '移除',
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _removingSelectedItems = true;
      _busyItemIds.addAll(selectedItems.map((item) => item.id));
    });
    try {
      for (final item in selectedItems) {
        await AppServices.instance.documentRepository.removeDocumentItem(
          documentId: widget.documentId,
          itemId: item.id,
        );
      }
      if (!mounted) {
        return;
      }
      final removedIds = selectedItems.map((item) => item.id).toSet();
      final removedQuestionCount =
          selectedItems.where((item) => item.kind == 'question').length;
      final removedLayoutCount =
          selectedItems.where((item) => item.kind != 'question').length;
      if (_focusedItemId != null && removedIds.contains(_focusedItemId)) {
        _focusedItemId = null;
      }
      if (_focusedItemTitle != null &&
          selectedItems.any((item) => item.title == _focusedItemTitle)) {
        _focusedItemTitle = null;
      }
      _lastScrolledItemId = null;
      await _patchItems(
        (items) => items
            .where((candidate) => !removedIds.contains(candidate.id))
            .toList(),
      );
      await _patchDocument(
        (document) => document.copyWith(
          questionCount: document.questionCount - removedQuestionCount < 0
              ? 0
              : document.questionCount - removedQuestionCount,
          layoutCount: document.layoutCount - removedLayoutCount < 0
              ? 0
              : document.layoutCount - removedLayoutCount,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedItemIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移除 ${selectedItems.length} 个文档项')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('批量移除文档项失败', error);
      _reloadItems();
    } finally {
      if (mounted) {
        setState(() {
          _removingSelectedItems = false;
          for (final item in selectedItems) {
            _busyItemIds.remove(item.id);
          }
        });
      }
    }
  }

  Future<void> _duplicateSelectedItems(
    List<DocumentItemSummary> allItems,
  ) async {
    if (_duplicatingSelectedItems || _selectedItemIds.isEmpty) {
      return;
    }
    final selectedItems = allItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
    if (selectedItems.isEmpty) {
      return;
    }

    setState(() {
      _duplicatingSelectedItems = true;
      _busyItemIds.addAll(selectedItems.map((item) => item.id));
    });
    try {
      var duplicatedCount = 0;
      var insertAfterItemId = selectedItems.last.id;
      final duplicatedIds = <String>[];
      for (final item in selectedItems) {
        final duplicated = await _duplicateDocumentItem(
          item,
          showFeedback: false,
          insertAfterItemId: insertAfterItemId,
        );
        if (duplicated != null) {
          duplicatedCount += 1;
          duplicatedIds.add(duplicated.id);
          insertAfterItemId = duplicated.id;
        }
      }
      if (!mounted) {
        return;
      }
      if (duplicatedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已选文档项没有可复制的来源')),
        );
        return;
      }
      setState(() {
        _selectedItemIds
          ..clear()
          ..addAll(duplicatedIds);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已复制 $duplicatedCount 个文档项，并作为连续块插入到当前已选项后',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('批量复制文档项失败', error);
      _reloadItems();
    } finally {
      if (mounted) {
        setState(() {
          _duplicatingSelectedItems = false;
          for (final item in selectedItems) {
            _busyItemIds.remove(item.id);
          }
        });
      }
    }
  }

  Future<DocumentItemSummary?> _copyDocumentItemToDocument({
    required DocumentItemSummary item,
    required String targetDocumentId,
  }) async {
    if (item.kind == 'question') {
      final questionId = item.sourceQuestionId;
      if (questionId == null || questionId.isEmpty) {
        return null;
      }
      final question =
          await AppServices.instance.questionRepository.getQuestion(questionId);
      if (question == null) {
        return null;
      }
      return AppServices.instance.documentRepository.addQuestionToDocument(
        documentId: targetDocumentId,
        question: question,
      );
    }

    final layoutElements = await _layoutElementsFuture;
    final matchedElement =
        layoutElements.cast<LayoutElementSummary?>().firstWhere(
              (element) =>
                  element?.id == item.sourceLayoutElementId ||
                  element?.name == item.title,
              orElse: () => null,
            );
    if (matchedElement == null) {
      return null;
    }
    return AppServices.instance.documentRepository.addLayoutElementToDocument(
      documentId: targetDocumentId,
      layoutElement: matchedElement,
    );
  }

  Future<void> _createDocumentFromSelectedItems(
    List<DocumentItemSummary> allItems,
  ) async {
    if (_creatingDocumentFromSelectedItems || _selectedItemIds.isEmpty) {
      return;
    }
    final selectedItems = allItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
    if (selectedItems.isEmpty) {
      return;
    }

    final removeAfterCopy = await _pickSelectedItemsDocumentHandoffMode(
      selectedItems.length,
    );
    if (removeAfterCopy == null || !mounted) {
      return;
    }

    final currentDocument = await _documentFuture;
    if (!mounted) {
      return;
    }
    final targetDocument = await showCreateDocumentDialog(
      context,
      initialName:
          currentDocument == null ? '文档节选' : '${currentDocument.name} 节选',
      initialKind: currentDocument?.kind ?? 'handout',
      title: '新建文档承接',
    );
    if (targetDocument == null || !mounted) {
      return;
    }

    setState(() {
      _creatingDocumentFromSelectedItems = true;
      _busyItemIds.addAll(selectedItems.map((item) => item.id));
    });
    try {
      var copiedCount = 0;
      DocumentItemSummary? lastCreatedItem;
      final copiedSourceItems = <DocumentItemSummary>[];
      for (final item in selectedItems) {
        final createdItem = await _copyDocumentItemToDocument(
          item: item,
          targetDocumentId: targetDocument.id,
        );
        if (createdItem != null) {
          copiedCount += 1;
          lastCreatedItem = createdItem;
          copiedSourceItems.add(item);
        }
      }
      if (!mounted) {
        return;
      }
      if (copiedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已选文档项没有可复制到新文档的来源')),
        );
        return;
      }
      if (removeAfterCopy) {
        for (final item in copiedSourceItems) {
          await _removeDocumentItem(item, showFeedback: false);
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedItemIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removeAfterCopy
                ? '已将 $copiedCount 个文档项承接到新文档，并从当前文档移出：${targetDocument.name}'
                : '已将 $copiedCount 个文档项复制到新文档：${targetDocument.name}',
          ),
        ),
      );
      Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: targetDocument.id,
          focusItemId: lastCreatedItem?.id,
          focusItemTitle: lastCreatedItem?.title,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('新建文档并复制已选文档项失败', error);
    } finally {
      if (mounted) {
        setState(() {
          _creatingDocumentFromSelectedItems = false;
          for (final item in selectedItems) {
            _busyItemIds.remove(item.id);
          }
        });
      }
    }
  }

  Future<void> _addSelectedItemsToDocument(
    List<DocumentItemSummary> allItems,
  ) async {
    if (_addingSelectedItemsToDocument || _selectedItemIds.isEmpty) {
      return;
    }
    final selectedItems = allItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
    if (selectedItems.isEmpty) {
      return;
    }

    final removeAfterCopy = await _pickSelectedItemsDocumentHandoffMode(
      selectedItems.length,
    );
    if (removeAfterCopy == null || !mounted) {
      return;
    }

    final targetDocument = await pickTargetDocument(
      context,
      excludedDocumentIds: {widget.documentId},
    );
    if (targetDocument == null || !mounted) {
      return;
    }

    setState(() {
      _addingSelectedItemsToDocument = true;
      _busyItemIds.addAll(selectedItems.map((item) => item.id));
    });
    try {
      var copiedCount = 0;
      DocumentItemSummary? lastCreatedItem;
      final copiedSourceItems = <DocumentItemSummary>[];
      for (final item in selectedItems) {
        final createdItem = await _copyDocumentItemToDocument(
          item: item,
          targetDocumentId: targetDocument.id,
        );
        if (createdItem != null) {
          copiedCount += 1;
          lastCreatedItem = createdItem;
          copiedSourceItems.add(item);
        }
      }
      if (!mounted) {
        return;
      }
      if (copiedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已选文档项没有可承接到目标文档的来源')),
        );
        return;
      }
      if (removeAfterCopy) {
        for (final item in copiedSourceItems) {
          await _removeDocumentItem(item, showFeedback: false);
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedItemIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removeAfterCopy
                ? '已将 $copiedCount 个文档项承接到目标文档，并从当前文档移出：${targetDocument.name}'
                : '已将 $copiedCount 个文档项复制到目标文档：${targetDocument.name}',
          ),
        ),
      );
      Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: targetDocument.id,
          focusItemId: lastCreatedItem?.id,
          focusItemTitle: lastCreatedItem?.title,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('承接到目标文档失败', error);
    } finally {
      if (mounted) {
        setState(() {
          _addingSelectedItemsToDocument = false;
          for (final item in selectedItems) {
            _busyItemIds.remove(item.id);
          }
        });
      }
    }
  }

  Future<bool?> _pickSelectedItemsDocumentHandoffMode(int itemCount) {
    final itemLabel = itemCount == 1 ? '这个文档项' : '当前选中的 $itemCount 个文档项';
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
                  '新建文档承接',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  '即将把$itemLabel承接到一份新文档。承接完成后，是否同时把这批文档项从当前文档移出？',
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
                        child: const Text('复制承接'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('承接并移出'),
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

  Future<bool> _addQuestionItemToBasket(
    DocumentItemSummary item, {
    bool showFeedback = true,
  }) async {
    final questionId = item.sourceQuestionId;
    if (questionId == null || questionId.isEmpty) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未找到可加入选题篮的题目来源：${item.title}')),
        );
      }
      return false;
    }
    if (_basketQuestionIds.contains(questionId)) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('这道题已经在选题篮里：${item.title}')),
        );
      }
      return false;
    }
    final question =
        await AppServices.instance.questionRepository.getQuestion(questionId);
    if (!mounted) {
      return false;
    }
    if (question == null) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未找到可加入选题篮的题目来源：${item.title}')),
        );
      }
      return false;
    }
    await AppServices.instance.questionRepository.addQuestionToBasket(question);
    if (mounted) {
      setState(() {
        _basketQuestionIds.add(questionId);
      });
    }
    if (mounted && showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加入选题篮：${item.title}')),
      );
    }
    return true;
  }

  Future<bool> _removeQuestionItemFromBasket(
    DocumentItemSummary item, {
    bool showFeedback = true,
  }) async {
    final questionId = item.sourceQuestionId;
    if (questionId == null || questionId.isEmpty) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未找到可移出选题篮的题目来源：${item.title}')),
        );
      }
      return false;
    }
    if (!_basketQuestionIds.contains(questionId)) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('这道题当前不在选题篮里：${item.title}')),
        );
      }
      return false;
    }
    await AppServices.instance.questionRepository.removeQuestionFromBasket(
      questionId,
    );
    if (mounted) {
      setState(() {
        _basketQuestionIds.remove(questionId);
      });
    }
    if (mounted && showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移出选题篮：${item.title}')),
      );
    }
    return true;
  }

  Future<void> _addSelectedQuestionItemsToBasket(
    List<DocumentItemSummary> allItems,
  ) async {
    if (_addingSelectedQuestionsToBasket || _selectedItemIds.isEmpty) {
      return;
    }
    final selectedItems = allItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
    final questionItems = selectedItems
        .where(
          (item) =>
              item.kind == 'question' &&
              (item.sourceQuestionId ?? '').trim().isNotEmpty,
        )
        .toList(growable: false);
    if (questionItems.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前已选文档项里没有可加入选题篮的题目项')),
      );
      return;
    }

    final removeAfterAdd = await _pickQuestionItemsBasketFollowUp(
      questionItems.length,
    );
    if (removeAfterAdd == null || !mounted) {
      return;
    }

    setState(() {
      _addingSelectedQuestionsToBasket = true;
      _busyItemIds.addAll(questionItems.map((item) => item.id));
    });
    try {
      var addedCount = 0;
      for (final item in questionItems) {
        final added = await _addQuestionItemToBasket(item, showFeedback: false);
        if (added) {
          addedCount += 1;
          if (removeAfterAdd) {
            await _removeDocumentItem(item, showFeedback: false);
          }
        }
      }
      if (!mounted) {
        return;
      }
      if (addedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有成功加入新的题目到选题篮')),
        );
        return;
      }
      setState(() {
        _selectedItemIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removeAfterAdd
                ? '已将 $addedCount 道题加入选题篮，并从文档中移出'
                : '已将 $addedCount 道题加入选题篮',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('批量加入选题篮失败', error);
    } finally {
      if (mounted) {
        setState(() {
          _addingSelectedQuestionsToBasket = false;
          for (final item in questionItems) {
            _busyItemIds.remove(item.id);
          }
        });
      }
    }
  }

  Future<void> _removeSelectedQuestionItemsFromBasket(
    List<DocumentItemSummary> allItems,
  ) async {
    if (_removingSelectedQuestionsFromBasket || _selectedItemIds.isEmpty) {
      return;
    }
    final questionItems = allItems
        .where(
          (item) =>
              _selectedItemIds.contains(item.id) &&
              item.kind == 'question' &&
              (item.sourceQuestionId?.isNotEmpty ?? false) &&
              _basketQuestionIds.contains(item.sourceQuestionId),
        )
        .toList(growable: false);
    if (questionItems.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前已选文档项里没有可移出的在篮题目项')),
      );
      return;
    }

    setState(() {
      _removingSelectedQuestionsFromBasket = true;
      _busyItemIds.addAll(questionItems.map((item) => item.id));
    });
    try {
      var removedCount = 0;
      for (final item in questionItems) {
        final removed = await _removeQuestionItemFromBasket(
          item,
          showFeedback: false,
        );
        if (removed) {
          removedCount += 1;
        }
      }
      if (!mounted) {
        return;
      }
      if (removedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有成功从选题篮移出题目')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将 $removedCount 道题从选题篮移出')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('批量移出选题篮失败', error);
    } finally {
      if (mounted) {
        setState(() {
          _removingSelectedQuestionsFromBasket = false;
          for (final item in questionItems) {
            _busyItemIds.remove(item.id);
          }
        });
      }
    }
  }

  Future<bool?> _pickQuestionItemsBasketFollowUp(int questionCount) {
    final title = questionCount == 1 ? '加入选题篮' : '批量加入选题篮';
    final content = questionCount == 1
        ? '即将把这道题加入选题篮。加入后是否同时把它从当前文档移出？'
        : '即将把当前选中的 $questionCount 道题加入选题篮。加入后是否同时把这批题从当前文档移出？';
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
                  title,
                  style: Theme.of(dialogContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  content,
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

  Future<void> _moveSelectedItems(
    int offset,
    List<DocumentItemSummary> allItems,
  ) async {
    if (_movingSelectedItems || _selectedItemIds.isEmpty) {
      return;
    }
    final movableItems = _movableSelectedItems(allItems, offset);
    if (movableItems.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(offset < 0 ? '当前已选项已经不能再上移了' : '当前已选项已经不能再下移了'),
        ),
      );
      return;
    }

    setState(() {
      _movingSelectedItems = true;
      _busyItemIds.addAll(movableItems.map((item) => item.id));
    });
    try {
      for (final item in movableItems) {
        await AppServices.instance.documentRepository.moveDocumentItem(
          documentId: widget.documentId,
          itemId: item.id,
          offset: offset,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _focusedItemId = movableItems.first.id;
        _focusedItemTitle = movableItems.first.title;
      });
      _lastScrolledItemId = null;
      await _patchItems((items) => _reorderSelectedItems(items, offset));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            offset < 0
                ? '已上移 ${movableItems.length} 个已选文档项'
                : '已下移 ${movableItems.length} 个已选文档项',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError(offset < 0 ? '批量上移失败' : '批量下移失败', error);
      _reloadItems();
    } finally {
      if (mounted) {
        setState(() {
          _movingSelectedItems = false;
          for (final item in movableItems) {
            _busyItemIds.remove(item.id);
          }
        });
      }
    }
  }

  Future<void> _moveSelectedItemsToBoundary(
    int offset,
    List<DocumentItemSummary> allItems,
  ) async {
    if (_movingSelectedItems || _selectedItemIds.isEmpty) {
      return;
    }
    var reorderedItems = List<DocumentItemSummary>.from(allItems);
    var totalMovedItems = 0;
    final touchedItemIds = <String>{};

    setState(() {
      _movingSelectedItems = true;
    });
    try {
      while (true) {
        final movableItems = _movableSelectedItems(reorderedItems, offset);
        if (movableItems.isEmpty) {
          break;
        }
        touchedItemIds.addAll(movableItems.map((item) => item.id));
        setState(() {
          _busyItemIds.addAll(movableItems.map((item) => item.id));
        });
        for (final item in movableItems) {
          await AppServices.instance.documentRepository.moveDocumentItem(
            documentId: widget.documentId,
            itemId: item.id,
            offset: offset,
          );
        }
        totalMovedItems += movableItems.length;
        reorderedItems = _reorderSelectedItems(reorderedItems, offset);
      }
      if (!mounted) {
        return;
      }
      if (totalMovedItems == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(offset < 0 ? '当前已选项已经在顶部' : '当前已选项已经在底部'),
          ),
        );
        return;
      }
      setState(() {
        _focusedItemId = reorderedItems
            .firstWhere((item) => _selectedItemIds.contains(item.id))
            .id;
        _focusedItemTitle = reorderedItems
            .firstWhere((item) => _selectedItemIds.contains(item.id))
            .title;
      });
      _lastScrolledItemId = null;
      await _patchItems((_) => reorderedItems);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(offset < 0 ? '已将当前已选区块置顶' : '已将当前已选区块置底'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError(offset < 0 ? '批量置顶失败' : '批量置底失败', error);
      _reloadItems();
    } finally {
      if (mounted) {
        setState(() {
          _movingSelectedItems = false;
          for (final itemId in touchedItemIds) {
            _busyItemIds.remove(itemId);
          }
        });
      }
    }
  }

  List<DocumentItemSummary> _movableSelectedItems(
    List<DocumentItemSummary> items,
    int offset,
  ) {
    final movable = <DocumentItemSummary>[];
    if (offset < 0) {
      for (var index = 0; index < items.length; index += 1) {
        final item = items[index];
        if (!_selectedItemIds.contains(item.id) || index == 0) {
          continue;
        }
        if (_selectedItemIds.contains(items[index - 1].id)) {
          continue;
        }
        movable.add(item);
      }
      return movable;
    }
    for (var index = items.length - 1; index >= 0; index -= 1) {
      final item = items[index];
      if (!_selectedItemIds.contains(item.id) || index == items.length - 1) {
        continue;
      }
      if (_selectedItemIds.contains(items[index + 1].id)) {
        continue;
      }
      movable.add(item);
    }
    return movable;
  }

  List<DocumentItemSummary> _reorderSelectedItems(
    List<DocumentItemSummary> items,
    int offset,
  ) {
    final reordered = List<DocumentItemSummary>.from(items);
    if (offset < 0) {
      for (var index = 1; index < reordered.length; index += 1) {
        if (_selectedItemIds.contains(reordered[index].id) &&
            !_selectedItemIds.contains(reordered[index - 1].id)) {
          final current = reordered[index];
          reordered[index] = reordered[index - 1];
          reordered[index - 1] = current;
        }
      }
      return reordered;
    }
    for (var index = reordered.length - 2; index >= 0; index -= 1) {
      if (_selectedItemIds.contains(reordered[index].id) &&
          !_selectedItemIds.contains(reordered[index + 1].id)) {
        final current = reordered[index];
        reordered[index] = reordered[index + 1];
        reordered[index + 1] = current;
      }
    }
    return reordered;
  }

  Future<void> _exportDocument() async {
    try {
      final currentDocument = await _currentDocumentSnapshot();
      final job = await AppServices.instance.documentRepository.createExportJob(
        documentId: widget.documentId,
      );
      final updatedDocument = currentDocument?.copyWith(
        latestExportStatus: job.status,
        latestExportJobId: job.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _focusedExportJobId = job.id;
      });
      _lastScrolledItemId = null;
      await _patchDocument(
        (document) => document.copyWith(
          latestExportStatus: job.status,
          latestExportJobId: job.id,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已创建导出任务')),
      );
      final result = await Navigator.of(context).pushNamed(
        AppRouter.exports,
        arguments: ExportsPageArgs(
          focusDocumentName: updatedDocument?.name,
          focusJobId: job.id,
          documentSnapshot: updatedDocument,
        ),
      );
      if (!mounted) {
        return;
      }
      if (result is DocumentSummary) {
        setState(() {
          _documentFuture = Future<DocumentSummary?>.value(result);
        });
        return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('创建导出任务失败', error);
    }
  }

  Future<void> _addLayoutElement() async {
    try {
      final layoutElements = await _layoutElementsFuture;
      if (!mounted || layoutElements.isEmpty) {
        return;
      }

      final result = await showModalBottomSheet<_LayoutElementPickerResult>(
        context: context,
        showDragHandle: true,
        builder: (context) => _LayoutElementPicker(
          layoutElements: layoutElements,
        ),
      );

      if (result == null) {
        return;
      }

      setState(() {
        _layoutElementsFuture =
            Future<List<LayoutElementSummary>>.value(result.layoutElements);
      });

      if (result.selected == null) {
        return;
      }

      await _insertLayoutElement(result.selected!);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('插入排版元素失败', error);
    }
  }

  Future<void> _createCustomLayoutElement() async {
    final result = await showDialog<_CreateLayoutElementResult>(
      context: context,
      builder: (context) => const _CreateLayoutElementDialog(),
    );
    if (result == null) {
      return;
    }
    try {
      final created =
          await AppServices.instance.documentRepository.createLayoutElement(
        name: result.name,
        description: result.description,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _layoutElementsFuture = Future<List<LayoutElementSummary>>.value(
          <LayoutElementSummary>[
            created,
            ...result.existingElements,
          ],
        );
      });
      await _insertLayoutElement(created);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('创建排版元素失败', error);
    }
  }

  Future<void> _editLayoutItem(DocumentItemSummary item) async {
    final layoutElementId = item.sourceLayoutElementId;
    if (layoutElementId == null || layoutElementId.isEmpty) {
      return;
    }
    final result = await showDialog<_CreateLayoutElementResult>(
      context: context,
      builder: (context) => _CreateLayoutElementDialog(
        title: '编辑排版元素',
        submitLabel: '保存并更新',
        initialName: item.title,
        initialDescription: item.detail,
      ),
    );
    if (result == null) {
      return;
    }
    await _runItemAction(item, () async {
      try {
        final updated =
            await AppServices.instance.documentRepository.updateLayoutElement(
          layoutElementId: layoutElementId,
          name: result.name,
          description: result.description,
        );
        if (!mounted) {
          return;
        }
        final currentLayoutElements = await _layoutElementsFuture;
        if (!mounted) {
          return;
        }
        setState(() {
          _layoutElementsFuture = Future<List<LayoutElementSummary>>.value(
            currentLayoutElements
                .map((element) =>
                    element.id == layoutElementId ? updated : element)
                .toList(growable: false),
          );
          _focusedItemId = item.id;
          _focusedItemTitle = updated.name;
        });
        await _patchItems(
          (items) => items
              .map(
                (candidate) =>
                    candidate.sourceLayoutElementId == layoutElementId
                        ? DocumentItemSummary(
                            id: candidate.id,
                            kind: candidate.kind,
                            title: updated.name,
                            detail: updated.description,
                            sourceQuestionId: candidate.sourceQuestionId,
                            sourceLayoutElementId: layoutElementId,
                            previewBlocks: updated.previewBlocks,
                          )
                        : candidate,
              )
              .toList(growable: false),
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已更新排版元素：${updated.name}')),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showActionError('更新排版元素失败', error);
      }
    });
  }

  Future<void> _insertLayoutElement(LayoutElementSummary selected) async {
    final previousItems = await _itemsFuture;
    final anchorItemId = _lastSelectedItemIdInOrder(previousItems);
    final insertAfterIndex = anchorItemId == null
        ? null
        : previousItems.indexWhere((item) => item.id == anchorItemId);
    final createdItem = await AppServices.instance.documentRepository
        .addLayoutElementToDocument(
      documentId: widget.documentId,
      layoutElement: selected,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _focusedItemId = createdItem.id;
      _focusedItemTitle = selected.name;
    });
    _lastScrolledItemId = null;
    await _patchItems((items) => <DocumentItemSummary>[...items, createdItem]);
    await _patchDocument(
      (document) => document.copyWith(layoutCount: document.layoutCount + 1),
    );
    await _repositionAppendedItem(
      createdItem: createdItem,
      previousItems: previousItems,
      insertAfterIndex: insertAfterIndex,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          insertAfterIndex == null
              ? '已插入排版元素：${selected.name}'
              : (_selectedItemIds.length > 1
                  ? '已在当前已选区块后插入排版元素：${selected.name}'
                  : '已在当前选中项后插入排版元素：${selected.name}'),
        ),
      ),
    );
  }

  Future<DocumentItemSummary?> _duplicateDocumentItem(
    DocumentItemSummary item, {
    bool showFeedback = true,
    String? insertAfterItemId,
  }) async {
    final previousItems = await _itemsFuture;
    final anchorItemId = insertAfterItemId ?? item.id;
    final insertAfterIndex =
        previousItems.indexWhere((candidate) => candidate.id == anchorItemId);
    if (item.kind == 'question') {
      final questionId = item.sourceQuestionId;
      if (questionId == null || questionId.isEmpty) {
        if (mounted && showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('未找到可复用的题目来源：${item.title}')),
          );
        }
        return null;
      }
      final question =
          await AppServices.instance.questionRepository.getQuestion(questionId);
      if (!mounted) {
        return null;
      }
      if (question == null) {
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('未找到可复用的题目来源：${item.title}')),
          );
        }
        return null;
      }
      final createdItem =
          await AppServices.instance.documentRepository.addQuestionToDocument(
        documentId: widget.documentId,
        question: question,
      );
      if (!mounted) {
        return null;
      }
      setState(() {
        _focusedItemId = createdItem.id;
        _focusedItemTitle = createdItem.title;
      });
      _lastScrolledItemId = null;
      await _patchItems(
          (items) => <DocumentItemSummary>[...items, createdItem]);
      await _patchDocument(
        (document) =>
            document.copyWith(questionCount: document.questionCount + 1),
      );
      await _repositionAppendedItem(
        createdItem: createdItem,
        previousItems: previousItems,
        insertAfterIndex: insertAfterIndex,
      );
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              insertAfterIndex >= 0
                  ? '已在原题目项后复制：${createdItem.title}'
                  : '已复制题目项：${createdItem.title}',
            ),
          ),
        );
      }
      return createdItem;
    }

    final layoutElements = await _layoutElementsFuture;
    if (!mounted) {
      return null;
    }
    final matchedElement =
        layoutElements.cast<LayoutElementSummary?>().firstWhere(
              (element) =>
                  element?.id == item.sourceLayoutElementId ||
                  element?.name == item.title,
              orElse: () => null,
            );
    if (matchedElement == null) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未找到可复用的排版元素模板：${item.title}')),
        );
      }
      return null;
    }
    final createdItem = await AppServices.instance.documentRepository
        .addLayoutElementToDocument(
      documentId: widget.documentId,
      layoutElement: matchedElement,
    );
    if (!mounted) {
      return null;
    }
    setState(() {
      _focusedItemId = createdItem.id;
      _focusedItemTitle = createdItem.title;
    });
    _lastScrolledItemId = null;
    await _patchItems((items) => <DocumentItemSummary>[...items, createdItem]);
    await _patchDocument(
      (document) => document.copyWith(layoutCount: document.layoutCount + 1),
    );
    await _repositionAppendedItem(
      createdItem: createdItem,
      previousItems: previousItems,
      insertAfterIndex: insertAfterIndex,
    );
    if (mounted && showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            insertAfterIndex >= 0
                ? '已在原排版项后复制：${createdItem.title}'
                : '已复制排版元素：${createdItem.title}',
          ),
        ),
      );
    }
    return createdItem;
  }

  Future<void> _duplicateItem(DocumentItemSummary item) async {
    await _runItemAction(item, () async {
      try {
        await _duplicateDocumentItem(item);
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showActionError('复制文档项失败', error);
      }
    });
  }

  Future<void> _openSourceQuestion(DocumentItemSummary item) async {
    await _runItemAction(item, () async {
      final questionId = item.sourceQuestionId;
      if (questionId == null || questionId.isEmpty) {
        return;
      }
      await Navigator.of(context).pushNamed(
        AppRouter.questionDetail,
        arguments: QuestionDetailArgs(
          questionId: questionId,
          preferredDocumentSnapshot: await _currentDocumentSnapshot(),
          insertAfterItemId: item.id,
          insertAfterItemTitle: item.title,
        ),
      );
    });
  }

  Future<void> _addQuestionItemFromDocument(DocumentItemSummary item) async {
    await _runItemAction(item, () async {
      try {
        final removeAfterAdd = await _pickQuestionItemsBasketFollowUp(1);
        if (removeAfterAdd == null || !mounted) {
          return;
        }
        final added = await _addQuestionItemToBasket(item, showFeedback: false);
        if (!mounted || !added) {
          return;
        }
        if (removeAfterAdd) {
          await _removeDocumentItem(item, showFeedback: false);
        }
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              removeAfterAdd ? '已将题目加入选题篮，并从文档中移出' : '已将题目加入选题篮',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showActionError('加入选题篮失败', error);
      }
    });
  }

  Future<void> _removeQuestionItemFromDocument(DocumentItemSummary item) async {
    await _runItemAction(item, () async {
      try {
        final removed = await _removeQuestionItemFromBasket(
          item,
          showFeedback: false,
        );
        if (!mounted || !removed) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已将题目从选题篮移出')),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showActionError('移出选题篮失败', error);
      }
    });
  }

  void _showActionError(String prefix, Object error) {
    final message = error is HttpJsonException
        ? '$prefix：${error.message}（HTTP ${error.statusCode}）'
        : '$prefix：$error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  ExportJobSummary _latestJobSummary(DocumentSummary document) {
    return ExportJobSummary(
      id: document.latestExportJobId ?? '',
      documentName: document.name,
      format: 'pdf',
      status: document.latestExportStatus,
      updatedAtLabel: '最近一次',
    );
  }

  Future<void> _openExports(DocumentSummary document) async {
    final currentDocument = await _currentDocumentSnapshot() ?? document;
    if (!mounted) {
      return;
    }
    final result = await Navigator.of(context).pushNamed(
      AppRouter.exports,
      arguments: ExportsPageArgs(
        focusDocumentName: currentDocument.name,
        focusJobId: currentDocument.latestExportJobId,
        documentSnapshot: currentDocument,
      ),
    );
    if (!mounted) {
      return;
    }
    if (result is DocumentSummary) {
      setState(() {
        _documentFuture = Future<DocumentSummary?>.value(result);
      });
    }
  }

  Future<void> _openDocumentsWorkspace() async {
    final currentDocument = await _currentDocumentSnapshot();
    if (!mounted) {
      return;
    }
    final addedCount = _recentlyAddedQuestionCount;
    Navigator.of(context).pushNamed(
      AppRouter.documents,
      arguments: DocumentsPageArgs(
        focusDocumentId: widget.documentId,
        documentSnapshot: currentDocument,
        flashMessage: addedCount == null
            ? '已定位到刚刚编辑的文档。'
            : '本次已批量加入 $addedCount 道题，文档工作区已定位到对应文档。',
        highlightTitle: addedCount == null ? '刚刚编辑过的文档' : '批量加题已同步',
        highlightDetail: addedCount == null
            ? '这份文档刚从详情页返回，列表统计和最近导出状态已刷新。'
            : '本次已批量加入 $addedCount 道题，当前卡片统计已经按最新文档状态刷新。',
        recentlyAddedQuestionCount: addedCount,
        feedbackBadgeLabel: addedCount == null ? '编辑已同步' : '批量加题已同步',
      ),
    );
  }

  Future<void> _openLibrary() async {
    final currentDocument = await _currentDocumentSnapshot();
    final insertionAnchor = await _currentInsertionAnchor();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRouter.library,
      arguments: LibraryPageArgs(
        preferredDocumentSnapshot: currentDocument,
        insertAfterItemId: insertionAnchor?.id,
        insertAfterItemTitle: insertionAnchor?.title,
      ),
    );
    if (!mounted) {
      return;
    }
    _reloadAll();
  }

  Future<void> _openBasket() async {
    final currentDocument = await _currentDocumentSnapshot();
    final insertionAnchor = await _currentInsertionAnchor();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRouter.basket,
      arguments: QuestionBasketPageArgs(
        preferredDocumentSnapshot: currentDocument,
        insertAfterItemId: insertionAnchor?.id,
        insertAfterItemTitle: insertionAnchor?.title,
      ),
    );
    if (!mounted) {
      return;
    }
    _reloadAll();
  }

  Future<void> _openLatestExportDetail(DocumentSummary document) async {
    final currentDocument = await _currentDocumentSnapshot() ?? document;
    if (!mounted) {
      return;
    }
    if (currentDocument.latestExportJobId == null) {
      return;
    }
    final result = await Navigator.of(context).pushNamed(
      AppRouter.exportDetail,
      arguments: ExportDetailArgs(
        job: _latestJobSummary(currentDocument),
        documentSnapshot: currentDocument,
      ),
    );
    if (!mounted) {
      return;
    }
    if (result is DocumentSummary) {
      setState(() {
        _documentFuture = Future<DocumentSummary?>.value(result);
      });
    }
  }

  Future<void> _openLatestExportResult(DocumentSummary document) async {
    final currentDocument = await _currentDocumentSnapshot() ?? document;
    if (!mounted) {
      return;
    }
    if (currentDocument.latestExportJobId == null) {
      return;
    }
    final result = await Navigator.of(context).pushNamed(
      AppRouter.exportResult,
      arguments: ExportDetailArgs(
        job: _latestJobSummary(currentDocument),
        documentSnapshot: currentDocument,
      ),
    );
    if (!mounted) {
      return;
    }
    if (result is DocumentSummary) {
      setState(() {
        _documentFuture = Future<DocumentSummary?>.value(result);
      });
    }
  }

  Future<void> _renameDocument(DocumentSummary document) async {
    final nextName = await showRenameDocumentDialog(
      context,
      initialName: document.name,
    );
    if (nextName == null || !mounted) {
      return;
    }
    final trimmedName = nextName.trim();
    if (trimmedName.isEmpty || trimmedName == document.name.trim()) {
      return;
    }

    setState(() {
      _renamingDocument = true;
    });
    try {
      final renamed =
          await AppServices.instance.documentRepository.renameDocument(
        documentId: widget.documentId,
        name: trimmedName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _documentFuture = Future<DocumentSummary?>.value(renamed);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文档名称已更新')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('重命名文档失败', error);
    } finally {
      if (mounted) {
        setState(() {
          _renamingDocument = false;
        });
      }
    }
  }

  Future<void> _removeDocument(DocumentSummary document) async {
    final confirmed = await _showConfirmDialog(
      title: '删除文档',
      message: '确定删除“${document.name}”吗？这个操作会把它从当前工作区移除。',
      confirmLabel: '删除',
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _removingDocument = true;
    });
    try {
      await AppServices.instance.documentRepository
          .removeDocument(widget.documentId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文档已删除')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('删除文档失败', error);
    } finally {
      if (mounted) {
        setState(() {
          _removingDocument = false;
        });
      }
    }
  }

  Future<void> _duplicateDocument(DocumentSummary document) async {
    final targetDocument = await showCreateDocumentDialog(
      context,
      initialName: '${document.name} 副本',
      initialKind: document.kind,
      title: '复制文档',
    );
    if (targetDocument == null || !mounted) {
      return;
    }

    setState(() {
      _duplicatingDocument = true;
    });
    try {
      final items = await _itemsFuture;
      var copiedCount = 0;
      DocumentItemSummary? lastCreatedItem;
      for (final item in items) {
        final createdItem = await _copyDocumentItemToDocument(
          item: item,
          targetDocumentId: targetDocument.id,
        );
        if (createdItem != null) {
          copiedCount += 1;
          lastCreatedItem = createdItem;
        }
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copiedCount == 0
                ? '已创建空副本：${targetDocument.name}'
                : '已创建文档副本：${targetDocument.name}',
          ),
        ),
      );
      await Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: targetDocument.id,
          focusItemId: lastCreatedItem?.id,
          focusItemTitle: lastCreatedItem?.title,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('复制文档失败', error);
    } finally {
      if (mounted) {
        setState(() {
          _duplicatingDocument = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文档详情'),
        leading: BackButton(
          onPressed: _popWithCurrentDocument,
        ),
      ),
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) {
                return;
              }
              _popWithCurrentDocument();
            },
            child: FutureBuilder<DocumentSummary?>(
              future: _documentFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final message = error is HttpJsonException
                      ? '文档加载失败：${error.message}（HTTP ${error.statusCode}）'
                      : '文档加载失败：$error';
                  return _DocumentErrorCard(message: message);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final document = snapshot.data;
                if (document == null) {
                  return const Center(child: Text('未找到对应文档'));
                }

                return workspaceConstrainedContent(
                  context,
                  child: ListView(
                    controller: _scrollController,
                    padding: workspacePagePadding(context),
                    children: [
                      _DocumentHeroCard(
                        document: document,
                        liveQuestionCount: _liveQuestionCount,
                        liveLayoutCount: _liveLayoutCount,
                        highlightLatestExport: _focusedExportJobId != null &&
                            _focusedExportJobId == document.latestExportJobId,
                      ),
                      const SizedBox(height: 18),
                      _DocumentContextCard(
                        modeLabel: AppConfig.dataModeLabel,
                        sessionLabel:
                            AppServices.instance.session?.username ?? '未登录',
                        tenantLabel:
                            AppServices.instance.activeTenant?.code ?? '未选择租户',
                      ),
                      const SizedBox(height: 18),
                      WorkspacePanel(
                        padding: const EdgeInsets.all(24),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wideDesktop = constraints.maxWidth >= 1120;
                            final summary = const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                WorkspaceEyebrow(
                                  label: 'Compose Controls',
                                  icon: Icons.dashboard_customize_outlined,
                                ),
                                SizedBox(height: 14),
                                Text(
                                  '这里可以直接整理文档项、调整顺序，并去题库或选题篮继续补题。',
                                  style: TextStyle(
                                    height: 1.6,
                                    color: TelegramPalette.textMuted,
                                  ),
                                ),
                              ],
                            );
                            final actionButtons = <Widget>[
                              FilledButton.tonalIcon(
                                onPressed: _reloadAll,
                                icon: const Icon(Icons.edit_note_outlined),
                                label: const Text('刷新状态'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _renamingDocument ||
                                        _removingDocument ||
                                        _duplicatingDocument
                                    ? null
                                    : () => _renameDocument(document),
                                icon: _renamingDocument
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.drive_file_rename_outline,
                                      ),
                                label: Text(
                                  _renamingDocument ? '重命名中…' : '重命名文档',
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _removingDocument ||
                                        _renamingDocument ||
                                        _duplicatingDocument
                                    ? null
                                    : () => _removeDocument(document),
                                icon: _removingDocument
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.delete_outline),
                                label: Text(
                                  _removingDocument ? '删除中…' : '删除文档',
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _duplicatingDocument ||
                                        _renamingDocument ||
                                        _removingDocument
                                    ? null
                                    : () => _duplicateDocument(document),
                                icon: _duplicatingDocument
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.copy_all_outlined),
                                label: Text(
                                  _duplicatingDocument ? '复制中…' : '复制文档',
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _openDocumentsWorkspace,
                                icon: const Icon(Icons.dashboard_outlined),
                                label: const Text('返回文档工作区'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: document.latestExportStatus ==
                                        'not_started'
                                    ? null
                                    : () => _openExports(document),
                                icon: const Icon(Icons.history_outlined),
                                label: const Text('查看导出记录'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: document.latestExportJobId == null
                                    ? null
                                    : () => _openLatestExportDetail(document),
                                icon: const Icon(Icons.receipt_long_outlined),
                                label: const Text('查看最近导出详情'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: document.latestExportStatus !=
                                            'succeeded' ||
                                        document.latestExportJobId == null
                                    ? null
                                    : () => _openLatestExportResult(document),
                                icon: const Icon(Icons.visibility_outlined),
                                label: const Text('打开最近结果'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _exportDocument,
                                icon: const Icon(Icons.cloud_outlined),
                                label: const Text('导出并查看记录'),
                              ),
                            ];
                            final actionRail = Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: TelegramPalette.surfaceSoft,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: TelegramPalette.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const WorkspaceEyebrow(
                                    label: '文档操作',
                                    icon: Icons.tune_outlined,
                                  ),
                                  const SizedBox(height: 14),
                                  LayoutBuilder(
                                    builder: (context, railConstraints) {
                                      if (!wideDesktop) {
                                        return Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: actionButtons,
                                        );
                                      }
                                      final buttonWidth =
                                          (railConstraints.maxWidth - 12) / 2;
                                      return Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          for (final button in actionButtons)
                                            SizedBox(
                                              width: buttonWidth,
                                              child: button,
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                            if (!wideDesktop) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  summary,
                                  const SizedBox(height: 18),
                                  actionRail,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 320, child: summary),
                                const SizedBox(width: 20),
                                Expanded(child: actionRail),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      FutureBuilder<List<DocumentItemSummary>>(
                        future: _itemsFuture,
                        builder: (context, itemsSnapshot) {
                          if (itemsSnapshot.hasError) {
                            final error = itemsSnapshot.error;
                            final message = error is HttpJsonException
                                ? '文档项加载失败：${error.message}（HTTP ${error.statusCode}）'
                                : '文档项加载失败：$error';
                            return _DocumentErrorCard(
                              message: message,
                              onRetry: _reloadItems,
                            );
                          }
                          if (!itemsSnapshot.hasData) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          _scheduleFocusedItemScroll(itemsSnapshot.data!);
                          _syncDerivedCounts(itemsSnapshot.data!);
                          _selectedItemIds = _selectedItemIds
                              .where(
                                (id) => itemsSnapshot.data!
                                    .any((item) => item.id == id),
                              )
                              .toSet();
                          final filteredItems =
                              _applyItemFilters(itemsSnapshot.data!);
                          final insertionAnchorId =
                              _lastSelectedItemIdInOrder(itemsSnapshot.data!);
                          final insertionAnchor = insertionAnchorId == null
                              ? null
                              : itemsSnapshot.data!
                                  .cast<DocumentItemSummary?>()
                                  .firstWhere(
                                    (item) => item?.id == insertionAnchorId,
                                    orElse: () => null,
                                  );

                          return Column(
                            children: [
                              if (_focusedItemId != null &&
                                  itemsSnapshot.data!.any(
                                    (item) => item.id == _focusedItemId,
                                  )) ...[
                                _FocusedItemNotice(
                                  title: itemsSnapshot.data!
                                      .firstWhere(
                                          (item) => item.id == _focusedItemId)
                                      .title,
                                ),
                                const SizedBox(height: 12),
                              ] else if (_focusedItemTitle != null &&
                                  itemsSnapshot.data!.any(
                                    (item) => item.title == _focusedItemTitle,
                                  )) ...[
                                _FocusedItemNotice(title: _focusedItemTitle!),
                                const SizedBox(height: 12),
                              ],
                              if (insertionAnchor != null) ...[
                                _InsertionAnchorCard(
                                  selectedCount: _selectedItemIds.length,
                                  anchorTitle: insertionAnchor.title,
                                ),
                                const SizedBox(height: 12),
                              ],
                              FutureBuilder<List<LayoutElementSummary>>(
                                future: _layoutElementsFuture,
                                builder: (context, layoutSnapshot) {
                                  return _ComposeHintCard(
                                    onAddLayoutElement: _addLayoutElement,
                                    onCreateLayoutElement:
                                        _createCustomLayoutElement,
                                    onOpenLibrary: _openLibrary,
                                    onOpenBasket: _openBasket,
                                    quickLayoutElements: layoutSnapshot.hasData
                                        ? layoutSnapshot.data!.take(3).toList()
                                        : const <LayoutElementSummary>[],
                                    onInsertQuickLayout: _insertLayoutElement,
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _DocumentItemsToolbar(
                                items: itemsSnapshot.data!,
                                filteredItems: filteredItems,
                                filteredInBasketQuestionCount: filteredItems
                                    .where(
                                      (item) =>
                                          item.kind == 'question' &&
                                          (item.sourceQuestionId?.isNotEmpty ??
                                              false) &&
                                          _basketQuestionIds
                                              .contains(item.sourceQuestionId),
                                    )
                                    .length,
                                filteredOutOfBasketQuestionCount: filteredItems
                                    .where(
                                      (item) =>
                                          item.kind == 'question' &&
                                          (item.sourceQuestionId?.isNotEmpty ??
                                              false) &&
                                          !_basketQuestionIds
                                              .contains(item.sourceQuestionId),
                                    )
                                    .length,
                                queryController: _itemQueryController,
                                query: _itemQuery,
                                kindFilter: _itemKindFilter,
                                basketFilter: _itemBasketFilter,
                                subjectFilter: _itemSubjectFilter,
                                stageFilter: _itemStageFilter,
                                gradeFilter: _itemGradeFilter,
                                textbookFilter: _itemTextbookFilter,
                                chapterFilter: _itemChapterFilter,
                                sortBy: _itemSortBy,
                                showOnlySelected: _showOnlySelectedItems,
                                selectedCount: _selectedItemIds.length,
                                onQueryChanged: (value) {
                                  setState(() {
                                    _itemQuery = value;
                                  });
                                },
                                onKindChanged: (value) {
                                  setState(() {
                                    _itemKindFilter = value;
                                  });
                                },
                                onBasketFilterChanged: (value) {
                                  setState(() {
                                    _itemBasketFilter = value;
                                  });
                                },
                                onSubjectFilterChanged: (value) {
                                  setState(() {
                                    _itemSubjectFilter = value;
                                  });
                                },
                                onStageFilterChanged: (value) {
                                  setState(() {
                                    _itemStageFilter = value;
                                  });
                                },
                                onGradeFilterChanged: (value) {
                                  setState(() {
                                    _itemGradeFilter = value;
                                  });
                                },
                                onTextbookFilterChanged: (value) {
                                  setState(() {
                                    _itemTextbookFilter = value;
                                  });
                                },
                                onChapterFilterChanged: (value) {
                                  setState(() {
                                    _itemChapterFilter = value;
                                  });
                                },
                                onSortChanged: (value) {
                                  setState(() {
                                    _itemSortBy = value;
                                  });
                                },
                                onShowOnlySelectedChanged: (value) {
                                  setState(() {
                                    _showOnlySelectedItems = value;
                                  });
                                },
                                onClearFilters: _clearItemFilters,
                              ),
                              const SizedBox(height: 12),
                              if (itemsSnapshot.data!.isNotEmpty) ...[
                                _DocumentItemsSelectionBar(
                                  selectedCount: _selectedItemIds.length,
                                  selectedQuestionCount: itemsSnapshot.data!
                                      .where(
                                        (item) =>
                                            _selectedItemIds
                                                .contains(item.id) &&
                                            item.kind == 'question',
                                      )
                                      .length,
                                  selectedLayoutCount: itemsSnapshot.data!
                                      .where(
                                        (item) =>
                                            _selectedItemIds
                                                .contains(item.id) &&
                                            item.kind != 'question',
                                      )
                                      .length,
                                  selectedQuestionSubjectCount: itemsSnapshot
                                      .data!
                                      .where(
                                        (item) =>
                                            _selectedItemIds
                                                .contains(item.id) &&
                                            item.kind == 'question',
                                      )
                                      .map<String>(
                                        (item) => item.subject?.trim() ?? '',
                                      )
                                      .where((value) => value.isNotEmpty)
                                      .toSet()
                                      .length,
                                  selectedQuestionTextbookCount: itemsSnapshot
                                      .data!
                                      .where(
                                        (item) =>
                                            _selectedItemIds
                                                .contains(item.id) &&
                                            item.kind == 'question',
                                      )
                                      .map<String>(
                                        (item) => item.textbook?.trim() ?? '',
                                      )
                                      .where((value) => value.isNotEmpty)
                                      .toSet()
                                      .length,
                                  selectedQuestionChapterCount: itemsSnapshot
                                      .data!
                                      .where(
                                        (item) =>
                                            _selectedItemIds
                                                .contains(item.id) &&
                                            item.kind == 'question',
                                      )
                                      .map<String>(
                                        (item) => item.chapter?.trim() ?? '',
                                      )
                                      .where((value) => value.isNotEmpty)
                                      .toSet()
                                      .length,
                                  selectedQuestionStageCount:
                                      itemsSnapshot.data!
                                          .where(
                                            (item) =>
                                                _selectedItemIds
                                                    .contains(item.id) &&
                                                item.kind == 'question',
                                          )
                                          .map<String>(
                                            (item) => item.stage?.trim() ?? '',
                                          )
                                          .where((value) => value.isNotEmpty)
                                          .toSet()
                                          .length,
                                  selectedQuestionGradeCount:
                                      itemsSnapshot.data!
                                          .where(
                                            (item) =>
                                                _selectedItemIds
                                                    .contains(item.id) &&
                                                item.kind == 'question',
                                          )
                                          .map<String>(
                                            (item) => item.grade?.trim() ?? '',
                                          )
                                          .where((value) => value.isNotEmpty)
                                          .toSet()
                                          .length,
                                  filteredCount: filteredItems.length,
                                  selectedFilteredCount: filteredItems
                                      .where(
                                        (item) =>
                                            _selectedItemIds.contains(item.id),
                                      )
                                      .length,
                                  filteredQuestionCount: filteredItems
                                      .where((item) => item.kind == 'question')
                                      .length,
                                  filteredInBasketQuestionCount: filteredItems
                                      .where(
                                        (item) =>
                                            item.kind == 'question' &&
                                            (item.sourceQuestionId
                                                    ?.isNotEmpty ??
                                                false) &&
                                            _basketQuestionIds.contains(
                                                item.sourceQuestionId),
                                      )
                                      .length,
                                  filteredNotInBasketQuestionCount:
                                      filteredItems
                                          .where(
                                            (item) =>
                                                item.kind == 'question' &&
                                                (item.sourceQuestionId
                                                        ?.isNotEmpty ??
                                                    false) &&
                                                !_basketQuestionIds.contains(
                                                    item.sourceQuestionId),
                                          )
                                          .length,
                                  filteredLayoutCount: filteredItems
                                      .where((item) => item.kind != 'question')
                                      .length,
                                  allFilteredSelected: filteredItems
                                          .isNotEmpty &&
                                      filteredItems.every(
                                        (item) =>
                                            _selectedItemIds.contains(item.id),
                                      ),
                                  addingSelectedQuestionsToBasket:
                                      _addingSelectedQuestionsToBasket,
                                  removingSelectedQuestionsFromBasket:
                                      _removingSelectedQuestionsFromBasket,
                                  addingSelectedItemsToDocument:
                                      _addingSelectedItemsToDocument,
                                  creatingDocumentFromSelected:
                                      _creatingDocumentFromSelectedItems,
                                  duplicatingSelected:
                                      _duplicatingSelectedItems,
                                  movingSelected: _movingSelectedItems,
                                  removingSelected: _removingSelectedItems,
                                  onSelectAll: () =>
                                      _selectAllFilteredItems(filteredItems),
                                  onSelectQuestions: () =>
                                      _selectFilteredItemsByKind(
                                    filteredItems,
                                    'question',
                                  ),
                                  onSelectLayouts: () =>
                                      _selectFilteredItemsByKind(
                                    filteredItems,
                                    'non_question',
                                  ),
                                  onSelectInBasketQuestions: () =>
                                      _selectFilteredItemsInBasketQuestions(
                                    filteredItems,
                                  ),
                                  onSelectNotInBasketQuestions: () =>
                                      _selectFilteredItemsNotInBasketQuestions(
                                    filteredItems,
                                  ),
                                  onInvertSelection: () =>
                                      _invertFilteredItemsSelection(
                                          filteredItems),
                                  onClearSelection: _clearItemSelection,
                                  onAddSelectedQuestionsToBasket: () =>
                                      _addSelectedQuestionItemsToBasket(
                                    itemsSnapshot.data!,
                                  ),
                                  onRemoveSelectedQuestionsFromBasket: () =>
                                      _removeSelectedQuestionItemsFromBasket(
                                    itemsSnapshot.data!,
                                  ),
                                  onAddSelectedItemsToDocument: () =>
                                      _addSelectedItemsToDocument(
                                    itemsSnapshot.data!,
                                  ),
                                  onCreateDocumentFromSelected: () =>
                                      _createDocumentFromSelectedItems(
                                    itemsSnapshot.data!,
                                  ),
                                  onDuplicateSelected: () =>
                                      _duplicateSelectedItems(
                                          itemsSnapshot.data!),
                                  onMoveUpSelected: () => _moveSelectedItems(
                                      -1, itemsSnapshot.data!),
                                  onMoveDownSelected: () => _moveSelectedItems(
                                      1, itemsSnapshot.data!),
                                  onMoveSelectedToTop: () =>
                                      _moveSelectedItemsToBoundary(
                                    -1,
                                    itemsSnapshot.data!,
                                  ),
                                  onMoveSelectedToBottom: () =>
                                      _moveSelectedItemsToBoundary(
                                    1,
                                    itemsSnapshot.data!,
                                  ),
                                  onRemoveSelected: () =>
                                      _removeSelectedItems(filteredItems),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (itemsSnapshot.data!.isEmpty)
                                WorkspacePanel(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '当前文档还没有内容。你可以先去题库挑题、打开选题篮批量加入，或者先插入排版元素搭好结构。',
                                        style: TextStyle(
                                          height: 1.5,
                                          color: TelegramPalette.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          FilledButton.tonalIcon(
                                            onPressed: _openLibrary,
                                            icon: const Icon(Icons.search),
                                            label: const Text('去题库挑题'),
                                          ),
                                          FilledButton.tonalIcon(
                                            onPressed: _openBasket,
                                            icon: const Icon(
                                              Icons
                                                  .collections_bookmark_outlined,
                                            ),
                                            label: const Text('打开选题篮'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: _addLayoutElement,
                                            icon: const Icon(
                                                Icons.add_box_outlined),
                                            label: const Text('插入排版元素'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed:
                                                _createCustomLayoutElement,
                                            icon: const Icon(
                                                Icons.note_add_outlined),
                                            label: const Text('新建排版元素'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              if (itemsSnapshot.data!.isNotEmpty &&
                                  filteredItems.isEmpty)
                                WorkspacePanel(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '当前筛选条件下没有匹配的文档项。',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: TelegramPalette.textStrong,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _itemQuery.trim().isEmpty
                                            ? '可以切换文档项类型筛选，或清空筛选后查看全部文档项。'
                                            : '可以调整关键词或类型筛选，重新定位目标文档项。',
                                        style: const TextStyle(
                                          height: 1.5,
                                          color: TelegramPalette.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      TextButton.icon(
                                        onPressed: _clearItemFilters,
                                        icon: const Icon(
                                          Icons.filter_alt_off_outlined,
                                        ),
                                        label: const Text('清空筛选'),
                                      ),
                                    ],
                                  ),
                                ),
                              ...filteredItems.map((item) {
                                final itemIndex = itemsSnapshot.data!
                                    .indexWhere(
                                        (candidate) => candidate.id == item.id);
                                return Padding(
                                  key: _keyForItem(item.id),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DocumentItemCard(
                                    item: item,
                                    isSelected:
                                        _selectedItemIds.contains(item.id),
                                    busy: _busyItemIds.contains(item.id),
                                    canMoveUp: itemIndex > 0,
                                    canMoveDown: itemIndex >= 0 &&
                                        itemIndex <
                                            itemsSnapshot.data!.length - 1,
                                    highlighted: (_focusedItemId != null &&
                                            _focusedItemId == item.id) ||
                                        (_focusedItemTitle != null &&
                                            _focusedItemTitle == item.title),
                                    onMoveUp: () => _moveItem(item, -1),
                                    onMoveDown: () => _moveItem(item, 1),
                                    onRemove: () => _removeItem(item),
                                    onOpenSourceQuestion:
                                        item.sourceQuestionId == null ||
                                                item.sourceQuestionId!.isEmpty
                                            ? null
                                            : () => _openSourceQuestion(item),
                                    onAddToBasket: item.kind != 'question' ||
                                            item.sourceQuestionId == null ||
                                            item.sourceQuestionId!.isEmpty ||
                                            _basketQuestionIds.contains(
                                              item.sourceQuestionId,
                                            )
                                        ? null
                                        : () =>
                                            _addQuestionItemFromDocument(item),
                                    onRemoveFromBasket: item.kind !=
                                                'question' ||
                                            item.sourceQuestionId == null ||
                                            item.sourceQuestionId!.isEmpty ||
                                            !_basketQuestionIds.contains(
                                              item.sourceQuestionId,
                                            )
                                        ? null
                                        : () => _removeQuestionItemFromDocument(
                                            item),
                                    isInBasket: item.kind == 'question' &&
                                        (item.sourceQuestionId?.isNotEmpty ??
                                            false) &&
                                        _basketQuestionIds.contains(
                                          item.sourceQuestionId,
                                        ),
                                    onDuplicate: () => _duplicateItem(item),
                                    onEditLayout: item.kind == 'question'
                                        ? null
                                        : () => _editLayoutItem(item),
                                    onSelectionChanged: (selected) {
                                      _setItemSelection(item.id, selected);
                                    },
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentItemsSelectionBar extends StatelessWidget {
  const _DocumentItemsSelectionBar({
    required this.selectedCount,
    required this.selectedQuestionCount,
    required this.selectedLayoutCount,
    required this.selectedQuestionSubjectCount,
    required this.selectedQuestionTextbookCount,
    required this.selectedQuestionChapterCount,
    required this.selectedQuestionStageCount,
    required this.selectedQuestionGradeCount,
    required this.filteredCount,
    required this.selectedFilteredCount,
    required this.filteredQuestionCount,
    required this.filteredInBasketQuestionCount,
    required this.filteredNotInBasketQuestionCount,
    required this.filteredLayoutCount,
    required this.allFilteredSelected,
    required this.addingSelectedQuestionsToBasket,
    required this.removingSelectedQuestionsFromBasket,
    required this.addingSelectedItemsToDocument,
    required this.creatingDocumentFromSelected,
    required this.duplicatingSelected,
    required this.movingSelected,
    required this.removingSelected,
    required this.onSelectAll,
    required this.onSelectQuestions,
    required this.onSelectInBasketQuestions,
    required this.onSelectNotInBasketQuestions,
    required this.onInvertSelection,
    required this.onSelectLayouts,
    required this.onClearSelection,
    required this.onAddSelectedQuestionsToBasket,
    required this.onRemoveSelectedQuestionsFromBasket,
    required this.onAddSelectedItemsToDocument,
    required this.onCreateDocumentFromSelected,
    required this.onDuplicateSelected,
    required this.onMoveUpSelected,
    required this.onMoveDownSelected,
    required this.onMoveSelectedToTop,
    required this.onMoveSelectedToBottom,
    required this.onRemoveSelected,
  });

  final int selectedCount;
  final int selectedQuestionCount;
  final int selectedLayoutCount;
  final int selectedQuestionSubjectCount;
  final int selectedQuestionTextbookCount;
  final int selectedQuestionChapterCount;
  final int selectedQuestionStageCount;
  final int selectedQuestionGradeCount;
  final int filteredCount;
  final int selectedFilteredCount;
  final int filteredQuestionCount;
  final int filteredInBasketQuestionCount;
  final int filteredNotInBasketQuestionCount;
  final int filteredLayoutCount;
  final bool allFilteredSelected;
  final bool addingSelectedQuestionsToBasket;
  final bool removingSelectedQuestionsFromBasket;
  final bool addingSelectedItemsToDocument;
  final bool creatingDocumentFromSelected;
  final bool duplicatingSelected;
  final bool movingSelected;
  final bool removingSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectQuestions;
  final VoidCallback onSelectInBasketQuestions;
  final VoidCallback onSelectNotInBasketQuestions;
  final VoidCallback onInvertSelection;
  final VoidCallback onSelectLayouts;
  final VoidCallback onClearSelection;
  final Future<void> Function() onAddSelectedQuestionsToBasket;
  final Future<void> Function() onRemoveSelectedQuestionsFromBasket;
  final Future<void> Function() onAddSelectedItemsToDocument;
  final Future<void> Function() onCreateDocumentFromSelected;
  final Future<void> Function() onDuplicateSelected;
  final Future<void> Function() onMoveUpSelected;
  final Future<void> Function() onMoveDownSelected;
  final Future<void> Function() onMoveSelectedToTop;
  final Future<void> Function() onMoveSelectedToBottom;
  final Future<void> Function() onRemoveSelected;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      backgroundColor: selectedCount > 0
          ? TelegramPalette.surfaceAccent
          : TelegramPalette.surfaceRaised,
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            selectedCount > 0
                ? '已选择 $selectedCount / $filteredCount 个文档项'
                : '可选择当前结果中的部分文档项再批量处理',
            style: const TextStyle(
              color: TelegramPalette.textStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (selectedCount > 0)
            _ContextChip(label: '已选题目', value: '$selectedQuestionCount'),
          if (selectedCount > 0)
            _ContextChip(label: '已选排版', value: '$selectedLayoutCount'),
          if (selectedQuestionCount > 0)
            _ContextChip(
              label: '涉及学科',
              value: '$selectedQuestionSubjectCount',
            ),
          if (selectedQuestionCount > 0)
            _ContextChip(
              label: '涉及教材',
              value: '$selectedQuestionTextbookCount',
            ),
          if (selectedQuestionCount > 0)
            _ContextChip(
              label: '涉及章节',
              value: '$selectedQuestionChapterCount',
            ),
          if (selectedQuestionCount > 0)
            _ContextChip(
              label: '涉及学段',
              value: '$selectedQuestionStageCount',
            ),
          if (selectedQuestionCount > 0)
            _ContextChip(
              label: '涉及年级',
              value: '$selectedQuestionGradeCount',
            ),
          OutlinedButton.icon(
            onPressed: allFilteredSelected ? null : onSelectAll,
            icon: const Icon(Icons.select_all),
            label: Text(allFilteredSelected ? '已全选' : '全选当前结果'),
          ),
          OutlinedButton.icon(
            onPressed: filteredQuestionCount == 0 ? null : onSelectQuestions,
            icon: const Icon(Icons.quiz_outlined),
            label: Text(
              filteredQuestionCount == 0 ? '无题目项' : '全选题目项',
            ),
          ),
          OutlinedButton.icon(
            onPressed: filteredInBasketQuestionCount == 0
                ? null
                : onSelectInBasketQuestions,
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
            label: Text(
              filteredInBasketQuestionCount == 0 ? '无在篮题' : '选中已在篮中题目',
            ),
          ),
          OutlinedButton.icon(
            onPressed: filteredNotInBasketQuestionCount == 0
                ? null
                : onSelectNotInBasketQuestions,
            icon: const Icon(Icons.playlist_add_outlined),
            label: Text(
              filteredNotInBasketQuestionCount == 0 ? '无未入篮题' : '选中未在篮中题目',
            ),
          ),
          OutlinedButton.icon(
            onPressed: filteredLayoutCount == 0 ? null : onSelectLayouts,
            icon: const Icon(Icons.view_agenda_outlined),
            label: Text(
              filteredLayoutCount == 0 ? '无排版项' : '全选排版项',
            ),
          ),
          OutlinedButton.icon(
            onPressed: filteredCount == 0 ? null : onInvertSelection,
            icon: const Icon(Icons.flip_to_back_outlined),
            label: Text(
              selectedFilteredCount == 0 ? '反选当前结果' : '反选当前结果',
            ),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ? null : onClearSelection,
            icon: const Icon(Icons.clear_all),
            label: const Text('清空选择'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelectedQuestionsToBasket ||
                    removingSelectedQuestionsFromBasket ||
                    addingSelectedItemsToDocument ||
                    creatingDocumentFromSelected ||
                    duplicatingSelected ||
                    movingSelected ||
                    removingSelected
                ? null
                : () => onAddSelectedQuestionsToBasket(),
            icon: addingSelectedQuestionsToBasket
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.playlist_add_outlined),
            label: Text(
              addingSelectedQuestionsToBasket ? '加入中…' : '加入选题篮',
            ),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelectedQuestionsToBasket ||
                    removingSelectedQuestionsFromBasket ||
                    addingSelectedItemsToDocument ||
                    creatingDocumentFromSelected ||
                    duplicatingSelected ||
                    movingSelected ||
                    removingSelected
                ? null
                : () => onRemoveSelectedQuestionsFromBasket(),
            icon: removingSelectedQuestionsFromBasket
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.playlist_remove_outlined),
            label: Text(
              removingSelectedQuestionsFromBasket ? '移出中…' : '移出选题篮',
            ),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelectedQuestionsToBasket ||
                    removingSelectedQuestionsFromBasket ||
                    addingSelectedItemsToDocument ||
                    creatingDocumentFromSelected ||
                    duplicatingSelected ||
                    movingSelected ||
                    removingSelected
                ? null
                : () => onAddSelectedItemsToDocument(),
            icon: addingSelectedItemsToDocument
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.drive_file_move_outline),
            label: Text(
              addingSelectedItemsToDocument ? '承接中…' : '加入文档承接',
            ),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelectedQuestionsToBasket ||
                    removingSelectedQuestionsFromBasket ||
                    addingSelectedItemsToDocument ||
                    creatingDocumentFromSelected ||
                    duplicatingSelected ||
                    movingSelected ||
                    removingSelected
                ? null
                : () => onCreateDocumentFromSelected(),
            icon: creatingDocumentFromSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.library_add_outlined),
            label: Text(
              creatingDocumentFromSelected ? '创建中…' : '新建文档承接',
            ),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelectedQuestionsToBasket ||
                    removingSelectedQuestionsFromBasket ||
                    addingSelectedItemsToDocument ||
                    creatingDocumentFromSelected ||
                    duplicatingSelected ||
                    movingSelected ||
                    removingSelected
                ? null
                : () => onDuplicateSelected(),
            icon: duplicatingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy_all_outlined),
            label: Text(duplicatingSelected ? '复制中…' : '批量复制'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelectedQuestionsToBasket ||
                    removingSelectedQuestionsFromBasket ||
                    addingSelectedItemsToDocument ||
                    creatingDocumentFromSelected ||
                    duplicatingSelected ||
                    movingSelected ||
                    removingSelected
                ? null
                : () => onMoveUpSelected(),
            icon: movingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.keyboard_arrow_up),
            label: Text(movingSelected ? '调整中…' : '批量上移'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelectedQuestionsToBasket ||
                    removingSelectedQuestionsFromBasket ||
                    addingSelectedItemsToDocument ||
                    creatingDocumentFromSelected ||
                    duplicatingSelected ||
                    movingSelected ||
                    removingSelected
                ? null
                : () => onMoveDownSelected(),
            icon: movingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.keyboard_arrow_down),
            label: Text(movingSelected ? '调整中…' : '批量下移'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelectedQuestionsToBasket ||
                    removingSelectedQuestionsFromBasket ||
                    addingSelectedItemsToDocument ||
                    creatingDocumentFromSelected ||
                    duplicatingSelected ||
                    movingSelected ||
                    removingSelected
                ? null
                : () => onMoveSelectedToTop(),
            icon: movingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.vertical_align_top),
            label: Text(movingSelected ? '调整中…' : '置顶'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelectedQuestionsToBasket ||
                    addingSelectedItemsToDocument ||
                    creatingDocumentFromSelected ||
                    duplicatingSelected ||
                    movingSelected ||
                    removingSelected
                ? null
                : () => onMoveSelectedToBottom(),
            icon: movingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.vertical_align_bottom),
            label: Text(movingSelected ? '调整中…' : '置底'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    addingSelectedQuestionsToBasket ||
                    addingSelectedItemsToDocument ||
                    creatingDocumentFromSelected ||
                    duplicatingSelected ||
                    movingSelected ||
                    removingSelected
                ? null
                : () => onRemoveSelected(),
            icon: removingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(removingSelected ? '移除中…' : '批量移除'),
          ),
        ],
      ),
    );
  }
}

class _FocusedItemNotice extends StatelessWidget {
  const _FocusedItemNotice({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      backgroundColor: TelegramPalette.surfaceAccent,
      borderColor: TelegramPalette.borderAccent,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.playlist_add_check,
              color: TelegramPalette.textStrong),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '已定位到刚加入的文档项：$title',
              style: const TextStyle(
                height: 1.5,
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

class _ComposeHintCard extends StatelessWidget {
  const _ComposeHintCard({
    required this.onAddLayoutElement,
    required this.onCreateLayoutElement,
    required this.onOpenLibrary,
    required this.onOpenBasket,
    required this.quickLayoutElements,
    required this.onInsertQuickLayout,
  });

  final Future<void> Function() onAddLayoutElement;
  final Future<void> Function() onCreateLayoutElement;
  final Future<void> Function() onOpenLibrary;
  final Future<void> Function() onOpenBasket;
  final List<LayoutElementSummary> quickLayoutElements;
  final Future<void> Function(LayoutElementSummary element) onInsertQuickLayout;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '文档编排工作区',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '这里可以继续插入排版元素、回到题库或选题篮补题，并把新增内容按当前工作位置插回文档。',
                      style: TextStyle(
                        height: 1.5,
                        color: TelegramPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onAddLayoutElement,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('插入排版元素'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCreateLayoutElement,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('新建排版元素'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onOpenLibrary,
                    icon: const Icon(Icons.search),
                    label: const Text('去题库挑题'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenBasket,
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    label: const Text('打开选题篮'),
                  ),
                ],
              ),
            ],
          ),
          if (quickLayoutElements.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              '常用排版元素',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: TelegramPalette.textStrong,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: quickLayoutElements
                  .map(
                    (element) => ActionChip(
                      avatar: const Icon(
                        Icons.auto_awesome_outlined,
                        size: 18,
                      ),
                      label: Text(element.name),
                      onPressed: () => onInsertQuickLayout(element),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsertionAnchorCard extends StatelessWidget {
  const _InsertionAnchorCard({
    required this.selectedCount,
    required this.anchorTitle,
  });

  final int selectedCount;
  final String anchorTitle;

  @override
  Widget build(BuildContext context) {
    final detail = selectedCount > 1
        ? '当前已选区块会作为工作位置，接下来从题库、选题篮加入的题和新插入的排版元素都会落在“$anchorTitle”后面。'
        : '当前工作位置已锁定，接下来从题库、选题篮加入的题和新插入的排版元素都会落在“$anchorTitle”后面。';
    return WorkspacePanel(
      backgroundColor: TelegramPalette.surfaceAccent,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.vertical_align_center_outlined,
            color: TelegramPalette.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCount > 1 ? '当前插入位置：已选区块末尾' : '当前插入位置',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TelegramPalette.textStrong,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: const TextStyle(
                    height: 1.45,
                    color: TelegramPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentItemsToolbar extends StatelessWidget {
  const _DocumentItemsToolbar({
    required this.items,
    required this.filteredItems,
    required this.filteredInBasketQuestionCount,
    required this.filteredOutOfBasketQuestionCount,
    required this.queryController,
    required this.query,
    required this.kindFilter,
    required this.basketFilter,
    required this.subjectFilter,
    required this.stageFilter,
    required this.gradeFilter,
    required this.textbookFilter,
    required this.chapterFilter,
    required this.sortBy,
    required this.showOnlySelected,
    required this.selectedCount,
    required this.onQueryChanged,
    required this.onKindChanged,
    required this.onBasketFilterChanged,
    required this.onSubjectFilterChanged,
    required this.onStageFilterChanged,
    required this.onGradeFilterChanged,
    required this.onTextbookFilterChanged,
    required this.onChapterFilterChanged,
    required this.onSortChanged,
    required this.onShowOnlySelectedChanged,
    required this.onClearFilters,
  });

  final List<DocumentItemSummary> items;
  final List<DocumentItemSummary> filteredItems;
  final int filteredInBasketQuestionCount;
  final int filteredOutOfBasketQuestionCount;
  final TextEditingController queryController;
  final String query;
  final String kindFilter;
  final String basketFilter;
  final String subjectFilter;
  final String stageFilter;
  final String gradeFilter;
  final String textbookFilter;
  final String chapterFilter;
  final String sortBy;
  final bool showOnlySelected;
  final int selectedCount;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onBasketFilterChanged;
  final ValueChanged<String> onSubjectFilterChanged;
  final ValueChanged<String> onStageFilterChanged;
  final ValueChanged<String> onGradeFilterChanged;
  final ValueChanged<String> onTextbookFilterChanged;
  final ValueChanged<String> onChapterFilterChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onShowOnlySelectedChanged;
  final VoidCallback onClearFilters;

  List<(String, String)> get _activeFilterEntries {
    final entries = <(String, String)>[];
    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty) {
      entries.add(('关键词', normalizedQuery));
    }
    if (kindFilter == 'question') {
      entries.add(('文档项类型', '题目项'));
    } else if (kindFilter == 'layout_element') {
      entries.add(('文档项类型', '排版元素'));
    }
    if (basketFilter == 'in_basket') {
      entries.add(('选题篮', '已在选题篮'));
    } else if (basketFilter == 'not_in_basket') {
      entries.add(('选题篮', '未在选题篮'));
    }
    if (subjectFilter != 'all') {
      entries.add(('学科', subjectFilter));
    }
    if (stageFilter != 'all') {
      entries.add(('学段', stageFilter));
    }
    if (gradeFilter != 'all') {
      entries.add(('年级', gradeFilter));
    }
    if (textbookFilter != 'all') {
      entries.add(('教材', textbookFilter));
    }
    if (chapterFilter != 'all') {
      entries.add(('章节', chapterFilter));
    }
    if (sortBy != 'document_order') {
      entries.add(('排序', _sortLabel(sortBy)));
    }
    if (showOnlySelected) {
      entries.add(('范围', '只看已选'));
    }
    return entries;
  }

  String _sortLabel(String value) {
    switch (value) {
      case 'title':
        return '按标题';
      case 'kind':
        return '按类型';
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
      case 'basket_first':
        return '选题篮优先';
      case 'document_order':
      default:
        return '文档顺序';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredQuestionCount =
        filteredItems.where((item) => item.kind == 'question').length;
    final filteredLayoutCount = filteredItems.length - filteredQuestionCount;
    final filteredSubjectCount = _distinctValues(
      filteredItems
          .where((item) => item.kind == 'question')
          .map((item) => item.subject),
    ).length;
    final filteredStageCount = _distinctValues(
      filteredItems
          .where((item) => item.kind == 'question')
          .map((item) => item.stage),
    ).length;
    final filteredGradeCount = _distinctValues(
      filteredItems
          .where((item) => item.kind == 'question')
          .map((item) => item.grade),
    ).length;
    return WorkspacePanel(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final controls = <Widget>[
            SizedBox(
              width: compact ? double.infinity : 320,
              child: TextField(
                controller: queryController,
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  labelText: '搜索文档项',
                  hintText: '标题 / 类型 / 预览内容',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: onClearFilters,
                          icon: const Icon(Icons.close),
                          tooltip: '清空搜索',
                        ),
                ),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 180,
              child: DropdownButtonFormField<String>(
                initialValue: kindFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '文档项类型',
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部类型')),
                  DropdownMenuItem(value: 'question', child: Text('题目项')),
                  DropdownMenuItem(
                    value: 'layout_element',
                    child: Text('排版元素'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onKindChanged(value);
                  }
                },
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                initialValue: basketFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '选题篮状态',
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
              width: compact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                initialValue: stageFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '学段',
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('全部学段'),
                  ),
                  ..._distinctValues(
                    items
                        .where((item) => item.kind == 'question')
                        .map((item) => item.stage),
                  ).map(
                    (stage) => DropdownMenuItem(
                      value: stage,
                      child: Text(
                        stage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onStageFilterChanged(value);
                  }
                },
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                initialValue: gradeFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '年级',
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('全部年级'),
                  ),
                  ..._distinctValues(
                    items
                        .where((item) => item.kind == 'question')
                        .map((item) => item.grade),
                  ).map(
                    (grade) => DropdownMenuItem(
                      value: grade,
                      child: Text(
                        grade,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
              width: compact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                initialValue: chapterFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '章节',
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('全部章节'),
                  ),
                  ..._distinctValues(
                    items
                        .where((item) => item.kind == 'question')
                        .map((item) => item.chapter),
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
                    onChapterFilterChanged(value);
                  }
                },
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                initialValue: subjectFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '学科',
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('全部学科'),
                  ),
                  ..._distinctValues(
                    items
                        .where((item) => item.kind == 'question')
                        .map((item) => item.subject),
                  ).map(
                    (subject) => DropdownMenuItem(
                      value: subject,
                      child: Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onSubjectFilterChanged(value);
                  }
                },
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                initialValue: textbookFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '教材',
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('全部教材'),
                  ),
                  ..._distinctValues(
                    items
                        .where((item) => item.kind == 'question')
                        .map((item) => item.textbook),
                  ).map(
                    (textbook) => DropdownMenuItem(
                      value: textbook,
                      child: Text(
                        textbook,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onTextbookFilterChanged(value);
                  }
                },
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                initialValue: sortBy,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '排序',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'document_order',
                    child: Text('文档顺序'),
                  ),
                  DropdownMenuItem(value: 'title', child: Text('按标题')),
                  DropdownMenuItem(value: 'kind', child: Text('按类型')),
                  DropdownMenuItem(value: 'subject', child: Text('按学科')),
                  DropdownMenuItem(value: 'stage', child: Text('按学段')),
                  DropdownMenuItem(value: 'grade', child: Text('按年级')),
                  DropdownMenuItem(value: 'textbook', child: Text('按教材')),
                  DropdownMenuItem(value: 'chapter', child: Text('按章节')),
                  DropdownMenuItem(
                    value: 'basket_first',
                    child: Text('选题篮优先'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onSortChanged(value);
                  }
                },
              ),
            ),
            TextButton.icon(
              onPressed: query.trim().isEmpty &&
                      kindFilter == 'all' &&
                      basketFilter == 'all' &&
                      subjectFilter == 'all' &&
                      stageFilter == 'all' &&
                      gradeFilter == 'all' &&
                      textbookFilter == 'all' &&
                      chapterFilter == 'all' &&
                      sortBy == 'document_order' &&
                      !showOnlySelected
                  ? null
                  : onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('清空筛选'),
            ),
            WorkspaceFilterPill(
              label: showOnlySelected ? '只看已选中' : '只看已选',
              selected: showOnlySelected,
              onTap: selectedCount == 0
                  ? null
                  : () => onShowOnlySelectedChanged(!showOnlySelected),
              icon: Icons.checklist_rtl_outlined,
            ),
          ];
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < controls.length; i++) ...[
                  controls[i],
                  if (i != controls.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: controls,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ContextChip(
                    label: '当前结果',
                    value: '${filteredItems.length} 项',
                  ),
                  _ContextChip(
                    label: '题目项',
                    value: '$filteredQuestionCount',
                  ),
                  _ContextChip(
                    label: '排版项',
                    value: '$filteredLayoutCount',
                  ),
                  _ContextChip(
                    label: '学科',
                    value: '$filteredSubjectCount',
                  ),
                  _ContextChip(
                    label: '学段',
                    value: '$filteredStageCount',
                  ),
                  _ContextChip(
                    label: '年级',
                    value: '$filteredGradeCount',
                  ),
                  _ContextChip(
                    label: '已在篮',
                    value: '$filteredInBasketQuestionCount',
                  ),
                  _ContextChip(
                    label: '未入篮',
                    value: '$filteredOutOfBasketQuestionCount',
                  ),
                ],
              ),
              if (_activeFilterEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _activeFilterEntries
                      .map(
                        (entry) => _ContextChip(
                          label: entry.$1,
                          value: entry.$2,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<String> _distinctValues(Iterable<String?> values) {
    final normalized = values
        .map((value) => (value ?? '').trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return normalized;
  }
}

class _DocumentContextCard extends StatelessWidget {
  const _DocumentContextCard({
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
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _ContextChip(label: '模式', value: modeLabel),
          _ContextChip(label: '会话', value: sessionLabel),
          _ContextChip(label: '租户', value: tenantLabel),
        ],
      ),
    );
  }
}

class _DocumentHeroCard extends StatelessWidget {
  const _DocumentHeroCard({
    required this.document,
    required this.liveQuestionCount,
    required this.liveLayoutCount,
    required this.highlightLatestExport,
  });

  final DocumentSummary document;
  final int? liveQuestionCount;
  final int? liveLayoutCount;
  final bool highlightLatestExport;

  @override
  Widget build(BuildContext context) {
    final currentQuestionCount = liveQuestionCount ?? document.questionCount;
    final currentLayoutCount = liveLayoutCount ?? document.layoutCount;
    final hasLiveCountDrift = (liveQuestionCount != null &&
            liveQuestionCount != document.questionCount) ||
        (liveLayoutCount != null && liveLayoutCount != document.layoutCount);
    final detail = highlightLatestExport
        ? '当前正在回看这份文档最近一次导出后的状态。接下来可以继续编辑内容，或重新发起导出。'
        : '当前正在编辑这份文档。接下来可以补题、整理版式，或查看最近一次导出。';

    return WorkspacePanel(
      padding: const EdgeInsets.all(24),
      borderRadius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceEyebrow(
            label: document.kind == 'paper'
                ? 'Paper Workspace'
                : 'Handout Workspace',
            icon: document.kind == 'paper'
                ? Icons.quiz_outlined
                : Icons.menu_book_outlined,
          ),
          const SizedBox(height: 16),
          Text(
            document.name,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            detail,
            style: TextStyle(
              height: 1.6,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              WorkspaceMetricPill(
                label: '文档类型',
                value: document.kind == 'paper' ? '试卷' : '讲义',
                highlight: true,
              ),
              WorkspaceMetricPill(label: '题目', value: '$currentQuestionCount'),
              WorkspaceMetricPill(label: '排版元素', value: '$currentLayoutCount'),
              WorkspaceMetricPill(
                label: '最近导出',
                value: document.latestExportStatus,
                highlight: document.latestExportStatus != 'not_started',
              ),
              WorkspaceMetricPill(
                label: '当前模式',
                value: highlightLatestExport ? '导出后回看' : '继续编辑文档',
              ),
            ],
          ),
          if (hasLiveCountDrift) ...[
            const SizedBox(height: 14),
            const Text(
              '当前统计已按页面里的最新文档项即时更新。',
              style: TextStyle(
                height: 1.5,
                color: TelegramPalette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (highlightLatestExport) ...[
            const SizedBox(height: 14),
            WorkspacePanel(
              padding: const EdgeInsets.all(14),
              backgroundColor: TelegramPalette.surfaceAccent,
              borderColor: TelegramPalette.borderAccent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.task_alt,
                    color: TelegramPalette.textStrong,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '你刚刚查看的是这份文档最近一次导出任务，当前状态：${document.latestExportStatus}。',
                      style: const TextStyle(
                        height: 1.5,
                        color: TelegramPalette.textStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return WorkspaceInfoPill(
      label: label,
      value: value,
    );
  }
}

class _DocumentErrorCard extends StatelessWidget {
  const _DocumentErrorCard({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: WorkspacePanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '文档详情暂时不可用',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  height: 1.5,
                  color: TelegramPalette.textMuted,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新加载'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateLayoutElementResult {
  const _CreateLayoutElementResult({
    required this.name,
    required this.description,
    required this.existingElements,
  });

  final String name;
  final String description;
  final List<LayoutElementSummary> existingElements;
}

class _CreateLayoutElementDialog extends StatefulWidget {
  const _CreateLayoutElementDialog({
    this.title = '新建排版元素',
    this.submitLabel = '创建并插入',
    this.initialName = '课堂提问框',
    this.initialDescription = '请学生先说出这一步为什么能列对应边比例，再继续往下推。',
  });

  final String title;
  final String submitLabel;
  final String initialName;
  final String initialDescription;

  @override
  State<_CreateLayoutElementDialog> createState() =>
      _CreateLayoutElementDialogState();
}

class _CreateLayoutElementDialogState
    extends State<_CreateLayoutElementDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _descriptionController.text = widget.initialDescription;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写排版元素名称')),
      );
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      final existing =
          await AppServices.instance.documentRepository.listLayoutElements();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        _CreateLayoutElementResult(
          name: name,
          description: description,
          existingElements: existing,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                '快速定义一个可复用的排版元素，并立即插入当前文档。',
                style: TextStyle(
                  height: 1.5,
                  color: TelegramPalette.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '元素名称',
                  hintText: '例如：课堂提问框',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '内容说明',
                  hintText: '例如：提示学生先说思路，再给出板书留白。',
                  border: OutlineInputBorder(),
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
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(_submitting ? '提交中…' : widget.submitLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayoutElementPicker extends StatefulWidget {
  const _LayoutElementPicker({required this.layoutElements});

  final List<LayoutElementSummary> layoutElements;

  @override
  State<_LayoutElementPicker> createState() => _LayoutElementPickerState();
}

class _LayoutElementPickerResult {
  const _LayoutElementPickerResult({
    required this.layoutElements,
    this.selected,
  });

  final List<LayoutElementSummary> layoutElements;
  final LayoutElementSummary? selected;
}

class _LayoutElementPickerState extends State<_LayoutElementPicker> {
  final TextEditingController _queryController = TextEditingController();
  late List<LayoutElementSummary> _layoutElements = widget.layoutElements;
  final Set<String> _removingIds = <String>{};
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<LayoutElementSummary> get _filteredLayoutElements {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return _layoutElements;
    }
    return _layoutElements.where((layoutElement) {
      return <String>[
        layoutElement.name,
        layoutElement.description,
      ].any((value) => value.toLowerCase().contains(normalizedQuery));
    }).toList(growable: false);
  }

  Future<void> _removeLayoutElement(LayoutElementSummary layoutElement) async {
    final confirmed = await showDialog<bool>(
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
                  '删除排版元素',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  '确认删除“${layoutElement.name}”？未被文档引用时才允许删除。',
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
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('删除'),
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
    if (confirmed != true) {
      return;
    }
    setState(() {
      _removingIds.add(layoutElement.id);
    });
    try {
      await AppServices.instance.documentRepository.removeLayoutElement(
        layoutElement.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _layoutElements = _layoutElements
            .where((item) => item.id != layoutElement.id)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除排版元素：${layoutElement.name}')),
      );
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除排版元素失败，请稍后再试')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _removingIds.remove(layoutElement.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLayoutElements = _filteredLayoutElements;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            '选择排版元素',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '这里可以直接选择并插入当前可复用的排版元素，例如讲义抬头、提问框和总结区。',
            style: TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _queryController,
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            decoration: InputDecoration(
              labelText: '搜索排版元素',
              hintText: '名称 / 描述',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _queryController.clear();
                        setState(() {
                          _query = '';
                        });
                      },
                      icon: const Icon(Icons.close),
                      tooltip: '清空搜索',
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (filteredLayoutElements.isEmpty)
            WorkspacePanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前搜索条件下没有匹配的排版元素。',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: TelegramPalette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '可以调整关键词，或清空搜索后查看全部排版元素。',
                    style: TextStyle(
                      height: 1.5,
                      color: TelegramPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      _queryController.clear();
                      setState(() {
                        _query = '';
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('清空搜索'),
                  ),
                ],
              ),
            ),
          ...filteredLayoutElements.map(
            (layoutElement) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WorkspacePanel(
                padding: EdgeInsets.zero,
                borderRadius: 12,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    layoutElement.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          layoutElement.description,
                          style: const TextStyle(height: 1.5),
                        ),
                        if (layoutElement.previewBlocks.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ContentSection(
                            title: '内容预览',
                            blocks: layoutElement.previewBlocks,
                            fallbackText: layoutElement.description,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: SizedBox(
                    width: 112,
                    child: _removingIds.contains(layoutElement.id)
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.tonal(
                                onPressed: () => Navigator.of(context).pop(
                                  _LayoutElementPickerResult(
                                    selected: layoutElement,
                                    layoutElements: _layoutElements,
                                  ),
                                ),
                                child: const Text('插入'),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _removeLayoutElement(layoutElement),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: '删除排版元素',
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentItemCard extends StatelessWidget {
  const _DocumentItemCard({
    required this.item,
    required this.isSelected,
    required this.isInBasket,
    required this.busy,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.highlighted,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.onSelectionChanged,
    this.onOpenSourceQuestion,
    this.onAddToBasket,
    this.onRemoveFromBasket,
    this.onDuplicate,
    this.onEditLayout,
  });

  final DocumentItemSummary item;
  final bool isSelected;
  final bool isInBasket;
  final bool busy;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool highlighted;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback? onOpenSourceQuestion;
  final VoidCallback? onAddToBasket;
  final VoidCallback? onRemoveFromBasket;
  final VoidCallback? onDuplicate;
  final VoidCallback? onEditLayout;

  @override
  Widget build(BuildContext context) {
    final isQuestion = item.kind == 'question';
    return WorkspacePanel(
      backgroundColor: highlighted
          ? TelegramPalette.highlight
          : TelegramPalette.surfaceRaised,
      borderColor: highlighted
          ? TelegramPalette.highlightBorder
          : TelegramPalette.border,
      borderRadius: 12,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (selected) {
              onSelectionChanged(selected ?? false);
            },
          ),
          const SizedBox(width: 4),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isQuestion
                  ? TelegramPalette.surfaceAccent
                  : TelegramPalette.warningSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isQuestion ? Icons.quiz_outlined : Icons.view_agenda_outlined,
              color: TelegramPalette.accentDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.detail,
                  style: const TextStyle(color: TelegramPalette.textSoft),
                ),
                if (isQuestion && isInBasket) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: TelegramPalette.surfaceAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '已在选题篮',
                      style: TextStyle(
                        color: TelegramPalette.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (highlighted) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '刚加入的文档项',
                    style: TextStyle(
                      color: TelegramPalette.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (item.previewBlocks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ContentSection(
                    title: isQuestion ? '题目片段' : '排版片段',
                    blocks: item.previewBlocks,
                    fallbackText: item.detail,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      IconButton(
                        onPressed: canMoveUp ? onMoveUp : null,
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      IconButton(
                        onPressed: canMoveDown ? onMoveDown : null,
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                      if (onDuplicate != null)
                        IconButton(
                          onPressed: onDuplicate,
                          icon: const Icon(Icons.copy_all_outlined),
                        ),
                      if (onAddToBasket != null)
                        IconButton(
                          onPressed: onAddToBasket,
                          icon: const Icon(Icons.playlist_add_outlined),
                        ),
                      if (onRemoveFromBasket != null)
                        IconButton(
                          onPressed: onRemoveFromBasket,
                          icon: const Icon(Icons.playlist_remove_outlined),
                        ),
                      if (onEditLayout != null)
                        IconButton(
                          onPressed: onEditLayout,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      if (onOpenSourceQuestion != null)
                        IconButton(
                          onPressed: onOpenSourceQuestion,
                          icon: const Icon(Icons.open_in_new),
                        ),
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
