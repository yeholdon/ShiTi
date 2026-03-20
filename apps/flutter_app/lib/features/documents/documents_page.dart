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
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/primary_page_scroll_memory.dart';
import '../shared/primary_page_view_state_memory.dart';
import '../shared/primary_navigation_bar.dart';
import '../shared/workspace_shell.dart';
import 'create_document_dialog.dart';
import 'document_summary_preview.dart';
import 'rename_document_dialog.dart';
import 'select_document_dialog.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({
    super.key,
    this.args,
  });

  final DocumentsPageArgs? args;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  static const _pageKey = 'documents';
  final TextEditingController _queryController = TextEditingController();
  List<DocumentSummary> _documents = const <DocumentSummary>[];
  Object? _loadError;
  bool _loading = true;
  String? _exportingDocumentId;
  Set<String> _selectedDocumentIds = <String>{};
  bool _exportingSelected = false;
  bool _duplicatingSelected = false;
  bool _mergingSelected = false;
  bool _addingSelectedToDocument = false;
  bool _removingSelected = false;
  bool _showOnlySelectedDocuments = false;
  late final ScrollController _scrollController = ScrollController(
    initialScrollOffset:
        _hasContextualReturn ? 0 : PrimaryPageScrollMemory.offsetFor(_pageKey),
  );
  final Map<String, GlobalKey> _documentKeys = <String, GlobalKey>{};
  String? _focusedDocumentId;
  String? _lastScrolledDocumentId;
  String? _flashMessage;
  String? _highlightTitle;
  String? _highlightDetail;
  int? _recentlyAddedQuestionCount;
  String? _feedbackBadgeLabel;
  String _query = '';
  String _kindFilter = 'all';
  String _exportStatusFilter = 'all';
  String _sortBy = 'workspace';
  bool get _hasContextualReturn =>
      widget.args?.focusDocumentId != null ||
      widget.args?.documentSnapshot != null ||
      (widget.args?.flashMessage?.trim().isNotEmpty ?? false) ||
      (widget.args?.highlightTitle?.trim().isNotEmpty ?? false) ||
      (widget.args?.highlightDetail?.trim().isNotEmpty ?? false) ||
      widget.args?.recentlyAddedQuestionCount != null ||
      (widget.args?.feedbackBadgeLabel?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_rememberScrollOffset);
    final savedViewState = PrimaryPageViewStateMemory.documents;
    if (!_hasContextualReturn && savedViewState != null) {
      _query = savedViewState.query;
      _kindFilter = savedViewState.kindFilter;
      _exportStatusFilter = savedViewState.exportStatusFilter;
      _sortBy = savedViewState.sortBy;
      _showOnlySelectedDocuments = savedViewState.showOnlySelectedDocuments;
      _queryController.text = savedViewState.query;
    }
    _focusedDocumentId = widget.args?.focusDocumentId;
    _flashMessage = widget.args?.flashMessage;
    _highlightTitle = widget.args?.highlightTitle;
    _highlightDetail = widget.args?.highlightDetail;
    _recentlyAddedQuestionCount = widget.args?.recentlyAddedQuestionCount;
    _feedbackBadgeLabel = widget.args?.feedbackBadgeLabel;
    final seededDocument = widget.args?.documentSnapshot;
    if (seededDocument != null) {
      _documents = <DocumentSummary>[seededDocument];
      _loading = false;
    }
    _reload(preserveExisting: true);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _rememberScrollOffset() {
    PrimaryPageScrollMemory.update(_pageKey, _scrollController.offset);
  }

  void _rememberViewState() {
    PrimaryPageViewStateMemory.documents = PrimaryDocumentsViewState(
      query: _query,
      kindFilter: _kindFilter,
      exportStatusFilter: _exportStatusFilter,
      sortBy: _sortBy,
      showOnlySelectedDocuments: _showOnlySelectedDocuments,
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

  List<DocumentSummary> _applyFilters(List<DocumentSummary> documents) {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = documents.where((document) {
      if (_showOnlySelectedDocuments &&
          !_selectedDocumentIds.contains(document.id)) {
        return false;
      }
      if (_kindFilter != 'all' && document.kind != _kindFilter) {
        return false;
      }
      if (_exportStatusFilter != 'all' &&
          document.latestExportStatus != _exportStatusFilter) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return <String>[
        document.name,
        document.kind,
        document.latestExportStatus,
      ].any((value) => value.toLowerCase().contains(normalizedQuery));
    }).toList(growable: false);
    return _applySort(filtered);
  }

  List<DocumentSummary> _applySort(List<DocumentSummary> documents) {
    final sorted = documents.toList(growable: true);
    switch (_sortBy) {
      case 'name':
        sorted.sort(
          (left, right) => left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              ),
        );
        break;
      case 'questions':
        sorted.sort((left, right) {
          final compare = right.questionCount.compareTo(left.questionCount);
          if (compare != 0) {
            return compare;
          }
          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        });
        break;
      case 'layouts':
        sorted.sort((left, right) {
          final compare = right.layoutCount.compareTo(left.layoutCount);
          if (compare != 0) {
            return compare;
          }
          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        });
        break;
      case 'export_status':
        sorted.sort((left, right) {
          final compare = _exportStatusRank(left.latestExportStatus).compareTo(
            _exportStatusRank(right.latestExportStatus),
          );
          if (compare != 0) {
            return compare;
          }
          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        });
        break;
      case 'workspace':
      default:
        break;
    }
    return sorted;
  }

  int _exportStatusRank(String status) {
    switch (status) {
      case 'failed':
        return 0;
      case 'running':
        return 1;
      case 'pending':
        return 2;
      case 'not_started':
        return 3;
      case 'canceled':
        return 4;
      case 'succeeded':
        return 5;
      default:
        return 6;
    }
  }

  void _clearFilters() {
    _queryController.clear();
    setState(() {
      _query = '';
      _kindFilter = 'all';
      _exportStatusFilter = 'all';
      _sortBy = 'workspace';
      _showOnlySelectedDocuments = false;
    });
    _rememberViewState();
  }

  Future<void> _reload({bool preserveExisting = false}) async {
    setState(() {
      _loading = !preserveExisting || _documents.isEmpty;
      _loadError = null;
    });
    try {
      final documents =
          await AppServices.instance.documentRepository.listDocuments();
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = documents;
        _selectedDocumentIds = _selectedDocumentIds
            .where((id) => documents.any((document) => document.id == id))
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

  void _upsertDocument(DocumentSummary document, {bool prepend = false}) {
    final index = _documents.indexWhere((entry) => entry.id == document.id);
    if (index >= 0) {
      _documents = <DocumentSummary>[
        ..._documents.take(index),
        document,
        ..._documents.skip(index + 1),
      ];
      return;
    }
    if (prepend) {
      _documents = <DocumentSummary>[document, ..._documents];
      return;
    }
    _documents = <DocumentSummary>[..._documents, document];
  }

  void _setSelection(String documentId, bool selected) {
    setState(() {
      if (selected) {
        _selectedDocumentIds.add(documentId);
      } else {
        _selectedDocumentIds.remove(documentId);
      }
    });
  }

  void _selectAllFiltered(List<DocumentSummary> filteredDocuments) {
    setState(() {
      _selectedDocumentIds =
          filteredDocuments.map((document) => document.id).toSet();
    });
  }

  void _selectFilteredDocumentsByKind(
    List<DocumentSummary> filteredDocuments,
    String kind,
  ) {
    setState(() {
      _selectedDocumentIds = filteredDocuments
          .where((document) => document.kind == kind)
          .map((document) => document.id)
          .toSet();
    });
  }

  void _selectFilteredDocumentsByExportStatus(
    List<DocumentSummary> filteredDocuments,
    String exportStatus,
  ) {
    setState(() {
      _selectedDocumentIds = filteredDocuments
          .where((document) {
            if (exportStatus == 'in_progress') {
              return document.latestExportStatus == 'pending' ||
                  document.latestExportStatus == 'running';
            }
            return document.latestExportStatus == exportStatus;
          })
          .map((document) => document.id)
          .toSet();
    });
  }

  void _invertFilteredSelection(List<DocumentSummary> filteredDocuments) {
    setState(() {
      final nextSelection = <String>{..._selectedDocumentIds};
      for (final document in filteredDocuments) {
        if (nextSelection.contains(document.id)) {
          nextSelection.remove(document.id);
        } else {
          nextSelection.add(document.id);
        }
      }
      _selectedDocumentIds = nextSelection;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedDocumentIds.clear();
    });
  }

  Future<void> _refreshDocumentById(String documentId) async {
    try {
      final refreshed =
          await AppServices.instance.documentRepository.getDocument(documentId);
      if (!mounted) {
        return;
      }
      setState(() {
        if (refreshed == null) {
          _documents = _documents
              .where((document) => document.id != documentId)
              .toList(growable: false);
          if (_focusedDocumentId == documentId) {
            _focusedDocumentId = null;
            _lastScrolledDocumentId = null;
            _highlightTitle = '刚删除的文档已同步移除';
            _highlightDetail = '这份文档已从工作区列表中移除，你可以继续新建文档或编辑其他文档。';
            _feedbackBadgeLabel = '删除已同步';
            _flashMessage = '文档已删除，工作区已同步移除该卡片。';
            _recentlyAddedQuestionCount = null;
          }
          return;
        }
        _upsertDocument(refreshed, prepend: true);
      });
    } catch (_) {
      await _reload(preserveExisting: true);
    }
  }

  void _setWorkspaceFeedback({
    required String documentId,
    DocumentSummary? documentSnapshot,
    String? flashMessage,
    String? highlightTitle,
    String? highlightDetail,
    String? feedbackBadgeLabel,
  }) {
    setState(() {
      if (documentSnapshot != null) {
        _upsertDocument(documentSnapshot, prepend: true);
      }
      _focusedDocumentId = documentId;
      _lastScrolledDocumentId = null;
      _flashMessage = flashMessage;
      _highlightTitle = highlightTitle;
      _highlightDetail = highlightDetail;
      _feedbackBadgeLabel = feedbackBadgeLabel;
    });
  }

  GlobalKey _keyForDocument(String documentId) {
    return _documentKeys.putIfAbsent(documentId, GlobalKey.new);
  }

  void _scheduleFocusedDocumentScroll(List<DocumentSummary> documents) {
    if (_focusedDocumentId == null ||
        _lastScrolledDocumentId == _focusedDocumentId) {
      return;
    }
    final targetIndex =
        documents.indexWhere((document) => document.id == _focusedDocumentId);
    if (targetIndex == -1) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusedDocumentId == null) {
        return;
      }
      final targetContext = _keyForDocument(_focusedDocumentId!).currentContext;
      _lastScrolledDocumentId = _focusedDocumentId;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.14,
        );
        return;
      }
      if (!_scrollController.hasClients) {
        return;
      }
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      if (maxScrollExtent <= 0) {
        return;
      }
      final ratio =
          documents.length <= 1 ? 0.0 : targetIndex / (documents.length - 1);
      final targetOffset = (maxScrollExtent * ratio).clamp(
        0.0,
        maxScrollExtent,
      );
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openDocumentDetail(DocumentSummary document) async {
    final result = await Navigator.of(context).pushNamed(
      AppRouter.documentDetail,
      arguments: DocumentDetailArgs(
        documentId: document.id,
        documentSnapshot: document,
      ),
    );
    if (!mounted) {
      return;
    }
    final returnedSnapshot = result is DocumentSummary ? result : document;
    _setWorkspaceFeedback(
      documentId: document.id,
      documentSnapshot: returnedSnapshot,
      flashMessage: '已同步最近一次编辑后的文档状态。',
      highlightTitle: '刚刚编辑过的文档',
      highlightDetail: '这份文档刚从详情页返回，卡片统计和最近导出状态已按最新结果刷新。',
      feedbackBadgeLabel: '编辑已同步',
    );
    if (result is! DocumentSummary) {
      await _refreshDocumentById(document.id);
    }
    if (!mounted) {
      return;
    }
  }

  Future<void> _openExports(DocumentSummary document) async {
    final result = await Navigator.of(context).pushNamed(
      AppRouter.exports,
      arguments: ExportsPageArgs(
        focusDocumentName: document.name,
        focusJobId: document.latestExportJobId,
        documentSnapshot: document,
      ),
    );
    if (!mounted) {
      return;
    }
    final returnedSnapshot = result is DocumentSummary ? result : document;
    _setWorkspaceFeedback(
      documentId: document.id,
      documentSnapshot: returnedSnapshot,
      flashMessage: '已同步最近一次导出相关状态。',
      highlightTitle: '刚刚查看过导出的文档',
      highlightDetail: '这份文档刚从导出页返回，最近导出状态已按最新任务结果刷新。',
      feedbackBadgeLabel: '导出状态已同步',
    );
  }

  Future<void> _openLibraryForDocument(DocumentSummary document) async {
    await Navigator.of(context).pushNamed(
      AppRouter.library,
      arguments: LibraryPageArgs(
        preferredDocumentSnapshot: document,
      ),
    );
    if (!mounted) {
      return;
    }
    _setWorkspaceFeedback(
      documentId: document.id,
      documentSnapshot: document,
      flashMessage: '已从题库返回，可继续为这份文档加题或编排。',
      highlightTitle: '刚刚从题库返回的文档',
      highlightDetail: '题库页现在会默认把所选题目落回这份文档，你可以继续挑题或直接进入详情页查看结果。',
      feedbackBadgeLabel: '题库上下文已保留',
    );
    await _refreshDocumentById(document.id);
  }

  Future<void> _openBasketForDocument(DocumentSummary document) async {
    await Navigator.of(context).pushNamed(
      AppRouter.basket,
      arguments: QuestionBasketPageArgs(
        preferredDocumentSnapshot: document,
      ),
    );
    if (!mounted) {
      return;
    }
    _setWorkspaceFeedback(
      documentId: document.id,
      documentSnapshot: document,
      flashMessage: '已从选题篮返回，可继续为这份文档加题或编排。',
      highlightTitle: '刚刚从选题篮返回的文档',
      highlightDetail: '选题篮页现在会默认把所选题目落回这份文档，你可以继续处理子集题目或进入详情页查看结果。',
      feedbackBadgeLabel: '选题篮上下文已保留',
    );
    await _refreshDocumentById(document.id);
  }

  ExportJobSummary _latestJobSummary(DocumentSummary document) {
    return ExportJobSummary(
      id: document.latestExportJobId ?? '',
      documentName: document.name,
      format: 'pdf',
      status: document.latestExportStatus,
      updatedAtLabel: '最近一次',
      documentId: document.id,
    );
  }

  Future<void> _openLatestExportDetail(DocumentSummary document) async {
    if (document.latestExportJobId == null ||
        document.latestExportJobId!.isEmpty) {
      return;
    }
    final result = await Navigator.of(context).pushNamed(
      AppRouter.exportDetail,
      arguments: ExportDetailArgs(
        job: _latestJobSummary(document),
        documentSnapshot: document,
      ),
    );
    if (!mounted) {
      return;
    }
    final returnedSnapshot = result is DocumentSummary ? result : document;
    _setWorkspaceFeedback(
      documentId: document.id,
      documentSnapshot: returnedSnapshot,
      flashMessage: '已同步最近一次导出详情状态。',
      highlightTitle: '刚刚查看过最近导出详情',
      highlightDetail: '这份文档刚从最近一次导出详情返回，当前导出状态已按最新结果刷新。',
      feedbackBadgeLabel: '导出详情已同步',
    );
  }

  Future<void> _openLatestExportResult(DocumentSummary document) async {
    if (document.latestExportJobId == null ||
        document.latestExportJobId!.isEmpty) {
      return;
    }
    final result = await Navigator.of(context).pushNamed(
      AppRouter.exportResult,
      arguments: ExportDetailArgs(
        job: _latestJobSummary(document),
        documentSnapshot: document,
      ),
    );
    if (!mounted) {
      return;
    }
    final returnedSnapshot = result is DocumentSummary ? result : document;
    _setWorkspaceFeedback(
      documentId: document.id,
      documentSnapshot: returnedSnapshot,
      flashMessage: '已同步最近一次导出结果相关状态。',
      highlightTitle: '刚刚查看过最近导出结果',
      highlightDetail: '这份文档刚从导出结果页返回，当前导出状态已按最新结果刷新。',
      feedbackBadgeLabel: '导出结果已同步',
    );
  }

  Future<void> _exportDocument(DocumentSummary document) async {
    setState(() {
      _exportingDocumentId = document.id;
    });
    try {
      final job = await AppServices.instance.documentRepository.createExportJob(
        documentId: document.id,
      );
      if (!mounted) {
        return;
      }
      final pendingDocument = document.copyWith(
        latestExportStatus: job.status,
        latestExportJobId: job.id,
      );
      _setWorkspaceFeedback(
        documentId: document.id,
        documentSnapshot: pendingDocument,
        flashMessage: '已创建导出任务并定位到导出记录。',
        highlightTitle: '刚刚发起导出的文档',
        highlightDetail: '这份文档已经进入导出队列，可以继续查看任务进度或结果。',
        feedbackBadgeLabel: '导出已发起',
      );
      final result = await Navigator.of(context).pushNamed(
        AppRouter.exports,
        arguments: ExportsPageArgs(
          focusDocumentName: pendingDocument.name,
          focusJobId: job.id,
          documentSnapshot: pendingDocument,
        ),
      );
      if (!mounted) {
        return;
      }
      final returnedSnapshot =
          result is DocumentSummary ? result : pendingDocument;
      _setWorkspaceFeedback(
        documentId: document.id,
        documentSnapshot: returnedSnapshot,
        flashMessage: '已同步最近一次导出相关状态。',
        highlightTitle: '刚刚查看过导出的文档',
        highlightDetail: '这份文档刚从导出页返回，最近导出状态已按最新任务结果刷新。',
        feedbackBadgeLabel: '导出状态已同步',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '发起导出失败：${error.message}（HTTP ${error.statusCode}）'
          : '发起导出失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingDocumentId = null;
        });
      }
    }
  }

  Future<void> _createDocument() async {
    final created = await showCreateDocumentDialog(context);
    if (created == null || !mounted) {
      return;
    }
    setState(() {
      _upsertDocument(created, prepend: true);
      _focusedDocumentId = created.id;
      _lastScrolledDocumentId = null;
      _flashMessage = '新文档已创建并定位到工作区。';
      _highlightTitle = '刚创建的文档';
      _highlightDetail = '这份文档已经加入工作区，可以继续编排、加题或发起导出。';
      _feedbackBadgeLabel = '新建文档';
    });
    await _openDocumentDetail(created);
  }

  Future<void> _renameDocument(DocumentSummary document) async {
    final nextName = await showRenameDocumentDialog(
      context,
      initialName: document.name,
    );
    if (nextName == null ||
        nextName.trim() == document.name.trim() ||
        !mounted) {
      return;
    }

    try {
      final renamed =
          await AppServices.instance.documentRepository.renameDocument(
        documentId: document.id,
        name: nextName.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _upsertDocument(renamed, prepend: true);
        _focusedDocumentId = renamed.id;
        _lastScrolledDocumentId = null;
        _flashMessage = '文档名称已更新。';
        _highlightTitle = '刚重命名的文档';
        _highlightDetail = '文档工作区已经同步最新名称，可以继续编排或导出。';
        _feedbackBadgeLabel = '名称已同步';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '重命名失败：${error.message}（HTTP ${error.statusCode}）'
          : '重命名失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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

    try {
      final (copiedCount, lastCreatedItem) = await _copyDocumentContents(
        sourceDocumentId: document.id,
        targetDocumentId: targetDocument.id,
      );
      if (!mounted) {
        return;
      }
      _setWorkspaceFeedback(
        documentId: targetDocument.id,
        documentSnapshot: targetDocument,
        flashMessage: copiedCount == 0 ? '已创建空副本，你可以继续补内容。' : '已创建文档副本并定位到新文档。',
        highlightTitle: '刚复制出的文档',
        highlightDetail: copiedCount == 0
            ? '原文档当前没有可复制的内容，这份新文档已经加入工作区。'
            : '这份文档已经承接了原文档的内容，可以继续编排、加题或导出。',
        feedbackBadgeLabel: '文档复制已完成',
      );
      await Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: targetDocument.id,
          focusItemId: lastCreatedItem?.id,
          focusItemTitle: lastCreatedItem?.title,
        ),
      );
      if (!mounted) {
        return;
      }
      await _refreshDocumentById(targetDocument.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '复制文档失败：${error.message}（HTTP ${error.statusCode}）'
          : '复制文档失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<(int copiedCount, DocumentItemSummary? lastCreatedItem)>
      _copyDocumentContents({
    required String sourceDocumentId,
    required String targetDocumentId,
  }) async {
    final items = await AppServices.instance.documentRepository
        .listDocumentItems(sourceDocumentId);
    final layoutElements =
        await AppServices.instance.documentRepository.listLayoutElements();
    DocumentItemSummary? lastCreatedItem;
    var copiedCount = 0;
    for (final item in items) {
      final createdItem = await _copyDocumentItemToDocument(
        item: item,
        targetDocumentId: targetDocumentId,
        layoutElements: layoutElements,
      );
      if (createdItem != null) {
        copiedCount += 1;
        lastCreatedItem = createdItem;
      }
    }
    return (copiedCount, lastCreatedItem);
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

    try {
      await AppServices.instance.documentRepository.removeDocument(document.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = _documents
            .where((entry) => entry.id != document.id)
            .toList(growable: false);
        _selectedDocumentIds.remove(document.id);
        _focusedDocumentId = null;
        _lastScrolledDocumentId = null;
        _flashMessage = '文档已删除，工作区已同步移除该卡片。';
        _highlightTitle = '刚删除的文档已同步移除';
        _highlightDetail = '这份文档已从工作区列表中移除，你可以继续新建文档或编辑其他文档。';
        _feedbackBadgeLabel = '删除已同步';
        _recentlyAddedQuestionCount = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '删除文档失败：${error.message}（HTTP ${error.statusCode}）'
          : '删除文档失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _exportSelectedDocuments(
      List<DocumentSummary> filteredDocuments) async {
    final selectedDocuments = filteredDocuments
        .where((document) => _selectedDocumentIds.contains(document.id))
        .toList(growable: false);
    if (selectedDocuments.isEmpty || _exportingSelected) {
      return;
    }
    setState(() {
      _exportingSelected = true;
    });
    try {
      ExportJobSummary? latestJob;
      final updatedDocuments = <DocumentSummary>[];
      for (final document in selectedDocuments) {
        final job =
            await AppServices.instance.documentRepository.createExportJob(
          documentId: document.id,
        );
        latestJob = job;
        updatedDocuments.add(
          document.copyWith(
            latestExportStatus: job.status,
            latestExportJobId: job.id,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        for (final document in updatedDocuments) {
          _upsertDocument(document, prepend: false);
        }
        _selectedDocumentIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已发起 ${selectedDocuments.length} 份文档的导出任务')),
      );
      if (latestJob != null) {
        final latestDocument = updatedDocuments.isNotEmpty
            ? updatedDocuments.last
            : selectedDocuments.last;
        final result = await Navigator.of(context).pushNamed(
          AppRouter.exports,
          arguments: ExportsPageArgs(
            focusDocumentName: latestDocument.name,
            focusJobId: latestJob.id,
            documentSnapshot: latestDocument,
          ),
        );
        if (!mounted) {
          return;
        }
        if (result is DocumentSummary) {
          _setWorkspaceFeedback(
            documentId: result.id,
            documentSnapshot: result,
            flashMessage: '已同步批量导出后的最新状态。',
            highlightTitle: '刚发起批量导出的文档',
            highlightDetail: '文档工作区已同步最近一次批量导出任务结果。',
            feedbackBadgeLabel: '批量导出已同步',
          );
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '批量发起导出失败：${error.message}（HTTP ${error.statusCode}）'
          : '批量发起导出失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingSelected = false;
        });
      }
    }
  }

  Future<void> _removeSelectedDocuments(
      List<DocumentSummary> filteredDocuments) async {
    final selectedDocuments = filteredDocuments
        .where((document) => _selectedDocumentIds.contains(document.id))
        .toList(growable: false);
    if (selectedDocuments.isEmpty || _removingSelected) {
      return;
    }
    final confirmed = await _showConfirmDialog(
      title: '批量删除文档',
      message: '确定删除当前选中的 ${selectedDocuments.length} 份文档吗？这些文档会从工作区列表中移除。',
      confirmLabel: '删除',
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _removingSelected = true;
    });
    try {
      for (final document in selectedDocuments) {
        await AppServices.instance.documentRepository
            .removeDocument(document.id);
      }
      if (!mounted) {
        return;
      }
      final removedIds =
          selectedDocuments.map((document) => document.id).toSet();
      setState(() {
        _documents = _documents
            .where((document) => !removedIds.contains(document.id))
            .toList(growable: false);
        _selectedDocumentIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 ${selectedDocuments.length} 份文档')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '批量删除文档失败：${error.message}（HTTP ${error.statusCode}）'
          : '批量删除文档失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _removingSelected = false;
        });
      }
    }
  }

  Future<void> _duplicateSelectedDocuments(
    List<DocumentSummary> filteredDocuments,
  ) async {
    final selectedDocuments = filteredDocuments
        .where((document) => _selectedDocumentIds.contains(document.id))
        .toList(growable: false);
    if (selectedDocuments.isEmpty || _duplicatingSelected) {
      return;
    }

    setState(() {
      _duplicatingSelected = true;
    });
    try {
      final createdDocuments = <DocumentSummary>[];
      for (final document in selectedDocuments) {
        final targetDocument =
            await AppServices.instance.documentRepository.createDocument(
          name: '${document.name} 副本',
          kind: document.kind,
        );
        await _copyDocumentContents(
          sourceDocumentId: document.id,
          targetDocumentId: targetDocument.id,
        );
        createdDocuments.add(targetDocument);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        for (final document in createdDocuments.reversed) {
          _upsertDocument(document, prepend: true);
        }
        _selectedDocumentIds =
            createdDocuments.map((document) => document.id).toSet();
        _focusedDocumentId =
            createdDocuments.isEmpty ? null : createdDocuments.first.id;
        _lastScrolledDocumentId = null;
        _flashMessage = '已批量创建 ${createdDocuments.length} 份文档副本。';
        _highlightTitle = '刚复制出的文档';
        _highlightDetail = '这些副本已经加入工作区，可以继续编排、合并或导出。';
        _feedbackBadgeLabel = '批量复制已完成';
        _recentlyAddedQuestionCount = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已复制 ${createdDocuments.length} 份文档')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '批量复制文档失败：${error.message}（HTTP ${error.statusCode}）'
          : '批量复制文档失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _duplicatingSelected = false;
        });
      }
    }
  }

  Future<DocumentItemSummary?> _copyDocumentItemToDocument({
    required DocumentItemSummary item,
    required String targetDocumentId,
    required List<LayoutElementSummary> layoutElements,
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

  Future<void> _mergeSelectedDocumentsIntoNewDocument(
    List<DocumentSummary> filteredDocuments,
  ) async {
    final selectedDocuments = filteredDocuments
        .where((document) => _selectedDocumentIds.contains(document.id))
        .toList(growable: false);
    if (selectedDocuments.isEmpty || _mergingSelected) {
      return;
    }

    final removeAfterMerge = await _pickSelectedDocumentsMergeMode(
      selectedDocuments.length,
    );
    if (removeAfterMerge == null || !mounted) {
      return;
    }

    final targetDocument = await showCreateDocumentDialog(
      context,
      initialName: selectedDocuments.length == 1
          ? '${selectedDocuments.first.name} 合并稿'
          : '${selectedDocuments.first.name} 等合并稿',
      initialKind: selectedDocuments.first.kind,
      title: '合并为新文档',
    );
    if (targetDocument == null || !mounted) {
      return;
    }

    setState(() {
      _mergingSelected = true;
    });
    try {
      final layoutElements =
          await AppServices.instance.documentRepository.listLayoutElements();
      var copiedCount = 0;
      DocumentItemSummary? lastCreatedItem;
      final mergedSourceDocumentIds = <String>{};
      for (final document in selectedDocuments) {
        var documentCopiedAny = false;
        final items = await AppServices.instance.documentRepository
            .listDocumentItems(document.id);
        for (final item in items) {
          final createdItem = await _copyDocumentItemToDocument(
            item: item,
            targetDocumentId: targetDocument.id,
            layoutElements: layoutElements,
          );
          if (createdItem != null) {
            copiedCount += 1;
            lastCreatedItem = createdItem;
            documentCopiedAny = true;
          }
        }
        if (documentCopiedAny) {
          mergedSourceDocumentIds.add(document.id);
        }
      }
      if (!mounted) {
        return;
      }
      if (copiedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已选文档没有可合并到新文档的内容')),
        );
        return;
      }
      if (removeAfterMerge) {
        for (final document in selectedDocuments) {
          if (!mergedSourceDocumentIds.contains(document.id)) {
            continue;
          }
          await AppServices.instance.documentRepository
              .removeDocument(document.id);
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (removeAfterMerge) {
          _documents = _documents
              .where(
                  (document) => !mergedSourceDocumentIds.contains(document.id))
              .toList(growable: false);
        }
        _selectedDocumentIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removeAfterMerge
                ? '已将 ${selectedDocuments.length} 份文档合并到新文档，并移出源文档：${targetDocument.name}'
                : '已将 ${selectedDocuments.length} 份文档合并到新文档：${targetDocument.name}',
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
      if (!mounted) {
        return;
      }
      _setWorkspaceFeedback(
        documentId: targetDocument.id,
        documentSnapshot: targetDocument,
        flashMessage: '已完成文档合并并定位到新文档。',
        highlightTitle: '刚合并出的新文档',
        highlightDetail: '这份文档已经承接了所选文档的内容，可以继续编排、加题或导出。',
        feedbackBadgeLabel: '文档合并已完成',
      );
      await _refreshDocumentById(targetDocument.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '合并文档失败：${error.message}（HTTP ${error.statusCode}）'
          : '合并文档失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _mergingSelected = false;
        });
      }
    }
  }

  Future<void> _addSelectedDocumentsToDocument(
    List<DocumentSummary> filteredDocuments,
  ) async {
    final selectedDocuments = filteredDocuments
        .where((document) => _selectedDocumentIds.contains(document.id))
        .toList(growable: false);
    if (selectedDocuments.isEmpty || _addingSelectedToDocument) {
      return;
    }

    final removeAfterMerge = await _pickSelectedDocumentsMergeMode(
      selectedDocuments.length,
    );
    if (removeAfterMerge == null || !mounted) {
      return;
    }

    final targetDocument = await pickTargetDocument(
      context,
      excludedDocumentIds:
          selectedDocuments.map((document) => document.id).toSet(),
    );
    if (targetDocument == null || !mounted) {
      return;
    }

    setState(() {
      _addingSelectedToDocument = true;
    });
    try {
      final layoutElements =
          await AppServices.instance.documentRepository.listLayoutElements();
      var copiedCount = 0;
      DocumentItemSummary? lastCreatedItem;
      final mergedSourceDocumentIds = <String>{};
      for (final document in selectedDocuments) {
        var documentCopiedAny = false;
        final items = await AppServices.instance.documentRepository
            .listDocumentItems(document.id);
        for (final item in items) {
          final createdItem = await _copyDocumentItemToDocument(
            item: item,
            targetDocumentId: targetDocument.id,
            layoutElements: layoutElements,
          );
          if (createdItem != null) {
            copiedCount += 1;
            lastCreatedItem = createdItem;
            documentCopiedAny = true;
          }
        }
        if (documentCopiedAny) {
          mergedSourceDocumentIds.add(document.id);
        }
      }
      if (!mounted) {
        return;
      }
      if (copiedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已选文档没有可合并到目标文档的内容')),
        );
        return;
      }
      if (removeAfterMerge) {
        for (final document in selectedDocuments) {
          if (!mergedSourceDocumentIds.contains(document.id)) {
            continue;
          }
          await AppServices.instance.documentRepository
              .removeDocument(document.id);
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (removeAfterMerge) {
          _documents = _documents
              .where(
                  (document) => !mergedSourceDocumentIds.contains(document.id))
              .toList(growable: false);
        }
        _selectedDocumentIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removeAfterMerge
                ? '已将 ${selectedDocuments.length} 份文档合并到目标文档，并移出源文档：${targetDocument.name}'
                : '已将 ${selectedDocuments.length} 份文档合并到目标文档：${targetDocument.name}',
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
      if (!mounted) {
        return;
      }
      _setWorkspaceFeedback(
        documentId: targetDocument.id,
        documentSnapshot: targetDocument,
        flashMessage: '已完成文档合并并定位到目标文档。',
        highlightTitle: '刚承接合并内容的文档',
        highlightDetail: '这份文档已经承接了所选文档的内容，可以继续编排、加题或导出。',
        feedbackBadgeLabel: '合并到文档已完成',
      );
      await _refreshDocumentById(targetDocument.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '合并到目标文档失败：${error.message}（HTTP ${error.statusCode}）'
          : '合并到目标文档失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingSelectedToDocument = false;
        });
      }
    }
  }

  Future<bool?> _pickSelectedDocumentsMergeMode(int documentCount) {
    final documentLabel =
        documentCount == 1 ? '这份文档' : '当前选中的 $documentCount 份文档';
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
                  '批量合并文档',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  '即将把$documentLabel的内容合并到目标文档。合并完成后，是否同时把这些源文档从工作区移出？',
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
                        child: const Text('复制合并'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('合并并移出'),
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

  void _openWorkspace() {
    PrimaryNavigationBar.navigateToSection(context, PrimaryAppSection.home);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final wideDesktop = MediaQuery.sizeOf(context).width >= 1280;
    final filteredDocuments = _applyFilters(_documents);
    return Scaffold(
      appBar: AppBar(title: const Text('讲义与试卷')),
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: workspaceConstrainedContent(
            context,
            child: ListView(
              controller: _scrollController,
              padding: workspacePagePadding(context),
              children: [
                if (_flashMessage != null &&
                    _flashMessage!.trim().isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: EdgeInsets.all(compact ? 14 : 16),
                    decoration: BoxDecoration(
                      color: TelegramPalette.surfaceAccent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TelegramPalette.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.task_alt_outlined,
                          color: TelegramPalette.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _flashMessage!,
                            style: const TextStyle(
                              height: 1.45,
                              color: TelegramPalette.textStrong,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _flashMessage = null;
                            });
                          },
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (wideDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _DocumentsHeroStrip(
                          documentCount: _documents.length,
                          selectedCount: _selectedDocumentIds.length,
                          questionCount: _documents.fold<int>(
                            0,
                            (sum, document) => sum + document.questionCount,
                          ),
                          pendingExportCount: _documents
                              .where((document) =>
                                  document.latestExportStatus == 'pending' ||
                                  document.latestExportStatus == 'running')
                              .length,
                          hasFocusedContext: _focusedDocumentId != null ||
                              (_flashMessage?.trim().isNotEmpty ?? false) ||
                              (_highlightTitle?.trim().isNotEmpty ?? false) ||
                              (_feedbackBadgeLabel?.trim().isNotEmpty ?? false),
                          onOpenWorkspace: _openWorkspace,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 2,
                        child: _DocumentsStatusCard(
                          modeLabel: AppConfig.dataModeLabel,
                          sessionLabel:
                              AppServices.instance.session?.username ?? '未登录',
                          tenantLabel:
                              AppServices.instance.activeTenant?.code ??
                                  '未选择租户',
                        ),
                      ),
                    ],
                  )
                else ...[
                  _DocumentsHeroStrip(
                    documentCount: _documents.length,
                    selectedCount: _selectedDocumentIds.length,
                    questionCount: _documents.fold<int>(
                      0,
                      (sum, document) => sum + document.questionCount,
                    ),
                    pendingExportCount: _documents
                        .where((document) =>
                            document.latestExportStatus == 'pending' ||
                            document.latestExportStatus == 'running')
                        .length,
                    hasFocusedContext: _focusedDocumentId != null ||
                        (_flashMessage?.trim().isNotEmpty ?? false) ||
                        (_highlightTitle?.trim().isNotEmpty ?? false) ||
                        (_feedbackBadgeLabel?.trim().isNotEmpty ?? false),
                    onOpenWorkspace: _openWorkspace,
                  ),
                  const SizedBox(height: 18),
                  _DocumentsStatusCard(
                    modeLabel: AppConfig.dataModeLabel,
                    sessionLabel:
                        AppServices.instance.session?.username ?? '未登录',
                    tenantLabel:
                        AppServices.instance.activeTenant?.code ?? '未选择租户',
                  ),
                ],
                const SizedBox(height: 18),
                _DocumentsHeader(
                  onCreateDocument: _createDocument,
                  documentCount: _documents.length,
                  questionCount: _documents.fold<int>(
                    0,
                    (sum, document) => sum + document.questionCount,
                  ),
                  layoutCount: _documents.fold<int>(
                    0,
                    (sum, document) => sum + document.layoutCount,
                  ),
                  filteredDocumentCount: filteredDocuments.length,
                  filteredQuestionCount: filteredDocuments.fold<int>(
                    0,
                    (sum, document) => sum + document.questionCount,
                  ),
                  filteredLayoutCount: filteredDocuments.fold<int>(
                    0,
                    (sum, document) => sum + document.layoutCount,
                  ),
                  filteredHandoutCount: filteredDocuments
                      .where((document) => document.kind == 'handout')
                      .length,
                  filteredPaperCount: filteredDocuments
                      .where((document) => document.kind == 'paper')
                      .length,
                  filteredPendingExportCount: filteredDocuments
                      .where((document) =>
                          document.latestExportStatus == 'pending' ||
                          document.latestExportStatus == 'running')
                      .length,
                  filteredSucceededExportCount: filteredDocuments
                      .where(
                        (document) =>
                            document.latestExportStatus == 'succeeded',
                      )
                      .length,
                  filteredFailedExportCount: filteredDocuments
                      .where(
                        (document) => document.latestExportStatus == 'failed',
                      )
                      .length,
                  pendingExportCount: _documents
                      .where((document) =>
                          document.latestExportStatus == 'pending' ||
                          document.latestExportStatus == 'running')
                      .length,
                  queryController: _queryController,
                  query: _query,
                  kindFilter: _kindFilter,
                  exportStatusFilter: _exportStatusFilter,
                  sortBy: _sortBy,
                  onQueryChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                    _rememberViewState();
                  },
                  onKindChanged: (value) {
                    setState(() {
                      _kindFilter = value;
                    });
                    _rememberViewState();
                  },
                  onExportStatusChanged: (value) {
                    setState(() {
                      _exportStatusFilter = value;
                    });
                    _rememberViewState();
                  },
                  onSortChanged: (value) {
                    setState(() {
                      _sortBy = value;
                    });
                    _rememberViewState();
                  },
                  onClearFilters: _clearFilters,
                  recentlyAddedQuestionCount: _recentlyAddedQuestionCount,
                  feedbackBadgeLabel: _feedbackBadgeLabel,
                ),
                const SizedBox(height: 18),
                if (_loadError != null)
                  _DocumentsErrorCard(
                    message: _loadError is HttpJsonException
                        ? '文档列表加载失败：${(_loadError as HttpJsonException).message}（HTTP ${(_loadError as HttpJsonException).statusCode}）'
                        : '文档列表加载失败：$_loadError',
                    onRetry: _reload,
                  )
                else if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_documents.isEmpty)
                  WorkspacePanel(
                    padding: EdgeInsets.all(compact ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConfig.useMockData
                              ? '当前还没有文档。先新建一份讲义或试卷，再继续编排内容。'
                              : '当前还没有文档。先确认已登录并进入工作区，再新建讲义或试卷。',
                          style: const TextStyle(
                            height: 1.5,
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                        if (!AppConfig.useMockData) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: compact ? 8 : 10,
                            runSpacing: compact ? 8 : 10,
                            children: [
                              if (AppServices.instance.session == null)
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(AppRouter.login),
                                  icon: const Icon(Icons.login),
                                  label: const Text('先登录'),
                                ),
                              if (AppServices.instance.activeTenant == null)
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(AppRouter.tenantSwitch),
                                  icon: const Icon(Icons.apartment_outlined),
                                  label: const Text('选择租户'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )
                else ...[
                  Builder(
                    builder: (context) {
                      final filteredDocuments = _applyFilters(_documents);
                      _scheduleFocusedDocumentScroll(filteredDocuments);
                      if (filteredDocuments.isEmpty) {
                        final showingOnlySelected = _showOnlySelectedDocuments;
                        return WorkspacePanel(
                          padding: EdgeInsets.all(compact ? 14 : 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '当前没有可展示的文档。',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: TelegramPalette.textStrong,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                showingOnlySelected
                                    ? '可以先退出“只看已选”，或重新选择一批文档后再继续批量处理。'
                                    : _query.trim().isEmpty
                                        ? '可以切换文档类型筛选，或清空筛选后查看全部文档。'
                                        : '可以调整关键词或类型筛选，重新定位目标文档。',
                                style: const TextStyle(
                                  height: 1.5,
                                  color: TelegramPalette.textMuted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextButton.icon(
                                onPressed: showingOnlySelected
                                    ? () {
                                        setState(() {
                                          _showOnlySelectedDocuments = false;
                                        });
                                        _rememberViewState();
                                      }
                                    : _clearFilters,
                                icon: Icon(
                                  showingOnlySelected
                                      ? Icons.visibility_off_outlined
                                      : Icons.filter_alt_off_outlined,
                                ),
                                label: Text(
                                  showingOnlySelected
                                      ? '退出只看已选'
                                      : (compact ? '清空' : '清空筛选'),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final allFilteredSelected =
                          filteredDocuments.isNotEmpty &&
                              filteredDocuments.every(
                                (document) =>
                                    _selectedDocumentIds.contains(document.id),
                              );
                      final handoutCount = filteredDocuments
                          .where((document) => document.kind == 'handout')
                          .length;
                      final paperCount = filteredDocuments
                          .where((document) => document.kind == 'paper')
                          .length;
                      final notStartedCount = filteredDocuments
                          .where(
                            (document) =>
                                document.latestExportStatus == 'not_started',
                          )
                          .length;
                      final inProgressCount = filteredDocuments
                          .where(
                            (document) =>
                                document.latestExportStatus == 'pending' ||
                                document.latestExportStatus == 'running',
                          )
                          .length;
                      final failedCount = filteredDocuments
                          .where(
                            (document) =>
                                document.latestExportStatus == 'failed',
                          )
                          .length;
                      final succeededCount = filteredDocuments
                          .where(
                            (document) =>
                                document.latestExportStatus == 'succeeded',
                          )
                          .length;
                      final canceledCount = filteredDocuments
                          .where(
                            (document) =>
                                document.latestExportStatus == 'canceled',
                          )
                          .length;
                      return Column(
                        children: [
                          _DocumentsSelectionBar(
                            selectedCount: _selectedDocumentIds.length,
                            selectedHandoutCount: filteredDocuments
                                .where(
                                  (document) =>
                                      _selectedDocumentIds
                                          .contains(document.id) &&
                                      document.kind == 'handout',
                                )
                                .length,
                            selectedPaperCount: filteredDocuments
                                .where(
                                  (document) =>
                                      _selectedDocumentIds
                                          .contains(document.id) &&
                                      document.kind == 'paper',
                                )
                                .length,
                            selectedQuestionTotal: filteredDocuments
                                .where(
                                  (document) => _selectedDocumentIds
                                      .contains(document.id),
                                )
                                .fold<int>(
                                  0,
                                  (sum, document) =>
                                      sum + document.questionCount,
                                ),
                            selectedLayoutTotal: filteredDocuments
                                .where(
                                  (document) => _selectedDocumentIds
                                      .contains(document.id),
                                )
                                .fold<int>(
                                  0,
                                  (sum, document) => sum + document.layoutCount,
                                ),
                            filteredCount: filteredDocuments.length,
                            selectedFilteredCount: filteredDocuments
                                .where(
                                  (document) => _selectedDocumentIds
                                      .contains(document.id),
                                )
                                .length,
                            allFilteredSelected: allFilteredSelected,
                            handoutCount: handoutCount,
                            paperCount: paperCount,
                            notStartedCount: notStartedCount,
                            inProgressCount: inProgressCount,
                            failedCount: failedCount,
                            succeededCount: succeededCount,
                            canceledCount: canceledCount,
                            exportingSelected: _exportingSelected,
                            duplicatingSelected: _duplicatingSelected,
                            addingSelectedToDocument: _addingSelectedToDocument,
                            mergingSelected: _mergingSelected,
                            removingSelected: _removingSelected,
                            showOnlySelected: _showOnlySelectedDocuments,
                            onSelectAll: () =>
                                _selectAllFiltered(filteredDocuments),
                            onSelectHandouts: () =>
                                _selectFilteredDocumentsByKind(
                              filteredDocuments,
                              'handout',
                            ),
                            onSelectPapers: () =>
                                _selectFilteredDocumentsByKind(
                              filteredDocuments,
                              'paper',
                            ),
                            onSelectNotStarted: () =>
                                _selectFilteredDocumentsByExportStatus(
                              filteredDocuments,
                              'not_started',
                            ),
                            onSelectInProgress: () =>
                                _selectFilteredDocumentsByExportStatus(
                              filteredDocuments,
                              'in_progress',
                            ),
                            onSelectFailed: () =>
                                _selectFilteredDocumentsByExportStatus(
                              filteredDocuments,
                              'failed',
                            ),
                            onSelectSucceeded: () =>
                                _selectFilteredDocumentsByExportStatus(
                              filteredDocuments,
                              'succeeded',
                            ),
                            onSelectCanceled: () =>
                                _selectFilteredDocumentsByExportStatus(
                              filteredDocuments,
                              'canceled',
                            ),
                            onInvertSelection: () =>
                                _invertFilteredSelection(filteredDocuments),
                            onClearSelection: _clearSelection,
                            onShowOnlySelectedChanged: (value) {
                              setState(() {
                                _showOnlySelectedDocuments = value;
                              });
                              _rememberViewState();
                            },
                            onExportSelected: () =>
                                _exportSelectedDocuments(filteredDocuments),
                            onDuplicateSelected: () =>
                                _duplicateSelectedDocuments(filteredDocuments),
                            onAddSelectedToDocument: () =>
                                _addSelectedDocumentsToDocument(
                                    filteredDocuments),
                            onMergeSelected: () =>
                                _mergeSelectedDocumentsIntoNewDocument(
                              filteredDocuments,
                            ),
                            onRemoveSelected: () =>
                                _removeSelectedDocuments(filteredDocuments),
                          ),
                          const SizedBox(height: 12),
                          ...filteredDocuments.map(
                            (document) => Padding(
                              key: _keyForDocument(document.id),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DocumentCard(
                                document: document,
                                isSelected:
                                    _selectedDocumentIds.contains(document.id),
                                highlighted: _focusedDocumentId == document.id,
                                recentlyAddedQuestionCount:
                                    _focusedDocumentId == document.id
                                        ? _recentlyAddedQuestionCount
                                        : null,
                                highlightTitle:
                                    _focusedDocumentId == document.id
                                        ? _highlightTitle
                                        : null,
                                highlightDetail:
                                    _focusedDocumentId == document.id
                                        ? _highlightDetail
                                        : null,
                                feedbackBadgeLabel:
                                    _focusedDocumentId == document.id
                                        ? _feedbackBadgeLabel
                                        : null,
                                onOpenDetail: () =>
                                    _openDocumentDetail(document),
                                onOpenLibrary: () =>
                                    _openLibraryForDocument(document),
                                onOpenBasket: () =>
                                    _openBasketForDocument(document),
                                onExport: _exportingDocumentId == document.id
                                    ? null
                                    : () => _exportDocument(document),
                                exporting: _exportingDocumentId == document.id,
                                onOpenExports: () => _openExports(document),
                                onOpenLatestExportDetail:
                                    document.latestExportJobId == null
                                        ? null
                                        : () =>
                                            _openLatestExportDetail(document),
                                onOpenLatestExportResult: document
                                                .latestExportStatus !=
                                            'succeeded' ||
                                        document.latestExportJobId == null
                                    ? null
                                    : () => _openLatestExportResult(document),
                                onSelectionChanged: (selected) {
                                  _setSelection(document.id, selected);
                                },
                                onDuplicate: () => _duplicateDocument(document),
                                onRename: () => _renameDocument(document),
                                onRemove: () => _removeDocument(document),
                              ),
                            ),
                          )
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 900
          ? const PrimaryNavigationBar(
              currentSection: PrimaryAppSection.documents,
            )
          : null,
    );
  }
}

class _DocumentsHeroStrip extends StatelessWidget {
  const _DocumentsHeroStrip({
    required this.documentCount,
    required this.selectedCount,
    required this.questionCount,
    required this.pendingExportCount,
    required this.hasFocusedContext,
    required this.onOpenWorkspace,
  });

  final int documentCount;
  final int selectedCount;
  final int questionCount;
  final int pendingExportCount;
  final bool hasFocusedContext;
  final VoidCallback onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final detail = hasFocusedContext
        ? '当前正在回看某份文档的最新状态。你可以继续编辑内容、发起导出，或回到总览处理其他文档。'
        : '这里串起组题、排版和导出结果回看，重点是持续完善一份可用的讲义或试卷。';
    return WorkspacePanel(
      padding: workspaceHeroPanelPadding(context),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: 'Documents Workspace',
            icon: Icons.layers_outlined,
          ),
          const SizedBox(height: 14),
          const Text(
            '在这里持续整理讲义和试卷，边编排边准备导出。',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            style: TextStyle(
              height: 1.55,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenWorkspace,
                icon: const Icon(Icons.home_outlined),
                label: Text(compact ? '工作区' : '返回工作区'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              WorkspaceMetricPill(label: '文档数', value: '$documentCount'),
              WorkspaceMetricPill(label: '题目项', value: '$questionCount'),
              WorkspaceMetricPill(
                label: '已选文档',
                value: '$selectedCount',
                highlight: selectedCount > 0,
              ),
              WorkspaceMetricPill(
                label: '处理中导出',
                value: '$pendingExportCount',
                highlight: pendingExportCount > 0,
              ),
              WorkspaceMetricPill(
                label: '当前模式',
                value: hasFocusedContext ? '工作区回看' : '工作区总览',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentsSelectionBar extends StatelessWidget {
  const _DocumentsSelectionBar({
    required this.selectedCount,
    required this.selectedHandoutCount,
    required this.selectedPaperCount,
    required this.selectedQuestionTotal,
    required this.selectedLayoutTotal,
    required this.filteredCount,
    required this.selectedFilteredCount,
    required this.allFilteredSelected,
    required this.handoutCount,
    required this.paperCount,
    required this.notStartedCount,
    required this.inProgressCount,
    required this.failedCount,
    required this.succeededCount,
    required this.canceledCount,
    required this.exportingSelected,
    required this.duplicatingSelected,
    required this.addingSelectedToDocument,
    required this.mergingSelected,
    required this.removingSelected,
    required this.showOnlySelected,
    required this.onSelectAll,
    required this.onSelectHandouts,
    required this.onSelectPapers,
    required this.onSelectNotStarted,
    required this.onSelectInProgress,
    required this.onSelectFailed,
    required this.onSelectSucceeded,
    required this.onSelectCanceled,
    required this.onInvertSelection,
    required this.onClearSelection,
    required this.onShowOnlySelectedChanged,
    required this.onExportSelected,
    required this.onDuplicateSelected,
    required this.onAddSelectedToDocument,
    required this.onMergeSelected,
    required this.onRemoveSelected,
  });

  final int selectedCount;
  final int selectedHandoutCount;
  final int selectedPaperCount;
  final int selectedQuestionTotal;
  final int selectedLayoutTotal;
  final int filteredCount;
  final int selectedFilteredCount;
  final bool allFilteredSelected;
  final int handoutCount;
  final int paperCount;
  final int notStartedCount;
  final int inProgressCount;
  final int failedCount;
  final int succeededCount;
  final int canceledCount;
  final bool exportingSelected;
  final bool duplicatingSelected;
  final bool addingSelectedToDocument;
  final bool mergingSelected;
  final bool removingSelected;
  final bool showOnlySelected;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectHandouts;
  final VoidCallback onSelectPapers;
  final VoidCallback onSelectNotStarted;
  final VoidCallback onSelectInProgress;
  final VoidCallback onSelectFailed;
  final VoidCallback onSelectSucceeded;
  final VoidCallback onSelectCanceled;
  final VoidCallback onInvertSelection;
  final VoidCallback onClearSelection;
  final ValueChanged<bool> onShowOnlySelectedChanged;
  final Future<void> Function() onExportSelected;
  final Future<void> Function() onDuplicateSelected;
  final Future<void> Function() onAddSelectedToDocument;
  final Future<void> Function() onMergeSelected;
  final Future<void> Function() onRemoveSelected;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return WorkspacePanel(
      backgroundColor: selectedCount > 0
          ? TelegramPalette.surfaceAccent
          : TelegramPalette.surfaceRaised,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Wrap(
        spacing: compact ? 8 : 12,
        runSpacing: compact ? 8 : 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            selectedCount > 0
                ? '已选择 $selectedCount / $filteredCount 份文档'
                : (compact ? '选中文档后批量处理' : '可选择当前结果中的部分文档再批量处理'),
            style: const TextStyle(
              color: TelegramPalette.textStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (selectedCount > 0)
            _StatusChip(label: '已选讲义', value: '$selectedHandoutCount'),
          if (selectedCount > 0)
            _StatusChip(label: '已选试卷', value: '$selectedPaperCount'),
          if (selectedCount > 0)
            _StatusChip(label: '已选题目总数', value: '$selectedQuestionTotal'),
          if (selectedCount > 0)
            _StatusChip(label: '已选排版总数', value: '$selectedLayoutTotal'),
          OutlinedButton.icon(
            onPressed: allFilteredSelected ? null : onSelectAll,
            icon: const Icon(Icons.select_all),
            label: Text(
                allFilteredSelected ? '已全选' : (compact ? '全选结果' : '全选当前结果')),
          ),
          OutlinedButton.icon(
            onPressed: handoutCount == 0 ? null : onSelectHandouts,
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(compact ? '选讲义' : '选中讲义'),
          ),
          OutlinedButton.icon(
            onPressed: paperCount == 0 ? null : onSelectPapers,
            icon: const Icon(Icons.quiz_outlined),
            label: Text(compact ? '选试卷' : '选中试卷'),
          ),
          OutlinedButton.icon(
            onPressed: notStartedCount == 0 ? null : onSelectNotStarted,
            icon: const Icon(Icons.radio_button_unchecked_outlined),
            label: Text(compact ? '选未导出' : '选中未导出'),
          ),
          OutlinedButton.icon(
            onPressed: inProgressCount == 0 ? null : onSelectInProgress,
            icon: const Icon(Icons.sync_outlined),
            label: Text(compact ? '选处理中' : '选中处理中'),
          ),
          OutlinedButton.icon(
            onPressed: failedCount == 0 ? null : onSelectFailed,
            icon: const Icon(Icons.error_outline),
            label: Text(compact ? '选失败' : '选中失败'),
          ),
          OutlinedButton.icon(
            onPressed: succeededCount == 0 ? null : onSelectSucceeded,
            icon: const Icon(Icons.task_alt_outlined),
            label: Text(compact ? '选已完成' : '选中已完成'),
          ),
          OutlinedButton.icon(
            onPressed: canceledCount == 0 ? null : onSelectCanceled,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(compact ? '选已取消' : '选中已取消'),
          ),
          OutlinedButton.icon(
            onPressed: filteredCount == 0 ? null : onInvertSelection,
            icon: const Icon(Icons.flip_to_back_outlined),
            label: Text(compact ? '反选结果' : '反选当前结果'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ? null : onClearSelection,
            icon: const Icon(Icons.clear_all),
            label: Text(compact ? '清空' : '清空选择'),
          ),
          WorkspaceFilterPill(
            label:
                showOnlySelected ? (compact ? '已选中' : '只看已选中') : '只看已选',
            selected: showOnlySelected,
            onTap: selectedCount == 0
                ? null
                : () => onShowOnlySelectedChanged(!showOnlySelected),
            icon: Icons.checklist_rtl_outlined,
          ),
          FilledButton.icon(
            onPressed: selectedCount == 0 ||
                    exportingSelected ||
                    duplicatingSelected ||
                    addingSelectedToDocument ||
                    mergingSelected ||
                    removingSelected
                ? null
                : () => onExportSelected(),
            icon: exportingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload_outlined),
            label: Text(exportingSelected ? '导出中…' : '批量导出'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    exportingSelected ||
                    duplicatingSelected ||
                    addingSelectedToDocument ||
                    mergingSelected ||
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
            label: Text(
                duplicatingSelected ? '复制中…' : (compact ? '复制所选' : '批量复制')),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    exportingSelected ||
                    duplicatingSelected ||
                    addingSelectedToDocument ||
                    mergingSelected ||
                    removingSelected
                ? null
                : () => onAddSelectedToDocument(),
            icon: addingSelectedToDocument
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.drive_file_move_outlined),
            label: Text(addingSelectedToDocument ? '承接中…' : '合并到文档'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    exportingSelected ||
                    duplicatingSelected ||
                    addingSelectedToDocument ||
                    mergingSelected ||
                    removingSelected
                ? null
                : () => onMergeSelected(),
            icon: mergingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.merge_type_outlined),
            label: Text(mergingSelected ? '合并中…' : '合并为新文档'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    exportingSelected ||
                    duplicatingSelected ||
                    addingSelectedToDocument ||
                    mergingSelected ||
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
            label:
                Text(removingSelected ? '删除中…' : (compact ? '删除所选' : '批量删除')),
          ),
        ],
      ),
    );
  }
}

class _DocumentsStatusCard extends StatelessWidget {
  const _DocumentsStatusCard({
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
          workspacePanelPadding(context, mobile: 14, tablet: 16, desktop: 18),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _StatusChip(label: '模式', value: modeLabel),
          _StatusChip(label: '会话', value: sessionLabel),
          _StatusChip(label: '租户', value: tenantLabel),
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
        color: TelegramPalette.surfaceAccent,
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

class _DocumentsErrorCard extends StatelessWidget {
  const _DocumentsErrorCard({
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
            '文档工作区暂时不可用',
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
                    label: const Text('选择租户'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentsHeader extends StatelessWidget {
  const _DocumentsHeader({
    required this.onCreateDocument,
    required this.documentCount,
    required this.questionCount,
    required this.layoutCount,
    required this.filteredDocumentCount,
    required this.filteredQuestionCount,
    required this.filteredLayoutCount,
    required this.filteredHandoutCount,
    required this.filteredPaperCount,
    required this.filteredPendingExportCount,
    required this.filteredSucceededExportCount,
    required this.filteredFailedExportCount,
    required this.pendingExportCount,
    required this.queryController,
    required this.query,
    required this.kindFilter,
    required this.exportStatusFilter,
    required this.sortBy,
    required this.onQueryChanged,
    required this.onKindChanged,
    required this.onExportStatusChanged,
    required this.onSortChanged,
    required this.onClearFilters,
    this.recentlyAddedQuestionCount,
    this.feedbackBadgeLabel,
  });

  final Future<void> Function() onCreateDocument;
  final int documentCount;
  final int questionCount;
  final int layoutCount;
  final int filteredDocumentCount;
  final int filteredQuestionCount;
  final int filteredLayoutCount;
  final int filteredHandoutCount;
  final int filteredPaperCount;
  final int filteredPendingExportCount;
  final int filteredSucceededExportCount;
  final int filteredFailedExportCount;
  final int pendingExportCount;
  final TextEditingController queryController;
  final String query;
  final String kindFilter;
  final String exportStatusFilter;
  final String sortBy;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onExportStatusChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onClearFilters;
  final int? recentlyAddedQuestionCount;
  final String? feedbackBadgeLabel;

  List<(String, String)> get _activeFilterEntries {
    final entries = <(String, String)>[];
    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty) {
      entries.add(('关键词', normalizedQuery));
    }
    if (kindFilter == 'handout') {
      entries.add(('文档类型', '讲义'));
    } else if (kindFilter == 'paper') {
      entries.add(('文档类型', '试卷'));
    }
    if (exportStatusFilter != 'all') {
      entries.add(('导出状态', _exportStatusLabel(exportStatusFilter)));
    }
    if (sortBy != 'workspace') {
      entries.add(('排序', _sortLabel(sortBy)));
    }
    return entries;
  }

  String _exportStatusLabel(String value) {
    switch (value) {
      case 'not_started':
        return '未导出';
      case 'pending':
        return '待处理';
      case 'running':
        return '处理中';
      case 'succeeded':
        return '已完成';
      case 'failed':
        return '失败';
      case 'canceled':
        return '已取消';
      case 'all':
      default:
        return '全部状态';
    }
  }

  String _sortLabel(String value) {
    switch (value) {
      case 'name':
        return '按名称';
      case 'questions':
        return '题目数优先';
      case 'layouts':
        return '排版项优先';
      case 'export_status':
        return '导出状态优先';
      case 'workspace':
      default:
        return '工作区顺序';
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final desktopWide = MediaQuery.sizeOf(context).width >= 1180;
    return WorkspacePanel(
      padding: workspaceHeroPanelPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: 'Compose & Organize',
            icon: Icons.dashboard_customize_outlined,
          ),
          const SizedBox(height: 12),
          const Text(
            '文档工作区',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            '这里集中查看讲义和试卷，支持筛选、批量处理，并随时回到文档详情继续编排和导出。',
            style: TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          if (desktopWide)
            const Text(
              '结果摘要',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: TelegramPalette.textMuted,
              ),
            ),
          if (desktopWide) const SizedBox(height: 8),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              _HeaderMetricChip(label: '文档', value: '$documentCount'),
              _HeaderMetricChip(label: '题目项', value: '$questionCount'),
              _HeaderMetricChip(label: '排版元素', value: '$layoutCount'),
              _HeaderMetricChip(label: '待导出', value: '$pendingExportCount'),
              if (recentlyAddedQuestionCount != null)
                _HeaderMetricChip(
                  label: '本次新增',
                  value: '${recentlyAddedQuestionCount!} 题',
                ),
              if (feedbackBadgeLabel != null &&
                  feedbackBadgeLabel!.trim().isNotEmpty)
                _HeaderMetricChip(
                  label: '最近同步',
                  value: feedbackBadgeLabel!,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              _HeaderMetricChip(
                label: '当前结果文档',
                value: '$filteredDocumentCount',
              ),
              _HeaderMetricChip(
                label: '当前结果题目项',
                value: '$filteredQuestionCount',
              ),
              _HeaderMetricChip(
                label: '当前结果排版项',
                value: '$filteredLayoutCount',
              ),
              _HeaderMetricChip(
                label: '当前结果讲义',
                value: '$filteredHandoutCount',
              ),
              _HeaderMetricChip(
                label: '当前结果试卷',
                value: '$filteredPaperCount',
              ),
              _HeaderMetricChip(
                label: '当前结果处理中',
                value: '$filteredPendingExportCount',
              ),
              _HeaderMetricChip(
                label: '当前结果已完成',
                value: '$filteredSucceededExportCount',
              ),
              _HeaderMetricChip(
                label: '当前结果失败',
                value: '$filteredFailedExportCount',
              ),
            ],
          ),
          if (_activeFilterEntries.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (desktopWide)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '已启用条件',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: TelegramPalette.textMuted,
                  ),
                ),
              ),
            Wrap(
              spacing: compact ? 8 : 10,
              runSpacing: compact ? 8 : 10,
              children: _activeFilterEntries
                  .map(
                    (entry) => _HeaderMetricChip(
                      label: entry.$1,
                      value: entry.$2,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 18),
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
              final compactGrid = constraints.maxWidth < 900;
              final wideDesktop = constraints.maxWidth >= 1180;
              final controlWidth = stacked
                  ? double.infinity
                  : compactGrid
                      ? (constraints.maxWidth - 12) / 2
                      : wideDesktop
                          ? 220.0
                          : 200.0;
              final searchField = SizedBox(
                width: stacked
                    ? double.infinity
                    : compactGrid
                        ? controlWidth
                        : wideDesktop
                            ? 420
                            : 320,
                child: TextField(
                  controller: queryController,
                  onChanged: onQueryChanged,
                  decoration: InputDecoration(
                    labelText: '搜索文档',
                    hintText: '文档名称 / 类型 / 导出状态',
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
              );
              final kindControl = SizedBox(
                width: stacked
                    ? double.infinity
                    : compactGrid
                        ? controlWidth
                        : 180,
                child: DropdownButtonFormField<String>(
                  initialValue: kindFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '文档类型',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部类型')),
                    DropdownMenuItem(value: 'handout', child: Text('讲义')),
                    DropdownMenuItem(value: 'paper', child: Text('试卷')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onKindChanged(value);
                    }
                  },
                ),
              );
              final exportStatusControl = SizedBox(
                width: stacked
                    ? double.infinity
                    : compactGrid
                        ? controlWidth
                        : 200,
                child: DropdownButtonFormField<String>(
                  initialValue: exportStatusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '导出状态',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部状态')),
                    DropdownMenuItem(
                      value: 'not_started',
                      child: Text('未导出'),
                    ),
                    DropdownMenuItem(value: 'pending', child: Text('待处理')),
                    DropdownMenuItem(value: 'running', child: Text('处理中')),
                    DropdownMenuItem(
                      value: 'succeeded',
                      child: Text('已完成'),
                    ),
                    DropdownMenuItem(value: 'failed', child: Text('失败')),
                    DropdownMenuItem(value: 'canceled', child: Text('已取消')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onExportStatusChanged(value);
                    }
                  },
                ),
              );
              final sortControl = SizedBox(
                width: stacked
                    ? double.infinity
                    : compactGrid
                        ? controlWidth
                        : 200,
                child: DropdownButtonFormField<String>(
                  initialValue: sortBy,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '排序',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'workspace',
                      child: Text('工作区顺序'),
                    ),
                    DropdownMenuItem(
                      value: 'name',
                      child: Text('按名称'),
                    ),
                    DropdownMenuItem(
                      value: 'questions',
                      child: Text('题目数优先'),
                    ),
                    DropdownMenuItem(
                      value: 'layouts',
                      child: Text('排版项优先'),
                    ),
                    DropdownMenuItem(
                      value: 'export_status',
                      child: Text('导出状态优先'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onSortChanged(value);
                    }
                  },
                ),
              );
              final clearButton = TextButton.icon(
                onPressed: query.trim().isEmpty &&
                        kindFilter == 'all' &&
                        exportStatusFilter == 'all' &&
                        sortBy == 'workspace'
                    ? null
                    : onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(compact ? '清空' : '清空筛选'),
              );
              final createButton = FilledButton.icon(
                onPressed: onCreateDocument,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(compact ? '新建' : '新建文档'),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final widget in [
                      searchField,
                      kindControl,
                      exportStatusControl,
                      sortControl,
                      clearButton,
                      createButton,
                    ]) ...[
                      widget,
                      if (widget != createButton) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              if (wideDesktop) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 12),
                        kindControl,
                        const SizedBox(width: 12),
                        exportStatusControl,
                        const SizedBox(width: 12),
                        sortControl,
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        clearButton,
                        createButton,
                      ],
                    ),
                  ],
                );
              }
              return Wrap(
                spacing: compact ? 8 : 12,
                runSpacing: compact ? 8 : 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  searchField,
                  kindControl,
                  exportStatusControl,
                  sortControl,
                  clearButton,
                  createButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderMetricChip extends StatelessWidget {
  const _HeaderMetricChip({
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
        color: TelegramPalette.surfaceAccent,
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.isSelected,
    required this.highlighted,
    this.recentlyAddedQuestionCount,
    this.highlightTitle,
    this.highlightDetail,
    this.feedbackBadgeLabel,
    required this.onOpenDetail,
    required this.onOpenLibrary,
    required this.onOpenBasket,
    required this.onExport,
    required this.exporting,
    required this.onOpenExports,
    required this.onOpenLatestExportDetail,
    required this.onOpenLatestExportResult,
    required this.onSelectionChanged,
    required this.onDuplicate,
    required this.onRename,
    required this.onRemove,
  });

  final DocumentSummary document;
  final bool isSelected;
  final bool highlighted;
  final int? recentlyAddedQuestionCount;
  final String? highlightTitle;
  final String? highlightDetail;
  final String? feedbackBadgeLabel;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenBasket;
  final VoidCallback? onExport;
  final bool exporting;
  final VoidCallback onOpenExports;
  final VoidCallback? onOpenLatestExportDetail;
  final VoidCallback? onOpenLatestExportResult;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  String _exportStatusLabel(String status) {
    switch (status) {
      case 'not_started':
        return '未导出';
      case 'pending':
        return '待处理';
      case 'running':
        return '处理中';
      case 'succeeded':
        return '已完成';
      case 'failed':
        return '失败';
      case 'canceled':
        return '已取消';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final desktopWide = MediaQuery.sizeOf(context).width >= 1180;
    return WorkspacePanel(
      backgroundColor: highlighted
          ? TelegramPalette.highlight
          : TelegramPalette.surfaceRaised,
      borderColor: highlighted
          ? TelegramPalette.highlightBorder
          : TelegramPalette.border,
      borderRadius: 12,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (selected) {
                  onSelectionChanged(selected ?? false);
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  document.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              WorkspaceInfoPill(
                label: '类型',
                value: document.kind == 'paper' ? '试卷' : '讲义',
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (desktopWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DocumentSummaryPreview(
                    document: document,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: TelegramPalette.surfaceAccent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TelegramPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '文档摘要',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TelegramPalette.textStrong,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            WorkspaceInfoPill(
                              label: '类型',
                              value: document.kind == 'paper' ? '试卷' : '讲义',
                            ),
                            WorkspaceInfoPill(
                              label: '导出',
                              value: _exportStatusLabel(
                                document.latestExportStatus,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '题目 ${document.questionCount} · 排版 ${document.layoutCount}',
                          style: const TextStyle(
                            color: TelegramPalette.textStrong,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '继续编排、补题、查看导出都从这里往下走。',
                          style: TextStyle(
                            height: 1.45,
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            DocumentSummaryPreview(
              document: document,
              backgroundColor: Colors.white,
            ),
          if (highlighted ||
              (feedbackBadgeLabel != null &&
                  feedbackBadgeLabel!.trim().isNotEmpty) ||
              recentlyAddedQuestionCount != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (highlighted &&
                    feedbackBadgeLabel != null &&
                    feedbackBadgeLabel!.trim().isNotEmpty)
                  WorkspaceInfoPill(
                    label: '提示',
                    value: feedbackBadgeLabel!,
                    highlight: true,
                  ),
                if (highlighted && recentlyAddedQuestionCount != null)
                  WorkspaceInfoPill(
                    label: '新增',
                    value: '$recentlyAddedQuestionCount 题',
                    highlight: true,
                  ),
              ],
            ),
          ],
          if (highlighted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TelegramPalette.surfaceAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    highlightTitle ?? '这是你刚刚查看或导出过的文档',
                    style: const TextStyle(
                      color: TelegramPalette.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    highlightDetail ?? '列表统计和最近导出状态已刷新，可以继续编排或查看导出。',
                    style: const TextStyle(
                      color: TelegramPalette.textStrong,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenDetail,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('继续编排'),
              ),
              FilledButton.tonalIcon(
                onPressed: onOpenLibrary,
                icon: const Icon(Icons.travel_explore_outlined),
                label: Text(compact ? '去题库' : '去题库加题'),
              ),
              FilledButton.tonalIcon(
                onPressed: onOpenBasket,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(compact ? '选题篮' : '打开选题篮'),
              ),
              FilledButton.tonalIcon(
                onPressed: onExport,
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(exporting ? '导出中…' : '直接导出'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenExports,
                icon: const Icon(Icons.cloud_download_outlined),
                label: Text(compact ? '导出记录' : '查看导出'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenLatestExportDetail,
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(compact ? '最近详情' : '最近导出详情'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenLatestExportResult,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(compact ? '最近结果' : '打开最近结果'),
              ),
              OutlinedButton.icon(
                onPressed: onDuplicate,
                icon: const Icon(Icons.copy_outlined),
                label: Text(compact ? '复制' : '复制文档'),
              ),
              OutlinedButton.icon(
                onPressed: onRename,
                icon: const Icon(Icons.drive_file_rename_outline),
                label: const Text('重命名'),
              ),
              OutlinedButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
