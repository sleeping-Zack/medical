class UserMe {
  UserMe({
    required this.id,
    required this.phone,
    required this.role,
    this.shortId = '',
  });

  final int id;
  final String phone;
  final String role;
  /// 6 位绑定短号（服务端保证登录后必有，用于长辈端展示给家属）
  final String shortId;

  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      id: (json['id'] as num).toInt(),
      phone: json['phone'] as String,
      role: json['role'] as String,
      shortId: (json['short_id'] as String?) ?? '',
    );
  }
}

