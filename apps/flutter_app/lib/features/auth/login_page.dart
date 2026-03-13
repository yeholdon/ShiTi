import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/auth_session.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../router/app_router.dart';

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
            _registerMode
                ? '注册成功，继续选择租户工作区'
                : '登录成功，继续选择租户工作区',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录工作台')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '连接教研工作区',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _ModeBadge(),
                      const SizedBox(height: 12),
                      Text(
                        _registerMode
                            ? '先创建一个用户会话，再进入租户选择。当前后端注册只要求用户名，密码字段暂作占位。'
                            : '先建立登录会话，再进入租户选择。后续这里会接真实 JWT 登录和多租户切换。',
                        style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 24),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          _submitting
                              ? '正在建立会话...'
                              : _registerMode
                                  ? '注册并进入租户选择'
                                  : '登录并获取租户',
                        ),
                      ),
                      if (_session != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F3F0),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '当前会话：${_session!.username}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text('访问级别：${_session!.accessLevel}'),
                              Text('Token preview：${_session!.tokenPreview}'),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  Navigator.of(context).pushNamed(AppRouter.tenantSwitch);
                                },
                                icon: const Icon(Icons.apartment_outlined),
                                label: const Text('进入租户选择'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = AppConfig.useMockData
        ? const Color(0xFFB7791F)
        : const Color(0xFF0F766E);
    final label = AppConfig.useMockData ? '当前模式：MOCK 本地数据' : '当前模式：REMOTE 真实接口';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF9F1239), height: 1.4),
      ),
    );
  }
}
