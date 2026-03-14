import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/export_detail_args.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';

class ExportDetailPage extends StatelessWidget {
  const ExportDetailPage({
    super.key,
    required this.args,
  });

  final ExportDetailArgs args;

  static const Map<String, String> _statusCopy = <String, String>{
    'pending': '导出任务已经创建，系统会继续处理文档与图片资源。',
    'running': '导出正在进行中，通常会在几秒到几十秒内完成。',
    'succeeded': '导出已经完成，你可以直接打开结果文件进行查看或下载。',
    'failed': '导出没有成功完成，请回到文档页重新发起一次导出。',
    'canceled': '这次导出已被取消，需要时可以重新发起。',
  };

  @override
  Widget build(BuildContext context) {
    final job = args.job;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/export-jobs/${job.id}/result');
    final canOpenResult = !AppConfig.useMockData && job.status == 'succeeded';
    final currentDocumentSnapshot = _currentDocumentSnapshot();

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出详情'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(currentDocumentSnapshot),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ContextCard(
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
                  const SizedBox(height: 18),
                  if (job.status == 'succeeded')
                    _InfoTile(
                      label: '结果地址',
                      value: AppConfig.useMockData ? 'MOCK 模式没有真实导出文件' : uri.toString(),
                    ),
                  _InfoTile(
                    label: '任务编号',
                    value: job.id,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: canOpenResult
                            ? () => Navigator.of(context).pushNamed(
                                  AppRouter.exportResult,
                                  arguments: ExportDetailArgs(
                                    job: job,
                                    documentSnapshot: currentDocumentSnapshot,
                                  ),
                                )
                            : null,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('结果页'),
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
                            : () => Navigator.of(context).pushNamed(
                                  AppRouter.documentDetail,
                                  arguments: DocumentDetailArgs(
                                    documentId: job.documentId!,
                                    documentSnapshot: args.documentSnapshot,
                                    focusExportJobId: job.id,
                                  ),
                                ),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('返回文档'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(currentDocumentSnapshot),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('返回导出列表'),
                      ),
                    ],
                  ),
                  if (AppConfig.useMockData) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '当前是 MOCK 模式，页面用于验证交互链路，不会生成真实 PDF 文件。',
                      style: TextStyle(
                        color: TelegramPalette.warningText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openResult(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开导出结果：$uri')),
      );
    }
  }

  DocumentSummary? _currentDocumentSnapshot() {
    final snapshot = args.documentSnapshot;
    if (snapshot == null) {
      return null;
    }
    return snapshot.copyWith(
      latestExportStatus: args.job.status,
      latestExportJobId: args.job.id,
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
    return Card(
      child: Padding(
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
      ),
      child: Text(status),
    );
  }
}
