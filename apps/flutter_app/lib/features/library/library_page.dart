import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/library_filter_state.dart';
import '../../core/models/question_detail_args.dart';
import '../../core/models/question_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../router/app_router.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _searchController = TextEditingController();

  LibraryFilterState _filters = const LibraryFilterState();
  late Future<List<QuestionSummary>> _questionsFuture = _reload();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<QuestionSummary>> _reload() {
    return AppServices.instance.questionRepository.listQuestions(filters: _filters);
  }

  void _updateFilters(LibraryFilterState next) {
    setState(() {
      _filters = next;
      if (_searchController.text != next.query) {
        _searchController.text = next.query;
      }
      _questionsFuture = _reload();
    });
  }

  Future<void> _reloadWithGuard() async {
    setState(() {
      _questionsFuture = _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('题库检索'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.login);
            },
            icon: const Icon(Icons.login),
            label: const Text('登录'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _LibraryStatusCard(
            modeLabel: AppConfig.dataModeLabel,
            sessionLabel: AppServices.instance.session?.username ?? '未登录',
            tenantLabel: AppServices.instance.activeTenant?.code ?? '未选择租户',
          ),
          const SizedBox(height: 16),
          _FilterCard(
            filters: _filters,
            searchController: _searchController,
            onChanged: _updateFilters,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<QuestionSummary>>(
            future: _questionsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                final message = error is HttpJsonException
                    ? '题库加载失败：${error.message}（HTTP ${error.statusCode}）'
                    : '题库加载失败：$error';
                return _LibraryErrorCard(
                  message: message,
                  onRetry: _reloadWithGuard,
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

              final questions = snapshot.data!;
              if (questions.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      '当前没有可展示的题目。REMOTE 模式下请先登录并选择租户；MOCK 模式下可直接查看本地样例数据。',
                      style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
                    ),
                  ),
                );
              }
              return Column(
                children: questions
                    .map(
                      (question) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _QuestionPreviewCard(question: question),
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

class _LibraryStatusCard extends StatelessWidget {
  const _LibraryStatusCard({
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

class _LibraryErrorCard extends StatelessWidget {
  const _LibraryErrorCard({
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
              '题库暂时不可用',
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

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.filters,
    required this.searchController,
    required this.onChanged,
  });

  final LibraryFilterState filters;
  final TextEditingController searchController;
  final ValueChanged<LibraryFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '筛选条件',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: '按标题、章节或标签搜索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                onChanged(filters.copyWith(query: value));
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FilterDropdown(
                  label: '学科',
                  value: filters.subject,
                  options: const ['全部学科', '数学', '物理'],
                  onChanged: (value) => onChanged(filters.copyWith(subject: value)),
                ),
                _FilterDropdown(
                  label: '学段',
                  value: filters.stage,
                  options: const ['全部学段', '初中'],
                  onChanged: (value) => onChanged(filters.copyWith(stage: value)),
                ),
                _FilterDropdown(
                  label: '教材',
                  value: filters.textbook,
                  options: const ['全部教材', '浙教版', '人教版', '通用版'],
                  onChanged: (value) => onChanged(filters.copyWith(textbook: value)),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    searchController.clear();
                    onChanged(const LibraryFilterState());
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('清空筛选'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ))
            .toList(),
        onChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
      ),
    );
  }
}

class _QuestionPreviewCard extends StatelessWidget {
  const _QuestionPreviewCard({required this.question});

  final QuestionSummary question;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRouter.questionDetail,
            arguments: QuestionDetailArgs(questionId: question.id),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${question.subject} · ${question.grade} · ${question.textbook} · ${question.chapter}',
                style: const TextStyle(color: Color(0xFF52726D)),
              ),
              const SizedBox(height: 10),
              Text(
                question.stemPreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('难度 ${question.difficulty}')),
                  ...question.tags.map((tag) => Chip(label: Text(tag))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
