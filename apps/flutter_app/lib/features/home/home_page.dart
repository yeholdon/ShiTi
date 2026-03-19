import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/exports_page_args.dart';
import '../../core/models/library_filter_state.dart';
import '../../core/models/question_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../documents/create_document_dialog.dart';
import '../shared/primary_navigation_bar.dart';
import '../shared/primary_page_scroll_memory.dart';
import '../shared/workspace_shell.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _pageKey = 'home';

  late Future<_WorkspaceSnapshot> _snapshotFuture = _loadSnapshot();
  final ScrollController _scrollController = ScrollController(
    initialScrollOffset: PrimaryPageScrollMemory.offsetFor(_pageKey),
  );
  _RecentTaskFilter _recentTaskFilter = _RecentTaskFilter.all;
  _RecentTaskSort _recentTaskSort = _RecentTaskSort.recentOrder;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_rememberScrollOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _rememberScrollOffset() {
    PrimaryPageScrollMemory.update(_pageKey, _scrollController.offset);
  }

  Future<_WorkspaceSnapshot> _loadSnapshot() async {
    final services = AppServices.instance;
    final questions = await services.questionRepository.listQuestions(
      filters: const LibraryFilterState(),
    );
    final documents = await services.documentRepository.listDocuments();
    final exports = await services.documentRepository.listExportJobs();
    final basket = await services.questionRepository.listBasketQuestions();

    final questionCount = questions.length;
    final documentCount = documents.length;
    final basketCount = basket.length;
    final totalDocumentQuestions = documents.fold<int>(
      0,
      (sum, document) => sum + document.questionCount,
    );
    final totalLayoutCount = documents.fold<int>(
      0,
      (sum, document) => sum + document.layoutCount,
    );
    final activeExports = exports
        .where((job) => job.status == 'pending' || job.status == 'running')
        .toList();
    final latestExport = exports.isEmpty ? null : exports.first;
    final focusDocuments =
        documents.isEmpty ? <DocumentSummary>[] : [...documents]
          ..sort(
            (left, right) => (right.questionCount + right.layoutCount)
                .compareTo(left.questionCount + left.layoutCount),
          );
    final topDocument = focusDocuments.isEmpty ? null : focusDocuments.first;
    final topSubject = _pickTopLabel(
      questions.map((question) => question.subject),
      fallback: '还没有题目',
    );
    final topChapter = _pickTopLabel(
      questions.map((question) => question.chapter),
      fallback: '还没有章节分布',
    );

    final cards = <_SummaryCardData>[
      _SummaryCardData(
        title: '题库规模',
        value: '$questionCount',
        detail: questionCount == 0 ? '当前还没有远程题目。' : '当前聚焦学科：$topSubject',
        action: _WorkspaceCardAction.library,
      ),
      _SummaryCardData(
        title: '文档工作区',
        value: '$documentCount',
        detail: documentCount == 0
            ? '还没有讲义或试卷。'
            : '累计 $totalDocumentQuestions 题，版式 $totalLayoutCount 个',
        action: _WorkspaceCardAction.documents,
      ),
      _SummaryCardData(
        title: '导出状态',
        value: activeExports.isEmpty ? '稳定' : '${activeExports.length}',
        detail: activeExports.isEmpty
            ? (latestExport == null
                ? '当前还没有导出任务。'
                : '最近导出：${latestExport.documentName} · ${_exportStatusLabel(latestExport.status)}')
            : '当前有 ${activeExports.length} 个导出任务处理中',
        action: _WorkspaceCardAction.exports,
      ),
    ];

    final tasks = <_TaskData>[
      if (activeExports.isNotEmpty)
        ...activeExports.take(2).map(
          (job) {
            final matchedDocument =
                documents.cast<DocumentSummary?>().firstWhere(
                          (document) => document?.id == job.documentId,
                          orElse: () => null,
                        ) ??
                    documents.cast<DocumentSummary?>().firstWhere(
                          (document) => document?.name == job.documentName,
                          orElse: () => null,
                        );
            return _TaskData(
              title: job.documentName,
              detail:
                  '导出${_exportStatusLabel(job.status)} · ${job.updatedAtLabel}',
              action: _TaskAction.exports,
              document: matchedDocument,
              focusJobId: job.id,
            );
          },
        ),
      if (topDocument != null)
        _TaskData(
          title: topDocument.name,
          detail:
              '${topDocument.questionCount} 题 · ${topDocument.layoutCount} 个版式 · ${_documentKindLabel(topDocument.kind)}',
          action: _TaskAction.document,
          document: topDocument,
        ),
      if (basketCount > 0)
        _TaskData(
          title: '当前选题篮',
          detail: '$basketCount 题待整理 · 重点章节 $topChapter',
          action: _TaskAction.basket,
        ),
    ];

    return _WorkspaceSnapshot(
      cards: cards,
      tasks: tasks.isEmpty
          ? const <_TaskData>[
              _TaskData(
                title: '开始新的备课流',
                detail: '先去题库挑题，再回到文档工作区沉淀讲义结构。',
              ),
            ]
          : tasks.take(6).toList(),
      focusTitle: topDocument?.name ?? '开始新的讲义或试卷',
      focusBasketLabel: '$basketCount 题',
      focusDocumentLabel: '$documentCount 份',
      focusExportLabel: latestExport?.updatedAtLabel ?? '暂无导出',
      questionCount: questionCount,
      documentCount: documentCount,
      basketCount: basketCount,
    );
  }

  void _reloadSnapshot() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  Future<void> _createDocumentFromHome() async {
    final created = await showCreateDocumentDialog(context);
    if (created == null || !mounted) {
      return;
    }
    final result = await Navigator.of(context).pushNamed(
      AppRouter.documentDetail,
      arguments: DocumentDetailArgs(
        documentId: created.id,
        documentSnapshot: created,
      ),
    );
    if (!mounted) {
      return;
    }
    _reloadSnapshot();
    if (result is! DocumentSummary) {
      return;
    }
  }

  Future<void> _openTask(_TaskData task) async {
    switch (task.action) {
      case _TaskAction.document:
        final document = task.document;
        if (document == null) {
          return;
        }
        await Navigator.of(context).pushNamed(
          AppRouter.documentDetail,
          arguments: DocumentDetailArgs(
            documentId: document.id,
            documentSnapshot: document,
          ),
        );
        break;
      case _TaskAction.exports:
        await Navigator.of(context).pushNamed(
          AppRouter.exports,
          arguments: ExportsPageArgs(
            focusDocumentName: task.document?.name ?? task.title,
            focusJobId: task.focusJobId,
            documentSnapshot: task.document,
          ),
        );
        break;
      case _TaskAction.basket:
        await Navigator.of(context).pushNamed(AppRouter.basket);
        break;
      case _TaskAction.none:
        return;
    }
    if (!mounted) {
      return;
    }
    _reloadSnapshot();
  }

  Future<void> _openSummaryCard(_SummaryCardData card) async {
    switch (card.action) {
      case _WorkspaceCardAction.library:
        PrimaryNavigationBar.navigateToSection(
          context,
          PrimaryAppSection.library,
          resetScrollOffset: true,
        );
        return;
      case _WorkspaceCardAction.documents:
        PrimaryNavigationBar.navigateToSection(
          context,
          PrimaryAppSection.documents,
          resetScrollOffset: true,
        );
        return;
      case _WorkspaceCardAction.exports:
        PrimaryNavigationBar.navigateToSection(
          context,
          PrimaryAppSection.exports,
          resetScrollOffset: true,
        );
        return;
      case _WorkspaceCardAction.none:
        return;
    }
  }

  Future<void> _openFocusTarget(_WorkspaceFocusTarget target) async {
    switch (target) {
      case _WorkspaceFocusTarget.basket:
        await Navigator.of(context).pushNamed(AppRouter.basket);
        break;
      case _WorkspaceFocusTarget.documents:
        PrimaryNavigationBar.navigateToSection(
          context,
          PrimaryAppSection.documents,
          resetScrollOffset: true,
        );
        return;
      case _WorkspaceFocusTarget.exports:
        PrimaryNavigationBar.navigateToSection(
          context,
          PrimaryAppSection.exports,
          resetScrollOffset: true,
        );
        return;
      case _WorkspaceFocusTarget.none:
        return;
    }
    if (!mounted) {
      return;
    }
    _reloadSnapshot();
  }

  String _pickTopLabel(
    Iterable<String> values, {
    required String fallback,
  }) {
    final counts = <String, int>{};
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) {
        continue;
      }
      counts.update(value, (count) => count + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) {
      return fallback;
    }
    final entries = counts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return entries.first.key;
  }

  static String _exportStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return '待处理';
      case 'running':
        return '进行中';
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

  static String _documentKindLabel(String kind) {
    switch (kind) {
      case 'paper':
        return '试卷';
      case 'handout':
        return '讲义';
      default:
        return kind;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return Row(
                children: [
                  if (wide) const _WorkspaceRail(),
                  Expanded(
                    child: workspaceConstrainedContent(
                      context,
                      child: ListView(
                        controller: _scrollController,
                        padding: workspacePagePadding(context),
                        children: [
                          FutureBuilder<_WorkspaceSnapshot>(
                            future: _snapshotFuture,
                            builder: (context, snapshot) {
                              return _HeroSection(
                                wide: wide,
                                snapshot: snapshot,
                                onRefresh: _reloadSnapshot,
                                onOpenFocus: _openFocusTarget,
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          const _WorkspaceContextStrip(),
                          const SizedBox(height: 16),
                          if (!AppConfig.useMockData)
                            const _RemoteModeGuideCard(),
                          if (!AppConfig.useMockData)
                            const SizedBox(height: 16),
                          if (!AppConfig.useMockData)
                            const _RemoteWorkspaceProbeCard(),
                          const SizedBox(height: 24),
                          _WorkspaceEntryStrip(
                              onCreateDocument: _createDocumentFromHome),
                          const SizedBox(height: 24),
                          FutureBuilder<_WorkspaceSnapshot>(
                            future: _snapshotFuture,
                            builder: (context, snapshot) {
                              final cards = snapshot.data?.cards ??
                                  const <_SummaryCardData>[];
                              final recentTasks =
                                  snapshot.data?.tasks ?? const <_TaskData>[];
                              final visibleRecentTasks = recentTasks
                                  .where(
                                    (task) =>
                                        _recentTaskFilter ==
                                            _RecentTaskFilter.all ||
                                        task.action == _recentTaskFilter.action,
                                  )
                                  .toList(growable: false);
                              final sortedRecentTasks = _applyRecentTaskSort(
                                visibleRecentTasks,
                              );

                              return Column(
                                children: [
                                  if (snapshot.hasError)
                                    _WorkspaceLoadWarning(
                                      error: snapshot.error,
                                      onRetry: _reloadSnapshot,
                                    )
                                  else if (!snapshot.hasData)
                                    const _WorkspaceLoadingCard(),
                                  if (cards.isNotEmpty) ...[
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: cards
                                          .map(
                                            (card) => _SummaryCard(
                                              card: card,
                                              wide: wide,
                                              onTap: card.action ==
                                                      _WorkspaceCardAction.none
                                                  ? null
                                                  : () =>
                                                      _openSummaryCard(card),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  if (wide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: _RecentTasksPanel(
                                            tasks: recentTasks,
                                            visibleTasks: sortedRecentTasks,
                                            filter: _recentTaskFilter,
                                            sort: _recentTaskSort,
                                            onFilterChanged: (value) {
                                              setState(() {
                                                _recentTaskFilter = value;
                                              });
                                            },
                                            onSortChanged: (value) {
                                              setState(() {
                                                _recentTaskSort = value;
                                              });
                                            },
                                            onRefresh: _reloadSnapshot,
                                            onOpenTask: _openTask,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        const Expanded(
                                          flex: 2,
                                          child: _QuestionBasketPanel(),
                                        ),
                                      ],
                                    )
                                  else
                                    Column(
                                      children: [
                                        _RecentTasksPanel(
                                          tasks: recentTasks,
                                          visibleTasks: sortedRecentTasks,
                                          filter: _recentTaskFilter,
                                          sort: _recentTaskSort,
                                          onFilterChanged: (value) {
                                            setState(() {
                                              _recentTaskFilter = value;
                                            });
                                          },
                                          onSortChanged: (value) {
                                            setState(() {
                                              _recentTaskSort = value;
                                            });
                                          },
                                          onRefresh: _reloadSnapshot,
                                          onOpenTask: _openTask,
                                        ),
                                        const SizedBox(height: 16),
                                        const _QuestionBasketPanel(),
                                      ],
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 900
          ? const PrimaryNavigationBar(
              currentSection: PrimaryAppSection.home,
            )
          : null,
    );
  }

  List<_TaskData> _applyRecentTaskSort(List<_TaskData> tasks) {
    final sorted = tasks.toList(growable: true);
    switch (_recentTaskSort) {
      case _RecentTaskSort.title:
        sorted.sort(
          (left, right) => left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              ),
        );
        break;
      case _RecentTaskSort.type:
        sorted.sort((left, right) {
          final compare = _taskActionRank(left.action).compareTo(
            _taskActionRank(right.action),
          );
          if (compare != 0) {
            return compare;
          }
          return left.title.toLowerCase().compareTo(
                right.title.toLowerCase(),
              );
        });
        break;
      case _RecentTaskSort.recentOrder:
        break;
    }
    return sorted;
  }

  int _taskActionRank(_TaskAction action) {
    switch (action) {
      case _TaskAction.document:
        return 0;
      case _TaskAction.exports:
        return 1;
      case _TaskAction.basket:
        return 2;
      case _TaskAction.none:
        return 3;
    }
  }
}

class _RemoteWorkspaceProbeCard extends StatefulWidget {
  const _RemoteWorkspaceProbeCard();

  @override
  State<_RemoteWorkspaceProbeCard> createState() =>
      _RemoteWorkspaceProbeCardState();
}

class _RemoteWorkspaceProbeCardState extends State<_RemoteWorkspaceProbeCard> {
  late Future<_RemoteWorkspaceProbeResult> _probeFuture = _probe();

  Future<_RemoteWorkspaceProbeResult> _probe() async {
    final services = AppServices.instance;
    final questions = await services.questionRepository.listQuestions(
      filters: const LibraryFilterState(),
    );
    final documents = await services.documentRepository.listDocuments();
    return _RemoteWorkspaceProbeResult(
      questionCount: questions.length,
      documentCount: documents.length,
    );
  }

  void _reload() {
    setState(() {
      _probeFuture = _probe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = AppServices.instance.session != null;
    final hasTenant = AppServices.instance.activeTenant != null;
    final compact = MediaQuery.sizeOf(context).width < 640;
    return WorkspacePanel(
      padding: EdgeInsets.all(compact ? 14 : 20),
      child: FutureBuilder<_RemoteWorkspaceProbeResult>(
        future: _probeFuture,
        builder: (context, snapshot) {
          if (!hasSession || !hasTenant) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '工作区连通性探测',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 10),
                Text(
                  '当前还没有完整的远程上下文。先登录并选择租户后，这里会显示题库和文档工作区的真实加载结果。',
                  style: TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is HttpJsonException
                ? '连通性探测失败：${error.message}（HTTP ${error.statusCode}）'
                : '连通性探测失败：$error';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '工作区连通性探测',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    height: 1.5,
                    color: TelegramPalette.warningText,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: compact ? 8 : 10,
                  runSpacing: compact ? 8 : 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: Text(compact ? '探测' : '重新探测'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRouter.tenantSwitch),
                      icon: const Icon(Icons.apartment_outlined),
                      label: Text(compact ? '租户' : '切换租户'),
                    ),
                  ],
                ),
              ],
            );
          }

          if (!snapshot.hasData) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '工作区连通性探测',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                LinearProgressIndicator(),
              ],
            );
          }

          final result = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '工作区连通性探测',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                '工作区已经返回题库和文档数据，可以直接进入对应页面继续操作。',
                style: TextStyle(
                  height: 1.5,
                  color: TelegramPalette.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: compact ? 8 : 12,
                runSpacing: compact ? 8 : 12,
                children: [
                  _ContextChip(label: '题目数', value: '${result.questionCount}'),
                  _ContextChip(label: '文档数', value: '${result.documentCount}'),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: compact ? 8 : 10,
                runSpacing: compact ? 8 : 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => PrimaryNavigationBar.navigateToSection(
                      context,
                      PrimaryAppSection.library,
                      resetScrollOffset: true,
                    ),
                    icon: const Icon(Icons.search_outlined),
                    label: Text(compact ? '题库' : '进入题库'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => PrimaryNavigationBar.navigateToSection(
                      context,
                      PrimaryAppSection.documents,
                      resetScrollOffset: true,
                    ),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(compact ? '文档' : '进入文档'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: Text(compact ? '探测' : '重新探测'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RemoteWorkspaceProbeResult {
  const _RemoteWorkspaceProbeResult({
    required this.questionCount,
    required this.documentCount,
  });

  final int questionCount;
  final int documentCount;
}

class _RemoteModeGuideCard extends StatelessWidget {
  const _RemoteModeGuideCard();

  @override
  Widget build(BuildContext context) {
    final hasSession = AppServices.instance.session != null;
    final hasTenant = AppServices.instance.activeTenant != null;
    final compact = MediaQuery.sizeOf(context).width < 640;
    return WorkspacePanel(
      padding: EdgeInsets.all(compact ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '连接真实工作区',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            hasSession && hasTenant
                ? '当前已经具备账号和工作区上下文，可以直接进入题库和文档区处理真实数据。'
                : '要加载真实题库和文档，先登录账号，再选择要进入的工作区。',
            style: const TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.login),
                icon: const Icon(Icons.login),
                label: Text(hasSession ? '重建会话' : '去登录'),
              ),
              FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.tenantSwitch),
                icon: const Icon(Icons.apartment_outlined),
                label: Text(hasTenant ? '切换租户' : '选择租户'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkspaceContextStrip extends StatelessWidget {
  const _WorkspaceContextStrip();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return WorkspacePanel(
      padding:
          workspacePanelPadding(context, mobile: 14, tablet: 16, desktop: 18),
      child: Wrap(
        spacing: compact ? 8 : 12,
        runSpacing: compact ? 8 : 12,
        children: [
          _ContextChip(label: '模式', value: AppConfig.dataModeLabel),
          _ContextChip(
            label: '会话',
            value: AppServices.instance.session?.username ?? '未登录',
          ),
          _ContextChip(
            label: '租户',
            value: AppServices.instance.activeTenant?.code ?? '未选择租户',
          ),
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

class _WorkspaceRail extends StatelessWidget {
  const _WorkspaceRail();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        decoration: BoxDecoration(
          color: TelegramPalette.shellDeep,
          border: Border(
            right: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ShiTi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '教研工作台',
              style: TextStyle(color: Color(0xFF9FC7EA)),
            ),
            const SizedBox(height: 32),
            ...const [
              _RailItem(
                  icon: Icons.dashboard_outlined, label: '工作台', active: true),
              _RailItem(icon: Icons.search_outlined, label: '题库检索'),
              _RailItem(
                  icon: Icons.collections_bookmark_outlined, label: '选题篮'),
              _RailItem(icon: Icons.description_outlined, label: '讲义与试卷'),
              _RailItem(icon: Icons.cloud_outlined, label: '导出记录'),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Text(
                '移动端、网页端、桌面端共用一套 Flutter 工作台交互。',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: active ? TelegramPalette.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: active ? Colors.white : TelegramPalette.borderAccent),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : TelegramPalette.surfaceAccent,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.wide,
    required this.snapshot,
    required this.onRefresh,
    required this.onOpenFocus,
  });

  final bool wide;
  final AsyncSnapshot<_WorkspaceSnapshot> snapshot;
  final VoidCallback onRefresh;
  final ValueChanged<_WorkspaceFocusTarget> onOpenFocus;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: workspaceHeroPanelPadding(context),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF7FBFF),
            TelegramPalette.surfaceAccent,
            Color(0xFFE4F1FC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: wide
          ? Row(
              children: [
                const Expanded(child: _HeroCopy()),
                SizedBox(width: compact ? 16 : 24),
                Expanded(
                  child: _HeroPanel(
                    snapshot: snapshot,
                    onRefresh: onRefresh,
                    onOpenFocus: onOpenFocus,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeroCopy(),
                SizedBox(height: compact ? 16 : 20),
                _HeroPanel(
                  snapshot: snapshot,
                  onRefresh: onRefresh,
                  onOpenFocus: onOpenFocus,
                ),
              ],
            ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkspaceEyebrow(
          label: '跨平台教研工作流',
          icon: Icons.auto_awesome_outlined,
        ),
        const SizedBox(height: 16),
        const Text(
          '把备题、整理、组卷和导出，收进同一套工作台。',
          style: TextStyle(
              fontSize: 34, fontWeight: FontWeight.w700, height: 1.15),
        ),
        const SizedBox(height: 14),
        const Text(
          '优先服务教研场景：按教材章节找题、维护选题篮、沉淀讲义结构，并跟踪导出结果。',
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: TelegramPalette.textMuted,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: compact ? 8 : 12,
          runSpacing: compact ? 8 : 12,
          children: [
            WorkspaceMetricPill(
              label: '运行模式',
              value: AppConfig.dataModeLabel,
              highlight: !AppConfig.useMockData,
            ),
            WorkspaceMetricPill(
              label: '当前会话',
              value: AppServices.instance.session?.username ?? '未登录',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: compact ? 8 : 12,
          runSpacing: compact ? 8 : 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.login);
              },
              icon: const Icon(Icons.login),
              label: Text(compact ? '登录' : '登录工作台'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                PrimaryNavigationBar.navigateToSection(
                  context,
                  PrimaryAppSection.library,
                  resetScrollOffset: true,
                );
              },
              icon: const Icon(Icons.search_outlined),
              label: Text(compact ? '题库' : '打开题库'),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkspaceEntryStrip extends StatelessWidget {
  const _WorkspaceEntryStrip({
    required this.onCreateDocument,
  });

  final VoidCallback onCreateDocument;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return WorkspacePanel(
      padding:
          workspacePanelPadding(context, mobile: 14, tablet: 16, desktop: 18),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: compact ? 10 : 16,
        runSpacing: compact ? 10 : 16,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '从首页就能继续备课、组题和导出',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  '题库、选题篮、文档工作区、导出记录和我的入口已经接通，找题、编排、导出和结果回看可以连续完成。',
                  style: TextStyle(
                    height: 1.45,
                    color: TelegramPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: compact ? 8 : 12,
            runSpacing: compact ? 8 : 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: onCreateDocument,
                icon: const Icon(Icons.note_add_outlined),
                label: Text(compact ? '新建' : '新建文档'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  PrimaryNavigationBar.navigateToSection(
                    context,
                    PrimaryAppSection.account,
                    resetScrollOffset: true,
                  );
                },
                icon: const Icon(Icons.person_outline),
                label: Text(compact ? '我的' : '我的账号'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.tenantSwitch);
                },
                icon: const Icon(Icons.apartment_outlined),
                label: Text(compact ? '租户' : '租户切换'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.basket);
                },
                icon: const Icon(Icons.collections_bookmark_outlined),
                label: const Text('选题篮'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  PrimaryNavigationBar.navigateToSection(
                    context,
                    PrimaryAppSection.documents,
                    resetScrollOffset: true,
                  );
                },
                icon: const Icon(Icons.description_outlined),
                label: Text(compact ? '文档' : '文档工作区'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  PrimaryNavigationBar.navigateToSection(
                    context,
                    PrimaryAppSection.exports,
                    resetScrollOffset: true,
                  );
                },
                icon: const Icon(Icons.cloud_outlined),
                label: Text(compact ? '导出' : '导出记录'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.snapshot,
    required this.onRefresh,
    required this.onOpenFocus,
  });

  final AsyncSnapshot<_WorkspaceSnapshot> snapshot;
  final VoidCallback onRefresh;
  final ValueChanged<_WorkspaceFocusTarget> onOpenFocus;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final data = snapshot.data;
    final hasError = snapshot.hasError;
    final error = snapshot.error;
    final focusTitle =
        hasError ? '工作台快照加载失败' : data?.focusTitle ?? '正在同步工作台快照...';
    final basketLabel = hasError ? '需处理' : data?.focusBasketLabel ?? '--';
    final documentLabel = hasError ? '需处理' : data?.focusDocumentLabel ?? '--';
    final exportLabel = hasError ? '需处理' : data?.focusExportLabel ?? '--';
    final errorMessage = _workspaceLoadMessage(error);
    return Container(
      padding: workspacePanelPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前聚焦',
            style: TextStyle(fontSize: 12, color: TelegramPalette.textSoft),
          ),
          const SizedBox(height: 8),
          Text(
            focusTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (hasError) ...[
            const SizedBox(height: 10),
            Text(
              errorMessage,
              style: const TextStyle(
                height: 1.45,
                color: TelegramPalette.warningText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: compact ? 8 : 10,
              runSpacing: compact ? 8 : 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRouter.login);
                  },
                  icon: const Icon(Icons.login),
                  label: Text(compact ? '登录' : '重新登录'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRouter.tenantSwitch);
                  },
                  icon: const Icon(Icons.apartment_outlined),
                  label: Text(compact ? '租户' : '切换租户'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(compact ? '刷新' : '刷新工作台'),
            ),
          ),
          const SizedBox(height: 16),
          _FocusMetric(
            label: '选题篮',
            value: basketLabel,
            onTap: () => onOpenFocus(_WorkspaceFocusTarget.basket),
          ),
          _FocusMetric(
            label: '文档',
            value: documentLabel,
            onTap: () => onOpenFocus(_WorkspaceFocusTarget.documents),
          ),
          _FocusMetric(
            label: '最近导出',
            value: exportLabel,
            onTap: () => onOpenFocus(_WorkspaceFocusTarget.exports),
          ),
        ],
      ),
    );
  }
}

String _workspaceLoadMessage(Object? error) {
  if (error is HttpJsonException) {
    if (error.statusCode == 401) {
      return '当前会话已经失效。请重新登录后再同步工作台快照。';
    }
    if (error.statusCode == 403) {
      return '当前租户下没有足够权限读取题库或文档。请切换到有权限的租户，或先补齐成员权限。';
    }
    return '工作台快照加载失败：${error.message}（HTTP ${error.statusCode}）';
  }
  if (error == null) {
    return '正在同步题库、文档和导出快照。';
  }
  return '工作台快照加载失败：$error';
}

class _FocusMetric extends StatelessWidget {
  const _FocusMetric({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: const TextStyle(color: TelegramPalette.textSoft)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (onTap != null) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: TelegramPalette.textSoft,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _WorkspaceFocusTarget {
  none,
  basket,
  documents,
  exports,
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.detail,
    this.action = _WorkspaceCardAction.none,
  });

  final String title;
  final String value;
  final String detail;
  final _WorkspaceCardAction action;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.card,
    required this.wide,
    this.onTap,
  });

  final _SummaryCardData card;
  final bool wide;
  final VoidCallback? onTap;

  String? _actionLabel() {
    switch (card.action) {
      case _WorkspaceCardAction.library:
        return '打开题库';
      case _WorkspaceCardAction.documents:
        return '打开文档工作区';
      case _WorkspaceCardAction.exports:
        return '打开导出记录';
      case _WorkspaceCardAction.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final actionLabel = _actionLabel();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: wide ? 240 : double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.title,
                style: const TextStyle(
                  color: TelegramPalette.textSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                card.value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(card.detail, style: const TextStyle(height: 1.45)),
              if (onTap != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (actionLabel != null)
                      Text(
                        compact ? actionLabel.split(' ').first : actionLabel,
                        style: const TextStyle(
                          color: TelegramPalette.textSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const Icon(
                      Icons.chevron_right,
                      color: TelegramPalette.textSoft,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _WorkspaceCardAction {
  none,
  library,
  documents,
  exports,
}

class _RecentTasksPanel extends StatelessWidget {
  const _RecentTasksPanel({
    required this.tasks,
    required this.visibleTasks,
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onRefresh,
    required this.onOpenTask,
  });

  final List<_TaskData> tasks;
  final List<_TaskData> visibleTasks;
  final _RecentTaskFilter filter;
  final _RecentTaskSort sort;
  final ValueChanged<_RecentTaskFilter> onFilterChanged;
  final ValueChanged<_RecentTaskSort> onSortChanged;
  final VoidCallback onRefresh;
  final ValueChanged<_TaskData> onOpenTask;

  List<(String, String)> get _activeFilterEntries {
    final entries = <(String, String)>[];
    if (filter != _RecentTaskFilter.all) {
      entries.add(('类型', filter.label));
    }
    if (sort != _RecentTaskSort.recentOrder) {
      entries.add(('排序', sort.label));
    }
    return entries;
  }

  int get _visibleDocumentTaskCount =>
      visibleTasks.where((task) => task.action == _TaskAction.document).length;

  int get _visibleExportTaskCount =>
      visibleTasks.where((task) => task.action == _TaskAction.exports).length;

  int get _visibleBasketTaskCount =>
      visibleTasks.where((task) => task.action == _TaskAction.basket).length;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final desktopWide = MediaQuery.sizeOf(context).width >= 1180;
    return Container(
      padding: workspacePanelPadding(context),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '最近任务',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '刷新最近任务',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final filterChips = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _RecentTaskFilter.values
                    .map(
                      (entry) => _RecentTaskFilterPill(
                        label: entry.label,
                        selected: filter == entry,
                        onTap: () => onFilterChanged(entry),
                      ),
                    )
                    .toList(),
              );
              final sortControl = SizedBox(
                width: compact ? double.infinity : 220,
                child: DropdownButtonFormField<_RecentTaskSort>(
                  initialValue: sort,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '排序',
                  ),
                  items: _RecentTaskSort.values
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry,
                          child: Text(entry.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onSortChanged(value);
                    }
                  },
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    filterChips,
                    const SizedBox(height: 16),
                    sortControl,
                  ],
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  filterChips,
                  sortControl,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (desktopWide)
            const Text(
              '任务摘要',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: TelegramPalette.textMuted,
              ),
            ),
          if (desktopWide) const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              WorkspaceMetricPill(
                  label: '当前结果任务', value: '${visibleTasks.length}'),
              WorkspaceMetricPill(label: '总任务', value: '${tasks.length}'),
              WorkspaceMetricPill(
                label: '文档',
                value: '$_visibleDocumentTaskCount',
              ),
              WorkspaceMetricPill(
                label: '导出',
                value: '$_visibleExportTaskCount',
              ),
              WorkspaceMetricPill(
                label: '选题篮',
                value: '$_visibleBasketTaskCount',
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
              spacing: 10,
              runSpacing: 10,
              children: _activeFilterEntries
                  .map(
                    (entry) => WorkspaceMetricPill(
                      label: entry.$1,
                      value: entry.$2,
                      highlight: true,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          if (desktopWide)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                '任务列表',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: TelegramPalette.textMuted,
                ),
              ),
            ),
          if (visibleTasks.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前筛选下没有匹配的最近任务。',
                  style: TextStyle(color: TelegramPalette.textSoft),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    onFilterChanged(_RecentTaskFilter.all);
                    onSortChanged(_RecentTaskSort.recentOrder);
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: Text(compact ? '恢复默认' : '恢复默认视图'),
                ),
              ],
            ),
          ...visibleTasks.map(
            (task) => _TaskRow(
              task: task,
              onTap: task.action == _TaskAction.none
                  ? null
                  : () => onOpenTask(task),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    this.onTap,
  });

  final _TaskData task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: TelegramPalette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(task.detail,
                          style:
                              const TextStyle(color: TelegramPalette.textSoft)),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right,
                    color: TelegramPalette.textSoft,
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

enum _TaskAction {
  none,
  document,
  exports,
  basket,
}

enum _RecentTaskFilter {
  all('全部'),
  document('文档'),
  exports('导出'),
  basket('选题篮');

  const _RecentTaskFilter(this.label);

  final String label;

  _TaskAction? get action {
    switch (this) {
      case _RecentTaskFilter.all:
        return null;
      case _RecentTaskFilter.document:
        return _TaskAction.document;
      case _RecentTaskFilter.exports:
        return _TaskAction.exports;
      case _RecentTaskFilter.basket:
        return _TaskAction.basket;
    }
  }
}

enum _RecentTaskSort {
  recentOrder('最近优先'),
  title('按标题'),
  type('按类型');

  const _RecentTaskSort(this.label);

  final String label;
}

class _RecentTaskFilterPill extends StatelessWidget {
  const _RecentTaskFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        selected ? TelegramPalette.accentDark : TelegramPalette.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? TelegramPalette.surfaceAccent
                : TelegramPalette.highlight,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: TelegramPalette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: foregroundColor,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskData {
  const _TaskData({
    required this.title,
    required this.detail,
    this.action = _TaskAction.none,
    this.document,
    this.focusJobId,
  });

  final String title;
  final String detail;
  final _TaskAction action;
  final DocumentSummary? document;
  final String? focusJobId;
}

class _WorkspaceSnapshot {
  const _WorkspaceSnapshot({
    required this.cards,
    required this.tasks,
    required this.focusTitle,
    required this.focusBasketLabel,
    required this.focusDocumentLabel,
    required this.focusExportLabel,
    required this.questionCount,
    required this.documentCount,
    required this.basketCount,
  });

  final List<_SummaryCardData> cards;
  final List<_TaskData> tasks;
  final String focusTitle;
  final String focusBasketLabel;
  final String focusDocumentLabel;
  final String focusExportLabel;
  final int questionCount;
  final int documentCount;
  final int basketCount;
}

class _WorkspaceLoadingCard extends StatelessWidget {
  const _WorkspaceLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: WorkspacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '正在同步工作台快照...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceLoadWarning extends StatelessWidget {
  const _WorkspaceLoadWarning({
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final rawError = error;
    final message = rawError is HttpJsonException
        ? '工作台快照加载失败：${rawError.message}（HTTP ${rawError.statusCode}）'
        : '工作台快照加载失败：$rawError';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: WorkspacePanel(
        backgroundColor: TelegramPalette.surfaceSoft,
        padding: workspacePanelPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '工作台快照',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                height: 1.5,
                color: TelegramPalette.warningText,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(compact ? '同步' : '重新同步'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionBasketPanel extends StatefulWidget {
  const _QuestionBasketPanel();

  @override
  State<_QuestionBasketPanel> createState() => _QuestionBasketPanelState();
}

class _QuestionBasketPanelState extends State<_QuestionBasketPanel> {
  late Future<List<QuestionSummary>> _basketFuture = _loadBasket();

  Future<List<QuestionSummary>> _loadBasket() {
    return AppServices.instance.questionRepository.listBasketQuestions();
  }

  void _reload() {
    setState(() {
      _basketFuture = _loadBasket();
    });
  }

  Future<void> _openBasket() async {
    await Navigator.of(context).pushNamed(AppRouter.basket);
    if (!mounted) {
      return;
    }
    _reload();
  }

  Future<void> _openLibrary() async {
    PrimaryNavigationBar.navigateToSection(
      context,
      PrimaryAppSection.library,
      resetScrollOffset: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final desktopWide = MediaQuery.sizeOf(context).width >= 1180;
    return Container(
      padding: workspacePanelPadding(context),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: FutureBuilder<List<QuestionSummary>>(
        future: _basketFuture,
        builder: (context, snapshot) {
          final questions = snapshot.data ?? const <QuestionSummary>[];
          final questionCount = questions.length;
          final averageDifficulty = questionCount == 0
              ? 0.0
              : questions
                      .map((question) => question.difficulty)
                      .reduce((left, right) => left + right) /
                  questionCount;
          final chapterCounts = <String, int>{};
          final subjectCounts = <String, int>{};
          for (final question in questions) {
            final chapter =
                question.chapter.trim().isEmpty ? '未标注章节' : question.chapter;
            chapterCounts.update(chapter, (value) => value + 1,
                ifAbsent: () => 1);
            final subject =
                question.subject.trim().isEmpty ? '未标注学科' : question.subject;
            subjectCounts.update(subject, (value) => value + 1,
                ifAbsent: () => 1);
          }
          final topChapters = chapterCounts.entries.toList()
            ..sort((left, right) => right.value.compareTo(left.value));
          final topSubjects = subjectCounts.entries.toList()
            ..sort((left, right) => right.value.compareTo(left.value));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '选题篮',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: '刷新选题篮',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!snapshot.hasData)
                const Text('正在同步当前选题篮状态...')
              else ...[
                if (desktopWide)
                  const Text(
                    '当前摘要',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: TelegramPalette.textMuted,
                    ),
                  ),
                if (desktopWide) const SizedBox(height: 8),
                Text(
                  questionCount == 0
                      ? '当前选题篮为空。'
                      : '当前已选 $questionCount 题，平均难度 ${averageDifficulty.toStringAsFixed(1)}。',
                ),
                if (questionCount > 0) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      WorkspaceMetricPill(
                          label: '已选题目', value: '$questionCount'),
                      WorkspaceMetricPill(
                        label: '平均难度',
                        value: averageDifficulty.toStringAsFixed(1),
                      ),
                      if (topSubjects.isNotEmpty)
                        WorkspaceMetricPill(
                          label: '高频学科',
                          value: topSubjects.first.key,
                        ),
                      if (topChapters.isNotEmpty)
                        WorkspaceMetricPill(
                          label: '高频章节',
                          value: topChapters.first.key,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (desktopWide)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '下一步',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: TelegramPalette.textMuted,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _openLibrary,
                      icon: const Icon(Icons.travel_explore_outlined),
                      label: Text(compact ? '挑题' : '继续挑题'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openBasket,
                      icon: const Icon(Icons.collections_bookmark_outlined),
                      label: Text(compact ? '选题篮' : '查看选题篮'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (questionCount == 0)
                  const Text(
                    '建议先从题库按教材、章节或关键词收题，再回到这里做批量编排。',
                    style: TextStyle(
                      height: 1.5,
                      color: TelegramPalette.textMuted,
                    ),
                  )
                else ...[
                  const Text('按学科分布：'),
                  const SizedBox(height: 8),
                  ...topSubjects.take(3).map(
                        (entry) => Text('${entry.key} ${entry.value} 题'),
                      ),
                  const SizedBox(height: 12),
                  const Text('按章节分布：'),
                  const SizedBox(height: 8),
                  ...topChapters.take(3).map(
                        (entry) => Text('${entry.key} ${entry.value} 题'),
                      ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
