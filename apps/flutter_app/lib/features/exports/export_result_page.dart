import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_item_summary.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/export_detail_args.dart';
import '../../core/models/export_job_summary.dart';
import '../../core/models/layout_element_summary.dart';
import '../../core/models/library_page_args.dart';
import '../../core/models/question_basket_page_args.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../documents/create_document_dialog.dart';
import '../shared/workspace_shell.dart';
import 'export_result_preview.dart';

class ExportResultPage extends StatefulWidget {
  const ExportResultPage({
    super.key,
    required this.args,
  });

  final ExportDetailArgs args;

  @override
  State<ExportResultPage> createState() => _ExportResultPageState();
}

class _ExportResultPageState extends State<ExportResultPage> {
  late ExportJobSummary _job;
  bool _refreshing = false;
  bool _reExporting = false;
  bool _duplicatingDocument = false;

  @override
  void initState() {
    super.initState();
    _job = widget.args.job;
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final uri =
        Uri.parse('${AppConfig.apiBaseUrl}/export-jobs/${job.id}/result');
    final canOpenResult = !AppConfig.useMockData && job.status == 'succeeded';
    final canRefresh = !_refreshing && !_reExporting && !_duplicatingDocument;
    final canReExport = job.documentId != null &&
        !_refreshing &&
        !_reExporting &&
        !_duplicatingDocument;
    final currentDocumentSnapshot = _currentDocumentSnapshot();

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出结果'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(currentDocumentSnapshot),
        ),
      ),
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: workspaceConstrainedContent(
            context,
            child: ListView(
              padding: workspacePagePadding(context),
              children: [
                _ExportResultHeroCard(job: job),
                const SizedBox(height: 18),
                WorkspacePanel(
                  padding: const EdgeInsets.all(18),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoPill(label: '模式', value: AppConfig.dataModeLabel),
                      _InfoPill(
                        label: '会话',
                        value: AppServices.instance.session?.username ?? '未登录',
                      ),
                      _InfoPill(
                        label: '租户',
                        value:
                            AppServices.instance.activeTenant?.code ?? '未选择租户',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                WorkspacePanel(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wideDesktop = constraints.maxWidth >= 1120;
                      final mainContent = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.documentName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${job.format.toUpperCase()} · ${job.updatedAtLabel}',
                            style: const TextStyle(
                              color: TelegramPalette.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (!canOpenResult)
                            WorkspaceMessageBanner(
                              icon: AppConfig.useMockData
                                  ? Icons.warning_amber_rounded
                                  : Icons.hourglass_bottom_rounded,
                              title: AppConfig.useMockData
                                  ? '当前是样例结果预览'
                                  : '结果文件还没准备好',
                              message: AppConfig.useMockData
                                  ? '这里用于预览结果页流程，不会生成可下载文件。'
                                  : '当前导出还没有可查看的结果文件，请先等待任务成功。',
                              foregroundColor: AppConfig.useMockData
                                  ? TelegramPalette.warningText
                                  : TelegramPalette.textStrong,
                              backgroundColor: AppConfig.useMockData
                                  ? TelegramPalette.warningSurface
                                  : TelegramPalette.surfaceAccent,
                              borderColor: AppConfig.useMockData
                                  ? TelegramPalette.warningBorder
                                  : TelegramPalette.border,
                            )
                          else ...[
                            const Text(
                              '结果地址',
                              style: TextStyle(
                                color: TelegramPalette.textSoft,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              uri.toString(),
                              style: const TextStyle(height: 1.5),
                            ),
                            const SizedBox(height: 18),
                            ExportResultPreview(uri: uri),
                          ],
                        ],
                      );
                      final actionRail = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: TelegramPalette.surfaceSoft,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: TelegramPalette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const WorkspaceEyebrow(
                                  label: '继续处理',
                                  icon: Icons.arrow_outward_outlined,
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    FilledButton.icon(
                                      onPressed:
                                          canRefresh ? _refreshJob : null,
                                      icon: _refreshing
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.refresh_outlined),
                                      label:
                                          Text(_refreshing ? '刷新中…' : '刷新状态'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: canReExport
                                          ? _reExportDocument
                                          : null,
                                      icon: _reExporting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.restart_alt_outlined,
                                            ),
                                      label: Text(
                                        _reExporting ? '重新导出中…' : '基于当前文档重新导出',
                                      ),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: job.documentId == null ||
                                              _duplicatingDocument ||
                                              _refreshing ||
                                              _reExporting
                                          ? null
                                          : _duplicateDocument,
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
                                        _duplicatingDocument
                                            ? '复制中…'
                                            : '复制当前文档',
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: canOpenResult
                                          ? () =>
                                              _copyUrl(context, uri.toString())
                                          : null,
                                      icon: const Icon(Icons.copy_all_outlined),
                                      label: const Text('复制结果地址'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: canOpenResult
                                          ? () => _openResult(context, uri)
                                          : null,
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('浏览器打开'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: job.documentId == null
                                          ? null
                                          : () =>
                                              Navigator.of(context).pushNamed(
                                                AppRouter.documentDetail,
                                                arguments: DocumentDetailArgs(
                                                  documentId: job.documentId!,
                                                  documentSnapshot:
                                                      currentDocumentSnapshot,
                                                  focusExportJobId: job.id,
                                                ),
                                              ),
                                      icon: const Icon(
                                        Icons.description_outlined,
                                      ),
                                      label: const Text('继续编辑文档'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: job.documentId == null
                                          ? null
                                          : () =>
                                              Navigator.of(context).pushNamed(
                                                AppRouter.library,
                                                arguments: LibraryPageArgs(
                                                  preferredDocumentSnapshot:
                                                      currentDocumentSnapshot,
                                                ),
                                              ),
                                      icon: const Icon(
                                        Icons.travel_explore_outlined,
                                      ),
                                      label: const Text('去题库加题'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: job.documentId == null
                                          ? null
                                          : () =>
                                              Navigator.of(context).pushNamed(
                                                AppRouter.basket,
                                                arguments:
                                                    QuestionBasketPageArgs(
                                                  preferredDocumentSnapshot:
                                                      currentDocumentSnapshot,
                                                ),
                                              ),
                                      icon: const Icon(
                                        Icons.inventory_2_outlined,
                                      ),
                                      label: const Text('打开选题篮'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          Navigator.of(context).pop(
                                        currentDocumentSnapshot,
                                      ),
                                      icon: const Icon(Icons.arrow_back),
                                      label: const Text('返回导出详情'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      if (!wideDesktop) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            mainContent,
                            const SizedBox(height: 22),
                            actionRail,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: mainContent),
                          const SizedBox(width: 20),
                          SizedBox(width: 360, child: actionRail),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshJob() async {
    setState(() {
      _refreshing = true;
    });
    try {
      final refreshed =
          await AppServices.instance.documentRepository.getExportJob(_job.id);
      if (!mounted) {
        return;
      }
      if (refreshed == null) {
        _showActionError('未找到最新导出任务状态');
        return;
      }
      setState(() {
        _job = refreshed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已刷新导出任务状态')),
      );
    } on HttpJsonException catch (error) {
      _showActionError(error.message);
    } catch (_) {
      _showActionError('刷新导出状态失败，请稍后再试');
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _reExportDocument() async {
    final documentId = _job.documentId;
    if (documentId == null) {
      return;
    }
    setState(() {
      _reExporting = true;
    });
    try {
      final newJob =
          await AppServices.instance.documentRepository.createExportJob(
        documentId: documentId,
      );
      if (!mounted) {
        return;
      }
      final nextDocumentSnapshot = _documentSnapshotFor(newJob);
      await Navigator.of(context).pushNamed(
        AppRouter.exportDetail,
        arguments: ExportDetailArgs(
          job: newJob,
          documentSnapshot: nextDocumentSnapshot,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _job = newJob;
      });
    } on HttpJsonException catch (error) {
      _showActionError(error.message);
    } catch (_) {
      _showActionError('重新发起导出失败，请稍后再试');
    } finally {
      if (mounted) {
        setState(() {
          _reExporting = false;
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

  Future<void> _duplicateDocument() async {
    final documentId = _job.documentId;
    if (documentId == null) {
      return;
    }
    final currentDocumentSnapshot = _currentDocumentSnapshot();
    final targetDocument = await showCreateDocumentDialog(
      context,
      initialName: '${(currentDocumentSnapshot?.name ?? _job.documentName)} 副本',
      initialKind: currentDocumentSnapshot?.kind ?? 'handout',
      title: '复制当前文档',
    );
    if (targetDocument == null || !mounted) {
      return;
    }

    setState(() {
      _duplicatingDocument = true;
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
      _showActionError(error is HttpJsonException
          ? '复制当前文档失败：${error.message}（HTTP ${error.statusCode}）'
          : '复制当前文档失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _duplicatingDocument = false;
        });
      }
    }
  }

  Future<void> _copyUrl(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结果地址已复制')),
      );
    }
  }

  Future<void> _openResult(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开导出结果：$uri')),
      );
    }
  }

  void _showActionError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  DocumentSummary? _currentDocumentSnapshot() {
    return _documentSnapshotFor(_job);
  }

  DocumentSummary? _documentSnapshotFor(ExportJobSummary job) {
    final snapshot = widget.args.documentSnapshot;
    if (snapshot == null) {
      return null;
    }
    return snapshot.copyWith(
      latestExportStatus: job.status,
      latestExportJobId: job.id,
    );
  }
}

class _ExportResultHeroCard extends StatelessWidget {
  const _ExportResultHeroCard({
    required this.job,
  });

  final ExportJobSummary job;

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
    return WorkspacePanel(
      padding: const EdgeInsets.all(24),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: '导出结果',
            icon: Icons.visibility_outlined,
          ),
          const SizedBox(height: 14),
          Text(
            job.documentName,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            job.status == 'succeeded'
                ? '当前正在回看导出结果。接下来可以复制结果地址、重新导出，或回到文档继续编辑。'
                : '当前正在等待结果文件可用。接下来可以刷新状态，或直接重新导出。',
            style: const TextStyle(
              height: 1.55,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              WorkspaceMetricPill(
                label: '状态',
                value: _statusLabel(job.status),
                highlight: true,
              ),
              WorkspaceMetricPill(label: '格式', value: job.format.toUpperCase()),
              WorkspaceMetricPill(label: '最近更新', value: job.updatedAtLabel),
              const WorkspaceMetricPill(
                label: '当前模式',
                value: '查看导出结果',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
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
