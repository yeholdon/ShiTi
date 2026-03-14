import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/export_detail_args.dart';
import '../../core/models/export_job_summary.dart';
import '../../core/models/exports_page_args.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';

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
  late Future<List<ExportJobSummary>> _jobsFuture =
      AppServices.instance.documentRepository.listExportJobs();
  Timer? _refreshTimer;
  String? _retryingJobId;
  List<ExportJobSummary> _latestJobs = const <ExportJobSummary>[];
  DocumentSummary? _snapshotOverride;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _reload() {
    setState(() {
      _jobsFuture = AppServices.instance.documentRepository.listExportJobs();
    });
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
      final retried = await AppServices.instance.documentRepository.retryExportJob(
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

  @override
  Widget build(BuildContext context) {
    final currentDocumentSnapshot = _currentDocumentSnapshot();
    return Scaffold(
      appBar: AppBar(
        title: const Text('导出记录'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(currentDocumentSnapshot),
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, __) {
          if (!mounted) {
            return;
          }
          Navigator.of(context).pop(_currentDocumentSnapshot());
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _ExportsStatusCard(
              modeLabel: AppConfig.dataModeLabel,
              sessionLabel: AppServices.instance.session?.username ?? '未登录',
              tenantLabel: AppServices.instance.activeTenant?.code ?? '未选择租户',
              onRefresh: _reload,
            ),
            const SizedBox(height: 18),
            const _ExportsHeader(),
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
                if (snapshot.data!.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        '当前还没有导出记录。REMOTE 模式下请先在文档工作区发起导出，再回来查看状态。',
                        style: TextStyle(
                          height: 1.5,
                          color: TelegramPalette.textMuted,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!
                      .map(
                        (job) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ExportJobCard(
                            job: job,
                            highlighted: _isHighlighted(job),
                            retrying: _retryingJobId == job.id,
                            onShowDetail: () => _showDetail(job),
                            onOpenResult: () => _openResult(job),
                            onOpenDocument: () => _openDocument(job),
                            onRetry: () => _retryJob(job),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openResult(ExportJobSummary job) async {
    if (AppConfig.useMockData) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MOCK 模式下没有真实导出文件可打开。')),
      );
      return;
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/export-jobs/${job.id}/result');
    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开导出结果：$uri')),
      );
    }
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
            _StatusChip(label: '刷新', value: '每 8 秒自动同步'),
            FilledButton.tonalIcon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('立即刷新'),
            ),
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

class _ExportsErrorCard extends StatelessWidget {
  const _ExportsErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
          ],
        ),
      ),
    );
  }
}

class _ExportsHeader extends StatelessWidget {
  const _ExportsHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '导出状态',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            Text(
              '这里面向教师和教研用户展示导出结果，不会暴露后台运维术语。后续会继续接导出详情、失败重试和结果下载。',
              style: TextStyle(
                height: 1.5,
                color: TelegramPalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportJobCard extends StatelessWidget {
  const _ExportJobCard({
    required this.job,
    required this.highlighted,
    required this.retrying,
    required this.onShowDetail,
    required this.onOpenResult,
    required this.onOpenDocument,
    required this.onRetry,
  });

  final ExportJobSummary job;
  final bool highlighted;
  final bool retrying;
  final VoidCallback onShowDetail;
  final VoidCallback onOpenResult;
  final VoidCallback onOpenDocument;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onShowDetail,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('查看详情'),
                ),
                FilledButton.tonalIcon(
                  onPressed: job.status == 'succeeded' ? onOpenResult : null,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('打开结果'),
                ),
                OutlinedButton.icon(
                  onPressed: job.documentId == null ? null : onOpenDocument,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('返回文档'),
                ),
                if (job.status == 'failed')
                  OutlinedButton.icon(
                    onPressed: retrying ? null : onRetry,
                    icon: retrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(retrying ? '正在重试' : '再次导出'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
