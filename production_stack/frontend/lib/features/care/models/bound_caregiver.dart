class BoundCaregiver {
  BoundCaregiver({
    required this.caregiverId,
    required this.shortId,
    required this.phoneMasked,
    required this.role,
  });

  final int caregiverId;
  final String shortId;
  final String phoneMasked;
  final String role;

  factory BoundCaregiver.fromJson(Map<String, dynamic> json) {
    return BoundCaregiver(
      caregiverId: (json['caregiver_id'] as num).toInt(),
      shortId: json['short_id'] as String? ?? '',
      phoneMasked: json['phone_masked'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }
}
