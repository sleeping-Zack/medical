import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/validators.dart';
import '../providers/auth_controller.dart';
import '../providers/auth_state.dart';
import '../providers/sms_countdown_controller.dart';

/// 与 Web `AuthScreen.tsx` 同结构：白底、品牌、登录|注册分段、表单、安装提示、条款。
class AuthScreenPage extends ConsumerStatefulWidget {
  const AuthScreenPage({super.key, this.initialRegister = false});

  final bool initialRegister;

  @override
  ConsumerState<AuthScreenPage> createState() => _AuthScreenPageState();
}

class _AuthScreenPageState extends ConsumerState<AuthScreenPage> {
  static final RegExp _strongPassword = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$');

  late bool _isLogin;

  final _phoneCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _passwordObscure = true;

  /// Web `caregiver` → API `personal`；Web `elder` → API `elderly`
  String _apiRole = 'personal';

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.initialRegister;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _smsCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final countdown = ref.watch(smsCountdownProvider(SmsScene.register));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                const SizedBox(height: 8),
                _brand(),
                const SizedBox(height: 28),
                _loginRegisterSegment(),
                const SizedBox(height: 24),
                if (!_isLogin) ..._registerRolePicker(),
                _fieldLabel('手机号'),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: _inputDec('请输入11位手机号'),
                  onChanged: (v) {
                    final d = v.replaceAll(RegExp(r'\D'), '');
                    if (d != v) {
                      _phoneCtrl.value = TextEditingValue(text: d, selection: TextSelection.collapsed(offset: d.length));
                    }
                  },
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  _fieldLabel('验证码'),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _smsCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: _inputDec('6位数字'),
                          onChanged: (v) {
                            final d = v.replaceAll(RegExp(r'\D'), '');
                            if (d != v) {
                              _smsCtrl.value = TextEditingValue(text: d, selection: TextSelection.collapsed(offset: d.length));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEFF6FF),
                            foregroundColor: const Color(0xFF2563EB),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: countdown > 0 || auth.isBusy || _phoneCtrl.text.length != 11 ? null : _sendRegisterSms,
                          child: Text(
                            auth.isBusy ? '发送中…' : (countdown > 0 ? '${countdown}s 后重发' : '获取验证码'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '测试阶段：随意输入6位数字即可',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _fieldLabel('密码'),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _passwordObscure,
                  decoration: _inputDec(_isLogin ? '请输入密码' : '至少8位，含字母+数字').copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _passwordObscure = !_passwordObscure),
                      icon: Icon(_passwordObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _primarySubmit(auth),
                if (_isLogin) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('找回密码', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 20),
                _installBlock(),
                const SizedBox(height: 16),
                Text(
                  '登录即表示您同意我们的 服务条款 和 隐私政策。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.medication_rounded, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 16),
        Text(
          '智能用药提醒',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Text(
          '您的家庭健康守护助手',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _loginRegisterSegment() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _segBtn('登录', _isLogin, () => setState(() => _isLogin = true))),
          Expanded(child: _segBtn('注册', !_isLogin, () => setState(() => _isLogin = false))),
        ],
      ),
    );
  }

  Widget _segBtn(String label, bool sel, VoidCallback onTap) {
    return Material(
      color: sel ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      elevation: sel ? 1 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: sel ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _registerRolePicker() {
    return [
      const Align(
        alignment: Alignment.centerLeft,
        child: Text('我是...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _roleCard(
              title: '看护人',
              subtitle: '为家人设置提醒',
              selected: _apiRole == 'personal',
              border: const Color(0xFF2563EB),
              fill: const Color(0xFFEFF6FF),
              titleColor: const Color(0xFF1E3A8A),
              onTap: () => setState(() => _apiRole = 'personal'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _roleCard(
              title: '长辈',
              subtitle: '接收吃药提醒',
              selected: _apiRole == 'elderly',
              border: const Color(0xFFEA580C),
              fill: const Color(0xFFFFF7ED),
              titleColor: const Color(0xFF9A3412),
              onTap: () => setState(() => _apiRole = 'elderly'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
    ];
  }

  Widget _roleCard({
    required String title,
    required String subtitle,
    required bool selected,
    required Color border,
    required Color fill,
    required Color titleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? fill : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? border : const Color(0xFFF1F5F9), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: selected ? titleColor : const Color(0xFF334155))),
                  if (selected) Icon(Icons.check_circle, color: border, size: 22),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String t) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
      ),
    );
  }

  Widget _primarySubmit(AuthState auth) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
        ),
        onPressed: auth.isBusy ? null : _submit,
        child: auth.isBusy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(_isLogin ? '登录' : '注册并登录', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _installBlock() {
    return Column(
      children: [
        const Divider(color: Color(0xFFF1F5F9), height: 32),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: const Color(0xFFF8FAFC),
            foregroundColor: const Color(0xFF475569),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('原生 App 已安装；若从浏览器使用，请用浏览器菜单「添加到主屏幕」')),
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_outlined, size: 22),
              SizedBox(width: 8),
              Text('安装到手机桌面 (推荐)', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '安装后可像原生 App 一样使用，体验更佳',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Future<void> _sendRegisterSms() async {
    final err = validatePhone(_phoneCtrl.text);
    if (err != null) {
      _toast('请输入正确的11位手机号');
      return;
    }
    final cd = ref.read(smsCountdownProvider(SmsScene.register).notifier);
    if (cd.isRunning) return;
    try {
      final debug = await ref.read(authControllerProvider.notifier).sendSmsCode(
            phone: _phoneCtrl.text.trim(),
            scene: smsSceneToApi(SmsScene.register),
          );
      cd.start(seconds: 60);
      if (!mounted) return;
      _toast(debug == null ? '验证码已发送，请查收短信' : '验证码已发送。开发环境验证码：$debug');
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('发送失败');
    }
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 11) {
      _toast('请输入正确的11位手机号');
      return;
    }
    if (_isLogin) {
      if (_passwordCtrl.text.isEmpty) {
        _toast('请输入密码');
        return;
      }
      try {
        await ref.read(authControllerProvider.notifier).loginWithPassword(phone: phone, password: _passwordCtrl.text);
      } on ApiException catch (e) {
        _toast(e.message);
      } catch (_) {
        _toast('登录失败，请重试');
      }
    } else {
      if (!_strongPassword.hasMatch(_passwordCtrl.text)) {
        _toast('密码至少 8 位，且必须同时包含字母和数字（与后端一致）');
        return;
      }
      final code = _smsCtrl.text.trim();
      if (code.length != 6) {
        _toast('请输入 6 位短信验证码（须先点击获取验证码）');
        return;
      }
      try {
        await ref.read(authControllerProvider.notifier).register(
              phone: phone,
              code: code,
              password: _passwordCtrl.text,
              role: _apiRole,
            );
      } on ApiException catch (e) {
        _toast(e.message);
      } catch (_) {
        _toast('注册失败，请重试');
      }
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}
