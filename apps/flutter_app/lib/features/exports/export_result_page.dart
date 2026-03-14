import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/export_detail_args.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import 'export_result_preview.dart';

class ExportResultPage extends StatelessWidget {
  const ExportResultPage({
    super.key,
    required this.args,
  });

  final ExportDetailArgs args;

  @override
  Widget build(BuildContext context) {
    final job = args.job;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/export-jobs/${job.id}/result');
    final canOpenResult = !AppConfig.useMockData && job.status == 'succeeded';
    final currentDocumentSnapshot = _currentDocumentSnapshot();

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出结果'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(currentDocumentSnapshot),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
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
                    value: AppServices.instance.activeTenant?.code ?? '未选择租户',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
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
                    Text(
                      AppConfig.useMockData
                          ? '当前是 MOCK 模式，这里只验证导出结果入口流程，不会生成真实文件。'
                          : '当前导出还没有可查看的结果文件，请先等待任务成功。',
                      style: const TextStyle(
                        height: 1.6,
                        color: TelegramPalette.textMuted,
                      ),
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
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: canOpenResult
                            ? () => _copyUrl(context, uri.toString())
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
                            : () => Navigator.of(context).pushNamed(
                                  AppRouter.documentDetail,
                                  arguments: DocumentDetailArgs(
                                    documentId: job.documentId!,
                                    documentSnapshot: currentDocumentSnapshot,
                                    focusExportJobId: job.id,
                                  ),
                                ),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('返回文档'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(currentDocumentSnapshot),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('返回导出详情'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
