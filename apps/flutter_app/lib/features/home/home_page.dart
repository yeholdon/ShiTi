import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/library_filter_state.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../router/app_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = <_SummaryCardData>[
      const _SummaryCardData(
        title: '最近备课',
        value: '12',
        detail: '本周已整理题目与讲义草稿',
      ),
      const _SummaryCardData(
        title: '待处理导出',
        value: '3',
        detail: '试卷 2 份，讲义 1 份',
      ),
      const _SummaryCardData(
        title: '常用教材',
        value: '浙教版',
        detail: '最近 7 天使用频率最高',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Row(
              children: [
                if (wide) const _WorkspaceRail(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _HeroSection(wide: wide),
                      const SizedBox(height: 24),
                      const _WorkspaceContextStrip(),
                      const SizedBox(height: 16),
                      if (!AppConfig.useMockData) const _RemoteModeGuideCard(),
                      if (!AppConfig.useMockData) const SizedBox(height: 16),
                      if (!AppConfig.useMockData) const _RemoteWorkspaceProbeCard(),
                      const SizedBox(height: 24),
                      const _WorkspaceEntryStrip(),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: cards.map((card) => _SummaryCard(card: card, wide: wide)).toList(),
                      ),
                      const SizedBox(height: 24),
                      wide
                          ? const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _RecentTasksPanel()),
                                SizedBox(width: 16),
                                Expanded(flex: 2, child: _QuestionBasketPanel()),
                              ],
                            )
                          : const Column(
                              children: [
                                _RecentTasksPanel(),
                                SizedBox(height: 16),
                                _QuestionBasketPanel(),
                              ],
                            ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 900
          ? NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: '工作台'),
                NavigationDestination(icon: Icon(Icons.search_outlined), label: '题库'),
                NavigationDestination(icon: Icon(Icons.description_outlined), label: '文档'),
              ],
              onDestinationSelected: (index) {
                if (index == 1) {
                  Navigator.of(context).pushNamed(AppRouter.library);
                }
                if (index == 2) {
                  Navigator.of(context).pushNamed(AppRouter.documents);
                }
              },
            )
          : null,
    );
  }
}

class _RemoteWorkspaceProbeCard extends StatefulWidget {
  const _RemoteWorkspaceProbeCard();

  @override
  State<_RemoteWorkspaceProbeCard> createState() => _RemoteWorkspaceProbeCardState();
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
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
                    style: const TextStyle(height: 1.5, color: Color(0xFF7C2D12)),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新探测'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed(AppRouter.tenantSwitch),
                        icon: const Icon(Icons.apartment_outlined),
                        label: const Text('切换租户'),
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
                  '真实后端已经返回题库和文档工作区数据，可以直接进入对应页面继续操作。',
                  style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ContextChip(label: '题目数', value: '${result.questionCount}'),
                    _ContextChip(label: '文档数', value: '${result.documentCount}'),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).pushNamed(AppRouter.library),
                      icon: const Icon(Icons.search_outlined),
                      label: const Text('进入题库'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).pushNamed(AppRouter.documents),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('进入文档'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新探测'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'REMOTE 模式接入指引',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              hasSession && hasTenant
                  ? '当前已经具备会话和租户上下文，可以直接进入题库和文档工作区加载真实后端数据。'
                  : '当前还缺少真实后端上下文。先登录，再按租户代码解析并进入工作区，题库和文档列表才会走远程接口。',
              style: const TextStyle(height: 1.5, color: Color(0xFF4C6964)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pushNamed(AppRouter.login),
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
      ),
    );
  }
}

