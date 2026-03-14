import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/documents_page_args.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/exports_page_args.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../library/question_block_renderer.dart';
import '../../router/app_router.dart';
import 'create_document_dialog.dart';

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
  List<DocumentSummary> _documents = const <DocumentSummary>[];
  Object? _loadError;
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _documentKeys = <String, GlobalKey>{};
  String? _focusedDocumentId;
  String? _lastScrolledDocumentId;
  String? _flashMessage;
  String? _highlightTitle;
  String? _highlightDetail;
  int? _recentlyAddedQuestionCount;
  String? _feedbackBadgeLabel;

  @override
  void initState() {
    super.initState();
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

  Future<void> _reload({bool preserveExisting = false}) async {
    setState(() {
      _loading = !preserveExisting || _documents.isEmpty;
      _loadError = null;
    });
    try {
      final documents = await AppServices.instance.documentRepository.listDocuments();
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = documents;
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

  Future<void> _refreshDocumentById(String documentId) async {
    try {
      final refreshed = await AppServices.instance.documentRepository.getDocument(documentId);
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
    if (_focusedDocumentId == null || _lastScrolledDocumentId == _focusedDocumentId) {
      return;
    }
    final documentExists = documents.any((document) => document.id == _focusedDocumentId);
    if (!documentExists) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusedDocumentId == null) {
        return;
      }
      final targetContext = _keyForDocument(_focusedDocumentId!).currentContext;
      if (targetContext == null) {
        return;
      }
      _lastScrolledDocumentId = _focusedDocumentId;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.14,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('讲义与试卷')),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        children: [
          if (_flashMessage != null && _flashMessage!.trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(16),
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
          _DocumentsStatusCard(
            modeLabel: AppConfig.dataModeLabel,
            sessionLabel: AppServices.instance.session?.username ?? '未登录',
            tenantLabel: AppServices.instance.activeTenant?.code ?? '未选择租户',
          ),
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
            pendingExportCount: _documents
                .where((document) =>
                    document.latestExportStatus == 'pending' ||
                    document.latestExportStatus == 'running')
                .length,
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前没有可用文档。REMOTE 模式下请先登录并选择租户，然后再创建或查看文档。',
                      style: TextStyle(
                        height: 1.5,
                        color: TelegramPalette.textMuted,
                      ),
                    ),
                    if (!AppConfig.useMockData) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (AppServices.instance.session == null)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.of(context).pushNamed(AppRouter.login),
                              icon: const Icon(Icons.login),
                              label: const Text('先登录'),
                            ),
                          if (AppServices.instance.activeTenant == null)
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
              ),
            )
          else ...[
            Builder(
              builder: (context) {
                _scheduleFocusedDocumentScroll(_documents);
                return Column(
                  children: _documents
                      .map(
                        (document) => Padding(
                          key: _keyForDocument(document.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DocumentCard(
                            document: document,
                            highlighted: _focusedDocumentId == document.id,
                            recentlyAddedQuestionCount:
                                _focusedDocumentId == document.id
                                    ? _recentlyAddedQuestionCount
                                    : null,
                            highlightTitle: _focusedDocumentId == document.id
                                ? _highlightTitle
                                : null,
                            highlightDetail: _focusedDocumentId == document.id
                                ? _highlightDetail
                                : null,
                            feedbackBadgeLabel: _focusedDocumentId == document.id
                                ? _feedbackBadgeLabel
                                : null,
                            onOpenDetail: () => _openDocumentDetail(document),
                            onOpenExports: () => _openExports(document),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatusChip(label: '模式', value: modeLabel),
            _StatusChip(label: '会话', value: sessionLabel),
            _StatusChip(label: '租户', value: tenantLabel),
          ],
        ),
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

class _DocumentsErrorCard extends StatelessWidget {
  const _DocumentsErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final needsSession = !AppConfig.useMockData && AppServices.instance.session == null;
    final needsTenant = !AppConfig.useMockData && AppServices.instance.activeTenant == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
              style: TextStyle(
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
                      onPressed: () => Navigator.of(context).pushNamed(AppRouter.login),
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
    required this.pendingExportCount,
    this.recentlyAddedQuestionCount,
    this.feedbackBadgeLabel,
  });

  final Future<void> Function() onCreateDocument;
  final int documentCount;
  final int questionCount;
  final int layoutCount;
  final int pendingExportCount;
  final int? recentlyAddedQuestionCount;
  final String? feedbackBadgeLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '文档工作区',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              '这里承接讲义与试卷的编排。下一步会继续补文档详情、拖拽排序和导出状态，直接对接后端 documents / export-jobs API。',
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
                    label: '最近回流',
                    value: feedbackBadgeLabel!,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreateDocument,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('新建文档'),
            ),
          ],
        ),
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.highlighted,
    this.recentlyAddedQuestionCount,
    this.highlightTitle,
    this.highlightDetail,
    this.feedbackBadgeLabel,
    required this.onOpenDetail,
    required this.onOpenExports,
  });

  final DocumentSummary document;
  final bool highlighted;
  final int? recentlyAddedQuestionCount;
  final String? highlightTitle;
  final String? highlightDetail;
  final String? feedbackBadgeLabel;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenExports;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlighted ? TelegramPalette.highlight : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: highlighted ? TelegramPalette.highlightBorder : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    document.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(label: Text(document.kind == 'paper' ? '试卷' : '讲义')),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('题目 ${document.questionCount}')),
                Chip(label: Text('排版元素 ${document.layoutCount}')),
                Chip(label: Text('导出 ${document.latestExportStatus}')),
                if (highlighted &&
                    feedbackBadgeLabel != null &&
                    feedbackBadgeLabel!.trim().isNotEmpty)
                  Chip(label: Text(feedbackBadgeLabel!)),
                if (highlighted && recentlyAddedQuestionCount != null)
                  Chip(label: Text('本次新增 $recentlyAddedQuestionCount 题')),
              ],
            ),
            if (document.previewBlocks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TelegramPalette.border),
                ),
                child: QuestionBlockRenderer(
                  blocks: document.previewBlocks,
                  fallbackText: '暂无文档预览。',
                ),
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
                      highlightDetail ??
                          '列表统计和最近导出状态已刷新，可以继续编排或查看导出。',
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
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('继续编排'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenExports,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('查看导出'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
