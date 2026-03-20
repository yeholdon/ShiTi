import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/tenant_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/primary_navigation_bar.dart';
import '../shared/workspace_shell.dart';

class TenantSwitchPage extends StatefulWidget {
  const TenantSwitchPage({super.key});

  @override
  State<TenantSwitchPage> createState() => _TenantSwitchPageState();
}

class _TenantSwitchPageState extends State<TenantSwitchPage> {
  final _tenantCodeController = TextEditingController(text: 'math-studio');
  final _tenantSearchController = TextEditingController();
  late Future<List<TenantSummary>> _tenantsFuture =
      AppServices.instance.sessionRepository.listTenants();
  TenantSummary? _resolvedTenant;
  bool _resolving = false;
  String? _errorMessage;
  String _roleFilter = 'all';
  String _scopeFilter = 'all';
  String _sortMode = 'list';

  @override
  void dispose() {
    _tenantCodeController.dispose();
    _tenantSearchController.dispose();
    super.dispose();
  }

  List<TenantSummary> _filterTenants(List<TenantSummary> tenants) {
    final query = _tenantSearchController.text.trim().toLowerCase();
    final filtered = tenants.where((tenant) {
      final matchesQuery = query.isEmpty ||
          tenant.name.toLowerCase().contains(query) ||
          tenant.code.toLowerCase().contains(query) ||
          tenant.role.toLowerCase().contains(query);
      final matchesRole = _roleFilter == 'all' || tenant.role == _roleFilter;
      final matchesScope = _scopeFilter == 'all' ||
          (_scopeFilter == 'manageable' && tenant.role != 'member');
      return matchesQuery && matchesRole && matchesScope;
    }).toList();
    switch (_sortMode) {
      case 'name':
        filtered.sort((left, right) => left.name.compareTo(right.name));
      case 'role':
        filtered.sort((left, right) {
          final rankDiff =
              _tenantRoleRank(left.role) - _tenantRoleRank(right.role);
          if (rankDiff != 0) {
            return rankDiff;
          }
          return left.name.compareTo(right.name);
        });
      default:
        break;
    }
    return filtered;
  }

