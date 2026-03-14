import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/tenant_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';

class TenantSwitchPage extends StatefulWidget {
  const TenantSwitchPage({super.key});

  @override
  State<TenantSwitchPage> createState() => _TenantSwitchPageState();
}

class _TenantSwitchPageState extends State<TenantSwitchPage> {
  final _tenantCodeController = TextEditingController(text: 'math-studio');
  late Future<List<TenantSummary>> _tenantsFuture =
      AppServices.instance.sessionRepository.listTenants();
  TenantSummary? _resolvedTenant;
  bool _resolving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tenantCodeController.dispose();
    super.dispose();
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
      final tenant =
          await AppServices.instance.sessionRepository.resolveTenant(tenantCode);
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
    Navigator.of(context).pushNamed(AppRouter.home);
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
    return Scaffold(
      appBar: AppBar(title: const Text('选择租户工作区')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _TenantSwitcherHeader(
            tenantCodeController: _tenantCodeController,
            resolving: _resolving,
            errorMessage: _errorMessage,
            onResolveTenant: _resolveTenant,
            onCreateTenant: _createTenant,
          ),
          const SizedBox(height: 20),
          if (_resolvedTenant != null) ...[
            _TenantCard(
              tenant: _resolvedTenant!,
              actionLabel: '进入当前租户',
              onEnter: () => _enterTenant(_resolvedTenant!),
              onManageMembers: _resolvedTenant!.role == 'owner' || _resolvedTenant!.role == 'admin'
                  ? () {
                      AppServices.instance.setActiveTenant(_resolvedTenant!);
                      Navigator.of(context).pushNamed(AppRouter.tenantMembers);
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
              if (tenants.isEmpty && !AppConfig.useMockData) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      '当前账号还没有已加入的租户。你可以直接输入租户代码解析，或先创建一个新的租户工作区。',
                      style: TextStyle(
                        height: 1.5,
                        color: TelegramPalette.textMuted,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: tenants
                    .map(
                      (tenant) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _TenantCard(
                          tenant: tenant,
                          onEnter: () => _enterTenant(tenant),
                          onManageMembers: tenant.role == 'owner' || tenant.role == 'admin'
                              ? () {
                                  AppServices.instance.setActiveTenant(tenant);
                                  Navigator.of(context).pushNamed(AppRouter.tenantMembers);
                                }
                              : null,
                        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '多租户工作区',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppConfig.useMockData
                    ? TelegramPalette.warningSurface
                    : TelegramPalette.surfaceAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                AppConfig.useMockData
                    ? 'MOCK 模式：列表来自本地假数据'
                    : 'REMOTE 模式：按租户代码解析真实后端',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TelegramPalette.errorSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TelegramPalette.errorBorder),
                ),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: TelegramPalette.errorText,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const Text(
              '题库、讲义、试卷和审计记录都按租户隔离。用户端这里先做进入哪个工作区的选择页，后面再接真实会话状态与持久化。',
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
      final tenant = await AppServices.instance.sessionRepository.createTenant(
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
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
    return AlertDialog(
      title: const Text('创建租户'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: TelegramPalette.errorText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
            ],
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '创建中...' : '创建并进入'),
        ),
      ],
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.onEnter,
    this.onManageMembers,
    this.actionLabel = '进入',
  });

  final TenantSummary tenant;
  final VoidCallback onEnter;
  final VoidCallback? onManageMembers;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tenant.code} · ${tenant.role}',
                    style: const TextStyle(color: TelegramPalette.textSoft),
                  ),
                ],
              ),
            ),
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
                    child: const Text('成员管理'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
