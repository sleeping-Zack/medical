class ReminderItem {
  ReminderItem({
    required this.id,
    required this.targetUserId,
    required this.planId,
    required this.scheduleId,
    required this.dueTime,
    required this.status,
    required this.medicineName,
    required this.createdAt,
    this.confirmedAt,
    this.snoozeUntil,
    this.actionSource,
  });

  final String id;
  final int targetUserId;
  final int planId;
  final String scheduleId;
  final DateTime dueTime;
  final String status;
  final String medicineName;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? snoozeUntil;
  final String? actionSource;

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseMaybe(String key) {
      final v = json[key];
      if (v == null) return null;
      return DateTime.tryParse(v as String);
    }

    return ReminderItem(
      id: json['id'] as String,
      targetUserId: (json['target_user_id'] as num).toInt(),
      planId: (json['plan_id'] as num).toInt(),
      scheduleId: json['schedule_id'] as String,
      dueTime: DateTime.parse(json['due_time'] as String),
      status: (json['status'] as String? ?? 'pending').toLowerCase(),
      medicineName: json['medicine_name'] as String? ?? '药品',
      createdAt: DateTime.parse(json['created_at'] as String),
      confirmedAt: parseMaybe('confirmed_at'),
      snoozeUntil: parseMaybe('snooze_until'),
      actionSource: json['action_source'] as String?,
    );
  }
}