  Future<void> _resolveTenant() async {
    final tenantCode = _tenantCodeController.text.trim();
    if (tenantCode.isEmpty) {
      return;
    }

    setState(() {
      _resolving = true;
      _errorMessage = null;
    });
    try {
      final tenant = await AppServices.instance.sessionRepository
          .resolveTenant(tenantCode);
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedTenant = tenant;
        _resolving = false;
        if (tenant == null) {
          _errorMessage = '未找到租户代码 $tenantCode';
        }
      });
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolving = false;
        _errorMessage = '租户解析失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolving = false;
        _errorMessage = '租户解析失败：$error';
      });
    }
  }

  void _enterTenant(TenantSummary tenant) {
    AppServices.instance.setActiveTenant(tenant);
    PrimaryNavigationBar.navigateToSection(
      context,
      PrimaryAppSection.home,
    );
  }

  void _reloadTenants() {
    setState(() {
      _tenantsFuture = AppServices.instance.sessionRepository.listTenants();
    });
  }

  Future<void> _createTenant() async {
    final created = await showDialog<TenantSummary>(
      context: context,
      builder: (_) => const _CreateTenantDialog(),
    );
    if (created == null || !mounted) {
      return;
    }
    setState(() {
      _resolvedTenant = created;
      _errorMessage = null;
    });
    _reloadTenants();
    _enterTenant(created);
  }

  @override
  Widget build(BuildContext context) {
    final activeTenant = AppServices.instance.activeTenant;
    return Scaffold(
      appBar: AppBar(title: const Text('选择租户工作区')),
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: workspaceConstrainedContent(
            context,
            child: ListView(
              padding: workspacePagePadding(context),
              children: [
                _TenantHeroSection(
                  hasActiveTenant: activeTenant != null,
                  activeTenantName: activeTenant?.name,
                  resolvedTenantName: _resolvedTenant?.name,
                  useMockData: AppConfig.useMockData,
                ),
                const SizedBox(height: 18),
                _TenantSwitcherHeader(
                  tenantCodeController: _tenantCodeController,
                  resolving: _resolving,
                  errorMessage: _errorMessage,
                  onResolveTenant: _resolveTenant,
                  onCreateTenant: _createTenant,
                ),
                const SizedBox(height: 20),
                if (activeTenant != null) ...[
                  _TenantCard(
                    tenant: activeTenant,
                    isActive: true,
                    actionLabel: '回到当前租户',
                    onEnter: () => _enterTenant(activeTenant),
                    onManageMembers: activeTenant.role == 'owner' ||
                            activeTenant.role == 'admin'
                        ? () {
                            AppServices.instance.setActiveTenant(activeTenant);
                            Navigator.of(context)
                                .pushNamed(AppRouter.tenantMembers);
                          }
                        : null,
                  ),
                  const SizedBox(height: 20),
                ],
                if (_resolvedTenant != null &&
                    _resolvedTenant!.id != activeTenant?.id) ...[
                  _TenantCard(
                    tenant: _resolvedTenant!,
                    isActive: _resolvedTenant!.id == activeTenant?.id,
                    actionLabel: '进入当前租户',
                    onEnter: () => _enterTenant(_resolvedTenant!),
                    onManageMembers: _resolvedTenant!.role == 'owner' ||
                            _resolvedTenant!.role == 'admin'
                        ? () {
                            AppServices.instance
                                .setActiveTenant(_resolvedTenant!);
                            Navigator.of(context)
                                .pushNamed(AppRouter.tenantMembers);
                          }
                        : null,
                  ),
                  const SizedBox(height: 20),
                ],
                FutureBuilder<List<TenantSummary>>(
                  future: _tenantsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final tenants = snapshot.data!;
                    final visibleTenants = _filterTenants(tenants);
                    final activeTenantVisible = activeTenant != null &&
                        visibleTenants.any(
                          (tenant) => tenant.id == activeTenant.id,
                        );
                    if (tenants.isEmpty && !AppConfig.useMockData) {
                      return WorkspacePanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '当前账号还没有已加入的租户。你可以直接输入租户代码解析，或先创建一个新的租户工作区。',
                              style: TextStyle(
                                height: 1.5,
                                color: TelegramPalette.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _createTenant,
                              icon: const Icon(Icons.add_business_outlined),
                              label: const Text('创建第一个租户'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (tenants.isEmpty) {
                      return WorkspacePanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '当前还没有可显示的租户工作区。',
                              style: TextStyle(
                                height: 1.5,
                                color: TelegramPalette.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _createTenant,
                              icon: const Icon(Icons.add_business_outlined),
                              label: const Text('创建第一个租户'),
                            ),
                          ],
                        ),
                      );
                    }
                    return WorkspacePanel(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const WorkspaceEyebrow(
                            label: '租户目录',
                            icon: Icons.apartment_outlined,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '先定位工作区，再决定是直接进入，还是继续查看成员。',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '这里负责解析工作区代码、整理当前可见列表，并标出哪些工作区可以直接进入。',
                            style: TextStyle(
                              height: 1.5,
                              color: TelegramPalette.textMuted,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _tenantSearchController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: '搜索租户',
                              hintText: '按名称、代码或角色筛选',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _TenantFilterChip(
                                label: '全部角色',
                                selected: _roleFilter == 'all',
                                onTap: () =>
                                    setState(() => _roleFilter = 'all'),
                              ),
                              _TenantFilterChip(
                                label: '所有者',
                                selected: _roleFilter == 'owner',
                                onTap: () =>
                                    setState(() => _roleFilter = 'owner'),
                              ),
                              _TenantFilterChip(
                                label: '管理员',
                                selected: _roleFilter == 'admin',
                                onTap: () =>
                                    setState(() => _roleFilter = 'admin'),
                              ),
                              _TenantFilterChip(
                                label: '成员',
                                selected: _roleFilter == 'member',
                                onTap: () =>
                                    setState(() => _roleFilter = 'member'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _TenantFilterChip(
                                label: '全部租户',
                                selected: _scopeFilter == 'all',
                                onTap: () =>
                                    setState(() => _scopeFilter = 'all'),
                              ),
                              _TenantFilterChip(
                                label: '仅看可管理',
                                selected: _scopeFilter == 'manageable',
                                onTap: () =>
                                    setState(() => _scopeFilter = 'manageable'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _sortMode,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: '排序',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'list',
                                child: Text('列表顺序'),
                              ),
                              DropdownMenuItem(
                                  value: 'name', child: Text('按名称')),
                              DropdownMenuItem(
                                  value: 'role', child: Text('按角色')),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _sortMode = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              WorkspaceMetricPill(
                                label: '总租户',
                                value: '${tenants.length}',
                                highlight: true,
                              ),
                              WorkspaceMetricPill(
                                label: '当前结果',
                                value: '${visibleTenants.length}',
                              ),
                              WorkspaceMetricPill(
                                label: '所有者',
                                value:
                                    '${visibleTenants.where((tenant) => tenant.role == 'owner').length}',
                              ),
                              WorkspaceMetricPill(
                                label: '管理员',
                                value:
                                    '${visibleTenants.where((tenant) => tenant.role == 'admin').length}',
                              ),
                              WorkspaceMetricPill(
                                label: '成员',
                                value:
                                    '${visibleTenants.where((tenant) => tenant.role == 'member').length}',
                              ),
                              WorkspaceMetricPill(
                                label: '可管理',
                                value:
                                    '${visibleTenants.where((tenant) => tenant.role == 'owner' || tenant.role == 'admin').length}',
                              ),
                              if (activeTenant != null)
                                WorkspaceMetricPill(
                                  label: '当前工作区',
                                  value: activeTenantVisible ? '已包含' : '已隐藏',
                                ),
                            ],
                          ),
                          if (_roleFilter != 'all' ||
                              _scopeFilter != 'all' ||
                              _sortMode != 'list' ||
                              _tenantSearchController.text
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (_roleFilter != 'all')
                                  _TenantInfoChip(
                                    label: '角色',
                                    value: switch (_roleFilter) {
                                      'owner' => '所有者',
                                      'admin' => '管理员',
                                      _ => '成员',
                                    },
                                  ),
                                if (_scopeFilter != 'all')
                                  const _TenantInfoChip(
                                    label: '范围',
                                    value: '仅看可管理',
                                  ),
                                if (_sortMode != 'list')
                                  _TenantInfoChip(
                                    label: '排序',
                                    value: switch (_sortMode) {
                                      'name' => '按名称',
                                      'role' => '按角色',
                                      _ => '列表顺序',
                                    },
                                  ),
                                if (_tenantSearchController.text
                                    .trim()
                                    .isNotEmpty)
                                  _TenantInfoChip(
                                    label: '搜索',
                                    value: _tenantSearchController.text.trim(),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (visibleTenants.isEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '没有符合当前搜索或范围条件的租户。',
                                  style: TextStyle(
                                    color: TelegramPalette.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    _tenantSearchController.clear();
                                    setState(() {
                                      _roleFilter = 'all';
                                      _scopeFilter = 'all';
                                      _sortMode = 'list';
                                    });
                                  },
                                  icon: const Icon(Icons.restart_alt),
                                  label: const Text('恢复默认视图'),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: visibleTenants
                                  .map(
                                    (tenant) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: _TenantCard(
                                        tenant: tenant,
                                        isActive: tenant.id == activeTenant?.id,
                                        onEnter: () => _enterTenant(tenant),
                                        onManageMembers: tenant.role ==
                                                    'owner' ||
                                                tenant.role == 'admin'
                                            ? () {
                                                AppServices.instance
                                                    .setActiveTenant(tenant);
                                                Navigator.of(context).pushNamed(
                                                  AppRouter.tenantMembers,
                                                );
                                              }
                                            : null,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TenantHeroSection extends StatelessWidget {
  const _TenantHeroSection({
    required this.hasActiveTenant,
    required this.useMockData,
    this.activeTenantName,
    this.resolvedTenantName,
  });

  final bool hasActiveTenant;
  final bool useMockData;
  final String? activeTenantName;
  final String? resolvedTenantName;

  @override
  Widget build(BuildContext context) {
    final summaryMetrics = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        WorkspaceMetricPill(
          label: '当前模式',
          value: AppConfig.dataModeLabel,
          highlight: true,
        ),
        WorkspaceMetricPill(
          label: '活跃租户',
          value: hasActiveTenant ? (activeTenantName ?? '已选择') : '未选择',
        ),
        WorkspaceMetricPill(
          label: '最近解析',
          value: resolvedTenantName ?? '还未解析',
        ),
      ],
    );
    return WorkspacePanel(
      padding: const EdgeInsets.all(24),
      borderRadius: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useDesktopHero = constraints.maxWidth >= 960;
          final leadingContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkspaceEyebrow(
                label: '租户工作区',
                icon: Icons.domain_verification_outlined,
              ),
              const SizedBox(height: 14),
              const Text(
                '先确认工作区边界，再进入当前租户继续处理题库和文档。',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: useDesktopHero ? 560 : double.infinity,
                ),
                child: Text(
                  useMockData
                      ? '当前使用样例数据，工作区列表和页面反馈都来自本地演示内容。'
                      : '当前连接真实工作区，租户解析和成员权限都会按线上数据返回。',
                  style: const TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
              ),
              if (!useDesktopHero) ...[
                const SizedBox(height: 18),
                summaryMetrics,
              ],
            ],
          );

          if (!useDesktopHero) {
            return leadingContent;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leadingContent),
              const SizedBox(width: 28),
              SizedBox(
                width: 320,
                child: WorkspacePanel(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: TelegramPalette.surfaceRaised,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '当前摘要',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: TelegramPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      summaryMetrics,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TenantSwitcherHeader extends StatelessWidget {
  const _TenantSwitcherHeader({
    required this.tenantCodeController,
    required this.resolving,
    required this.errorMessage,
    required this.onResolveTenant,
    required this.onCreateTenant,
  });

  final TextEditingController tenantCodeController;
  final bool resolving;
  final String? errorMessage;
  final Future<void> Function() onResolveTenant;
  final Future<void> Function() onCreateTenant;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      padding: const EdgeInsets.all(24),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: '租户解析',
            icon: Icons.travel_explore_outlined,
          ),
          const SizedBox(height: 14),
          const Text(
            '解析租户代码，或直接创建新的教研工作区。',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppConfig.useMockData
                  ? TelegramPalette.warningSurface
                  : TelegramPalette.surfaceAccent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              AppConfig.useMockData ? '样例数据：列表来自本地演示内容' : '真实工作区：按代码读取在线工作区',
              style: TextStyle(
                color: AppConfig.useMockData
                    ? TelegramPalette.warningText
                    : TelegramPalette.accentDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            WorkspaceMessageBanner.error(
              title: '当前还不能进入工作区',
              message: errorMessage!,
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            '题库、讲义和试卷都会跟着当前工作区切换。当前会话和上次进入的工作区会保留在本机，刷新后可以继续回到原来的位置。',
            style: TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: tenantCodeController,
            decoration: const InputDecoration(
              labelText: '租户代码',
              hintText: '例如 math-studio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: resolving ? null : onResolveTenant,
            icon: resolving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore_outlined),
            label: Text(resolving ? '解析中...' : '按租户代码解析'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onCreateTenant,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('创建新租户'),
          ),
        ],
      ),
    );
  }
}

class _CreateTenantDialog extends StatefulWidget {
  const _CreateTenantDialog();

  @override
  State<_CreateTenantDialog> createState() => _CreateTenantDialogState();
}

class _CreateTenantDialogState extends State<_CreateTenantDialog> {
  final _codeController = TextEditingController(text: 'new-workspace');
  final _nameController = TextEditingController(text: '新建教研工作区');
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final createdTenant =
          await AppServices.instance.sessionRepository.createTenant(
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
      );
      var resolvedRole = createdTenant.role;
      try {
        final membership =
            await AppServices.instance.sessionRepository.joinCurrentTenant(
          tenantCode: createdTenant.code,
          role: 'owner',
        );
        resolvedRole = membership.role;
      } on HttpJsonException catch (error) {
        if (error.statusCode != 401 && error.statusCode != 403) {
          rethrow;
        }
      }
      final tenant = TenantSummary(
        id: createdTenant.id,
        code: createdTenant.code,
        name: createdTenant.name,
        role: resolvedRole,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(tenant);
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '创建租户失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '创建租户失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: WorkspacePanel(
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '创建租户',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                '填写租户代码和名称，创建后会直接进入该工作区。',
                style: TextStyle(
                  height: 1.5,
                  color: TelegramPalette.textMuted,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                WorkspaceMessageBanner.error(
                  title: '还不能创建租户',
                  message: _errorMessage!,
                  padding: const EdgeInsets.all(12),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '租户代码',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '租户名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(_submitting ? '创建中...' : '创建并进入'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.onEnter,
    this.onManageMembers,
    this.actionLabel = '进入',
    this.isActive = false,
  });

  final TenantSummary tenant;
  final VoidCallback onEnter;
  final VoidCallback? onManageMembers;
  final String actionLabel;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;
          return isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TenantCardHeader(tenant: tenant, isActive: isActive),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.tonal(
                          onPressed: onEnter,
                          child: Text(actionLabel),
                        ),
                        if (onManageMembers != null)
                          OutlinedButton(
                            onPressed: onManageMembers,
                            child: const Text('成员与权限'),
                          ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child:
                          _TenantCardHeader(tenant: tenant, isActive: isActive),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FilledButton.tonal(
                          onPressed: onEnter,
                          child: Text(actionLabel),
                        ),
                        if (onManageMembers != null) ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: onManageMembers,
                            child: const Text('成员与权限'),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
        },
      ),
    );
  }
}

class _TenantCardHeader extends StatelessWidget {
  const _TenantCardHeader({
    required this.tenant,
    required this.isActive,
  });

  final TenantSummary tenant;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: TelegramPalette.surfaceAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.domain_outlined,
            color: TelegramPalette.accentDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tenant.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (isActive) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: TelegramPalette.surfaceAccent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: TelegramPalette.border),
                  ),
                  child: const Text(
                    '当前工作区',
                    style: TextStyle(
                      color: TelegramPalette.accentDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${tenant.code} · ${tenant.role}',
                style: const TextStyle(color: TelegramPalette.textSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TenantInfoChip extends StatelessWidget {
  const _TenantInfoChip({
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
        color: TelegramPalette.surface,
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

class _TenantFilterChip extends StatelessWidget {
  const _TenantFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WorkspaceFilterPill(
      label: label,
      selected: selected,
      onTap: onTap,
      showSelectedCheckmark: true,
    );
  }
}

int _tenantRoleRank(String role) {
  return switch (role) {
    'owner' => 0,
    'admin' => 1,
    _ => 2,
  };
}
