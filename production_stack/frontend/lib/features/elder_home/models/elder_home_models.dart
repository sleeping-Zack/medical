/// 长辈端首页数据模型（可与后端 DTO 对齐）

enum IntakeRecordStatus {
  /// 已触发提醒
  notified,
  /// 已服下
  taken,
  /// 已选择稍后再服
  snoozed,
  /// 已过计划时间未完成（柔和展示，非医疗判定）
  missed,
  /// 今日本次跳过
  skipped,
  /// 尚未到点
  pending,
  /// 本次提醒已删除（通常不展示）
  deleted,
}

extension IntakeRecordStatusX on IntakeRecordStatus {
  String get friendlyLabel {
    switch (this) {
      case IntakeRecordStatus.notified:
        return '已提醒';
      case IntakeRecordStatus.taken:
        return '已服下';
      case IntakeRecordStatus.snoozed:
        return '稍后再服';
      case IntakeRecordStatus.missed:
        return '未按时';
      case IntakeRecordStatus.skipped:
        return '今日跳过';
      case IntakeRecordStatus.pending:
        return '待服用';
      case IntakeRecordStatus.deleted:
        return '已删除';
    }
  }
}

/// 今日一条服药记录（时间轴）
class ElderTodayIntakeRecord {
  const ElderTodayIntakeRecord({
    required this.id,
    required this.targetUserId,
    required this.planId,
    required this.scheduleId,
    required this.scheduledTime,
    required this.medicineName,
    required this.dosageLabel,
    required this.status,
    this.snoozeUntil,
  });

  final String id;
  final int targetUserId;
  final int planId;
  final String scheduleId;
  final DateTime scheduledTime;
  final String medicineName;
  final String dosageLabel;
  final IntakeRecordStatus status;
  final DateTime? snoozeUntil;
}

/// 主卡片状态
enum ElderMainCardPhase {
  /// 有待服，且未到点
  upcoming,
  /// 到点提醒中
  dueNow,
  /// 用户点了稍后再服
  snoozed,
  /// 今日全部完成
  allDone,
  /// 存在未按时记录（仍可有下一剂）
  hasMissed,
}

/// 最近一天趋势（柱状图）
class ElderDayTrend {
  const ElderDayTrend({
    required this.weekdayLabel,
    required this.completedDoses,
    required this.scheduledDoses,
  });

  final String weekdayLabel;
  final int completedDoses;
  final int scheduledDoses;

  double get rate => scheduledDoses <= 0 ? 0 : (completedDoses / scheduledDoses).clamp(0.0, 1.0);
}

/// 绑定家人（展示用）
class ElderFamilyMember {
  const ElderFamilyMember({
    required this.id,
    required this.displayName,
    required this.relationLabel,
    this.phone,
    this.avatarEmoji = '👤',
  });

  final String id;
  final String displayName;
  final String relationLabel;
  final String? phone;
  final String avatarEmoji;
}
