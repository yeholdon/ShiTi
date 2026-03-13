import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/export_job_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';

class ExportsPage extends StatefulWidget {
  const ExportsPage({super.key});

  @override
  State<ExportsPage> createState() => _ExportsPageState();
}

class _ExportsPageState extends State<ExportsPage> {
  late Future<List<ExportJobSummary>> _jobsFuture =
      AppServices.instance.documentRepository.listExportJobs();

  void _reload() {
    setState(() {
      _jobsFuture = AppServices.instance.documentRepository.listExportJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导出记录')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ExportsStatusCard(
            modeLabel: AppConfig.dataModeLabel,
            sessionLabel: AppServices.instance.session?.username ?? '未登录',
            tenantLabel: AppServices.instance.activeTenant?.code ?? '未选择租户',
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
              if (snapshot.data!.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      '当前还没有导出记录。REMOTE 模式下请先在文档工作区发起导出，再回来查看状态。',
                      style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
                    ),
                  ),
                );
              }

              return Column(
                children: snapshot.data!
                    .map(
                      (job) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExportJobCard(job: job),
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

class _ExportsStatusCard extends StatelessWidget {
  const _ExportsStatusCard({
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
              style: const TextStyle(height: 1.5, color: Color(0xFF4C6964)),
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
              style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportJobCard extends StatelessWidget {
  const _ExportJobCard({required this.job});

  final ExportJobSummary job;

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    switch (job.status) {
      case 'succeeded':
        chipColor = const Color(0xFFDCEEEA);
        break;
      case 'failed':
        chipColor = const Color(0xFFF7E0DC);
        break;
      default:
        chipColor = const Color(0xFFF3E9D7);
    }

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
              style: const TextStyle(color: Color(0xFF52726D)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('查看结果'),
                ),
                if (job.status == 'failed')
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh),
                    label: const Text('再次导出'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
