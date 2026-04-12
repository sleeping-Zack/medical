class UserMe {
  UserMe({required this.id, required this.phone, required this.role});

  final int id;
  final String phone;
  final String role;

  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      id: (json['id'] as num).toInt(),
      phone: json['phone'] as String,
      role: json['role'] as String,
    );
  }
}

