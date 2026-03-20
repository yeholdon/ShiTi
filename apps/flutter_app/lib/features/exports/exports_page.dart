import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_item_summary.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/export_detail_args.dart';
import '../../core/models/export_job_summary.dart';
import '../../core/models/exports_page_args.dart';
import '../../core/models/layout_element_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../documents/create_document_dialog.dart';
import '../shared/primary_page_scroll_memory.dart';
import '../shared/primary_page_view_state_memory.dart';
import '../shared/primary_navigation_bar.dart';
import '../shared/workspace_shell.dart';

class ExportsPage extends StatefulWidget {
  const ExportsPage({
    super.key,
    this.args,
  });

  final ExportsPageArgs? args;

  @override
  State<ExportsPage> createState() => _ExportsPageState();
}

class _ExportsPageState extends State<ExportsPage> {
  static const _pageKey = 'exports';
  late Future<List<ExportJobSummary>> _jobsFuture =
      AppServices.instance.documentRepository.listExportJobs();
  Timer? _refreshTimer;
  final TextEditingController _queryController = TextEditingController();
  late final ScrollController _scrollController = ScrollController(
    initialScrollOffset:
        _hasContextualReturn ? 0 : PrimaryPageScrollMemory.offsetFor(_pageKey),
  );
  String? _retryingJobId;
  String? _cancelingJobId;
  String? _duplicatingJobId;
  Set<String> _selectedJobIds = <String>{};
  bool _retryingSelected = false;
  bool _cancelingSelected = false;
  bool _duplicatingSelectedDocuments = false;
  bool _showOnlySelectedJobs = false;
  bool _showOnlyCurrentDocument = false;
  String _query = '';
  String _statusFilter = 'all';
  String _formatFilter = 'all';
  String _sortBy = 'queue';
  List<ExportJobSummary> _latestJobs = const <ExportJobSummary>[];
  DocumentSummary? _snapshotOverride;
  final Map<String, GlobalKey> _jobKeys = <String, GlobalKey>{};
  String? _lastScrolledJobId;
  bool get _hasContextualReturn =>
      widget.args?.documentSnapshot != null ||
      ((widget.args?.focusDocumentName ?? '').trim().isNotEmpty) ||
      ((widget.args?.focusJobId ?? '').trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_rememberScrollOffset);
    final savedViewState = PrimaryPageViewStateMemory.exports;
    if (!_hasContextualReturn && savedViewState != null) {
      _query = savedViewState.query;
      _statusFilter = savedViewState.statusFilter;
      _formatFilter = savedViewState.formatFilter;
      _sortBy = savedViewState.sortBy;
      _showOnlySelectedJobs = savedViewState.showOnlySelectedJobs;
      _queryController.text = savedViewState.query;
    }
    _showOnlyCurrentDocument = _hasContextualReturn ||
        (!_hasContextualReturn &&
            (savedViewState?.showOnlyCurrentDocument ?? false));
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) {
        if (mounted) {
          _reload();
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _rememberScrollOffset() {
    PrimaryPageScrollMemory.update(_pageKey, _scrollController.offset);
  }

  void _rememberViewState() {
    PrimaryPageViewStateMemory.exports = PrimaryExportsViewState(
      query: _query,
      statusFilter: _statusFilter,
      formatFilter: _formatFilter,
      sortBy: _sortBy,
      showOnlySelectedJobs: _showOnlySelectedJobs,
      showOnlyCurrentDocument: _showOnlyCurrentDocument,
    );
  }

  void _reload() {
    setState(() {
      _jobsFuture = AppServices.instance.documentRepository.listExportJobs();
    });
  }

  GlobalKey _keyForJob(String jobId) {
    return _jobKeys.putIfAbsent(jobId, GlobalKey.new);
  }

  void _scheduleFocusedJobScroll(List<ExportJobSummary> filteredJobs) {
    if (!_hasContextualReturn || filteredJobs.isEmpty) {
      return;
    }

    String? targetJobId = widget.args?.focusJobId;
    if (targetJobId == null || targetJobId.isEmpty) {
      for (final job in filteredJobs) {
        if (_isHighlighted(job)) {
          targetJobId = job.id;
          break;
        }
      }
    }
    if (targetJobId == null ||
        targetJobId.isEmpty ||
        _lastScrolledJobId == targetJobId) {
      return;
    }

    final targetIndex = filteredJobs.indexWhere((job) => job.id == targetJobId);
    if (targetIndex == -1) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetContext = _keyForJob(targetJobId!).currentContext;
      _lastScrolledJobId = targetJobId;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
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
      final ratio = filteredJobs.length <= 1
          ? 0.0
          : targetIndex / (filteredJobs.length - 1);
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

  List<ExportJobSummary> _applyFilters(List<ExportJobSummary> jobs) {
    final normalizedQuery = _query.trim().toLowerCase();
    final currentSnapshot = _currentDocumentSnapshot();
    final filtered = jobs.where((job) {
      if (_showOnlySelectedJobs && !_selectedJobIds.contains(job.id)) {
        return false;
      }
      if (_showOnlyCurrentDocument && currentSnapshot != null) {
        final matchesCurrentDocument = job.documentId != null
            ? job.documentId == currentSnapshot.id
            : job.documentName == currentSnapshot.name;
        if (!matchesCurrentDocument) {
          return false;
        }
      }
      if (_statusFilter != 'all' && job.status != _statusFilter) {
        return false;
      }
      if (_formatFilter != 'all' && job.format != _formatFilter) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return <String>[
        job.documentName,
        job.id,
        job.format,
      ].any((value) => value.toLowerCase().contains(normalizedQuery));
    }).toList(growable: false);
    return _applySort(filtered);
  }

  void _openWorkspace() {
    PrimaryNavigationBar.navigateToSection(context, PrimaryAppSection.home);
  }

  List<ExportJobSummary> _applySort(List<ExportJobSummary> jobs) {
    final sorted = jobs.toList(growable: true);
    switch (_sortBy) {
      case 'document_name':
        sorted.sort(
          (left, right) => left.documentName.toLowerCase().compareTo(
                right.documentName.toLowerCase(),
              ),
        );
        break;
      case 'status':
        sorted.sort((left, right) {
          final compare = _exportStatusRank(left.status).compareTo(
            _exportStatusRank(right.status),
          );
          if (compare != 0) {
            return compare;
          }
          return left.documentName.toLowerCase().compareTo(
                right.documentName.toLowerCase(),
              );
        });
        break;
      case 'format':
        sorted.sort((left, right) {
          final compare = left.format.toLowerCase().compareTo(
                right.format.toLowerCase(),
              );
          if (compare != 0) {
            return compare;
          }
          return left.documentName.toLowerCase().compareTo(
                right.documentName.toLowerCase(),
              );
        });
        break;
      case 'queue':
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
      case 'canceled':
        return 3;
      case 'succeeded':
        return 4;
      default:
        return 5;
    }
  }

  void _clearFilters() {
    _queryController.clear();
    setState(() {
      _query = '';
      _statusFilter = 'all';
      _formatFilter = 'all';
      _sortBy = 'queue';
      _showOnlySelectedJobs = false;
      _showOnlyCurrentDocument = false;
    });
    _rememberViewState();
  }

  void _patchJobLocally(ExportJobSummary updatedJob) {
    final index = _latestJobs.indexWhere((job) => job.id == updatedJob.id);
    if (index < 0) {
      return;
    }

    _latestJobs = <ExportJobSummary>[
      ..._latestJobs.take(index),
      updatedJob,
      ..._latestJobs.skip(index + 1),
    ];

    final currentSnapshot = _currentDocumentSnapshot();
    if (currentSnapshot == null) {
      return;
    }

    final sameDocument = updatedJob.documentId != null
        ? updatedJob.documentId == currentSnapshot.id
        : updatedJob.documentName == currentSnapshot.name;
    if (!sameDocument) {
      return;
    }

    _snapshotOverride = currentSnapshot.copyWith(
      latestExportStatus: updatedJob.status,
      latestExportJobId: updatedJob.id,
    );
  }

  void _setSelection(String jobId, bool selected) {
    setState(() {
      if (selected) {
        _selectedJobIds.add(jobId);
      } else {
        _selectedJobIds.remove(jobId);
      }
    });
  }

  void _selectAllFiltered(List<ExportJobSummary> filteredJobs) {
    setState(() {
      _selectedJobIds = filteredJobs.map((job) => job.id).toSet();
    });
  }

  void _selectJobsByStatuses(
    List<ExportJobSummary> filteredJobs,
    Set<String> statuses,
  ) {
    setState(() {
      _selectedJobIds = filteredJobs
          .where((job) => statuses.contains(job.status))
          .map((job) => job.id)
          .toSet();
    });
  }

  void _selectJobsByFormats(
    List<ExportJobSummary> filteredJobs,
    Set<String> formats,
  ) {
    setState(() {
      _selectedJobIds = filteredJobs
          .where((job) => formats.contains(job.format))
          .map((job) => job.id)
          .toSet();
    });
  }

  void _invertFilteredSelection(List<ExportJobSummary> filteredJobs) {
    setState(() {
      final nextSelection = <String>{..._selectedJobIds};
      for (final job in filteredJobs) {
        if (nextSelection.contains(job.id)) {
          nextSelection.remove(job.id);
        } else {
          nextSelection.add(job.id);
        }
      }
      _selectedJobIds = nextSelection;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedJobIds.clear();
    });
  }

  Future<void> _retryJob(ExportJobSummary job) async {
    setState(() {
      _retryingJobId = job.id;
      _patchJobLocally(
        job.copyWith(
          status: 'pending',
          updatedAtLabel: '刚刚重试',
        ),
      );
    });

    try {
      final retried =
          await AppServices.instance.documentRepository.retryExportJob(
        jobId: job.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已重新发起导出：${retried.documentName}')),
      );
      setState(() {
        _patchJobLocally(retried);
        _jobsFuture = AppServices.instance.documentRepository.listExportJobs();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '再次导出失败：${error.message}（HTTP ${error.statusCode}）'
          : '再次导出失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _retryingJobId = null;
        });
      }
    }
  }

  Future<void> _cancelJob(ExportJobSummary job) async {
    setState(() {
      _cancelingJobId = job.id;
      _patchJobLocally(
        job.copyWith(
          status: 'canceled',
          updatedAtLabel: '刚刚取消',
        ),
      );
    });

    try {
      final canceled =
          await AppServices.instance.documentRepository.cancelExportJob(
        jobId: job.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已取消导出：${canceled.documentName}')),
      );
      setState(() {
        _patchJobLocally(canceled);
        _jobsFuture = AppServices.instance.documentRepository.listExportJobs();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '取消导出失败：${error.message}（HTTP ${error.statusCode}）'
          : '取消导出失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancelingJobId = null;
        });
      }
    }
  }

  Future<void> _retrySelectedJobs(List<ExportJobSummary> filteredJobs) async {
    final selectedRetryableJobs = filteredJobs
        .where(
          (job) =>
              _selectedJobIds.contains(job.id) &&
              (job.status == 'failed' || job.status == 'canceled'),
        )
        .toList(growable: false);
    if (selectedRetryableJobs.isEmpty || _retryingSelected) {
      if (_selectedJobIds.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已选任务里没有可重试的失败或已取消任务')),
        );
      }
      return;
    }

    setState(() {
      _retryingSelected = true;
      for (final job in selectedRetryableJobs) {
        _patchJobLocally(
          job.copyWith(
            status: 'pending',
            updatedAtLabel: '刚刚重试',
          ),
        );
      }
    });
    try {
      for (final job in selectedRetryableJobs) {
        final retried =
            await AppServices.instance.documentRepository.retryExportJob(
          jobId: job.id,
        );
        _patchJobLocally(retried);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedJobIds.clear();
        _jobsFuture = AppServices.instance.documentRepository.listExportJobs();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已批量重试 ${selectedRetryableJobs.length} 个失败或已取消任务'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '批量重试失败：${error.message}（HTTP ${error.statusCode}）'
          : '批量重试失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      _reload();
    } finally {
      if (mounted) {
        setState(() {
          _retryingSelected = false;
        });
      }
    }
  }

  Future<void> _cancelSelectedJobs(List<ExportJobSummary> filteredJobs) async {
    final selectedCancelableJobs = filteredJobs
        .where(
          (job) =>
              _selectedJobIds.contains(job.id) &&
              (job.status == 'pending' || job.status == 'running'),
        )
        .toList(growable: false);
    if (selectedCancelableJobs.isEmpty || _cancelingSelected) {
      if (_selectedJobIds.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已选任务里没有可取消的进行中任务')),
        );
      }
      return;
    }

    setState(() {
      _cancelingSelected = true;
      for (final job in selectedCancelableJobs) {
        _patchJobLocally(
          job.copyWith(
            status: 'canceled',
            updatedAtLabel: '刚刚取消',
          ),
        );
      }
    });
    try {
      for (final job in selectedCancelableJobs) {
        final canceled =
            await AppServices.instance.documentRepository.cancelExportJob(
          jobId: job.id,
        );
        _patchJobLocally(canceled);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedJobIds.clear();
        _jobsFuture = AppServices.instance.documentRepository.listExportJobs();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已批量取消 ${selectedCancelableJobs.length} 个导出任务')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '批量取消失败：${error.message}（HTTP ${error.statusCode}）'
          : '批量取消失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      _reload();
    } finally {
      if (mounted) {
        setState(() {
          _cancelingSelected = false;
        });
      }
    }
  }

  Future<void> _duplicateSelectedDocuments(
    List<ExportJobSummary> filteredJobs,
  ) async {
    if (_duplicatingSelectedDocuments) {
      return;
    }
    final selectedDocumentJobs = <String, ExportJobSummary>{};
    for (final job in filteredJobs) {
      final documentId = job.documentId;
      if (!_selectedJobIds.contains(job.id) ||
          documentId == null ||
          documentId.isEmpty) {
        continue;
      }
      selectedDocumentJobs.putIfAbsent(documentId, () => job);
    }
    if (selectedDocumentJobs.isEmpty) {
      if (_selectedJobIds.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已选任务里没有可复制的源文档')),
        );
      }
      return;
    }

    setState(() {
      _duplicatingSelectedDocuments = true;
    });
    try {
      final layoutElements =
          await AppServices.instance.documentRepository.listLayoutElements();
      final createdDocuments = <DocumentSummary>[];
      for (final entry in selectedDocumentJobs.entries) {
        final documentId = entry.key;
        final job = entry.value;
        final sourceDocument = await AppServices.instance.documentRepository
            .getDocument(documentId);
        final targetDocument =
            await AppServices.instance.documentRepository.createDocument(
          name: '${(sourceDocument?.name ?? job.documentName)} 副本',
          kind: sourceDocument?.kind ?? 'handout',
        );
        final items = await AppServices.instance.documentRepository
            .listDocumentItems(documentId);
        for (final item in items) {
          await _copyDocumentItemToDocument(
            item: item,
            targetDocumentId: targetDocument.id,
            layoutElements: layoutElements,
          );
        }
        createdDocuments.add(targetDocument);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedJobIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已批量创建 ${createdDocuments.length} 份文档副本')),
      );
      if (createdDocuments.isNotEmpty) {
        final result = await Navigator.of(context).pushNamed(
          AppRouter.documentDetail,
          arguments: DocumentDetailArgs(
            documentId: createdDocuments.first.id,
          ),
        );
        if (!mounted || result is! DocumentSummary) {
          return;
        }
        setState(() {
          _snapshotOverride = result;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '批量复制源文档失败：${error.message}（HTTP ${error.statusCode}）'
          : '批量复制源文档失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _duplicatingSelectedDocuments = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDocumentSnapshot = _currentDocumentSnapshot();
    final filteredJobs = _applyFilters(_latestJobs);
    final hasReturnDocumentContext = widget.args?.documentSnapshot != null ||
        ((widget.args?.focusDocumentName ?? '').isNotEmpty);
    final showPrimaryNavigation = !hasReturnDocumentContext;
    return Scaffold(
      appBar: AppBar(
        title: const Text('导出记录'),
        leading: hasReturnDocumentContext
            ? BackButton(
                onPressed: () =>
                    Navigator.of(context).pop(currentDocumentSnapshot),
              )
            : null,
      ),
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: hasReturnDocumentContext
              ? PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (_, __) {
                    if (!mounted) {
                      return;
                    }
                    Navigator.of(context).pop(_currentDocumentSnapshot());
                  },
                  child: _buildPageBody(
                    currentDocumentSnapshot: currentDocumentSnapshot,
                    filteredJobs: filteredJobs,
                  ),
                )
              : _buildPageBody(
                  currentDocumentSnapshot: currentDocumentSnapshot,
                  filteredJobs: filteredJobs,
                ),
        ),
      ),
      bottomNavigationBar:
          MediaQuery.of(context).size.width < 900 && showPrimaryNavigation
              ? const PrimaryNavigationBar(
                  currentSection: PrimaryAppSection.exports,
                )
              : null,
    );
  }

  Widget _buildPageBody({
    required DocumentSummary? currentDocumentSnapshot,
    required List<ExportJobSummary> filteredJobs,
  }) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final wideDesktop = MediaQuery.sizeOf(context).width >= 1280;
    return workspaceConstrainedContent(
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
                  child: _ExportsHeroStrip(
                    totalCount: _latestJobs.length,
                    selectedCount: _selectedJobIds.length,
                    currentDocumentName: currentDocumentSnapshot?.name,
                    onOpenWorkspace: _openWorkspace,
                  ),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: 320,
                  child: _ExportsStatusCard(
                    modeLabel: AppConfig.dataModeLabel,
                    sessionLabel:
                        AppServices.instance.session?.username ?? '未登录',
                    tenantLabel:
                        AppServices.instance.activeTenant?.code ?? '未选择租户',
                    onRefresh: _reload,
                  ),
                ),
              ],
            )
          else ...[
            _ExportsHeroStrip(
              totalCount: _latestJobs.length,
              selectedCount: _selectedJobIds.length,
              currentDocumentName: currentDocumentSnapshot?.name,
              onOpenWorkspace: _openWorkspace,
            ),
            const SizedBox(height: 18),
            _ExportsStatusCard(
              modeLabel: AppConfig.dataModeLabel,
              sessionLabel: AppServices.instance.session?.username ?? '未登录',
              tenantLabel: AppServices.instance.activeTenant?.code ?? '未选择租户',
              onRefresh: _reload,
            ),
          ],
          const SizedBox(height: 18),
          _ExportsHeader(
            queryController: _queryController,
            query: _query,
            statusFilter: _statusFilter,
            formatFilter: _formatFilter,
            sortBy: _sortBy,
            filteredJobCount: filteredJobs.length,
            filteredDocumentCount:
                filteredJobs.map((job) => job.documentId).toSet().length,
            filteredPdfCount:
                filteredJobs.where((job) => job.format == 'pdf').length,
            filteredDocxCount:
                filteredJobs.where((job) => job.format == 'docx').length,
            filteredPendingCount: filteredJobs
                .where(
                  (job) => job.status == 'pending' || job.status == 'running',
                )
                .length,
            filteredSucceededCount:
                filteredJobs.where((job) => job.status == 'succeeded').length,
            filteredRetryableCount: filteredJobs
                .where(
                  (job) => job.status == 'failed' || job.status == 'canceled',
                )
                .length,
            currentDocumentName: currentDocumentSnapshot?.name,
            showOnlyCurrentDocument: _showOnlyCurrentDocument,
            onQueryChanged: (value) {
              setState(() {
                _query = value;
              });
              _rememberViewState();
            },
            onStatusChanged: (value) {
              setState(() {
                _statusFilter = value;
              });
              _rememberViewState();
            },
            onFormatChanged: (value) {
              setState(() {
                _formatFilter = value;
              });
              _rememberViewState();
            },
            onSortChanged: (value) {
              setState(() {
                _sortBy = value;
              });
              _rememberViewState();
            },
            onShowOnlyCurrentDocumentChanged: (value) {
              setState(() {
                _showOnlyCurrentDocument = value;
              });
              _rememberViewState();
            },
            onClearFilters: _clearFilters,
          ),
          if (currentDocumentSnapshot != null) ...[
            const SizedBox(height: 18),
            _CurrentDocumentContextCard(
              documentName: currentDocumentSnapshot.name,
              showOnlyCurrentDocument: _showOnlyCurrentDocument,
              onOpenDocument: () {
                Navigator.of(context).pushNamed(
                  AppRouter.documentDetail,
                  arguments: DocumentDetailArgs(
                    documentId: currentDocumentSnapshot.id,
                    documentSnapshot: currentDocumentSnapshot,
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 18),
          FutureBuilder<List<ExportJobSummary>>(
            future: _jobsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                final message = error is HttpJsonException
                    ? '导出记录加载失败：${error.message}（HTTP ${error.statusCode}）'
                    : '导出记录加载失败：$error';
                return _ExportsErrorCard(
                  message: message,
                  onRetry: _reload,
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              _latestJobs = snapshot.data!;
              _selectedJobIds = _selectedJobIds
                  .where((id) => _latestJobs.any((job) => job.id == id))
                  .toSet();
              final filteredJobs = _applyFilters(snapshot.data!);
              _scheduleFocusedJobScroll(filteredJobs);
              if (snapshot.data!.isEmpty) {
                return WorkspacePanel(
                  padding: EdgeInsets.all(compact ? 14 : 20),
                  child: Text(
                    AppConfig.useMockData
                        ? '当前还没有导出记录。先在文档里发起一次导出，这里就会开始记录进度和结果。'
                        : '当前还没有导出记录。先在文档里发起导出，这里会同步显示真实任务状态和结果。',
                    style: const TextStyle(
                      height: 1.5,
                      color: TelegramPalette.textMuted,
                    ),
                  ),
                );
              }
              if (filteredJobs.isEmpty) {
                final showingOnlySelected = _showOnlySelectedJobs;
                final showingOnlyCurrentDocument = _showOnlyCurrentDocument;
                return WorkspacePanel(
                  padding: EdgeInsets.all(compact ? 14 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '当前没有可展示的导出任务。',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: TelegramPalette.textStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        showingOnlyCurrentDocument
                            ? '当前文档暂时还没有匹配的导出任务，可以先退出“只看当前文档”或回文档页发起新的导出。'
                            : showingOnlySelected
                                ? '可以先退出“只看已选”，或重新选择一批任务后再继续批量处理。'
                                : _query.trim().isEmpty
                                    ? '可以切换状态筛选，或清空筛选后查看全部导出记录。'
                                    : '可以调整关键词或状态筛选，重新定位目标导出任务。',
                        style: const TextStyle(
                          height: 1.5,
                          color: TelegramPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: showingOnlyCurrentDocument
                            ? () {
                                setState(() {
                                  _showOnlyCurrentDocument = false;
                                });
                                _rememberViewState();
                              }
                            : showingOnlySelected
                                ? () {
                                    setState(() {
                                      _showOnlySelectedJobs = false;
                                    });
                                    _rememberViewState();
                                  }
                                : _clearFilters,
                        icon: Icon(
                          showingOnlyCurrentDocument || showingOnlySelected
                              ? Icons.visibility_off_outlined
                              : Icons.filter_alt_off_outlined,
                        ),
                        label: Text(
                          showingOnlyCurrentDocument
                              ? (compact ? '退出当前文档' : '退出只看当前文档')
                              : showingOnlySelected
                                  ? '退出只看已选'
                                  : (compact ? '清空' : '清空筛选'),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final allFilteredSelected = filteredJobs.isNotEmpty &&
                  filteredJobs.every((job) => _selectedJobIds.contains(job.id));
              final retryableCount = filteredJobs
                  .where(
                    (job) => job.status == 'failed' || job.status == 'canceled',
                  )
                  .length;
              final cancelableCount = filteredJobs
                  .where((job) =>
                      job.status == 'pending' || job.status == 'running')
                  .length;
              final succeededCount =
                  filteredJobs.where((job) => job.status == 'succeeded').length;
              final canceledCount =
                  filteredJobs.where((job) => job.status == 'canceled').length;
              final pdfCount =
                  filteredJobs.where((job) => job.format == 'pdf').length;
              final docxCount =
                  filteredJobs.where((job) => job.format == 'docx').length;

              return Column(
                children: [
                  _ExportsSelectionBar(
                    selectedCount: _selectedJobIds.length,
                    selectedRetryableCount: filteredJobs
                        .where(
                          (job) =>
                              _selectedJobIds.contains(job.id) &&
                              (job.status == 'failed' ||
                                  job.status == 'canceled'),
                        )
                        .length,
                    selectedCancelableCount: filteredJobs
                        .where(
                          (job) =>
                              _selectedJobIds.contains(job.id) &&
                              (job.status == 'pending' ||
                                  job.status == 'running'),
                        )
                        .length,
                    selectedSucceededCount: filteredJobs
                        .where(
                          (job) =>
                              _selectedJobIds.contains(job.id) &&
                              job.status == 'succeeded',
                        )
                        .length,
                    selectedCanceledCount: filteredJobs
                        .where(
                          (job) =>
                              _selectedJobIds.contains(job.id) &&
                              job.status == 'canceled',
                        )
                        .length,
                    selectedDocumentCount: filteredJobs
                        .where((job) => _selectedJobIds.contains(job.id))
                        .map((job) => job.documentId)
                        .toSet()
                        .length,
                    selectedFormatCount: filteredJobs
                        .where((job) => _selectedJobIds.contains(job.id))
                        .map((job) => job.format)
                        .toSet()
                        .length,
                    filteredCount: filteredJobs.length,
                    selectedFilteredCount: filteredJobs
                        .where((job) => _selectedJobIds.contains(job.id))
                        .length,
                    allFilteredSelected: allFilteredSelected,
                    retryingSelected: _retryingSelected,
                    cancelingSelected: _cancelingSelected,
                    duplicatingSelectedDocuments: _duplicatingSelectedDocuments,
                    showOnlySelected: _showOnlySelectedJobs,
                    retryableCount: retryableCount,
                    cancelableCount: cancelableCount,
                    succeededCount: succeededCount,
                    canceledCount: canceledCount,
                    pdfCount: pdfCount,
                    docxCount: docxCount,
                    onSelectAll: () => _selectAllFiltered(filteredJobs),
                    onSelectRetryable: () => _selectJobsByStatuses(
                      filteredJobs,
                      const <String>{'failed', 'canceled'},
                    ),
                    onSelectCancelable: () => _selectJobsByStatuses(
                      filteredJobs,
                      const <String>{'pending', 'running'},
                    ),
                    onSelectSucceeded: () => _selectJobsByStatuses(
                      filteredJobs,
                      const <String>{'succeeded'},
                    ),
                    onSelectCanceled: () => _selectJobsByStatuses(
                      filteredJobs,
                      const <String>{'canceled'},
                    ),
                    onSelectPdf: () => _selectJobsByFormats(
                      filteredJobs,
                      const <String>{'pdf'},
                    ),
                    onSelectDocx: () => _selectJobsByFormats(
                      filteredJobs,
                      const <String>{'docx'},
                    ),
                    onInvertSelection: () =>
                        _invertFilteredSelection(filteredJobs),
                    onClearSelection: _clearSelection,
                    onShowOnlySelectedChanged: (value) {
                      setState(() {
                        _showOnlySelectedJobs = value;
                      });
                      _rememberViewState();
                    },
                    onDuplicateSelectedDocuments: () =>
                        _duplicateSelectedDocuments(filteredJobs),
                    onRetrySelected: () => _retrySelectedJobs(filteredJobs),
                    onCancelSelected: () => _cancelSelectedJobs(filteredJobs),
                  ),
                  const SizedBox(height: 12),
                  ...filteredJobs.map(
                    (job) => Padding(
                      key: _keyForJob(job.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ExportJobCard(
                        job: job,
                        isSelected: _selectedJobIds.contains(job.id),
                        highlighted: _isHighlighted(job),
                        retrying: _retryingJobId == job.id,
                        canceling: _cancelingJobId == job.id,
                        duplicatingDocument: _duplicatingJobId == job.id,
                        onShowDetail: () => _showDetail(job),
                        onOpenResult: () => _openResult(job),
                        onOpenDocument: () => _openDocument(job),
                        onDuplicateDocument: () => _duplicateDocument(job),
                        onRetry: () => _retryJob(job),
                        onCancel: () => _cancelJob(job),
                        onSelectionChanged: (selected) {
                          _setSelection(job.id, selected);
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openResult(ExportJobSummary job) async {
    final result = await Navigator.of(context).pushNamed(
      AppRouter.exportResult,
      arguments: ExportDetailArgs(
        job: job,
        documentSnapshot: _matchingDocumentSnapshot(job),
      ),
    );
    if (!mounted || result is! DocumentSummary) {
      return;
    }
    setState(() {
      _snapshotOverride = result;
    });
  }

  Future<void> _showDetail(ExportJobSummary job) async {
    final result = await Navigator.of(context).pushNamed(
      AppRouter.exportDetail,
      arguments: ExportDetailArgs(
        job: job,
        documentSnapshot: _matchingDocumentSnapshot(job),
      ),
    );
    if (!mounted || result is! DocumentSummary) {
      return;
    }
    setState(() {
      _snapshotOverride = result;
    });
  }

  Future<void> _openDocument(ExportJobSummary job) async {
    final documentId = job.documentId;
    if (documentId == null || documentId.isEmpty) {
      return;
    }

    final result = await Navigator.of(context).pushNamed(
      AppRouter.documentDetail,
      arguments: DocumentDetailArgs(
        documentId: documentId,
        documentSnapshot: _matchingDocumentSnapshot(job),
        focusExportJobId: job.id,
      ),
    );
    if (!mounted || result is! DocumentSummary) {
      return;
    }
    setState(() {
      _snapshotOverride = result;
    });
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

  Future<void> _duplicateDocument(ExportJobSummary job) async {
    final documentId = job.documentId;
    if (documentId == null || documentId.isEmpty || _duplicatingJobId != null) {
      return;
    }
    final currentDocumentSnapshot = _matchingDocumentSnapshot(job);
    final targetDocument = await showCreateDocumentDialog(
      context,
      initialName: '${(currentDocumentSnapshot?.name ?? job.documentName)} 副本',
      initialKind: currentDocumentSnapshot?.kind ?? 'handout',
      title: '复制当前文档',
    );
    if (targetDocument == null || !mounted) {
      return;
    }

    setState(() {
      _duplicatingJobId = job.id;
    });
    try {
      final items = await AppServices.instance.documentRepository
          .listDocumentItems(documentId);
      final layoutElements =
          await AppServices.instance.documentRepository.listLayoutElements();
      DocumentItemSummary? lastCreatedItem;
      for (final item in items) {
        final createdItem = await _copyDocumentItemToDocument(
          item: item,
          targetDocumentId: targetDocument.id,
          layoutElements: layoutElements,
        );
        if (createdItem != null) {
          lastCreatedItem = createdItem;
        }
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已创建文档副本：${targetDocument.name}')),
      );
      final result = await Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: targetDocument.id,
          focusItemId: lastCreatedItem?.id,
          focusItemTitle: lastCreatedItem?.title,
        ),
      );
      if (!mounted || result is! DocumentSummary) {
        return;
      }
      setState(() {
        _snapshotOverride = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is HttpJsonException
          ? '复制当前文档失败：${error.message}（HTTP ${error.statusCode}）'
          : '复制当前文档失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _duplicatingJobId = null;
        });
      }
    }
  }

  DocumentSummary? _matchingDocumentSnapshot(ExportJobSummary job) {
    final snapshot = _snapshotOverride ?? widget.args?.documentSnapshot;
    if (snapshot == null) {
      return null;
    }
    if (job.documentId != null && job.documentId == snapshot.id) {
      return snapshot.copyWith(
        latestExportStatus: job.status,
        latestExportJobId: job.id,
      );
    }
    if (job.documentName == snapshot.name) {
      return snapshot.copyWith(
        latestExportStatus: job.status,
        latestExportJobId: job.id,
      );
    }
    return null;
  }

  DocumentSummary? _currentDocumentSnapshot() {
    final base = _snapshotOverride ?? widget.args?.documentSnapshot;
    if (base == null) {
      return null;
    }

    ExportJobSummary? matchedJob;
    final focusJobId = widget.args?.focusJobId;
    if (focusJobId != null && focusJobId.isNotEmpty) {
      for (final job in _latestJobs) {
        if (job.id == focusJobId) {
          matchedJob = job;
          break;
        }
      }
    }

    matchedJob ??= _matchingJobForDocument(base);
    if (matchedJob == null) {
      return base;
    }

    return base.copyWith(
      latestExportStatus: matchedJob.status,
      latestExportJobId: matchedJob.id,
    );
  }

  ExportJobSummary? _matchingJobForDocument(DocumentSummary document) {
    for (final job in _latestJobs) {
      if (job.documentId != null && job.documentId == document.id) {
        return job;
      }
    }
    for (final job in _latestJobs) {
      if (job.documentName == document.name) {
        return job;
      }
    }
    return null;
  }

  bool _isHighlighted(ExportJobSummary job) {
    final focusJobId = widget.args?.focusJobId;
    if (focusJobId != null && focusJobId.isNotEmpty) {
      return focusJobId == job.id;
    }

    final focusDocumentName = widget.args?.focusDocumentName;
    if (focusDocumentName != null && focusDocumentName.isNotEmpty) {
      return focusDocumentName == job.documentName;
    }

    return false;
  }
}

class _ExportsSelectionBar extends StatelessWidget {
  const _ExportsSelectionBar({
    required this.selectedCount,
    required this.selectedRetryableCount,
    required this.selectedCancelableCount,
    required this.selectedSucceededCount,
    required this.selectedCanceledCount,
    required this.selectedDocumentCount,
    required this.selectedFormatCount,
    required this.filteredCount,
    required this.selectedFilteredCount,
    required this.allFilteredSelected,
    required this.retryingSelected,
    required this.cancelingSelected,
    required this.duplicatingSelectedDocuments,
    required this.showOnlySelected,
    required this.retryableCount,
    required this.cancelableCount,
    required this.succeededCount,
    required this.canceledCount,
    required this.pdfCount,
    required this.docxCount,
    required this.onSelectAll,
    required this.onSelectRetryable,
    required this.onSelectCancelable,
    required this.onSelectSucceeded,
    required this.onSelectCanceled,
    required this.onSelectPdf,
    required this.onSelectDocx,
    required this.onInvertSelection,
    required this.onClearSelection,
    required this.onShowOnlySelectedChanged,
    required this.onDuplicateSelectedDocuments,
    required this.onRetrySelected,
    required this.onCancelSelected,
  });

  final int selectedCount;
  final int selectedRetryableCount;
  final int selectedCancelableCount;
  final int selectedSucceededCount;
  final int selectedCanceledCount;
  final int selectedDocumentCount;
  final int selectedFormatCount;
  final int filteredCount;
  final int selectedFilteredCount;
  final bool allFilteredSelected;
  final bool retryingSelected;
  final bool cancelingSelected;
  final bool duplicatingSelectedDocuments;
  final bool showOnlySelected;
  final int retryableCount;
  final int cancelableCount;
  final int succeededCount;
  final int canceledCount;
  final int pdfCount;
  final int docxCount;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectRetryable;
  final VoidCallback onSelectCancelable;
  final VoidCallback onSelectSucceeded;
  final VoidCallback onSelectCanceled;
  final VoidCallback onSelectPdf;
  final VoidCallback onSelectDocx;
  final VoidCallback onInvertSelection;
  final VoidCallback onClearSelection;
  final ValueChanged<bool> onShowOnlySelectedChanged;
  final Future<void> Function() onDuplicateSelectedDocuments;
  final Future<void> Function() onRetrySelected;
  final Future<void> Function() onCancelSelected;

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
                ? '已选择 $selectedCount / $filteredCount 个导出任务'
                : (compact ? '选中任务后批量处理' : '可选择当前结果中的部分任务再批量处理'),
            style: const TextStyle(
              color: TelegramPalette.textStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (selectedCount > 0)
            _StatusChip(label: '已选可重试', value: '$selectedRetryableCount'),
          if (selectedCount > 0)
            _StatusChip(label: '已选进行中', value: '$selectedCancelableCount'),
          if (selectedCount > 0)
            _StatusChip(label: '已选已完成', value: '$selectedSucceededCount'),
          if (selectedCount > 0)
            _StatusChip(label: '已选已取消', value: '$selectedCanceledCount'),
          if (selectedCount > 0)
            _StatusChip(label: '涉及文档', value: '$selectedDocumentCount'),
          if (selectedCount > 0)
            _StatusChip(label: '涉及格式', value: '$selectedFormatCount'),
          OutlinedButton.icon(
            onPressed: allFilteredSelected ? null : onSelectAll,
            icon: const Icon(Icons.select_all),
            label: Text(
                allFilteredSelected ? '已全选' : (compact ? '全选结果' : '全选当前结果')),
          ),
          OutlinedButton.icon(
            onPressed: retryableCount == 0 ? null : onSelectRetryable,
            icon: const Icon(Icons.refresh_outlined),
            label: Text(compact ? '选可重试' : '选中可重试'),
          ),
          OutlinedButton.icon(
            onPressed: cancelableCount == 0 ? null : onSelectCancelable,
            icon: const Icon(Icons.pending_actions_outlined),
            label: Text(compact ? '选进行中' : '选中进行中'),
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
            onPressed: pdfCount == 0 ? null : onSelectPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(compact ? '选 PDF' : '选中 PDF'),
          ),
          OutlinedButton.icon(
            onPressed: docxCount == 0 ? null : onSelectDocx,
            icon: const Icon(Icons.description_outlined),
            label: Text(compact ? '选 DOCX' : '选中 DOCX'),
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
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    retryingSelected ||
                    cancelingSelected ||
                    duplicatingSelectedDocuments
                ? null
                : () => onDuplicateSelectedDocuments(),
            icon: duplicatingSelectedDocuments
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy_all_outlined),
            label: Text(
              duplicatingSelectedDocuments
                  ? '复制中…'
                  : (compact ? '复制源文档' : '批量复制源文档'),
            ),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    retryingSelected ||
                    cancelingSelected ||
                    duplicatingSelectedDocuments
                ? null
                : () => onRetrySelected(),
            icon: retryingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
                retryingSelected ? '重试中…' : (compact ? '批量重试' : '批量重试失败/取消任务')),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ||
                    retryingSelected ||
                    cancelingSelected ||
                    duplicatingSelectedDocuments
                ? null
                : () => onCancelSelected(),
            icon: cancelingSelected
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.stop_circle_outlined),
            label: Text(
                cancelingSelected ? '取消中…' : (compact ? '批量取消' : '批量取消进行中任务')),
          ),
        ],
      ),
    );
  }
}

class _ExportsHeroStrip extends StatelessWidget {
  const _ExportsHeroStrip({
    required this.totalCount,
    required this.selectedCount,
    this.currentDocumentName,
    required this.onOpenWorkspace,
  });

  final int totalCount;
  final int selectedCount;
  final String? currentDocumentName;
  final VoidCallback onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final inDocumentContext =
        currentDocumentName != null && currentDocumentName!.trim().isNotEmpty;
    return WorkspacePanel(
      padding: workspaceHeroPanelPadding(context),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: '导出时间线',
            icon: Icons.cloud_sync_outlined,
          ),
          const SizedBox(height: 14),
          const Text(
            '把每次导出都做成可回看的进度记录。',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            currentDocumentName == null || currentDocumentName!.trim().isEmpty
                ? '这里聚合所有导出任务，方便你追踪失败、重试和结果回看。'
                : '当前从“$currentDocumentName”进入，这一页会优先显示这份文档的导出进度和结果。',
            style: const TextStyle(
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
              WorkspaceMetricPill(label: '任务总数', value: '$totalCount'),
              WorkspaceMetricPill(
                label: '已选任务',
                value: '$selectedCount',
                highlight: selectedCount > 0,
              ),
              const WorkspaceMetricPill(
                label: '自动刷新',
                value: '8 秒',
                highlight: true,
              ),
              WorkspaceMetricPill(
                label: '当前模式',
                value: inDocumentContext ? '当前文档回看' : '全部导出',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportsStatusCard extends StatelessWidget {
  const _ExportsStatusCard({
    required this.modeLabel,
    required this.sessionLabel,
    required this.tenantLabel,
    required this.onRefresh,
  });

  final String modeLabel;
  final String sessionLabel;
  final String tenantLabel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 640;
    final desktopRail = screenWidth >= 1100;
    return WorkspacePanel(
      padding:
          workspacePanelPadding(context, mobile: 14, tablet: 16, desktop: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '当前状态',
                  style: TextStyle(
                    fontSize: 12,
                    color: TelegramPalette.textSoft,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(compact || desktopRail ? '刷新' : '立即刷新'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: desktopRail ? 12 : 14,
                    vertical: desktopRail ? 8 : 10,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatusRow(label: '模式', value: modeLabel),
          const SizedBox(height: 8),
          _StatusRow(label: '会话', value: sessionLabel),
          const SizedBox(height: 8),
          _StatusRow(label: '租户', value: tenantLabel),
          const SizedBox(height: 8),
          const _StatusRow(label: '刷新', value: '每 8 秒自动同步'),
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
        color: TelegramPalette.surfaceAccent,
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

class _ExportsErrorCard extends StatelessWidget {
  const _ExportsErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '导出记录暂时不可用',
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
        ],
      ),
    );
  }
}

class _ExportsHeader extends StatelessWidget {
  const _ExportsHeader({
    required this.queryController,
    required this.query,
    required this.statusFilter,
    required this.formatFilter,
    required this.sortBy,
    required this.filteredJobCount,
    required this.filteredDocumentCount,
    required this.filteredPdfCount,
    required this.filteredDocxCount,
    required this.filteredPendingCount,
    required this.filteredSucceededCount,
    required this.filteredRetryableCount,
    this.currentDocumentName,
    required this.showOnlyCurrentDocument,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onFormatChanged,
    required this.onSortChanged,
    required this.onShowOnlyCurrentDocumentChanged,
    required this.onClearFilters,
  });

  final TextEditingController queryController;
  final String query;
  final String statusFilter;
  final String formatFilter;
  final String sortBy;
  final int filteredJobCount;
  final int filteredDocumentCount;
  final int filteredPdfCount;
  final int filteredDocxCount;
  final int filteredPendingCount;
  final int filteredSucceededCount;
  final int filteredRetryableCount;
  final String? currentDocumentName;
  final bool showOnlyCurrentDocument;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onShowOnlyCurrentDocumentChanged;
  final VoidCallback onClearFilters;

  List<(String, String)> get _activeFilterEntries {
    final entries = <(String, String)>[];
    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty) {
      entries.add(('关键词', normalizedQuery));
    }
    if (statusFilter != 'all') {
      entries.add(('状态', _statusLabel(statusFilter)));
    }
    if (formatFilter != 'all') {
      entries.add(('格式', formatFilter.toUpperCase()));
    }
    if (sortBy != 'queue') {
      entries.add(('排序', _sortLabel(sortBy)));
    }
    if (showOnlyCurrentDocument && currentDocumentName != null) {
      entries.add(('范围', '只看当前文档'));
    }
    return entries;
  }

  String _statusLabel(String value) {
    switch (value) {
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
      case 'document_name':
        return '按文档名';
      case 'status':
        return '按状态';
      case 'format':
        return '按格式';
      case 'queue':
      default:
        return '任务池顺序';
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final desktopWide = MediaQuery.sizeOf(context).width >= 1180;
    final overviewChips = <Widget>[
      WorkspaceMetricPill(label: '当前结果任务', value: '$filteredJobCount'),
      WorkspaceMetricPill(
        label: '当前结果文档',
        value: '$filteredDocumentCount',
      ),
      WorkspaceMetricPill(label: 'PDF', value: '$filteredPdfCount'),
      WorkspaceMetricPill(label: 'DOCX', value: '$filteredDocxCount'),
    ];
    final statusChips = <Widget>[
      WorkspaceMetricPill(label: '处理中', value: '$filteredPendingCount'),
      WorkspaceMetricPill(label: '已完成', value: '$filteredSucceededCount'),
      WorkspaceMetricPill(label: '可重试', value: '$filteredRetryableCount'),
    ];
    return WorkspacePanel(
      padding: workspaceHeroPanelPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: '队列筛选',
            icon: Icons.filter_list_outlined,
          ),
          const SizedBox(height: 12),
          const Text(
            '导出状态',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            '这里集中查看导出状态、结果格式和可返回的文档入口，方便继续重试、取消、复制源文档或回到当前文档。',
            style: TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
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
          if (!desktopWide)
            Wrap(
              spacing: compact ? 8 : 10,
              runSpacing: compact ? 8 : 10,
              children: [...overviewChips, ...statusChips],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '任务范围',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: TelegramPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: overviewChips,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '处理状态',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: TelegramPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: statusChips,
                      ),
                    ],
                  ),
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
                    (entry) => WorkspaceMetricPill(
                      label: entry.$1,
                      value: entry.$2,
                      highlight: true,
                    ),
                  )
                  .toList(growable: false),
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
                    labelText: '搜索导出任务',
                    hintText: '文档名 / 任务 ID / 格式',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: onClearFilters,
                            icon: const Icon(Icons.close),
                            tooltip: '清空关键词',
                          ),
                  ),
                ),
              );
              final statusControl = SizedBox(
                width: stacked
                    ? double.infinity
                    : compactGrid
                        ? controlWidth
                        : 180,
                child: DropdownButtonFormField<String>(
                  initialValue: statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '状态',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部状态')),
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
                      onStatusChanged(value);
                    }
                  },
                ),
              );
              final formatControl = SizedBox(
                width: stacked
                    ? double.infinity
                    : compactGrid
                        ? controlWidth
                        : 160,
                child: DropdownButtonFormField<String>(
                  initialValue: formatFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '格式',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部格式')),
                    DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                    DropdownMenuItem(value: 'docx', child: Text('DOCX')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onFormatChanged(value);
                    }
                  },
                ),
              );
              final sortControl = SizedBox(
                width: stacked
                    ? double.infinity
                    : compactGrid
                        ? controlWidth
                        : 180,
                child: DropdownButtonFormField<String>(
                  initialValue: sortBy,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '排序',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'queue',
                      child: Text('任务池顺序'),
                    ),
                    DropdownMenuItem(
                      value: 'document_name',
                      child: Text('按文档名'),
                    ),
                    DropdownMenuItem(
                      value: 'status',
                      child: Text('按状态'),
                    ),
                    DropdownMenuItem(
                      value: 'format',
                      child: Text('按格式'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onSortChanged(value);
                    }
                  },
                ),
              );
              final currentDocumentChip = currentDocumentName != null &&
                      currentDocumentName!.trim().isNotEmpty
                  ? WorkspaceFilterPill(
                      label: showOnlyCurrentDocument
                          ? '只看当前文档'
                          : (compact
                              ? '当前文档'
                              : '当前文档：${currentDocumentName!}'),
                      selected: showOnlyCurrentDocument,
                      onTap: () => onShowOnlyCurrentDocumentChanged(
                        !showOnlyCurrentDocument,
                      ),
                      icon: Icons.description_outlined,
                    )
                  : null;
              final clearButton = TextButton.icon(
                onPressed: query.trim().isEmpty &&
                        statusFilter == 'all' &&
                        formatFilter == 'all' &&
                        sortBy == 'queue' &&
                        !showOnlyCurrentDocument
                    ? null
                    : onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(compact ? '清空' : '清空筛选'),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final widget in [
                      searchField,
                      statusControl,
                      formatControl,
                      sortControl,
                      if (currentDocumentChip != null) currentDocumentChip,
                      clearButton,
                    ]) ...[
                      widget,
                      if (widget != clearButton) const SizedBox(height: 12),
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
                        statusControl,
                        const SizedBox(width: 12),
                        formatControl,
                        const SizedBox(width: 12),
                        sortControl,
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (currentDocumentChip != null) currentDocumentChip,
                        clearButton,
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
                  statusControl,
                  formatControl,
                  sortControl,
                  if (currentDocumentChip != null) currentDocumentChip,
                  clearButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CurrentDocumentContextCard extends StatelessWidget {
  const _CurrentDocumentContextCard({
    required this.documentName,
    required this.showOnlyCurrentDocument,
    required this.onOpenDocument,
  });

  final String documentName;
  final bool showOnlyCurrentDocument;
  final VoidCallback onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return WorkspacePanel(
      padding:
          workspacePanelPadding(context, mobile: 14, tablet: 16, desktop: 16),
      backgroundColor: TelegramPalette.surfaceAccent,
      borderColor: TelegramPalette.borderAccent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.description_outlined, color: TelegramPalette.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前文档：$documentName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TelegramPalette.textStrong,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  showOnlyCurrentDocument
                      ? '当前任务池已经聚焦到这份文档，你可以直接回看它的导出历史，或打开文档继续编辑。'
                      : '当前从这份文档上下文进入，你可以直接回看这份文档的导出历史，或打开文档继续编辑。',
                  style: const TextStyle(
                    height: 1.45,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onOpenDocument,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(compact ? '打开文档' : '打开当前文档'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportJobCard extends StatelessWidget {
  const _ExportJobCard({
    required this.job,
    required this.isSelected,
    required this.highlighted,
    required this.retrying,
    required this.canceling,
    required this.duplicatingDocument,
    required this.onShowDetail,
    required this.onOpenResult,
    required this.onOpenDocument,
    required this.onDuplicateDocument,
    required this.onRetry,
    required this.onCancel,
    required this.onSelectionChanged,
  });

  final ExportJobSummary job;
  final bool isSelected;
  final bool highlighted;
  final bool retrying;
  final bool canceling;
  final bool duplicatingDocument;
  final VoidCallback onShowDetail;
  final VoidCallback onOpenResult;
  final VoidCallback onOpenDocument;
  final VoidCallback onDuplicateDocument;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final ValueChanged<bool> onSelectionChanged;

  String _statusLabel(String status) {
    switch (status) {
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
    Color chipColor;
    switch (job.status) {
      case 'succeeded':
        chipColor = TelegramPalette.surfaceAccent;
        break;
      case 'failed':
        chipColor = TelegramPalette.errorSurface;
        break;
      default:
        chipColor = TelegramPalette.warningSurface;
    }

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
                  job.documentName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(job.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${job.format.toUpperCase()} · ${job.updatedAtLabel}',
            style: const TextStyle(color: TelegramPalette.textSoft),
          ),
          if (desktopWide) ...[
            const SizedBox(height: 10),
            Container(
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
                    '任务摘要',
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
                        label: '状态',
                        value: _statusLabel(job.status),
                      ),
                      WorkspaceInfoPill(
                        label: '格式',
                        value: job.format.toUpperCase(),
                      ),
                      if (job.documentId != null)
                        const WorkspaceInfoPill(
                          label: '回看',
                          value: '可回文档',
                          highlight: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '最近更新时间：${job.updatedAtLabel}',
                    style: const TextStyle(
                      color: TelegramPalette.textStrong,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '先看任务详情，再决定是回文档、看结果页还是重试。',
                    style: TextStyle(
                      height: 1.45,
                      color: TelegramPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (highlighted) ...[
            const SizedBox(height: 10),
            const Text(
              '当前文档的最近导出记录',
              style: TextStyle(
                color: TelegramPalette.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              FilledButton.icon(
                onPressed: onShowDetail,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(compact ? '详情' : '查看详情'),
              ),
              FilledButton.tonalIcon(
                onPressed: job.status == 'succeeded' ? onOpenResult : null,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('结果页'),
              ),
              OutlinedButton.icon(
                onPressed: job.documentId == null ? null : onOpenDocument,
                icon: const Icon(Icons.description_outlined),
                label: Text(compact ? '文档' : '返回文档'),
              ),
              if (job.status == 'pending' || job.status == 'running')
                OutlinedButton.icon(
                  onPressed: canceling ? null : onCancel,
                  icon: canceling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop_circle_outlined),
                  label: Text(canceling ? '正在取消' : (compact ? '取消' : '取消导出')),
                ),
              if (job.status == 'failed' || job.status == 'canceled')
                OutlinedButton.icon(
                  onPressed: retrying ? null : onRetry,
                  icon: retrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(retrying ? '正在重试' : (compact ? '重试' : '再次导出')),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            children: [
              OutlinedButton.icon(
                onPressed: job.documentId == null || duplicatingDocument
                    ? null
                    : onDuplicateDocument,
                icon: duplicatingDocument
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.copy_all_outlined),
                label: Text(
                  duplicatingDocument ? '复制中' : (compact ? '复制文档' : '复制当前文档'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
