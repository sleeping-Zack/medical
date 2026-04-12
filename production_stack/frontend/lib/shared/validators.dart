final _phoneReg = RegExp(r'^1[3-9]\d{9}$');
final _smsCodeReg = RegExp(r'^\d{6}$');
final _passwordReg = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$');

String? validatePhone(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return '请输入手机号';
  if (!_phoneReg.hasMatch(v)) return '请输入有效的 11 位中国大陆手机号';
  return null;
}

String? validateSmsCode(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return '请输入验证码';
  if (!_smsCodeReg.hasMatch(v)) return '请输入 6 位短信验证码';
  return null;
}

String? validatePassword(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return '请输入密码';
  if (!_passwordReg.hasMatch(v)) return '密码至少 8 位，且必须包含字母和数字';
  return null;
}

