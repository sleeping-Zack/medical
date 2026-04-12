import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/validators.dart';
import '../providers/auth_controller.dart';
import '../providers/sms_countdown_controller.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'personal';
  bool _passwordObscure = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final countdown = ref.watch(smsCountdownProvider(SmsScene.register));

    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '创建账号',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '手机号'),
                    validator: validatePhone,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '验证码'),
                          validator: validateSmsCode,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 140,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: countdown > 0 || auth.isBusy ? null : _sendCode,
                          child: Text(countdown > 0 ? '${countdown}s' : '获取验证码'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _passwordObscure,
                    decoration: InputDecoration(
                      labelText: '设置密码',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _passwordObscure = !_passwordObscure),
                        icon: Icon(_passwordObscure ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '选择角色',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'personal',
                            label: Text('家属端'),
                            icon: Icon(Icons.family_restroom),
                          ),
                          ButtonSegment<String>(
                            value: 'elderly',
                            label: Text('老人端'),
                            icon: Icon(Icons.accessible),
                          ),
                        ],
                        selected: {_role},
                        onSelectionChanged: auth.isBusy
                            ? null
                            : (selection) {
                                if (selection.isNotEmpty) {
                                  setState(() => _role = selection.first);
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _role == 'personal' ? '家属端：管理用药计划' : '老人端：被提醒并执行',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: auth.isBusy ? null : _submit,
                    child: Text(auth.isBusy ? '注册中...' : '注册并登录'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendCode() async {
    final phoneError = validatePhone(_phoneCtrl.text);
    if (phoneError != null) {
      _toast(phoneError);
      return;
    }
    final countdownCtrl = ref.read(smsCountdownProvider(SmsScene.register).notifier);
    if (countdownCtrl.isRunning) return;

    try {
      final debugCode = await ref.read(authControllerProvider.notifier).sendSmsCode(
            phone: _phoneCtrl.text.trim(),
            scene: smsSceneToApi(SmsScene.register),
          );
      countdownCtrl.start(seconds: 60);
      if (!mounted) return;
      _toast(debugCode == null ? '验证码已发送' : '验证码已发送（开发环境：$debugCode）');
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('发送失败，请稍后再试');
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _toast('请先按红色提示修正：手机号 11 位、验证码 6 位、密码至少 8 位且含字母和数字');
      return;
    }

    try {
      await ref.read(authControllerProvider.notifier).register(
            phone: _phoneCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            password: _passwordCtrl.text,
            role: _role,
          );
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('注册失败，请稍后再试');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