class _WorkspaceContextStrip extends StatelessWidget {
  const _WorkspaceContextStrip();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
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

class _WorkspaceRail extends StatelessWidget {
  const _WorkspaceRail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF123B37),
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
            style: TextStyle(color: Color(0xFFB8D7D1)),
          ),
          const SizedBox(height: 32),
          ...const [
            _RailItem(icon: Icons.dashboard_outlined, label: '工作台', active: true),
            _RailItem(icon: Icons.search_outlined, label: '题库检索'),
            _RailItem(icon: Icons.collections_bookmark_outlined, label: '选题篮'),
            _RailItem(icon: Icons.description_outlined, label: '讲义与试卷'),
            _RailItem(icon: Icons.cloud_outlined, label: '导出记录'),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF194843),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '移动端、网页端、桌面端共用一套 Flutter 工作台交互。',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
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
        color: active ? const Color(0xFF225953) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: active ? Colors.white : const Color(0xFFB8D7D1)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFFD5E8E4),
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F2EE), Color(0xFFF7FBF9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: wide
          ? Row(
              children: const [
                Expanded(child: _HeroCopy()),
                SizedBox(width: 24),
                Expanded(child: _HeroPanel()),
              ],
            )
          : const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCopy(),
                SizedBox(height: 20),
                _HeroPanel(),
              ],
            ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFD5E8E4),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text('跨平台教研工作流'),
        ),
        const SizedBox(height: 16),
        const Text(
          '把备题、整理、组卷和导出，收进同一套工作台。',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.15),
        ),
        const SizedBox(height: 14),
        const Text(
          '优先服务教研场景：按教材章节找题、维护选题篮、沉淀讲义结构，并跟踪导出结果。',
          style: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF35524E)),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.login);
              },
              icon: const Icon(Icons.login),
              label: const Text('登录工作台'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.library);
              },
              icon: const Icon(Icons.search_outlined),
              label: const Text('查看题库原型'),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkspaceEntryStrip extends StatelessWidget {
  const _WorkspaceEntryStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          const SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '下一层已经开始接真实客户端骨架',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  '当前 Flutter 端已经区分工作台首页、题库、登录和租户切换四个入口，下一步可以直接接 API 会话和题目列表。',
                  style: TextStyle(height: 1.45, color: Color(0xFF4C6964)),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.login);
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('登录原型'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.tenantSwitch);
                },
                icon: const Icon(Icons.apartment_outlined),
                label: const Text('租户切换'),
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
                  Navigator.of(context).pushNamed(AppRouter.documents);
                },
                icon: const Icon(Icons.description_outlined),
                label: const Text('文档工作区'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.exports);
                },
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('导出记录'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前聚焦', style: TextStyle(fontSize: 12, color: Color(0xFF52726D))),
          SizedBox(height: 8),
          Text('九年级几何复习讲义', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(height: 16),
          _FocusMetric(label: '选题篮', value: '18 题'),
          _FocusMetric(label: '已关联章节', value: '4 个'),
          _FocusMetric(label: '最近导出', value: '10 分钟前'),
        ],
      ),
    );
  }
}

class _FocusMetric extends StatelessWidget {
  const _FocusMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF52726D))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.card,
    required this.wide,
  });

  final _SummaryCardData card;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 240 : double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.title, style: const TextStyle(color: Color(0xFF52726D))),
          const SizedBox(height: 10),
          Text(card.value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(card.detail, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }
}

class _RecentTasksPanel extends StatelessWidget {
  const _RecentTasksPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('最近任务', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(height: 16),
          _TaskRow(title: '人教版函数单元卷', detail: '待补 2 道综合题'),
          _TaskRow(title: '九上圆专题讲义', detail: '导出完成，等待复查'),
          _TaskRow(title: '中考模拟卷错题回收', detail: '已关联 14 道历史题'),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: Color(0xFF0F766E), shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(color: Color(0xFF52726D))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBasketPanel extends StatelessWidget {
  const _QuestionBasketPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('选题篮', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(height: 16),
          Text('当前已选 18 题，平均难度 2.9。'),
          SizedBox(height: 12),
          Text('按章节分布：'),
          SizedBox(height: 8),
          Text('函数图像 6 题'),
          Text('相似三角形 5 题'),
          Text('圆综合 7 题'),
        ],
      ),
    );
  }
}
