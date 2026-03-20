import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/auth_session.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/workspace_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController(text: 'teacher_demo');
  final _passwordController = TextEditingController(text: 'demo-password');
  bool _submitting = false;
  bool _registerMode = false;
  AuthSession? _session;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _session = AppServices.instance.session;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final session = _registerMode
          ? await AppServices.instance.sessionRepository.register(
              username: _usernameController.text,
              password: _passwordController.text,
            )
          : await AppServices.instance.sessionRepository.login(
              username: _usernameController.text,
              password: _passwordController.text,
            );
      if (!mounted) {
        return;
      }
      AppServices.instance.setSession(session);
      setState(() {
        _session = session;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _registerMode ? '注册成功，继续选择租户工作区' : '登录成功，继续选择租户工作区',
          ),
        ),
      );
      Navigator.of(context).pushNamed(AppRouter.tenantSwitch);
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage =
            '${_registerMode ? '注册' : '登录'}失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '${_registerMode ? '注册' : '登录'}失败：$error';
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await AppServices.instance.sessionRepository.logout();
      AppServices.instance.clearSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _session = null;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前会话已退出')),
      );
    } on HttpJsonException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '退出失败：${error.message}（HTTP ${error.statusCode}）';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = '退出失败：$error';
      });
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final nextController = TextEditingController();
    String? dialogError;
    var dialogSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
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
                  _session = null;
                  _submitting = false;
                });
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('密码已修改，请重新登录')),
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

  Future<void> _showResetPasswordDialog() async {
    final usernameController =
        TextEditingController(text: _usernameController.text.trim());
    final tokenController = TextEditingController();
    final nextController = TextEditingController();
    var deliveryMode = 'preview';
    String? dialogError;
    String? dialogHint;
    var dialogSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> requestToken() async {
              setDialogState(() {
                dialogSubmitting = true;
                dialogError = null;
                dialogHint = null;
              });
              try {
                final result = await AppServices.instance.sessionRepository
                    .requestPasswordReset(
                  username: usernameController.text,
                  deliveryMode: deliveryMode,
                );
                setDialogState(() {
                  dialogSubmitting = false;
                  if ((result.resetTokenPreview ?? '').isNotEmpty) {
                    tokenController.text = result.resetTokenPreview!;
                    dialogHint = '已生成一次性重置码，已自动填入。'
                        '${result.deliveryTargetHint != null ? '（${result.deliveryTargetHint}）' : ''}'
                        '${result.previewHint ?? ''}';
                  } else if (result.deliveryMode == 'console') {
                    dialogHint = '已按控制台投递方式生成重置码，请查看服务端日志。'
                        '${result.deliveryTransport != null ? '（${result.deliveryTransport}）' : ''}'
                        '${result.previewHint ?? ''}';
                  } else if (result.deliveryMode == 'email') {
                    dialogHint = '已按邮件投递预演方式生成重置码。'
                        '${result.deliveryTargetHint != null ? '（目标：${result.deliveryTargetHint}）' : ''}'
                        '${result.deliveryTransport != null ? '（通道：${result.deliveryTransport}）' : ''}'
                        '${result.previewHint ?? ''}';
                  } else if ((result.previewHint ?? '').isNotEmpty) {
                    dialogHint = '当前仍在冷却窗口内，请继续使用已有重置码。${result.previewHint!}'
                        '${result.cooldownSeconds != null ? '（约 ${result.cooldownSeconds} 秒后可重发）' : ''}';
                  } else {
                    dialogHint = '如果该用户存在，重置流程已经创建。';
                  }
                });
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

            Future<void> submitReset() async {
              setDialogState(() {
                dialogSubmitting = true;
                dialogError = null;
                dialogHint = null;
              });
              try {
                await AppServices.instance.sessionRepository.resetPassword(
                  username: usernameController.text,
                  resetToken: tokenController.text,
                  newPassword: nextController.text,
                );
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                if (!mounted) {
                  return;
                }
                _usernameController.text = usernameController.text;
                _passwordController.text = nextController.text;
                setState(() {
                  _registerMode = false;
                });
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('密码已重置，请直接登录')),
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
                constraints: const BoxConstraints(maxWidth: 520),
                child: WorkspacePanel(
                  borderRadius: 28,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '忘记密码',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '先获取一次性重置码，再设置新密码。重置完成后可以直接登录。',
                          style: TextStyle(
                            height: 1.5,
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: usernameController,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DeliveryModeChip(
                              icon: Icons.visibility_outlined,
                              label: '本机预览',
                              selected: deliveryMode == 'preview',
                              enabled: !dialogSubmitting,
                              onSelected: () {
                                setDialogState(() {
                                  deliveryMode = 'preview';
                                  dialogError = null;
                                  dialogHint = null;
                                });
                              },
                            ),
                            _DeliveryModeChip(
                              icon: Icons.terminal_outlined,
                              label: '控制台投递',
                              selected: deliveryMode == 'console',
                              enabled: !dialogSubmitting,
                              onSelected: () {
                                setDialogState(() {
                                  deliveryMode = 'console';
                                  dialogError = null;
                                  dialogHint = null;
                                });
                              },
                            ),
                            _DeliveryModeChip(
                              icon: Icons.email_outlined,
                              label: '邮件预演',
                              selected: deliveryMode == 'email',
                              enabled: !dialogSubmitting,
                              onSelected: () {
                                setDialogState(() {
                                  deliveryMode = 'email';
                                  dialogError = null;
                                  dialogHint = null;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: tokenController,
                          decoration: const InputDecoration(
                            labelText: '一次性重置码',
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
                        if (dialogHint != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            dialogHint!,
                            style: const TextStyle(
                              color: TelegramPalette.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
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
                              TextButton(
                                onPressed:
                                    dialogSubmitting ? null : requestToken,
                                child: Text(
                                  dialogSubmitting ? '处理中...' : '获取重置码',
                                ),
                              ),
                              FilledButton(
                                onPressed:
                                    dialogSubmitting ? null : submitReset,
                                child: const Text('重置密码'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    usernameController.dispose();
    tokenController.dispose();
    nextController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录工作台')),
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  flex: 6,
                                  child: _LoginHeroPanel(),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 5,
                                  child: _buildAuthPanel(),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                const _LoginHeroPanel(),
                                const SizedBox(height: 18),
                                _buildAuthPanel(),
                              ],
                            ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthPanel() {
    return WorkspaceGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: '登录入口',
            icon: Icons.hub_outlined,
          ),
          const SizedBox(height: 16),
          Text(
            _registerMode ? '创建账号后继续进入工作区' : '登录后继续你的教研流程',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 12),
          _ModeBadge(),
          const SizedBox(height: 14),
          Text(
            _registerMode
                ? '先创建账号，再进入工作区选择。完成后可以继续去题库、文档和导出页工作。'
                : '先建立登录会话，再进入工作区选择。登录状态会在本机保留，之后可以直接回到上次的工作流。',
            style: const TextStyle(
              height: 1.55,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.login),
                label: Text('登录'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.person_add_alt_1),
                label: Text('注册'),
              ),
            ],
            selected: <bool>{_registerMode},
            onSelectionChanged: (selection) {
              setState(() {
                _registerMode = selection.first;
                _session = null;
                _errorMessage = null;
              });
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 22),
          const Text(
            '用户名',
            style: TextStyle(
              fontSize: 13,
              color: TelegramPalette.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              hintText: 'teacher_demo',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '密码',
            style: TextStyle(
              fontSize: 13,
              color: TelegramPalette.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: '输入密码',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _submitting ? null : _showResetPasswordDialog,
              icon: const Icon(Icons.lock_reset),
              label: const Text('忘记密码'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_registerMode ? Icons.person_add_alt_1 : Icons.login),
              label: Text(
                _submitting
                    ? '正在建立会话...'
                    : _registerMode
                        ? '注册并进入租户选择'
                        : '登录并进入工作区选择',
              ),
            ),
          ),
          if (_session != null) ...[
            const SizedBox(height: 20),
            WorkspacePanel(
              padding: const EdgeInsets.all(18),
              backgroundColor: TelegramPalette.surfaceAccent,
              borderColor: TelegramPalette.borderAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前会话：${_session!.username}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('访问级别：${_session!.accessLevel}'),
                  Text('令牌预览：${_session!.tokenPreview}'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.of(context)
                              .pushNamed(AppRouter.tenantSwitch);
                        },
                        icon: const Icon(Icons.apartment_outlined),
                        label: const Text('进入租户选择'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed:
                            _submitting ? null : _showChangePasswordDialog,
                        icon: const Icon(Icons.password_outlined),
                        label: const Text('修改密码'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('退出登录'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoginHeroPanel extends StatelessWidget {
  const _LoginHeroPanel();

  @override
  Widget build(BuildContext context) {
    final hasSession = AppServices.instance.session != null;
    final hasTenant = AppServices.instance.activeTenant != null;
    return WorkspacePanel(
      padding: const EdgeInsets.all(28),
      borderRadius: 30,
      backgroundColor: TelegramPalette.shellDeep,
      borderColor: TelegramPalette.shellDeepSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: 'ShiTi 教研工作台',
            icon: Icons.auto_awesome_outlined,
            foregroundColor: Colors.white,
            backgroundColor: Color(0x223390EC),
          ),
          const SizedBox(height: 20),
          const Text(
            '把登录入口做成真正的工作流起点，而不只是一个表单。',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '题库检索、选题篮、文档编排和导出结果已经连成一条连续流程。这一页现在负责把会话、租户和常用动作清楚地接起来。',
            style: TextStyle(
              color: Color(0xD6FFFFFF),
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              WorkspaceMetricPill(
                label: '会话状态',
                value: hasSession ? '已建立' : '未登录',
                highlight: hasSession,
              ),
              WorkspaceMetricPill(
                label: '租户上下文',
                value: hasTenant ? '已绑定' : '待选择',
                highlight: hasTenant,
              ),
              WorkspaceMetricPill(
                label: '数据模式',
                value: AppConfig.dataModeLabel,
                highlight: !AppConfig.useMockData,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const WorkspaceBulletPoint(
            text: '支持登录、注册、修改密码和找回密码。',
            color: Color(0xFF8BD0FF),
          ),
          const SizedBox(height: 12),
          const WorkspaceBulletPoint(
            text: '完成登录后直接衔接租户工作区，不再让用户在入口页失去方向。',
            color: Color(0xFF8BD0FF),
          ),
          const SizedBox(height: 12),
          const WorkspaceBulletPoint(
            text: '保留轻量但明确的状态提示，让你一眼看清当前用的是样例数据还是真实工作区。',
            color: Color(0xFF8BD0FF),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本轮视觉方向',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '教研驾驶舱',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '浅色玻璃面板 + 深色信息舞台，让工作台入口更像产品首页，也更像控制面板。',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = AppConfig.useMockData
        ? TelegramPalette.warningText
        : TelegramPalette.accentDark;
    final label = AppConfig.useMockData ? '当前模式：样例数据' : '当前模式：真实工作区';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
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

class _DeliveryModeChip extends StatelessWidget {
  const _DeliveryModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return WorkspaceFilterPill(
      label: label,
      selected: selected,
      onTap: enabled ? onSelected : null,
      icon: icon,
    );
  }
}
