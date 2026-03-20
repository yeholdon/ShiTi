import 'package:flutter/material.dart';
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

class ExportDetailPage extends StatefulWidget {
  const ExportDetailPage({
    super.key,
    required this.args,
  });

  final ExportDetailArgs args;

  @override
  State<ExportDetailPage> createState() => _ExportDetailPageState();
}

class _ExportDetailPageState extends State<ExportDetailPage> {
  late ExportJobSummary _job;
  bool _canceling = false;
  bool _retrying = false;
  bool _refreshing = false;
  bool _duplicatingDocument = false;

  static const Map<String, String> _statusCopy = <String, String>{
    'pending': '导出任务已经创建，系统会继续处理文档与图片资源。',
    'running': '导出正在进行中，通常会在几秒到几十秒内完成。',
    'succeeded': '导出已经完成，你可以直接打开结果文件进行查看或下载。',
    'failed': '导出没有成功完成，请回到文档页重新发起一次导出。',
    'canceled': '这次导出已被取消，需要时可以重新发起。',
  };

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
    final canRefresh =
        !_refreshing && !_canceling && !_retrying && !_duplicatingDocument;
    final canCancel = (job.status == 'pending' || job.status == 'running') &&
        !_canceling &&
        !_retrying &&
        !_duplicatingDocument;
    final canRetry = (job.status == 'failed' || job.status == 'canceled') &&
        !_retrying &&
        !_canceling &&
        !_duplicatingDocument;
    final currentDocumentSnapshot = _currentDocumentSnapshot();

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出详情'),
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
                _ExportDetailHeroCard(job: job),
                const SizedBox(height: 18),
                _ContextCard(
                  modeLabel: AppConfig.dataModeLabel,
                  sessionLabel: AppServices.instance.session?.username ?? '未登录',
                  tenantLabel:
                      AppServices.instance.activeTenant?.code ?? '未选择租户',
                ),
                const SizedBox(height: 18),
                WorkspacePanel(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wideDesktop = constraints.maxWidth >= 1120;
                      final summary = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  job.documentName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _StatusChip(status: job.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${job.format.toUpperCase()} · 最近更新 ${job.updatedAtLabel}',
                            style: const TextStyle(
                              color: TelegramPalette.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _statusCopy[job.status] ?? '当前可以继续查看导出状态和结果入口。',
                            style: const TextStyle(
                              height: 1.6,
                              color: TelegramPalette.textStrong,
                            ),
                          ),
                          if (AppConfig.useMockData) ...[
                            const SizedBox(height: 16),
                            const WorkspaceMessageBanner.warning(
                              title: '当前是样例流程预览',
                              message:
                                  '这里主要用于预览导出流程，不会生成真实 PDF 文件。',
                            ),
                          ],
                        ],
                      );
                      final sideRail = Column(
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
                                  label: '任务摘要',
                                  icon: Icons.fact_check_outlined,
                                ),
                                const SizedBox(height: 14),
                                if (job.status == 'succeeded')
                                  _InfoTile(
                                    label: '结果地址',
                                    value: AppConfig.useMockData
                                        ? '样例数据模式不会生成真实导出文件'
                                        : uri.toString(),
                                  ),
                                _InfoTile(
                                  label: '任务编号',
                                  value: job.id,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: TelegramPalette.surfaceAccent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: TelegramPalette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const WorkspaceEyebrow(
                                  label: '下一步',
                                  icon: Icons.arrow_outward_outlined,
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: canOpenResult
                                          ? () =>
                                              Navigator.of(context).pushNamed(
                                                AppRouter.exportResult,
                                                arguments: ExportDetailArgs(
                                                  job: job,
                                                  documentSnapshot:
                                                      currentDocumentSnapshot,
                                                ),
                                              )
                                          : null,
                                      icon:
                                          const Icon(Icons.visibility_outlined),
                                      label: const Text('结果页'),
                                    ),
                                    FilledButton.tonalIcon(
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
                                      onPressed: canOpenResult
                                          ? () => _openResult(context, uri)
                                          : null,
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('浏览器打开'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: canCancel ? _cancelJob : null,
                                      icon: _canceling
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.stop_circle_outlined,
                                            ),
                                      label: Text(_canceling ? '取消中…' : '取消导出'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: canRetry ? _retryJob : null,
                                      icon: _retrying
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.refresh_outlined),
                                      label: Text(_retrying ? '重试中…' : '再次导出'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: job.documentId == null ||
                                              _duplicatingDocument ||
                                              _refreshing ||
                                              _canceling ||
                                              _retrying
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
                                    OutlinedButton.icon(
                                      onPressed: job.documentId == null
                                          ? null
                                          : () =>
                                              Navigator.of(context).pushNamed(
                                                AppRouter.documentDetail,
                                                arguments: DocumentDetailArgs(
                                                  documentId: job.documentId!,
                                                  documentSnapshot: widget
                                                      .args.documentSnapshot,
                                                  focusExportJobId: job.id,
                                                ),
                                              ),
                                      icon: const Icon(
                                        Icons.description_outlined,
                                      ),
                                      label: const Text('返回文档'),
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
                                      label: const Text('返回导出列表'),
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
                            summary,
                            const SizedBox(height: 18),
                            sideRail,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: summary),
                          const SizedBox(width: 20),
                          SizedBox(width: 360, child: sideRail),
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

  Future<void> _cancelJob() async {
    setState(() {
      _canceling = true;
    });
    try {
      final updated = await AppServices.instance.documentRepository
          .cancelExportJob(jobId: _job.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _job = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消当前导出任务')),
      );
    } on HttpJsonException catch (error) {
      _showActionError(error.message);
    } catch (_) {
      _showActionError('取消导出失败，请稍后再试');
    } finally {
      if (mounted) {
        setState(() {
          _canceling = false;
        });
      }
    }
  }

  Future<void> _retryJob() async {
    setState(() {
      _retrying = true;
    });
    try {
      final updated = await AppServices.instance.documentRepository
          .retryExportJob(jobId: _job.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _job = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重新发起导出任务')),
      );
    } on HttpJsonException catch (error) {
      _showActionError(error.message);
    } catch (_) {
      _showActionError('重新导出失败，请稍后再试');
    } finally {
      if (mounted) {
        setState(() {
          _retrying = false;
        });
      }
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
    final snapshot = widget.args.documentSnapshot;
    if (snapshot == null) {
      return null;
    }
    return snapshot.copyWith(
      latestExportStatus: _job.status,
      latestExportJobId: _job.id,
    );
  }
}

class _ExportDetailHeroCard extends StatelessWidget {
  const _ExportDetailHeroCard({
    required this.job,
  });

  final ExportJobSummary job;

  @override
  Widget build(BuildContext context) {
    final detail = switch (job.status) {
      'succeeded' => '当前正在查看这次导出的任务详情。接下来可以打开结果文件，或回到文档继续编辑。',
      'failed' || 'canceled' => '当前正在查看这次导出的任务详情。接下来可以重试，或回到文档调整内容后再导出。',
      _ => '当前正在查看这次导出的任务详情。接下来可以刷新状态，或先回到文档继续编辑。',
    };
    return WorkspacePanel(
      padding: const EdgeInsets.all(24),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: 'Export Detail',
            icon: Icons.cloud_done_outlined,
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
            detail,
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
                value: job.status,
                highlight: true,
              ),
              WorkspaceMetricPill(label: '格式', value: job.format.toUpperCase()),
              WorkspaceMetricPill(label: '最近更新', value: job.updatedAtLabel),
              const WorkspaceMetricPill(
                label: '当前模式',
                value: '查看任务详情',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
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
          _InfoPill(label: '模式', value: modeLabel),
          _InfoPill(label: '会话', value: sessionLabel),
          _InfoPill(label: '租户', value: tenantLabel),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: TelegramPalette.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    switch (status) {
      case 'succeeded':
        chipColor = TelegramPalette.surfaceAccent;
        break;
      case 'failed':
        chipColor = TelegramPalette.errorSurface;
        break;
      default:
        chipColor = TelegramPalette.warningSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: Text(status),
    );
  }
}
