import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../router/app_router.dart';
import 'create_document_dialog.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  late Future<List<DocumentSummary>> _documentsFuture =
      AppServices.instance.documentRepository.listDocuments();

  void _reload() {
    setState(() {
      _documentsFuture = AppServices.instance.documentRepository.listDocuments();
    });
  }

  Future<void> _createDocument() async {
    final created = await showCreateDocumentDialog(context);
    if (created == null || !mounted) {
      return;
    }
    _reload();
    Navigator.of(context).pushNamed(
      AppRouter.documentDetail,
      arguments: DocumentDetailArgs(documentId: created.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('讲义与试卷')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _DocumentsStatusCard(
            modeLabel: AppConfig.dataModeLabel,
            sessionLabel: AppServices.instance.session?.username ?? '未登录',
            tenantLabel: AppServices.instance.activeTenant?.code ?? '未选择租户',
          ),
          const SizedBox(height: 18),
          _DocumentsHeader(onCreateDocument: _createDocument),
          const SizedBox(height: 18),
          FutureBuilder<List<DocumentSummary>>(
            future: _documentsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                final message = error is HttpJsonException
                    ? '文档列表加载失败：${error.message}（HTTP ${error.statusCode}）'
                    : '文档列表加载失败：$error';
                return _DocumentsErrorCard(
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
              if (snapshot.data!.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '当前没有可用文档。REMOTE 模式下请先登录并选择租户，然后再创建或查看文档。',
                          style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
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
                  ),
                );
              }
              return Column(
                children: snapshot.data!
                    .map(
                      (document) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DocumentCard(document: document),
                      ),
                    )
                    .toList(),
              );
            },
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
        color: const Color(0xFFE8F3F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label：$value',
        style: const TextStyle(
          color: Color(0xFF35524E),
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
  final VoidCallback onRetry;

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
              style: const TextStyle(height: 1.5, color: Color(0xFF4C6964)),
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
  const _DocumentsHeader({required this.onCreateDocument});

  final Future<void> Function() onCreateDocument;

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
              style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});

  final DocumentSummary document;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRouter.documentDetail,
                      arguments: DocumentDetailArgs(documentId: document.id),
                    );
                  },
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('继续编排'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRouter.exports);
                  },
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
