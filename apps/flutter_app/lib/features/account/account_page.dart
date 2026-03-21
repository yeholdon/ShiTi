import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/primary_navigation_bar.dart';
import '../shared/primary_page_scroll_memory.dart';
import '../shared/workspace_shell.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const _pageKey = 'account';

  final ScrollController _scrollController = ScrollController(
    initialScrollOffset: PrimaryPageScrollMemory.offsetFor(_pageKey),
  );
  bool _loggingOut = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_rememberScrollOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _rememberScrollOffset() {
    PrimaryPageScrollMemory.update(_pageKey, _scrollController.offset);
  }

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final nextController = TextEditingController();
    String? dialogError;
    var dialogSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              setDialogState(() {
                dialogSubmitting = true;
                dialogError = null;
              });
              try {
                await AppServices.instance.sessionRepository.changePassword(
                  currentPassword: currentController.text,
                  newPassword: nextController.text,
                );
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                AppServices.instance.clearSession();
                if (!mounted) {
                  return;
                }
                setState(() {
                  _loggingOut = false;
                  _errorMessage = null;
                });
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('密码已修改，请重新登录')),
                );
                Navigator.of(dialogContext).pushNamedAndRemoveUntil(
                  AppRouter.login,
                  (route) => false,
                );
              } on HttpJsonException catch (error) {
                setDialogState(() {
                  dialogSubmitting = false;
                  dialogError = '${error.message}（HTTP ${error.statusCode}）';
                });
              } catch (error) {
                setDialogState(() {
                  dialogSubmitting = false;
                  dialogError = '$error';
                });
              }
            }

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                        '修改密码',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '修改完成后会退出当前会话，需要用新密码重新登录。',
                        style: TextStyle(
                          height: 1.5,
                          color: TelegramPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: currentController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '当前密码',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nextController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '新密码',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: dialogError!),
                      ],
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            TextButton(
                              onPressed: dialogSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: dialogSubmitting ? null : submit,
                              child: Text(
                                dialogSubmitting ? '提交中...' : '确认修改',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    currentController.dispose();
    nextController.dispose();
  }

  Future<void> _logout() async {
    if (_loggingOut) {
      return;
    }
    setState(() {
      _loggingOut = true;
      _errorMessage = null;
    });
    try {
      await AppServices.instance.sessionRepository.logout();
      AppServices.instance.clearSession();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前会话已退出')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.login,
        (route) => false,
      );
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loggingOut = false;
        _errorMessage = '退出失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loggingOut = false;
        _errorMessage = '退出失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final wideDesktop = MediaQuery.sizeOf(context).width >= 1100;
    final pagePadding = workspacePagePadding(context);
    final session = AppServices.instance.session;
    final activeTenant = AppServices.instance.activeTenant;
    final canManageTenantMembers = (activeTenant?.role ?? '') == 'owner' ||
        (activeTenant?.role ?? '') == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: workspaceConstrainedContent(
            context,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                pagePadding.left,
                16,
                pagePadding.right,
                pagePadding.bottom,
              ),
              children: [
                _AccountHeroSection(
                  modeLabel: AppConfig.dataModeLabel,
                  username: session?.username,
                  tenantName: activeTenant?.name,
                  tenantRole: activeTenant?.role,
                ),
                const SizedBox(height: 18),
                WorkspacePanel(
                  padding: workspacePagePadding(context),
                  borderRadius: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WorkspaceEyebrow(
                        label: '账号中心',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '确认当前账号、当前工作区，以及接下来回哪里继续。',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '这里用来确认当前是谁、正在哪个工作区，以及是否需要切换账号或切换机构。',
                        style: TextStyle(
                          height: 1.5,
                          color: TelegramPalette.textMuted,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: TelegramPalette.errorSurface,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: TelegramPalette.errorBorder),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: TelegramPalette.errorText,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (!wideDesktop) ...[
                        _AccountInfoCard(
                          title: '当前账号',
                          icon: Icons.badge_outlined,
                          emptyMessage: '当前还没有登录会话。先登录，再进入机构选择。',
                          items: [
                            if (session != null) ('用户名', session.username),
                            if (session != null) ('访问级别', session.accessLevel),
                            if (session != null) ('令牌预览', session.tokenPreview),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _AccountInfoCard(
                          title: '当前机构',
                          icon: Icons.apartment_outlined,
                          emptyMessage: '当前还没有选择机构。先解析或创建机构，再进入题库和文档。',
                          items: [
                            if (activeTenant != null) ('机构名称', activeTenant.name),
                            if (activeTenant != null) ('机构代码', activeTenant.code),
                            if (activeTenant != null) ('当前角色', activeTenant.role),
                          ],
                        ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _AccountInfoCard(
                                title: '当前账号',
                                icon: Icons.badge_outlined,
                                emptyMessage: '当前还没有登录会话。先登录，再进入机构选择。',
                                items: [
                                  if (session != null) ('用户名', session.username),
                                  if (session != null)
                                    ('访问级别', session.accessLevel),
                                  if (session != null)
                                    ('令牌预览', session.tokenPreview),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _AccountInfoCard(
                                title: '当前机构',
                                icon: Icons.apartment_outlined,
                                emptyMessage:
                                    '当前还没有选择机构。先解析或创建机构，再进入题库和文档。',
                                items: [
                                  if (activeTenant != null)
                                    ('机构名称', activeTenant.name),
                                  if (activeTenant != null)
                                    ('机构代码', activeTenant.code),
                                  if (activeTenant != null)
                                    ('当前角色', activeTenant.role),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),
                      _AccountSecurityCard(
                        hasSession: session != null,
                        onChangePassword:
                            session == null ? null : _showChangePasswordDialog,
                        onGoToLogin: () {
                          Navigator.of(context).pushNamed(AppRouter.login);
                        },
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: compact ? 8 : 12,
                        runSpacing: compact ? 8 : 12,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(context).pushNamed(AppRouter.login);
                            },
                            icon: Icon(
                              session == null
                                  ? Icons.login
                                  : Icons.manage_accounts_outlined,
                            ),
                            label: Text(
                              session == null
                                  ? '去登录'
                                  : (compact ? '账号会话' : '账号与会话'),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(context)
                                  .pushNamed(AppRouter.tenantSwitch);
                            },
                            icon: const Icon(Icons.swap_horiz_outlined),
                            label: Text(
                              activeTenant == null
                                  ? '选择机构'
                                  : (compact ? '切机构' : '切换机构'),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              PrimaryNavigationBar.navigateToSection(
                                context,
                                PrimaryAppSection.home,
                              );
                            },
                            icon: const Icon(Icons.home_outlined),
                            label: Text(compact ? '工作台' : '返回工作台'),
                          ),
                          if (canManageTenantMembers)
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRouter.tenantMembers,
                                );
                              },
                              icon: const Icon(Icons.group_outlined),
                              label: Text(compact ? '成员权限' : '成员与权限'),
                            ),
                          if (session != null)
                            OutlinedButton.icon(
                              onPressed: _loggingOut ? null : _logout,
                              icon: _loggingOut
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.logout),
                              label: Text(
                                _loggingOut
                                    ? '退出中...'
                                    : (compact ? '退出' : '退出登录'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 900
          ? const PrimaryNavigationBar(
              currentSection: PrimaryAppSection.account,
            )
          : null,
    );
  }
}

class _AccountSecurityCard extends StatelessWidget {
  const _AccountSecurityCard({
    required this.hasSession,
    required this.onChangePassword,
    required this.onGoToLogin,
  });

  final bool hasSession;
  final Future<void> Function()? onChangePassword;
  final VoidCallback onGoToLogin;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      backgroundColor: TelegramPalette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline, color: TelegramPalette.accentDark),
              SizedBox(width: 10),
              Text(
                '账号安全',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '如果当前密码需要轮换，可以直接在这里修改。修改成功后会立即退出当前会话，避免旧会话继续保留。',
            style: TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          WorkspaceMetricPill(
            label: '当前状态',
            value: hasSession ? '可修改密码' : '需先登录',
            highlight: hasSession,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: compact ? 8 : 12,
            runSpacing: compact ? 8 : 12,
            children: [
              FilledButton.icon(
                onPressed: hasSession ? () => onChangePassword?.call() : null,
                icon: const Icon(Icons.password_outlined),
                label: const Text('修改密码'),
              ),
              if (!hasSession)
                OutlinedButton.icon(
                  onPressed: onGoToLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('先去登录'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountHeroSection extends StatelessWidget {
  const _AccountHeroSection({
    required this.modeLabel,
    this.username,
    this.tenantName,
    this.tenantRole,
  });

  final String modeLabel;
  final String? username;
  final String? tenantName;
  final String? tenantRole;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final summaryMetrics = Wrap(
      spacing: compact ? 8 : 12,
      runSpacing: compact ? 8 : 12,
      children: [
        WorkspaceMetricPill(
          label: '运行模式',
          value: modeLabel,
          highlight: true,
        ),
        WorkspaceMetricPill(
          label: '当前账号',
          value: username ?? '未登录',
        ),
        WorkspaceMetricPill(
          label: '当前机构',
          value: tenantName ?? '未选择',
        ),
        WorkspaceMetricPill(
          label: '当前角色',
          value: tenantRole ?? '未选择',
        ),
      ],
    );
    return WorkspacePanel(
      padding: workspaceHeroPanelPadding(context),
      borderRadius: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final headlineSize = constraints.maxWidth >= 960 ? 26.0 : 28.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkspaceEyebrow(
                label: '账号与工作区',
                icon: Icons.account_circle_outlined,
              ),
              const SizedBox(height: 14),
              Text(
                '先确认当前身份和机构，再回到教学工作台继续处理内容。',
                style: TextStyle(
                  fontSize: headlineSize,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: const Text(
                  '这里专门用来确认身份和工作区，再回到题库、文档或导出继续处理内容。',
                  style: TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              summaryMetrics,
            ],
          );
        },
      ),
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.items,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return WorkspacePanel(
      padding: workspacePanelPadding(context),
      backgroundColor: TelegramPalette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: TelegramPalette.accentDark),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              emptyMessage,
              style: const TextStyle(
                height: 1.5,
                color: TelegramPalette.textMuted,
              ),
            )
          else
            Wrap(
              spacing: compact ? 8 : 12,
              runSpacing: compact ? 8 : 12,
              children: items
                  .map(
                    (entry) => WorkspaceMetricPill(
                      label: entry.$1,
                      value: entry.$2,
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WorkspaceMessageBanner.error(
      message: message,
      title: '暂时无法完成当前操作',
    );
  }
}
