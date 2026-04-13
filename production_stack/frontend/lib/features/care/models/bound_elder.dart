class BoundElder {
  BoundElder({
    required this.elderId,
    required this.shortId,
    required this.phoneMasked,
    required this.canManageMedicine,
    required this.canViewRecords,
    required this.canReceiveAlerts,
  });

  final int elderId;
  final String shortId;
  final String phoneMasked;
  final bool canManageMedicine;
  final bool canViewRecords;
  final bool canReceiveAlerts;

  factory BoundElder.fromJson(Map<String, dynamic> json) {
    return BoundElder(
      elderId: (json['elder_id'] as num).toInt(),
      shortId: json['short_id'] as String? ?? '',
      phoneMasked: json['phone_masked'] as String? ?? '',
      canManageMedicine: json['can_manage_medicine'] as bool? ?? false,
      canViewRecords: json['can_view_records'] as bool? ?? false,
      canReceiveAlerts: json['can_receive_alerts'] as bool? ?? false,
    );
  }
}
