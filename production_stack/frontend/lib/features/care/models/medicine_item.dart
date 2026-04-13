class MedicineItem {
  MedicineItem({
    required this.id,
    required this.targetUserId,
    required this.name,
    this.specification,
    this.note,
    required this.archived,
  });

  final int id;
  final int targetUserId;
  final String name;
  final String? specification;
  final String? note;
  final bool archived;

  factory MedicineItem.fromJson(Map<String, dynamic> json) {
    return MedicineItem(
      id: (json['id'] as num).toInt(),
      targetUserId: (json['target_user_id'] as num).toInt(),
      name: json['name'] as String,
      specification: json['specification'] as String?,
      note: json['note'] as String?,
      archived: json['archived'] as bool? ?? false,
    );
  }
}
