import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/validators.dart';
import '../providers/auth_controller.dart';
import '../providers/sms_countdown_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with SingleTickerProviderStateMixin {
  final _passwordFormKey = GlobalKey<FormState>();
  final _smsFormKey = GlobalKey<FormState>();

  final _passwordPhoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _passwordObscure = true;

  final _smsPhoneCtrl = TextEditingController();
  final _smsCodeCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordPhoneCtrl.dispose();
    _passwordCtrl.dispose();
    _smsPhoneCtrl.dispose();
    _smsCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final smsCountdown = ref.watch(smsCountdownProvider(SmsScene.login));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('登录'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '验证码登录'),
              Tab(text: '密码登录'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _SmsLoginTab(
                formKey: _smsFormKey,
                phoneCtrl: _smsPhoneCtrl,
                codeCtrl: _smsCodeCtrl,
                countdown: smsCountdown,
                isBusy: auth.isBusy,
                onSendCode: () => _sendSmsCode(scene: SmsScene.login, phone: _smsPhoneCtrl.text),
                onLogin: _loginWithSms,
              ),
              _PasswordLoginTab(
                formKey: _passwordFormKey,
                phoneCtrl: _passwordPhoneCtrl,
                passwordCtrl: _passwordCtrl,
                obscure: _passwordObscure,
                onToggleObscure: () => setState(() => _passwordObscure = !_passwordObscure),
                isBusy: auth.isBusy,
                onLogin: _loginWithPassword,
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('注册'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('找回密码'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendSmsCode({required SmsScene scene, required String phone}) async {
    final phoneError = validatePhone(phone);
    if (phoneError != null) {
      _toast(phoneError);
      return;
    }

    final countdownCtrl = ref.read(smsCountdownProvider(scene).notifier);
    if (countdownCtrl.isRunning) return;

    try {
      final debugCode = await ref.read(authControllerProvider.notifier).sendSmsCode(
            phone: phone.trim(),
            scene: smsSceneToApi(scene),
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

  Future<void> _loginWithPassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) {
      _toast('请先按红色提示填写手机号和密码');
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).loginWithPassword(
            phone: _passwordPhoneCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('登录失败，请稍后再试');
    }
  }

  Future<void> _loginWithSms() async {
    if (!(_smsFormKey.currentState?.validate() ?? false)) {
      _toast('请先按红色提示填写手机号和验证码');
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).loginWithSms(
            phone: _smsPhoneCtrl.text.trim(),
            code: _smsCodeCtrl.text.trim(),
          );
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('登录失败，请稍后再试');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SmsLoginTab extends StatelessWidget {
  const _SmsLoginTab({
    required this.formKey,
    required this.phoneCtrl,
    required this.codeCtrl,
    required this.countdown,
    required this.isBusy,
    required this.onSendCode,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneCtrl;
  final TextEditingController codeCtrl;
  final int countdown;
  final bool isBusy;
  final VoidCallback onSendCode;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '短信验证码登录',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '手机号'),
                validator: validatePhone,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: codeCtrl,
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
                      onPressed: countdown > 0 || isBusy ? null : onSendCode,
                      child: Text(countdown > 0 ? '${countdown}s' : '获取验证码'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isBusy ? null : onLogin,
                child: Text(isBusy ? '登录中...' : '登录'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordLoginTab extends StatelessWidget {
  const _PasswordLoginTab({
    required this.formKey,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.isBusy,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final bool isBusy;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '手机号密码登录',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '手机号'),
                validator: validatePhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: '密码',
                  suffixIcon: IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
                validator: validatePassword,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isBusy ? null : onLogin,
                child: Text(isBusy ? '登录中...' : '登录'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

