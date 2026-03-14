import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_item_summary.dart';
import '../../core/models/documents_page_args.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/export_detail_args.dart';
import '../../core/models/export_job_summary.dart';
import '../../core/models/exports_page_args.dart';
import '../../core/models/layout_element_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../library/question_block_renderer.dart';
import '../../router/app_router.dart';

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
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};
  late String? _focusedItemId = widget.focusItemId;
  late String? _focusedItemTitle = widget.focusItemTitle;
  late String? _focusedExportJobId = widget.focusExportJobId;
  int? _recentlyAddedQuestionCount;
  String? _lastScrolledItemId;
  int? _liveQuestionCount;
  int? _liveLayoutCount;

  @override
  void initState() {
    super.initState();
    _documentFuture = widget.documentSnapshot != null
        ? Future<DocumentSummary?>.value(widget.documentSnapshot)
        : AppServices.instance.documentRepository.getDocument(widget.documentId);
    _itemsFuture =
        AppServices.instance.documentRepository.listDocumentItems(widget.documentId);
    _recentlyAddedQuestionCount = widget.recentlyAddedQuestionCount;
    if (widget.documentSnapshot != null) {
      _refreshDocumentFromServer();
    }
  }

  void _reloadDocument() {
    setState(() {
      _documentFuture =
          AppServices.instance.documentRepository.getDocument(widget.documentId);
    });
  }

  void _reloadItems() {
    setState(() {
      _itemsFuture =
          AppServices.instance.documentRepository.listDocumentItems(widget.documentId);
    });
  }

  void _reloadAll() {
    _reloadDocument();
    _reloadItems();
  }

  Future<void> _patchItems(
    List<DocumentItemSummary> Function(List<DocumentItemSummary> items) transform,
  ) async {
    final currentItems = await _itemsFuture;
    if (!mounted) {
      return;
    }
    final nextItems = transform(List<DocumentItemSummary>.from(currentItems));
    setState(() {
      _itemsFuture = Future<List<DocumentItemSummary>>.value(nextItems);
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
      _documentFuture = Future<DocumentSummary?>.value(transform(currentDocument));
    });
  }

  Future<void> _refreshDocumentFromServer() async {
    final refreshed =
        await AppServices.instance.documentRepository.getDocument(widget.documentId);
    if (!mounted || refreshed == null) {
      return;
    }
    setState(() {
      _documentFuture = Future<DocumentSummary?>.value(refreshed);
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

  Future<void> _popWithCurrentDocument() async {
    final snapshot = await _currentDocumentSnapshot();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(snapshot);
  }

  void _syncDerivedCounts(List<DocumentItemSummary> items) {
    final questionCount =
        items.where((item) => item.kind == 'question').length;
    final layoutCount = items.length - questionCount;
    if (_liveQuestionCount == questionCount && _liveLayoutCount == layoutCount) {
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

  Future<void> _moveItem(DocumentItemSummary item, int offset) async {
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
        final currentIndex = items.indexWhere((candidate) => candidate.id == item.id);
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
  }

  Future<void> _removeItem(DocumentItemSummary item) async {
    try {
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移除文档项：${item.title}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('移除文档项失败', error);
    }
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
      final layoutElements =
          await AppServices.instance.documentRepository.listLayoutElements();
      if (!mounted || layoutElements.isEmpty) {
        return;
      }

      final selected = await showModalBottomSheet<LayoutElementSummary>(
        context: context,
        showDragHandle: true,
        builder: (context) => _LayoutElementPicker(
          layoutElements: layoutElements,
        ),
      );

      if (selected == null) {
        return;
      }

      final createdItem =
          await AppServices.instance.documentRepository.addLayoutElementToDocument(
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已插入排版元素：${selected.name}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('插入排版元素失败', error);
    }
  }

  void _showActionError(String prefix, Object error) {
    final message = error is HttpJsonException
        ? '$prefix：${error.message}（HTTP ${error.statusCode}）'
        : '$prefix：$error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
        highlightTitle: addedCount == null ? '刚刚编辑过的文档' : '已回流批量加题结果',
        highlightDetail: addedCount == null
            ? '这份文档刚从详情页返回，列表统计和最近导出状态已刷新。'
            : '本次已批量加入 $addedCount 道题，当前卡片统计已经按最新文档状态刷新。',
        recentlyAddedQuestionCount: addedCount,
        feedbackBadgeLabel: addedCount == null ? '编辑已同步' : '批量加题已同步',
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文档详情'),
        leading: BackButton(
          onPressed: _popWithCurrentDocument,
        ),
      ),
      body: PopScope(
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

            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              children: [
              _DocumentContextCard(
                modeLabel: AppConfig.dataModeLabel,
                sessionLabel: AppServices.instance.session?.username ?? '未登录',
                tenantLabel: AppServices.instance.activeTenant?.code ?? '未选择租户',
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(document.kind == 'paper' ? '试卷' : '讲义')),
                          Chip(
                            label: Text(
                              '题目 ${_liveQuestionCount ?? document.questionCount}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              '排版元素 ${_liveLayoutCount ?? document.layoutCount}',
                            ),
                          ),
                          Chip(label: Text('最近导出 ${document.latestExportStatus}')),
                        ],
                      ),
                      if ((_liveQuestionCount != null &&
                              _liveQuestionCount != document.questionCount) ||
                          (_liveLayoutCount != null &&
                              _liveLayoutCount != document.layoutCount)) ...[
                        const SizedBox(height: 14),
                        const Text(
                          '当前统计已按页面里最新文档项即时更新。',
                          style: TextStyle(
                            height: 1.5,
                            color: TelegramPalette.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_focusedExportJobId != null &&
                          _focusedExportJobId == document.latestExportJobId) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: TelegramPalette.surfaceAccent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TelegramPalette.borderAccent),
                          ),
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
                      const SizedBox(height: 18),
                      const Text(
                        '这里已经开始展示文档项。下一步可以直接接 documents detail / reorder / add-item API，把本地骨架换成真实编排页。',
                        style: TextStyle(
                          height: 1.6,
                          color: TelegramPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _reloadAll,
                            icon: const Icon(Icons.edit_note_outlined),
                            label: const Text('刷新状态'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _openDocumentsWorkspace,
                            icon: const Icon(Icons.dashboard_outlined),
                            label: const Text('返回文档工作区'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: document.latestExportStatus == 'not_started'
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
                            onPressed: document.latestExportStatus != 'succeeded' ||
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
                        ],
                      ),
                    ],
                  ),
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

                  return Column(
                    children: [
                      if (_focusedItemId != null &&
                          itemsSnapshot.data!.any(
                            (item) => item.id == _focusedItemId,
                          )) ...[
                        _FocusedItemNotice(
                          title: itemsSnapshot.data!
                              .firstWhere((item) => item.id == _focusedItemId)
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
                      _ComposeHintCard(onAddLayoutElement: _addLayoutElement),
                      const SizedBox(height: 12),
                      if (itemsSnapshot.data!.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              '当前文档还没有内容。可以先从题目详情或选题篮加入题目，再在这里插入排版元素。',
                              style: TextStyle(
                                height: 1.5,
                                color: TelegramPalette.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ...itemsSnapshot.data!.map(
                        (item) => Padding(
                          key: _keyForItem(item.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DocumentItemCard(
                            item: item,
                            highlighted:
                                (_focusedItemId != null &&
                                        _focusedItemId == item.id) ||
                                    (_focusedItemTitle != null &&
                                        _focusedItemTitle == item.title),
                            onMoveUp: () => _moveItem(item, -1),
                            onMoveDown: () => _moveItem(item, 1),
                            onRemove: () => _removeItem(item),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              ],
            );
          },
        ),
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
    return Card(
      color: TelegramPalette.surfaceAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TelegramPalette.borderAccent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.playlist_add_check, color: TelegramPalette.textStrong),
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
      ),
    );
  }
}

class _ComposeHintCard extends StatelessWidget {
  const _ComposeHintCard({required this.onAddLayoutElement});

  final Future<void> Function() onAddLayoutElement;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 12,
          children: [
            const SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '文档编排预览',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '这里先展示文档项顺序、题目项和排版元素项。后续接真实接口后，可以在移动端和桌面端共用同一套编排逻辑。',
                    style: TextStyle(
                      height: 1.5,
                      color: TelegramPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onAddLayoutElement,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('插入排版元素'),
            ),
          ],
        ),
      ),
    );
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
    return Card(
      child: Padding(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TelegramPalette.surfaceAccent,
        borderRadius: BorderRadius.circular(14),
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
        child: Card(
          child: Padding(
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
      ),
    );
  }
}

class _LayoutElementPicker extends StatelessWidget {
  const _LayoutElementPicker({required this.layoutElements});

  final List<LayoutElementSummary> layoutElements;

  @override
  Widget build(BuildContext context) {
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
            '这里先接本地排版元素列表。后续切到真实接口后，可以直接插入讲义抬头、提问框和总结区。',
            style: TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          ...layoutElements.map(
            (layoutElement) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
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
                          QuestionBlockRenderer(
                            blocks: layoutElement.previewBlocks,
                            fallbackText: layoutElement.description,
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(layoutElement),
                    child: const Text('插入'),
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
    required this.highlighted,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final DocumentItemSummary item;
  final bool highlighted;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isQuestion = item.kind == 'question';
    return Card(
      color: highlighted ? TelegramPalette.highlight : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlighted
            ? const BorderSide(color: TelegramPalette.highlightBorder, width: 1.2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    QuestionBlockRenderer(
                      blocks: item.previewBlocks,
                      fallbackText: item.detail,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: onMoveUp,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  onPressed: onMoveDown,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
