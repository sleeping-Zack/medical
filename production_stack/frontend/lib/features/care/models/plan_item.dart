class PlanItem {
  PlanItem({
    required this.id,
    required this.targetUserId,
    required this.medicineId,
    required this.medicineName,
    required this.status,
    required this.startDate,
    required this.schedulesJson,
    this.label,
  });

  final int id;
  final int targetUserId;
  final int medicineId;
  final String medicineName;
  final String status;
  final String startDate;
  final List<dynamic> schedulesJson;
  final String? label;

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      id: (json['id'] as num).toInt(),
      targetUserId: (json['target_user_id'] as num).toInt(),
      medicineId: (json['medicine_id'] as num).toInt(),
      medicineName: json['medicine_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      schedulesJson: (json['schedules_json'] as List<dynamic>?) ?? const [],
      label: json['label'] as String?,
    );
  }
}
