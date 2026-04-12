import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/validators.dart';
import '../providers/auth_controller.dart';
import '../providers/sms_countdown_controller.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
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
    final countdown = ref.watch(smsCountdownProvider(SmsScene.resetPassword));

    return Scaffold(
      appBar: AppBar(title: const Text('找回密码')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '重置密码',
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
                      labelText: '新密码',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _passwordObscure = !_passwordObscure),
                        icon: Icon(_passwordObscure ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: auth.isBusy ? null : _submit,
                    child: Text(auth.isBusy ? '提交中...' : '重置密码'),
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

    final countdownCtrl = ref.read(smsCountdownProvider(SmsScene.resetPassword).notifier);
    if (countdownCtrl.isRunning) return;

    try {
      final debugCode = await ref.read(authControllerProvider.notifier).sendSmsCode(
            phone: _phoneCtrl.text.trim(),
            scene: smsSceneToApi(SmsScene.resetPassword),
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
      _toast('请先按红色提示修正表单');
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            phone: _phoneCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            newPassword: _passwordCtrl.text,
          );
      if (!mounted) return;
      _toast('密码已重置，请使用新密码登录');
      context.pop();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('重置失败，请稍后再试');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

